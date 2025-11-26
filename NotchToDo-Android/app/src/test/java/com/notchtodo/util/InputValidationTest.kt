package com.notchtodo.util

import org.junit.Assert.*
import org.junit.Test
import java.util.Date

class InputValidationTest {

    // MARK: - Task Title Validation

    @Test
    fun `valid task title succeeds`() {
        val result = InputValidation.validateTaskTitle("Buy groceries")
        assertTrue(result is InputValidation.ValidationResult.Success)
        assertEquals("Buy groceries", (result as InputValidation.ValidationResult.Success).value)
    }

    @Test
    fun `task title is trimmed`() {
        val result = InputValidation.validateTaskTitle("  Trimmed title  ")
        assertTrue(result is InputValidation.ValidationResult.Success)
        assertEquals("Trimmed title", (result as InputValidation.ValidationResult.Success).value)
    }

    @Test
    fun `empty task title fails`() {
        val result = InputValidation.validateTaskTitle("")
        assertTrue(result is InputValidation.ValidationResult.Error)
        assertEquals(
            InputValidation.ValidationError.EMPTY_TITLE,
            (result as InputValidation.ValidationResult.Error).error
        )
    }

    @Test
    fun `whitespace only task title fails`() {
        val result = InputValidation.validateTaskTitle("   ")
        assertTrue(result is InputValidation.ValidationResult.Error)
    }

    @Test
    fun `too long task title fails`() {
        val longTitle = "a".repeat(501)
        val config = InputValidation.Config(maxTitleLength = 500)
        
        val result = InputValidation.validateTaskTitle(longTitle, config)
        assertTrue(result is InputValidation.ValidationResult.Error)
        assertEquals(
            InputValidation.ValidationError.TITLE_TOO_LONG,
            (result as InputValidation.ValidationResult.Error).error
        )
    }

    @Test
    fun `task title with unicode succeeds`() {
        val result = InputValidation.validateTaskTitle("Buy 🍎 and 🥕")
        assertTrue(result is InputValidation.ValidationResult.Success)
        assertEquals("Buy 🍎 and 🥕", (result as InputValidation.ValidationResult.Success).value)
    }

    // MARK: - Priority Validation

    @Test
    fun `valid priorities succeed`() {
        assertTrue(InputValidation.validatePriority(1) is InputValidation.ValidationResult.Success)
        assertTrue(InputValidation.validatePriority(3) is InputValidation.ValidationResult.Success)
        assertTrue(InputValidation.validatePriority(5) is InputValidation.ValidationResult.Success)
    }

    @Test
    fun `invalid priority fails`() {
        val result0 = InputValidation.validatePriority(0)
        assertTrue(result0 is InputValidation.ValidationResult.Error)
        assertEquals(
            InputValidation.ValidationError.INVALID_PRIORITY,
            (result0 as InputValidation.ValidationResult.Error).error
        )
        
        val result6 = InputValidation.validatePriority(6)
        assertTrue(result6 is InputValidation.ValidationResult.Error)
    }

    // MARK: - Status Validation

    @Test
    fun `valid statuses succeed`() {
        assertTrue(InputValidation.validateStatus(1) is InputValidation.ValidationResult.Success)
        assertTrue(InputValidation.validateStatus(2) is InputValidation.ValidationResult.Success)
        assertTrue(InputValidation.validateStatus(3) is InputValidation.ValidationResult.Success)
    }

    @Test
    fun `invalid status fails`() {
        assertTrue(InputValidation.validateStatus(0) is InputValidation.ValidationResult.Error)
        assertTrue(InputValidation.validateStatus(4) is InputValidation.ValidationResult.Error)
    }

    // MARK: - Deadline Validation

    @Test
    fun `future deadline succeeds`() {
        val futureDate = Date(System.currentTimeMillis() + 3600000) // 1 hour from now
        val result = InputValidation.validateDeadline(futureDate)
        assertTrue(result is InputValidation.ValidationResult.Success)
    }

    @Test
    fun `null deadline succeeds`() {
        val result = InputValidation.validateDeadline(null)
        assertTrue(result is InputValidation.ValidationResult.Success)
        assertNull((result as InputValidation.ValidationResult.Success).value)
    }

