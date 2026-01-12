package com.notchtodo.util

import kotlinx.coroutines.delay
import kotlin.math.min
import kotlin.math.pow

/**
 * Helper for retrying operations with exponential backoff.
 */
object RetryHelper {
    
    /**
     * Configuration for retry behavior
     */
    data class RetryConfig(
        val maxAttempts: Int = 3,
        val initialDelayMs: Long = 1000,
        val maxDelayMs: Long = 30000,
        val backoffMultiplier: Double = 2.0,
        val retryOn: (Exception) -> Boolean = { true }
    )
    
    /**
     * Default configuration for network operations
     */
    val networkConfig = RetryConfig(
        maxAttempts = 3,
        initialDelayMs = 1000,
        maxDelayMs = 10000,
        backoffMultiplier = 2.0,
        retryOn = { e ->
            // Retry on network errors, but not on auth errors
            when {
                e.message?.contains("401") == true -> false  // Auth error - don't retry
                e.message?.contains("403") == true -> false  // Forbidden - don't retry
                e.message?.contains("404") == true -> false  // Not found - don't retry
                else -> true
            }
        }
    )
    
    /**
     * Execute an operation with exponential backoff retry.
     * 
     * @param config Retry configuration
     * @param operation The suspending operation to execute
     * @return Result of the operation
     */
    suspend fun <T> withRetry(
        config: RetryConfig = networkConfig,
        operation: suspend () -> T
    ): T {
        var lastException: Exception? = null
        var currentDelay = config.initialDelayMs
        
        repeat(config.maxAttempts) { attempt ->
            try {
                return operation()
            } catch (e: Exception) {
                lastException = e
                
                // Check if we should retry this exception
                if (!config.retryOn(e)) {
                    DebugLog.error("Non-retryable error on attempt ${attempt + 1}", e)
                    throw e
                }
                
                // Don't delay after the last attempt
                if (attempt < config.maxAttempts - 1) {
                    DebugLog.log(
                        "Retry attempt ${attempt + 1}/${config.maxAttempts} failed, " +
                        "retrying in ${currentDelay}ms: ${e.message}",
                        DebugLog.Category.SYNC
                    )
                    delay(currentDelay)
                    currentDelay = min(
                        (currentDelay * config.backoffMultiplier).toLong(),
                        config.maxDelayMs
                    )
                }
            }
        }
        
        DebugLog.error("All ${config.maxAttempts} retry attempts failed", lastException)
        throw lastException ?: Exception("Retry failed with unknown error")
    }
    
    /**
     * Execute an operation with exponential backoff retry, returning null on failure.
     * 
     * @param config Retry configuration
     * @param operation The suspending operation to execute
     * @return Result of the operation or null if all retries failed
     */
    suspend fun <T> withRetryOrNull(
        config: RetryConfig = networkConfig,
        operation: suspend () -> T
    ): T? {
        return try {
            withRetry(config, operation)
        } catch (e: Exception) {
            DebugLog.error("Operation failed after all retries", e, DebugLog.Category.SYNC)
            null
        }
    }
}
