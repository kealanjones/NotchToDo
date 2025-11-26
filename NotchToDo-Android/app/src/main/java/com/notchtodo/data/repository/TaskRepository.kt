package com.notchtodo.data.repository

import com.notchtodo.data.local.dao.TaskDao
import com.notchtodo.data.local.entities.TaskEntity
import com.notchtodo.data.local.entities.toDomain
import com.notchtodo.data.local.entities.toEntity
import com.notchtodo.data.remote.SupabaseApi
import com.notchtodo.data.remote.dto.*
import com.notchtodo.domain.model.Task
import com.notchtodo.util.DateUtils
import com.notchtodo.util.DebugLog
import com.notchtodo.util.RetryHelper
import com.notchtodo.util.SecurePreferences
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map
import java.util.Date
import java.util.UUID
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Repository for Task operations.
 * Implements offline-first architecture with bidirectional sync.
 */
@Singleton
class TaskRepository @Inject constructor(
    private val taskDao: TaskDao,
    private val api: SupabaseApi,
    private val securePreferences: SecurePreferences,
    private val authRepository: AuthRepository
) {

    // ==================== Local Operations ====================

    fun observeAllTasks(): Flow<List<Task>> {
        return taskDao.observeAllTasks().map { entities ->
            entities.map { it.toDomain() }
        }
    }

    fun observeTasksByOrb(orbId: UUID): Flow<List<Task>> {
        return taskDao.observeTasksByOrb(orbId.toString()).map { entities ->
            entities.map { it.toDomain() }
        }
    }

    fun observeTasksByStatus(status: Task.TaskStatus): Flow<List<Task>> {
        return taskDao.observeTasksByStatus(status.value).map { entities ->
            entities.map { it.toDomain() }
        }
    }

    fun observeTask(taskId: UUID): Flow<Task?> {
        return taskDao.observeTask(taskId.toString()).map { it?.toDomain() }
    }

    suspend fun getTask(taskId: UUID): Task? {
        return taskDao.getTask(taskId.toString())?.toDomain()
    }

    fun searchTasks(query: String): Flow<List<Task>> {
        return taskDao.searchTasks(query).map { entities ->
            entities.map { it.toDomain() }
        }
    }

    // ==================== CRUD Operations ====================

    suspend fun createTask(task: Task): Result<Task> {
        return try {
            DebugLog.log("Creating task: ${task.title}", DebugLog.Category.DATA)

            // Save to local database
            val entity = task.toEntity().copy(syncPending = true)
            taskDao.insert(entity)

            // Sync to remote
            syncTaskToRemote(task)

            Result.success(task)
        } catch (e: Exception) {
            DebugLog.error("Failed to create task", e, DebugLog.Category.DATA)
            Result.failure(e)
        }
    }

    suspend fun updateTask(task: Task): Result<Task> {
        return try {
            DebugLog.log("Updating task: ${task.title}", DebugLog.Category.DATA)

            val updatedTask = task.copy(updatedAt = Date())
            val entity = updatedTask.toEntity().copy(syncPending = true)
            taskDao.update(entity)

            // Sync to remote
            syncTaskToRemote(updatedTask)

            Result.success(updatedTask)
        } catch (e: Exception) {
            DebugLog.error("Failed to update task", e, DebugLog.Category.DATA)
            Result.failure(e)
        }
    }

    suspend fun deleteTask(taskId: UUID): Result<Unit> {
        return try {
            DebugLog.log("Deleting task: $taskId", DebugLog.Category.DATA)

            // Soft delete locally
            taskDao.softDelete(taskId.toString())

            // Sync to remote
            val userId = authRepository.getUserId()
            if (userId != null) {
                try {
                    val response = api.softDeleteTask(
                        idFilter = "eq.${taskId}",
                        deletedAt = mapOf("deleted_at" to DateUtils.formatISO8601(Date()))
                    )
                    if (!response.isSuccessful) {
                        DebugLog.error("Remote delete failed: ${response.code()}", category = DebugLog.Category.SYNC)
                    }
                } catch (e: Exception) {
                    DebugLog.error("Failed to sync delete to remote", e, DebugLog.Category.SYNC)
                }
            }

            Result.success(Unit)
        } catch (e: Exception) {
            DebugLog.error("Failed to delete task", e, DebugLog.Category.DATA)
            Result.failure(e)
        }
    }

    suspend fun updateTaskStatus(taskId: UUID, status: Task.TaskStatus): Result<Unit> {
        return try {
            val now = Date().time
            taskDao.updateStatus(taskId.toString(), status.value, now)

            // Sync to remote
            val userId = authRepository.getUserId()
            if (userId != null) {
                try {
                    val updates = TaskUpdateRequest(status = status.value)
                    api.updateTask(idFilter = "eq.${taskId}", updates = updates)
                } catch (e: Exception) {
                    DebugLog.error("Failed to sync status update", e, DebugLog.Category.SYNC)
                }
            }

            Result.success(Unit)
        } catch (e: Exception) {
            DebugLog.error("Failed to update task status", e, DebugLog.Category.DATA)
            Result.failure(e)
        }
    }

    // ==================== Sync Operations ====================

    suspend fun syncTasks(): Result<Unit> {
        return try {
            val userId = authRepository.getUserId() ?: return Result.failure(Exception("Not authenticated"))

            DebugLog.log("Starting task sync", DebugLog.Category.SYNC)

            // Fetch remote tasks
            val response = api.getTasks()
            if (response.isSuccessful) {
                val remoteTasks = response.body() ?: emptyList()
                DebugLog.log("Fetched ${remoteTasks.size} tasks from remote", DebugLog.Category.SYNC)

                // Upsert to local database
                val entities = remoteTasks.map { it.toEntity() }
                taskDao.upsertTasks(entities)

                // Push pending local changes
                pushPendingTasks()

                // Update last sync time
                securePreferences.saveLastSyncTime(System.currentTimeMillis())

                DebugLog.log("Task sync completed", DebugLog.Category.SYNC)
                Result.success(Unit)
            } else {
                val error = "Sync failed: ${response.code()}"
                DebugLog.error(error, category = DebugLog.Category.SYNC)
                Result.failure(Exception(error))
            }
        } catch (e: Exception) {
            DebugLog.error("Task sync failed", e, DebugLog.Category.SYNC)
            Result.failure(e)
        }
    }

    private suspend fun pushPendingTasks() {
        try {
            val pendingTasks = taskDao.getPendingSyncTasks()
            DebugLog.log("Pushing ${pendingTasks.size} pending tasks", DebugLog.Category.SYNC)

            pendingTasks.forEach { entity ->
                syncTaskToRemote(entity.toDomain())
            }
        } catch (e: Exception) {
            DebugLog.error("Failed to push pending tasks", e, DebugLog.Category.SYNC)
        }
    }

    private suspend fun syncTaskToRemote(task: Task) {
        val userId = authRepository.getUserId() ?: run {
            DebugLog.log("Cannot sync task: not authenticated", DebugLog.Category.SYNC)
            return
        }

        RetryHelper.withRetryOrNull(RetryHelper.networkConfig) {
            // Check if task exists on remote
            val existingResponse = api.getTask(idFilter = "eq.${task.id}")

            if (existingResponse.isSuccessful && existingResponse.body()?.isNotEmpty() == true) {
                // Update existing task
                val updates = TaskUpdateRequest(
                    title = task.title,
                    notes = task.notes.ifEmpty { null },
                    status = task.status.value,
                    priority = task.priority,
                    isCompleted = task.isCompleted,
                    dueDate = task.dueDate?.let { DateUtils.formatISO8601(it) },
                    orbId = task.orbId?.toString(),
                    sortOrder = task.sortOrder
                )
                val updateResponse = api.updateTask(idFilter = "eq.${task.id}", updates = updates)
                if (!updateResponse.isSuccessful) {
                    throw Exception("Update failed: ${updateResponse.code()}")
                }
            } else {
                // Create new task
                val createRequest = task.toCreateRequest()
                val createResponse = api.createTask(createRequest)
                if (!createResponse.isSuccessful) {
                    throw Exception("Create failed: ${createResponse.code()}")
                }
            }

            // Mark as synced
            taskDao.updateSyncPending(task.id.toString(), false)
            DebugLog.log("Successfully synced task: ${task.title}", DebugLog.Category.SYNC)
        } ?: DebugLog.error("Failed to sync task after retries: ${task.title}", category = DebugLog.Category.SYNC)
    }
}
