package com.notchtodo.util

import org.junit.Assert.*
import org.junit.Test
import retrofit2.HttpException
import retrofit2.Response
import java.io.IOException
import java.net.SocketTimeoutException
import java.net.UnknownHostException
import javax.net.ssl.SSLHandshakeException

class UserFacingErrorTest {

    // MARK: - DisplayableError Tests

    @Test
    fun `displayableError has all properties`() {
        val error = UserFacingError.DisplayableError(
            title = "Test Title",
            message = "Test message",
            suggestion = "Test suggestion",
            isRetryable = true
        )
        
        assertEquals("Test Title", error.title)
        assertEquals("Test message", error.message)
        assertEquals("Test suggestion", error.suggestion)
        assertTrue(error.isRetryable)
    }

    // MARK: - Pre-defined Error Tests

    @Test
    fun `networkUnavailable has correct properties`() {
        val error = UserFacingError.networkUnavailable
        
        assertEquals("No Connection", error.title)
        assertTrue(error.isRetryable)
        assertNotNull(error.suggestion)
    }

    @Test
    fun `serverError has correct properties`() {
        val error = UserFacingError.serverError
        
        assertEquals("Server Error", error.title)
        assertTrue(error.isRetryable)
    }

    @Test
    fun `timeout has correct properties`() {
        val error = UserFacingError.timeout
        
        assertEquals("Request Timed Out", error.title)
        assertTrue(error.isRetryable)
    }

    @Test
    fun `sessionExpired has correct properties`() {
        val error = UserFacingError.sessionExpired
        
        assertEquals("Session Expired", error.title)
        assertFalse(error.isRetryable)
        assertNotNull(error.suggestion)
    }

    @Test
    fun `syncFailed has correct properties`() {
        val error = UserFacingError.syncFailed
        
        assertEquals("Sync Failed", error.title)
        assertTrue(error.isRetryable)
        assertTrue(error.message.contains("saved locally"))
    }

    // MARK: - Exception Mapping Tests

    @Test
    fun `UnknownHostException maps to networkUnavailable`() {
        val exception = UnknownHostException("Cannot resolve host")
        val error = UserFacingError.from(exception)
        
        assertEquals("No Connection", error.title)
        assertTrue(error.isRetryable)
    }

    @Test
    fun `SocketTimeoutException maps to timeout`() {
        val exception = SocketTimeoutException("Connection timed out")
        val error = UserFacingError.from(exception)
        
        assertEquals("Request Timed Out", error.title)
        assertTrue(error.isRetryable)
    }

    @Test
    fun `IOException maps to network error`() {
        val exception = IOException("Network error")
        val error = UserFacingError.from(exception)
        
        assertEquals("Connection Error", error.title)
        assertTrue(error.isRetryable)
    }

    @Test
    fun `SSLHandshakeException maps to security error`() {
        val exception = SSLHandshakeException("Certificate error")
        val error = UserFacingError.from(exception)
        
        assertEquals("Security Error", error.title)
        assertFalse(error.isRetryable)
    }

    // MARK: - HTTP Exception Mapping Tests

    @Test
    fun `401 error maps to sessionExpired`() {
        val exception = HttpException(Response.error<Any>(401, okhttp3.ResponseBody.create(null, "")))
        val error = UserFacingError.from(exception)
        
        assertEquals("Session Expired", error.title)
        assertFalse(error.isRetryable)
    }

    @Test
    fun `403 error maps to accessDenied`() {
        val exception = HttpException(Response.error<Any>(403, okhttp3.ResponseBody.create(null, "")))
        val error = UserFacingError.from(exception)
        
        assertEquals("Access Denied", error.title)
        assertFalse(error.isRetryable)
    }

    @Test
    fun `404 error maps to notFound`() {
        val exception = HttpException(Response.error<Any>(404, okhttp3.ResponseBody.create(null, "")))
        val error = UserFacingError.from(exception)
        
        assertEquals("Not Found", error.title)
        assertFalse(error.isRetryable)
    }

    @Test
    fun `429 error maps to rateLimited`() {
        val exception = HttpException(Response.error<Any>(429, okhttp3.ResponseBody.create(null, "")))
        val error = UserFacingError.from(exception)
        
        assertEquals("Too Many Requests", error.title)
        assertTrue(error.isRetryable)
    }

    @Test
    fun `500 error maps to serverError`() {
        val exception = HttpException(Response.error<Any>(500, okhttp3.ResponseBody.create(null, "")))
        val error = UserFacingError.from(exception)
        
        assertEquals("Server Error", error.title)
        assertTrue(error.isRetryable)
    }

    @Test
    fun `503 error maps to serviceUnavailable`() {
        val exception = HttpException(Response.error<Any>(503, okhttp3.ResponseBody.create(null, "")))
        val error = UserFacingError.from(exception)
        
        assertEquals("Service Unavailable", error.title)
        assertTrue(error.isRetryable)
    }

    // MARK: - Validation Error Mapping

    @Test
    fun `validation errors map correctly`() {
        val validationError = InputValidation.ValidationError.EMPTY_TITLE
        val error = UserFacingError.fromValidation(validationError)
        
        assertEquals("Invalid Input", error.title)
        assertEquals(validationError.message, error.message)
        assertFalse(error.isRetryable)
    }

    // MARK: - Unknown Error Mapping

    @Test
    fun `unknown exception maps to generic error`() {
        class CustomException : Exception("Custom error message")
        
        val exception = CustomException()
        val error = UserFacingError.from(exception)
        
        assertEquals("Error", error.title)
        assertTrue(error.isRetryable)
    }
}
