package com.notchtodo.workers

import android.content.Context
import androidx.hilt.work.HiltWorker
import androidx.work.CoroutineWorker
import androidx.work.WorkerParameters
import com.notchtodo.data.repository.AuthRepository
import com.notchtodo.data.repository.OrbRepository
import com.notchtodo.data.repository.TaskRepository
import com.notchtodo.util.DebugLog
import dagger.assisted.Assisted
import dagger.assisted.AssistedInject

/**
 * Background worker for syncing data with Supabase.
 */
@HiltWorker
class SyncWorker @AssistedInject constructor(
    @Assisted context: Context,
    @Assisted params: WorkerParameters,
    private val authRepository: AuthRepository,
    private val taskRepository: TaskRepository,
    private val orbRepository: OrbRepository
) : CoroutineWorker(context, params) {

    override suspend fun doWork(): Result {
        return try {
            DebugLog.log("Starting background sync", DebugLog.Category.SYNC)

            // Check if authenticated
            if (!authRepository.isAuthenticated()) {
                DebugLog.log("Not authenticated, skipping sync", DebugLog.Category.SYNC)
                return Result.success()
            }

            // Refresh token if needed
            val session = authRepository.getCurrentSession()
            if (session?.needsRefresh() == true) {
                val refreshResult = authRepository.refreshToken()
                if (refreshResult.isFailure) {
                    DebugLog.error("Token refresh failed during sync", category = DebugLog.Category.SYNC)
                    return Result.retry()
                }
            }

            // Sync orbs first (as tasks depend on orbs)
            val orbResult = orbRepository.syncOrbs()
            if (orbResult.isFailure) {
                DebugLog.error("Orb sync failed", category = DebugLog.Category.SYNC)
                return Result.retry()
            }

            // Sync tasks
            val taskResult = taskRepository.syncTasks()
            if (taskResult.isFailure) {
                DebugLog.error("Task sync failed", category = DebugLog.Category.SYNC)
                return Result.retry()
            }

            DebugLog.log("Background sync completed successfully", DebugLog.Category.SYNC)
            Result.success()
        } catch (e: Exception) {
            DebugLog.error("Background sync failed", e, DebugLog.Category.SYNC)
            Result.retry()
        }
    }
}
