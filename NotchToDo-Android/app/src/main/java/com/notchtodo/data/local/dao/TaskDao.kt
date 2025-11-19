package com.notchtodo.data.local.dao

import androidx.room.*
import com.notchtodo.data.local.entities.TaskEntity
import kotlinx.coroutines.flow.Flow

/**
 * Data Access Object for Task operations.
 */
@Dao
interface TaskDao {

    @Query("SELECT * FROM tasks WHERE deleted_at IS NULL ORDER BY sort_order ASC, created_at DESC")
    fun observeAllTasks(): Flow<List<TaskEntity>>

    @Query("SELECT * FROM tasks WHERE deleted_at IS NULL AND orb_id = :orbId ORDER BY sort_order ASC, created_at DESC")
    fun observeTasksByOrb(orbId: String): Flow<List<TaskEntity>>

    @Query("SELECT * FROM tasks WHERE deleted_at IS NULL AND status = :status ORDER BY sort_order ASC, created_at DESC")
    fun observeTasksByStatus(status: Int): Flow<List<TaskEntity>>

    @Query("SELECT * FROM tasks WHERE deleted_at IS NULL AND id = :taskId")
    fun observeTask(taskId: String): Flow<TaskEntity?>

    @Query("SELECT * FROM tasks WHERE deleted_at IS NULL AND id = :taskId")
    suspend fun getTask(taskId: String): TaskEntity?

    @Query("SELECT * FROM tasks WHERE deleted_at IS NULL")
    suspend fun getAllTasks(): List<TaskEntity>

    @Query("SELECT * FROM tasks WHERE deleted_at IS NULL AND orb_id = :orbId")
    suspend fun getTasksByOrb(orbId: String): List<TaskEntity>

    @Query("""
        SELECT * FROM tasks
        WHERE deleted_at IS NULL
        AND (title LIKE '%' || :query || '%' OR notes LIKE '%' || :query || '%')
        ORDER BY sort_order ASC, created_at DESC
    """)
    fun searchTasks(query: String): Flow<List<TaskEntity>>

    @Query("SELECT * FROM tasks WHERE sync_pending = 1")
    suspend fun getPendingSyncTasks(): List<TaskEntity>

    @Query("SELECT * FROM tasks WHERE updated_at > :since")
    suspend fun getTasksUpdatedSince(since: Long): List<TaskEntity>

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insert(task: TaskEntity)

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertAll(tasks: List<TaskEntity>)

    @Update
    suspend fun update(task: TaskEntity)

    @Query("UPDATE tasks SET deleted_at = :deletedAt WHERE id = :taskId")
    suspend fun softDelete(taskId: String, deletedAt: Long = System.currentTimeMillis())

    @Delete
    suspend fun delete(task: TaskEntity)

    @Query("DELETE FROM tasks WHERE id = :taskId")
    suspend fun deleteById(taskId: String)

    @Query("DELETE FROM tasks WHERE deleted_at IS NOT NULL AND deleted_at < :before")
    suspend fun deleteOldSoftDeletedTasks(before: Long)

    @Query("UPDATE tasks SET sync_pending = :pending WHERE id = :taskId")
    suspend fun updateSyncPending(taskId: String, pending: Boolean)

    @Query("UPDATE tasks SET status = :status, updated_at = :updatedAt WHERE id = :taskId")
    suspend fun updateStatus(taskId: String, status: Int, updatedAt: Long = System.currentTimeMillis())

    @Query("UPDATE tasks SET is_completed = :isCompleted, updated_at = :updatedAt WHERE id = :taskId")
    suspend fun updateCompleted(taskId: String, isCompleted: Boolean, updatedAt: Long = System.currentTimeMillis())

    @Query("SELECT COUNT(*) FROM tasks WHERE deleted_at IS NULL")
    suspend fun getTaskCount(): Int

    @Query("SELECT COUNT(*) FROM tasks WHERE deleted_at IS NULL AND orb_id = :orbId")
    suspend fun getTaskCountByOrb(orbId: String): Int

    @Query("SELECT COUNT(*) FROM tasks WHERE deleted_at IS NULL AND status = :status")
    suspend fun getTaskCountByStatus(status: Int): Int

    @Transaction
    suspend fun upsertTask(task: TaskEntity) {
        val existing = getTask(task.id)
        if (existing == null) {
            insert(task)
        } else {
            // Only update if remote version is newer
            if (task.version >= existing.version) {
                insert(task)
            }
        }
    }

    @Transaction
    suspend fun upsertTasks(tasks: List<TaskEntity>) {
        tasks.forEach { upsertTask(it) }
    }
}
