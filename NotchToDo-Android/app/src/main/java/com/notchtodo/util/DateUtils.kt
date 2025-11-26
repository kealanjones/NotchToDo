package com.notchtodo.util

import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.TimeZone

/**
 * Centralized date formatting utilities for consistent ISO8601 handling.
 */
object DateUtils {
    
    // Thread-local formatter to avoid synchronization issues
    private val iso8601Formatter: ThreadLocal<SimpleDateFormat> = object : ThreadLocal<SimpleDateFormat>() {
        override fun initialValue(): SimpleDateFormat {
            return SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSSSSS'Z'", Locale.US).apply {
                timeZone = TimeZone.getTimeZone("UTC")
            }
        }
    }
    
    private val iso8601ParserWithFraction: ThreadLocal<SimpleDateFormat> = object : ThreadLocal<SimpleDateFormat>() {
        override fun initialValue(): SimpleDateFormat {
            return SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSSSSS'Z'", Locale.US).apply {
                timeZone = TimeZone.getTimeZone("UTC")
            }
        }
    }
    
    private val iso8601ParserWithoutFraction: ThreadLocal<SimpleDateFormat> = object : ThreadLocal<SimpleDateFormat>() {
        override fun initialValue(): SimpleDateFormat {
            return SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss'Z'", Locale.US).apply {
                timeZone = TimeZone.getTimeZone("UTC")
            }
        }
    }
    
    /**
     * Formats a Date to ISO8601 string with microsecond precision.
     * Example output: "2025-11-26T14:30:00.123456Z"
     */
    fun formatISO8601(date: Date): String {
        return iso8601Formatter.get()!!.format(date)
    }
    
    /**
     * Parses an ISO8601 string to Date.
     * Supports both with and without fractional seconds.
     */
    fun parseISO8601(dateString: String): Date? {
        return try {
            if (dateString.contains(".")) {
                iso8601ParserWithFraction.get()!!.parse(dateString)
            } else {
                iso8601ParserWithoutFraction.get()!!.parse(dateString)
            }
        } catch (e: Exception) {
            DebugLog.error("Failed to parse ISO8601 date: $dateString", e)
            null
        }
    }
    
    /**
     * Formats a Date for display (e.g., "Nov 26, 2025")
     */
    fun formatForDisplay(date: Date): String {
        val formatter = SimpleDateFormat("MMM d, yyyy", Locale.getDefault())
        return formatter.format(date)
    }
    
    /**
     * Formats a Date with time for display (e.g., "Nov 26, 2025 at 2:30 PM")
     */
    fun formatWithTimeForDisplay(date: Date): String {
        val formatter = SimpleDateFormat("MMM d, yyyy 'at' h:mm a", Locale.getDefault())
        return formatter.format(date)
    }
}
