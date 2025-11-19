package com.notchtodo

import android.app.Application
import androidx.work.*
import com.notchtodo.util.DebugLog
import com.notchtodo.workers.SyncWorker
import dagger.hilt.android.HiltAndroidApp
import java.util.concurrent.TimeUnit

/**
 * Application class for NotchToDo.
 */
@HiltAndroidApp
class NotchToDoApplication : Application() {

    override fun onCreate() {
        super.onCreate()

        DebugLog.log("NotchToDo application starting", DebugLog.Category.GENERAL)

        // Enable debug logging in debug builds
        if (BuildConfig.DEBUG) {
            DebugLog.enableAll()
        }

        // Schedule periodic sync
        scheduleSyncWork()
    }

    private fun scheduleSyncWork() {
        val constraints = Constraints.Builder()
            .setRequiredNetworkType(NetworkType.CONNECTED)
            .build()

        val syncRequest = PeriodicWorkRequestBuilder<SyncWorker>(
            15, TimeUnit.MINUTES,
            5, TimeUnit.MINUTES
        )
            .setConstraints(constraints)
            .setBackoffCriteria(
                BackoffPolicy.EXPONENTIAL,
                WorkRequest.MIN_BACKOFF_MILLIS,
                TimeUnit.MILLISECONDS
            )
            .build()

        WorkManager.getInstance(this).enqueueUniquePeriodicWork(
            "sync_work",
            ExistingPeriodicWorkPolicy.KEEP,
            syncRequest
        )

        DebugLog.log("Scheduled periodic sync work", DebugLog.Category.SYNC)
    }
}
