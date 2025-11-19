package com.notchtodo.domain.model

import java.util.Date
import java.util.UUID

/**
 * Domain model for a Task.
 * Represents the business logic layer, independent of data sources.
 */
data class Task(
    val id: UUID,
    val title: String,
    val notes: String = "",
    val status: TaskStatus = TaskStatus.OUTSTANDING,
    val priority: Int = 1,
    val isCompleted: Boolean = false,
    val dueDate: Date? = null,
    val orbId: UUID? = null,
    val sortOrder: Double = 0.0,
    val createdAt: Date = Date(),
    val updatedAt: Date = Date(),
    val version: Long = 0,
    val deletedAt: Date? = null
) {
    /**
     * Three-state status system
     */
    enum class TaskStatus(val value: Int) {
        OUTSTANDING(1),
        IN_PROGRESS(2),
        COMPLETE(3);

        companion object {
            fun fromValue(value: Int): TaskStatus {
                return entries.find { it.value == value } ?: OUTSTANDING
            }
        }

        fun getDisplayName(): String = when (this) {
            OUTSTANDING -> "Outstanding"
            IN_PROGRESS -> "In Progress"
            COMPLETE -> "Complete"
        }

        fun getIconName(): String = when (this) {
            OUTSTANDING -> "circle"
            IN_PROGRESS -> "circle_half"
            COMPLETE -> "check_circle"
        }
    }

    /**
     * Calculate the number of notes/lines in the details
     */
    fun getNoteCount(): Int {
        if (notes.isEmpty()) return 0
        val lines = notes.split("\n")
            .map { it.trim() }
            .filter { it.isNotEmpty() }
        return lines.size
    }

    /**
     * Check if task is overdue
     */
    fun isOverdue(): Boolean {
        return dueDate?.let { it.before(Date()) && !isCompleted } ?: false
    }

    /**
     * Check if task is due today
     */
    fun isDueToday(): Boolean {
        // Simple check - can be enhanced with proper date comparison
        return dueDate?.let {
            val today = Date()
            it.date == today.date && it.month == today.month && it.year == today.year
        } ?: false
    }

    /**
     * Get priority display
     */
    fun getPriorityDisplay(): String = when (priority) {
        1 -> "Low"
        2 -> "Medium"
        3 -> "High"
        else -> "Normal"
    }

    companion object {
        /**
         * Create a new task with default values
         */
        fun create(
            title: String,
            orbId: UUID? = null,
            status: TaskStatus = TaskStatus.OUTSTANDING
        ): Task {
            return Task(
                id = UUID.randomUUID(),
                title = title,
                orbId = orbId,
                status = status,
                createdAt = Date(),
                updatedAt = Date()
            )
        }
    }
}