    @Test
    fun `past deadline fails`() {
        val pastDate = Date(System.currentTimeMillis() - 3600000) // 1 hour ago
        val result = InputValidation.validateDeadline(pastDate)
        assertTrue(result is InputValidation.ValidationResult.Error)
        assertEquals(
            InputValidation.ValidationError.DEADLINE_IN_PAST,
            (result as InputValidation.ValidationResult.Error).error
        )
    }

    @Test
    fun `past deadline within tolerance succeeds`() {
        val recentDate = Date(System.currentTimeMillis() - 60000) // 1 minute ago
        val result = InputValidation.validateDeadline(recentDate)
        assertTrue(result is InputValidation.ValidationResult.Success)
    }

    @Test
    fun `past deadline allowed with config`() {
        val pastDate = Date(System.currentTimeMillis() - 3600000)
        val config = InputValidation.Config(allowPastDeadlines = true)
        
        val result = InputValidation.validateDeadline(pastDate, config)
        assertTrue(result is InputValidation.ValidationResult.Success)
    }

    // MARK: - Notes Validation

    @Test
    fun `valid notes succeed`() {
        val result = InputValidation.validateNotes("These are my notes")
        assertTrue(result is InputValidation.ValidationResult.Success)
        assertEquals("These are my notes", (result as InputValidation.ValidationResult.Success).value)
    }

    @Test
    fun `null notes return empty string`() {
        val result = InputValidation.validateNotes(null)
        assertTrue(result is InputValidation.ValidationResult.Success)
        assertEquals("", (result as InputValidation.ValidationResult.Success).value)
    }

    @Test
    fun `too long notes fail`() {
        val longNotes = "a".repeat(10001)
        val config = InputValidation.Config(maxNotesLength = 10000)
        
        val result = InputValidation.validateNotes(longNotes, config)
        assertTrue(result is InputValidation.ValidationResult.Error)
    }

    // MARK: - Orb Name Validation

    @Test
    fun `valid orb name succeeds`() {
        val result = InputValidation.validateOrbName("Work Projects")
        assertTrue(result is InputValidation.ValidationResult.Success)
        assertEquals("Work Projects", (result as InputValidation.ValidationResult.Success).value)
    }

    @Test
    fun `orb name is trimmed`() {
        val result = InputValidation.validateOrbName("  Personal  ")
        assertTrue(result is InputValidation.ValidationResult.Success)
        assertEquals("Personal", (result as InputValidation.ValidationResult.Success).value)
    }

    @Test
    fun `empty orb name fails`() {
        val result = InputValidation.validateOrbName("")
        assertTrue(result is InputValidation.ValidationResult.Error)
        assertEquals(
            InputValidation.ValidationError.EMPTY_ORB_NAME,
            (result as InputValidation.ValidationResult.Error).error
        )
    }

    @Test
    fun `too long orb name fails`() {
        val longName = "a".repeat(101)
        val config = InputValidation.Config(maxOrbNameLength = 100)
        
        val result = InputValidation.validateOrbName(longName, config)
        assertTrue(result is InputValidation.ValidationResult.Error)
    }

    // MARK: - Convenience Methods

    @Test
    fun `sanitize trims and truncates`() {
        assertEquals("hello", InputValidation.sanitize("  hello  ", 100))
        assertEquals("hello", InputValidation.sanitize("hello world", 5))
        assertEquals("test", InputValidation.sanitize("test", 10))
    }

    @Test
    fun `isValidInput checks empty strings`() {
        assertTrue(InputValidation.isValidInput("valid"))
        assertTrue(InputValidation.isValidInput("  valid  "))
        assertFalse(InputValidation.isValidInput(""))
        assertFalse(InputValidation.isValidInput("   "))
    }

    // MARK: - Error Messages

    @Test
    fun `error messages are not empty`() {
        assertFalse(InputValidation.ValidationError.EMPTY_TITLE.message.isEmpty())
        assertFalse(InputValidation.ValidationError.EMPTY_TITLE.suggestion.isEmpty())
        assertFalse(InputValidation.ValidationError.TITLE_TOO_LONG.message.isEmpty())
        assertFalse(InputValidation.ValidationError.DEADLINE_IN_PAST.message.isEmpty())
    }
}
