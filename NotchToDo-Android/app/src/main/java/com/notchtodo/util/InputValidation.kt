package com.notchtodo.util

import java.util.Date

/**
 * Input validation utilities for task and orb creation.
 */
object InputValidation {
    
    // MARK: - Configuration
    
    data class Config(
        val maxTitleLength: Int = 500,
        val maxOrbNameLength: Int = 100,
        val maxNotesLength: Int = 10000,
        val validPriorityRange: IntRange = 1..5,
        val validStatusRange: IntRange = 1..3,
        val allowPastDeadlines: Boolean = false
    ) {
        companion object {
            val DEFAULT = Config()
        }
    }
    
    // MARK: - Validation Results
    
    sealed class ValidationResult<out T> {
        data class Success<T>(val value: T) : ValidationResult<T>()
        data class Error(val error: ValidationError) : ValidationResult<Nothing>()
        
        fun getOrNull(): T? = (this as? Success)?.value
        fun getOrThrow(): T = when (this) {
            is Success -> value
            is Error -> throw IllegalArgumentException(error.message)
        }
    }
    
    enum class ValidationError(val message: String, val suggestion: String) {
        EMPTY_TITLE(
            "Task title cannot be empty",
            "Please enter a title for your task"
        ),
        TITLE_TOO_LONG(
            "Task title is too long",
            "Try shortening the title"
        ),
        TITLE_INVALID_CHARACTERS(
            "Task title contains invalid characters",
            "Remove any special characters from the title"
        ),
        EMPTY_ORB_NAME(
            "Project name cannot be empty",
            "Please enter a name for your project"
        ),
        ORB_NAME_TOO_LONG(
            "Project name is too long",
            "Try shortening the project name"
        ),
        INVALID_PRIORITY(
            "Priority value is invalid",
            "Set priority to a value between 1 and 5"
        ),
        INVALID_STATUS(
            "Status value is invalid",
            "Set status to a valid value"
        ),
        DEADLINE_IN_PAST(
            "Deadline cannot be in the past",
            "Choose a deadline in the future"
        ),
        NOTES_TOO_LONG(
            "Notes are too long",
            "Try shortening the notes"
        )
    }
    
    // MARK: - Task Validation
    
    /**
     * Validates task title and returns sanitized title or error.
     */
    fun validateTaskTitle(
        title: String,
        config: Config = Config.DEFAULT
    ): ValidationResult<String> {
        val trimmed = title.trim()
        
        if (trimmed.isEmpty()) {
            return ValidationResult.Error(ValidationError.EMPTY_TITLE)
        }
        
        if (trimmed.length > config.maxTitleLength) {
            return ValidationResult.Error(ValidationError.TITLE_TOO_LONG)
        }
        
        // Check for control characters (but allow unicode)
        if (trimmed.any { it.isISOControl() && !it.isWhitespace() }) {
            return ValidationResult.Error(ValidationError.TITLE_INVALID_CHARACTERS)
        }
        
        return ValidationResult.Success(trimmed)
    }
    
    /**
     * Validates task priority.
     */
    fun validatePriority(
        priority: Int,
        config: Config = Config.DEFAULT
    ): ValidationResult<Int> {
        if (priority !in config.validPriorityRange) {
            return ValidationResult.Error(ValidationError.INVALID_PRIORITY)
        }
        return ValidationResult.Success(priority)
    }
    
    /**
     * Validates task status.
     */
    fun validateStatus(
        status: Int,
        config: Config = Config.DEFAULT
    ): ValidationResult<Int> {
        if (status !in config.validStatusRange) {
            return ValidationResult.Error(ValidationError.INVALID_STATUS)
        }
        return ValidationResult.Success(status)
    }
    
    /**
     * Validates deadline.
     */
    fun validateDeadline(
        deadline: Date?,
        config: Config = Config.DEFAULT
    ): ValidationResult<Date?> {
        if (deadline == null) return ValidationResult.Success(null)
        
        if (!config.allowPastDeadlines) {
            // Allow some tolerance (5 minutes) for recently set deadlines
            val tolerance = 5 * 60 * 1000L
            if (deadline.time + tolerance < System.currentTimeMillis()) {
                return ValidationResult.Error(ValidationError.DEADLINE_IN_PAST)
            }
        }
        
        return ValidationResult.Success(deadline)
    }
    
    /**
     * Validates notes/details.
     */
    fun validateNotes(
        notes: String?,
        config: Config = Config.DEFAULT
    ): ValidationResult<String> {
        if (notes == null) return ValidationResult.Success("")
        
        val trimmed = notes.trim()
        if (trimmed.length > config.maxNotesLength) {
            return ValidationResult.Error(ValidationError.NOTES_TOO_LONG)
        }
        
        return ValidationResult.Success(trimmed)
    }
    
    // MARK: - Orb Validation
    
    /**
     * Validates orb name and returns sanitized name or error.
     */
    fun validateOrbName(
        name: String,
        config: Config = Config.DEFAULT
    ): ValidationResult<String> {
        val trimmed = name.trim()
        
        if (trimmed.isEmpty()) {
            return ValidationResult.Error(ValidationError.EMPTY_ORB_NAME)
        }
        
        if (trimmed.length > config.maxOrbNameLength) {
            return ValidationResult.Error(ValidationError.ORB_NAME_TOO_LONG)
        }
        
        return ValidationResult.Success(trimmed)
    }
    
    // MARK: - Convenience Methods
    
    /**
     * Sanitizes a string by trimming whitespace and limiting length.
     */
    fun sanitize(input: String, maxLength: Int): String {
        val trimmed = input.trim()
        return if (trimmed.length <= maxLength) trimmed else trimmed.take(maxLength)
    }
    
    /**
     * Checks if a string is a valid non-empty input.
     */
    fun isValidInput(input: String): Boolean {
        return input.trim().isNotEmpty()
    }
}
