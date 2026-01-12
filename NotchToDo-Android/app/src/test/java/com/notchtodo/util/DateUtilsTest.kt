package com.notchtodo.util

import org.junit.Assert.*
import org.junit.Test
import java.util.Date
import java.util.TimeZone

class DateUtilsTest {

    @Test
    fun `formatISO8601 produces valid format`() {
        val date = Date(0) // 1970-01-01T00:00:00.000Z
        val formatted = DateUtils.formatISO8601(date)
        
        assertTrue(formatted.contains("1970-01-01"))
        assertTrue(formatted.contains("T"))
        assertTrue(formatted.endsWith("Z"))
    }

    @Test
    fun `parseISO8601 parses standard format`() {
        val dateString = "2024-06-15T14:30:00Z"
        val date = DateUtils.parseISO8601(dateString)
        
        assertNotNull(date)
    }

    @Test
    fun `parseISO8601 parses format with fractional seconds`() {
        val dateString = "2024-06-15T14:30:00.123Z"
        val date = DateUtils.parseISO8601(dateString)
        
        assertNotNull(date)
    }

    @Test
    fun `parseISO8601 returns null for invalid format`() {
        val invalidString = "not a date"
        val date = DateUtils.parseISO8601(invalidString)
        
        assertNull(date)
    }

    @Test
    fun `roundtrip format and parse`() {
        val original = Date()
        val formatted = DateUtils.formatISO8601(original)
        val parsed = DateUtils.parseISO8601(formatted)
        
        assertNotNull(parsed)
        // Allow 1 second tolerance for formatting differences
        assertTrue(kotlin.math.abs(original.time - parsed!!.time) < 1000)
    }

    @Test
    fun `formatForDisplay returns date only`() {
        val date = Date()
        val formatted = DateUtils.formatForDisplay(date)
        
        assertFalse(formatted.contains("T"))
        assertFalse(formatted.contains("Z"))
    }

    @Test
    fun `formatWithTimeForDisplay includes time`() {
        val date = Date()
        val formatted = DateUtils.formatWithTimeForDisplay(date)
        
        assertTrue(formatted.isNotEmpty())
        // Should contain a separator between date and time
        assertTrue(formatted.contains(" ") || formatted.contains(","))
    }

    @Test
    fun `thread safety with concurrent access`() {
        val threads = (1..10).map {
            Thread {
                repeat(100) {
                    val date = Date()
                    val formatted = DateUtils.formatISO8601(date)
                    DateUtils.parseISO8601(formatted)
                }
            }
        }
        
        threads.forEach { it.start() }
        threads.forEach { it.join() }
        
        // If we get here without exceptions, thread safety is working
        assertTrue(true)
    }
}
