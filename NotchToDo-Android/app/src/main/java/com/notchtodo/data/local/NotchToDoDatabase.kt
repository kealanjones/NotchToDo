package com.notchtodo.data.local

import androidx.room.Database
import androidx.room.RoomDatabase
import com.notchtodo.data.local.dao.OrbDao
import com.notchtodo.data.local.dao.TaskDao
import com.notchtodo.data.local.entities.OrbEntity
import com.notchtodo.data.local.entities.TaskEntity

/**
 * Room database for NotchToDo.
 * Version 1: Initial schema with tasks and orbs.
 */
@Database(
    entities = [
        TaskEntity::class,
        OrbEntity::class
    ],
    version = 1,
    exportSchema = true
)
abstract class NotchToDoDatabase : RoomDatabase() {
    abstract fun taskDao(): TaskDao
    abstract fun orbDao(): OrbDao

    companion object {
        const val DATABASE_NAME = "notchtodo_database"
    }
}
