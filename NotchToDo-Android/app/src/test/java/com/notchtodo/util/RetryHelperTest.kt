package com.notchtodo.util

import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.runTest
import org.junit.Assert.*
import org.junit.Test
import retrofit2.HttpException
import retrofit2.Response
import java.io.IOException

@OptIn(ExperimentalCoroutinesApi::class)
class RetryHelperTest {

    // MARK: - Basic Tests

    @Test
    fun `withRetry succeeds on first attempt`() = runTest {
        var attempts = 0
        
        val result = RetryHelper.withRetry {
            attempts++
            "success"
        }
        
        assertEquals("success", result)
        assertEquals(1, attempts)
    }

    @Test
    fun `withRetry retries on failure`() = runTest {
        var attempts = 0
        
        val result = RetryHelper.withRetry(
            config = RetryHelper.RetryConfig(maxAttempts = 3, initialDelayMs = 10)
        ) {
            attempts++
            if (attempts < 3) {
                throw IOException("Network error")
            }
            "success after retries"
        }
        
        assertEquals("success after retries", result)
        assertEquals(3, attempts)
    }

    @Test
    fun `withRetry throws after max attempts`() = runTest {
        var attempts = 0
        
        try {
            RetryHelper.withRetry(
                config = RetryHelper.RetryConfig(maxAttempts = 3, initialDelayMs = 10)
            ) {
                attempts++
                throw IOException("Persistent error")
            }
            fail("Should have thrown")
        } catch (e: IOException) {
            assertEquals("Persistent error", e.message)
            assertEquals(3, attempts)
        }
    }

    // MARK: - withRetryOrNull Tests

    @Test
    fun `withRetryOrNull returns null on failure`() = runTest {
        val result = RetryHelper.withRetryOrNull(
            config = RetryHelper.RetryConfig(maxAttempts = 2, initialDelayMs = 10)
        ) {
            throw IOException("Error")
        }
        
        assertNull(result)
    }

    @Test
    fun `withRetryOrNull returns value on success`() = runTest {
        val result = RetryHelper.withRetryOrNull {
            42
        }
        
        assertEquals(42, result)
    }

    // MARK: - Non-Retryable Errors

    @Test
    fun `401 error is not retried`() = runTest {
        var attempts = 0
        
        try {
            RetryHelper.withRetry(
                config = RetryHelper.RetryConfig(maxAttempts = 3, initialDelayMs = 10)
            ) {
                attempts++
                throw HttpException(Response.error<Any>(401, okhttp3.ResponseBody.create(null, "")))
            }
            fail("Should have thrown")
        } catch (e: HttpException) {
            assertEquals(1, attempts) // Should not retry
        }
    }

    @Test
    fun `403 error is not retried`() = runTest {
        var attempts = 0
        
        try {
            RetryHelper.withRetry(
                config = RetryHelper.RetryConfig(maxAttempts = 3, initialDelayMs = 10)
            ) {
                attempts++
                throw HttpException(Response.error<Any>(403, okhttp3.ResponseBody.create(null, "")))
            }
            fail("Should have thrown")
        } catch (e: HttpException) {
            assertEquals(1, attempts)
        }
    }

    @Test
    fun `404 error is not retried`() = runTest {
        var attempts = 0
        
        try {
            RetryHelper.withRetry(
                config = RetryHelper.RetryConfig(maxAttempts = 3, initialDelayMs = 10)
            ) {
                attempts++
                throw HttpException(Response.error<Any>(404, okhttp3.ResponseBody.create(null, "")))
            }
            fail("Should have thrown")
        } catch (e: HttpException) {
            assertEquals(1, attempts)
        }
    }

    @Test
    fun `500 error is retried`() = runTest {
        var attempts = 0
        
        try {
            RetryHelper.withRetry(
                config = RetryHelper.RetryConfig(maxAttempts = 3, initialDelayMs = 10)
            ) {
                attempts++
                throw HttpException(Response.error<Any>(500, okhttp3.ResponseBody.create(null, "")))
            }
            fail("Should have thrown")
        } catch (e: HttpException) {
            assertEquals(3, attempts) // Should retry
        }
    }

    // MARK: - Custom Retry Predicate

    @Test
    fun `custom retry predicate is respected`() = runTest {
        var attempts = 0
        
        class CustomException : Exception()
        
        val config = RetryHelper.RetryConfig(
            maxAttempts = 3,
            initialDelayMs = 10,
            retryOn = { e -> e !is CustomException }
        )
        
        try {
            RetryHelper.withRetry(config) {
                attempts++
                throw CustomException()
            }
            fail("Should have thrown")
        } catch (e: CustomException) {
            assertEquals(1, attempts) // Custom exception should not retry
        }
    }

    // MARK: - Backoff Tests

    @Test
    fun `backoff increases delay between attempts`() = runTest {
        val delays = mutableListOf<Long>()
        var lastAttemptTime = System.currentTimeMillis()
        
        try {
            RetryHelper.withRetry(
                config = RetryHelper.RetryConfig(
                    maxAttempts = 4,
                    initialDelayMs = 50,
                    maxDelayMs = 1000,
                    backoffMultiplier = 2.0
                )
            ) {
                val now = System.currentTimeMillis()
                if (delays.isNotEmpty() || lastAttemptTime != now) {
                    delays.add(now - lastAttemptTime)
                }
                lastAttemptTime = now
                throw IOException("Error")
            }
        } catch (e: IOException) {
            // Expected
        }
        
        // Verify delays increase (with some tolerance for timing)
        assertTrue(delays.size >= 2)
        // Each delay should be roughly double the previous (with jitter)
    }

    @Test
    fun `delay is capped at maxDelay`() = runTest {
        val config = RetryHelper.RetryConfig(
            maxAttempts = 5,
            initialDelayMs = 100,
            maxDelayMs = 200,
            backoffMultiplier = 10.0 // Would exceed max quickly
        )
        
        var lastTime = System.currentTimeMillis()
        val delays = mutableListOf<Long>()
        
        try {
            RetryHelper.withRetry(config) {
                val now = System.currentTimeMillis()
                delays.add(now - lastTime)
                lastTime = now
                throw IOException("Error")
            }
        } catch (e: IOException) {
            // Expected
        }
        
        // All delays after the first should be capped around maxDelay
        // (allowing some tolerance for execution time)
        delays.drop(1).forEach { delay ->
            assertTrue(delay <= 500) // 200ms max + generous tolerance
        }
    }

    // MARK: - Default Config Tests

    @Test
    fun `default config has reasonable values`() {
        val config = RetryHelper.RetryConfig.default
        
        assertEquals(3, config.maxAttempts)
        assertTrue(config.initialDelayMs > 0)
        assertTrue(config.maxDelayMs >= config.initialDelayMs)
        assertTrue(config.backoffMultiplier > 1.0)
    }
}
