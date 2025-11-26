package com.notchtodo.util

import java.net.SocketTimeoutException
import java.net.UnknownHostException
import retrofit2.HttpException

/**
 * User-friendly error handling utilities for Android.
 */
object UserFacingError {
    
    /**
     * Represents an error that can be shown to the user.
     */
    data class DisplayableError(
        val title: String,
        val message: String,
        val suggestion: String? = null,
        val isRetryable: Boolean = false,
        val underlyingException: Throwable? = null
    )
    
    // MARK: - Network Errors
    
    val networkUnavailable = DisplayableError(
        title = "No Connection",
        message = "Unable to connect to the server. Please check your internet connection.",
        suggestion = "Make sure you're connected to Wi-Fi or have cellular data enabled.",
        isRetryable = true
    )
    
    val serverError = DisplayableError(
        title = "Server Error",
        message = "Something went wrong on our end. Please try again later.",
        suggestion = "If this problem persists, contact support.",
        isRetryable = true
    )
    
    val timeout = DisplayableError(
        title = "Request Timed Out",
        message = "The request took too long to complete.",
        suggestion = "Please check your connection and try again.",
        isRetryable = true
    )
    
    // MARK: - Authentication Errors
    
    val sessionExpired = DisplayableError(
        title = "Session Expired",
        message = "Your session has expired. Please sign in again.",
        suggestion = "Tap 'Sign In' to continue.",
        isRetryable = false
    )
    
    val invalidCredentials = DisplayableError(
        title = "Invalid Credentials",
        message = "The email or password you entered is incorrect.",
        suggestion = "Please check your credentials and try again.",
        isRetryable = false
    )
    
    val accountLocked = DisplayableError(
        title = "Account Locked",
        message = "Your account has been temporarily locked due to too many failed attempts.",
        suggestion = "Please wait a few minutes before trying again.",
        isRetryable = false
    )
    
    // MARK: - Sync Errors
    
    val syncFailed = DisplayableError(
        title = "Sync Failed",
        message = "Unable to sync your data. Your changes are saved locally.",
        suggestion = "We'll automatically retry when your connection improves.",
        isRetryable = true
    )
    
    val conflictDetected = DisplayableError(
        title = "Sync Conflict",
        message = "Your data was modified on another device. We've kept the most recent version.",
        suggestion = null,
        isRetryable = false
    )
    
    // MARK: - Data Errors
    
    val taskNotFound = DisplayableError(
        title = "Task Not Found",
        message = "This task may have been deleted or moved.",
        suggestion = "Try refreshing the list.",
        isRetryable = true
    )
    
    val orbNotFound = DisplayableError(
        title = "Project Not Found",
        message = "This project may have been deleted or moved.",
        suggestion = "Try refreshing the list.",
        isRetryable = true
    )
    
    val saveFailed = DisplayableError(
        title = "Save Failed",
        message = "Unable to save your changes. Please try again.",
        suggestion = "If this problem persists, try closing and reopening the app.",
        isRetryable = true
    )
    
    val deleteFailed = DisplayableError(
        title = "Delete Failed",
        message = "Unable to delete this item. Please try again.",
        suggestion = null,
        isRetryable = true
    )
    
    // MARK: - Permission Errors
    
    val microphoneAccessDenied = DisplayableError(
        title = "Microphone Access Required",
        message = "Voice commands require microphone access.",
        suggestion = "Go to Settings > Apps > NotchToDo > Permissions and enable Microphone.",
        isRetryable = false
    )
    
    // MARK: - Error Mapping
    
    /**
     * Converts a system exception to a user-friendly displayable error.
     */
    fun from(throwable: Throwable): DisplayableError {
        return when (throwable) {
            is UnknownHostException -> networkUnavailable.copy(underlyingException = throwable)
            
            is SocketTimeoutException -> timeout.copy(underlyingException = throwable)
            
            is HttpException -> {
                val code = throwable.code()
                when (code) {
                    401 -> sessionExpired.copy(underlyingException = throwable)
                    403 -> DisplayableError(
                        title = "Access Denied",
                        message = "You don't have permission to perform this action.",
                        suggestion = null,
                        isRetryable = false,
                        underlyingException = throwable
                    )
                    404 -> taskNotFound.copy(underlyingException = throwable)
                    409 -> conflictDetected.copy(underlyingException = throwable)
                    429 -> DisplayableError(
                        title = "Too Many Requests",
                        message = "Please slow down and try again in a moment.",
                        suggestion = null,
                        isRetryable = true,
                        underlyingException = throwable
                    )
                    in 500..599 -> serverError.copy(underlyingException = throwable)
                    else -> DisplayableError(
                        title = "Request Failed",
                        message = "Something went wrong. Please try again.",
                        suggestion = null,
                        isRetryable = true,
                        underlyingException = throwable
                    )
                }
            }
            
            is java.io.IOException -> DisplayableError(
                title = "Network Error",
                message = "A network error occurred. Please check your connection.",
                suggestion = "Make sure you're connected to the internet.",
                isRetryable = true,
                underlyingException = throwable
            )
            
            is IllegalArgumentException -> {
                // Likely a validation error
                DisplayableError(
                    title = "Invalid Input",
                    message = throwable.message ?: "Please check your input.",
                    suggestion = null,
                    isRetryable = false,
                    underlyingException = throwable
                )
            }
            
            else -> DisplayableError(
                title = "Error",
                message = throwable.localizedMessage ?: "An unexpected error occurred.",
                suggestion = "Please try again. If the problem persists, contact support.",
                isRetryable = true,
                underlyingException = throwable
            )
        }
    }
    
    /**
     * Converts a validation error to a displayable error.
     */
    fun fromValidation(error: InputValidation.ValidationError): DisplayableError {
        return DisplayableError(
            title = "Invalid Input",
            message = error.message,
            suggestion = error.suggestion,
            isRetryable = false
        )
    }
}
