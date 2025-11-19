package com.notchtodo.data.remote.dto

import com.google.gson.annotations.SerializedName
import com.notchtodo.data.local.entities.TaskEntity
import com.notchtodo.domain.model.Task
import java.util.Date
import java.util.UUID

/**
 * Data Transfer Object for Task from Supabase API.
 * Maps to the 'tasks' table in PostgreSQL.
 */
data class TaskDto(
    @SerializedName("id")
    val id: String,

    @SerializedName("user_id")
    val userId: String? = null,

    @SerializedName("orb_id")
    val orbId: String? = null,

    @SerializedName("title")
    val title: String,

    @SerializedName("notes")
    val notes: String? = null,

    @SerializedName("status")
    val status: Int = 1,

    @SerializedName("priority")
    val priority: Int = 1,

    @SerializedName("is_completed")
    val isCompleted: Boolean = false,

    @SerializedName("due_date")
    val dueDate: String? = null, // ISO8601 timestamp

    @SerializedName("sort_order")
    val sortOrder: Double = 0.0,

    @SerializedName("version")
    val version: Long = 0,

    @SerializedName("created_at")
    val createdAt: String,

    @SerializedName("updated_at")
    val updatedAt: String,

    @SerializedName("deleted_at")
    val deletedAt: String? = null
)

/**
 * Request body for creating/updating a task
 */
data class TaskCreateRequest(
    @SerializedName("id")
    val id: String? = null,

    @SerializedName("orb_id")
    val orbId: String? = null,

    @SerializedName("title")
    val title: String,

    @SerializedName("notes")
    val notes: String? = null,

    @SerializedName("status")
    val status: Int = 1,

    @SerializedName("priority")
    val priority: Int = 1,

    @SerializedName("is_completed")
    val isCompleted: Boolean = false,

    @SerializedName("due_date")
    val dueDate: String? = null,

    @SerializedName("sort_order")
    val sortOrder: Double = 0.0
)

/**
 * Request body for updating a task
 */
data class TaskUpdateRequest(
    @SerializedName("title")
    val title: String? = null,

    @SerializedName("notes")
    val notes: String? = null,

    @SerializedName("status")
    val status: Int? = null,

    @SerializedName("priority")
    val priority: Int? = null,

    @SerializedName("is_completed")
    val isCompleted: Boolean? = null,

    @SerializedName("due_date")
    val dueDate: String? = null,

    @SerializedName("orb_id")
    val orbId: String? = null,

    @SerializedName("sort_order")
    val sortOrder: Double? = null
)

/**
 * Conversion functions
 */
fun TaskDto.toEntity(): TaskEntity {
    return TaskEntity(
        id = id,
        title = title,
        notes = notes ?: "",
        status = status,
        priority = priority,
        isCompleted = isCompleted,
        dueDate = dueDate?.let { parseISO8601(it)?.time },
        orbId = orbId,
        sortOrder = sortOrder,
        createdAt = parseISO8601(createdAt)?.time ?: System.currentTimeMillis(),
        updatedAt = parseISO8601(updatedAt)?.time ?: System.currentTimeMillis(),
        version = version,
        deletedAt = deletedAt?.let { parseISO8601(it)?.time },
        syncPending = false
    )
}

fun Task.toDto(userId: String): TaskDto {
    return TaskDto(
        id = id.toString(),
        userId = userId,
        orbId = orbId?.toString(),
        title = title,
        notes = notes.ifEmpty { null },
        status = status.value,
        priority = priority,
        isCompleted = isCompleted,
        dueDate = dueDate?.let { formatISO8601(it) },
        sortOrder = sortOrder,
        version = version,
        createdAt = formatISO8601(createdAt),
        updatedAt = formatISO8601(updatedAt),
        deletedAt = deletedAt?.let { formatISO8601(it) }
    )
}

fun Task.toCreateRequest(): TaskCreateRequest {
    return TaskCreateRequest(
        id = id.toString(),
        orbId = orbId?.toString(),
        title = title,
        notes = notes.ifEmpty { null },
        status = status.value,
        priority = priority,
        isCompleted = isCompleted,
        dueDate = dueDate?.let { formatISO8601(it) },
        sortOrder = sortOrder
    )
}

/**
 * ISO8601 date parsing and formatting helpers
 */
private fun parseISO8601(dateString: String): Date? {
    return try {
        val formatter = java.text.SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSSSSS'Z'", java.util.Locale.US)
        formatter.timeZone = java.util.TimeZone.getTimeZone("UTC")
        formatter.parse(dateString)
    } catch (e: Exception) {
        try {
            val formatter = java.text.SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss'Z'", java.util.Locale.US)
            formatter.timeZone = java.util.TimeZone.getTimeZone("UTC")
            formatter.parse(dateString)
        } catch (e2: Exception) {
            null
        }
    }
}

private fun formatISO8601(date: Date): String {
    val formatter = java.text.SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSSSSS'Z'", java.util.Locale.US)
    formatter.timeZone = java.util.TimeZone.getTimeZone("UTC")
    return formatter.format(date)
}
