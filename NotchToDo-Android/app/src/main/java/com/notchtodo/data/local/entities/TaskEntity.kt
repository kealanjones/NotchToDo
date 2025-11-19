package com.notchtodo.data.local.entities

import androidx.room.ColumnInfo
import androidx.room.Entity
import androidx.room.ForeignKey
import androidx.room.Index
import androidx.room.PrimaryKey
import com.notchtodo.domain.model.Task
import java.util.Date
import java.util.UUID

/**
 * Room entity for Task table.
 * Represents the local database schema.
 */
@Entity(
    tableName = "tasks",
    foreignKeys = [
        ForeignKey(
            entity = OrbEntity::class,
            parentColumns = ["id"],
            childColumns = ["orb_id"],
            onDelete = ForeignKey.CASCADE
        )
    ],
    indices = [
        Index("orb_id"),
        Index("status"),
        Index("updated_at"),
        Index("created_at")
    ]
)
data class TaskEntity(
    @PrimaryKey
    @ColumnInfo(name = "id")
    val id: String,

    @ColumnInfo(name = "title")
    val title: String,

    @ColumnInfo(name = "notes")
    val notes: String = "",

    @ColumnInfo(name = "status")
    val status: Int = 1, // 1=Outstanding, 2=In Progress, 3=Complete

    @ColumnInfo(name = "priority")
    val priority: Int = 1,

    @ColumnInfo(name = "is_completed")
    val isCompleted: Boolean = false,

    @ColumnInfo(name = "due_date")
    val dueDate: Long? = null,

    @ColumnInfo(name = "orb_id")
    val orbId: String? = null,

    @ColumnInfo(name = "sort_order")
    val sortOrder: Double = 0.0,

    @ColumnInfo(name = "created_at")
    val createdAt: Long,

    @ColumnInfo(name = "updated_at")
    val updatedAt: Long,

    @ColumnInfo(name = "version")
    val version: Long = 0,

    @ColumnInfo(name = "deleted_at")
    val deletedAt: Long? = null,

    @ColumnInfo(name = "sync_pending")
    val syncPending: Boolean = false
)

/**
 * Converter functions between TaskEntity and Task domain model
 */
fun TaskEntity.toDomain(): Task {
    return Task(
        id = UUID.fromString(id),
        title = title,
        notes = notes,
        status = Task.TaskStatus.fromValue(status),
        priority = priority,
        isCompleted = isCompleted,
        dueDate = dueDate?.let { Date(it) },
        orbId = orbId?.let { UUID.fromString(it) },
        sortOrder = sortOrder,
        createdAt = Date(createdAt),
        updatedAt = Date(updatedAt),
        version = version,
        deletedAt = deletedAt?.let { Date(it) }
    )
}

fun Task.toEntity(): TaskEntity {
    return TaskEntity(
        id = id.toString(),
        title = title,
        notes = notes,
        status = status.value,
        priority = priority,
        isCompleted = isCompleted,
        dueDate = dueDate?.time,
        orbId = orbId?.toString(),
        sortOrder = sortOrder,
        createdAt = createdAt.time,
        updatedAt = updatedAt.time,
        version = version,
        deletedAt = deletedAt?.time,
        syncPending = false
    )
}
