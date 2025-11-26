import XCTest
@testable import SharedKit

final class InputValidationTests: XCTestCase {
    
    // MARK: - Task Title Validation
    
    func testValidTaskTitle() throws {
        let result = try InputValidation.validateTaskTitle("Buy groceries")
        XCTAssertEqual(result, "Buy groceries")
    }
    
    func testTaskTitleTrimming() throws {
        let result = try InputValidation.validateTaskTitle("  Trimmed title  ")
        XCTAssertEqual(result, "Trimmed title")
    }
    
    func testEmptyTaskTitle() {
        XCTAssertThrowsError(try InputValidation.validateTaskTitle("")) { error in
            guard let validationError = error as? InputValidation.ValidationError else {
                XCTFail("Wrong error type")
                return
            }
            if case .emptyTitle = validationError {
                // Expected
            } else {
                XCTFail("Wrong validation error: \(validationError)")
            }
        }
    }
    
    func testWhitespaceOnlyTaskTitle() {
        XCTAssertThrowsError(try InputValidation.validateTaskTitle("   ")) { error in
            guard let validationError = error as? InputValidation.ValidationError else {
                XCTFail("Wrong error type")
                return
            }
            if case .emptyTitle = validationError {
                // Expected
            } else {
                XCTFail("Wrong validation error")
            }
        }
    }
    
    func testTaskTitleTooLong() {
        let longTitle = String(repeating: "a", count: 501)
        let config = InputValidation.Config(maxTitleLength: 500)
        
        XCTAssertThrowsError(try InputValidation.validateTaskTitle(longTitle, config: config)) { error in
            guard let validationError = error as? InputValidation.ValidationError else {
                XCTFail("Wrong error type")
                return
            }
            if case .titleTooLong(let maxLength) = validationError {
                XCTAssertEqual(maxLength, 500)
            } else {
                XCTFail("Wrong validation error")
            }
        }
    }
    
    func testTaskTitleWithUnicode() throws {
        let result = try InputValidation.validateTaskTitle("Buy 🍎 and 🥕")
        XCTAssertEqual(result, "Buy 🍎 and 🥕")
    }
    
    // MARK: - Priority Validation
    
    func testValidPriority() throws {
        XCTAssertEqual(try InputValidation.validatePriority(1), 1)
        XCTAssertEqual(try InputValidation.validatePriority(3), 3)
        XCTAssertEqual(try InputValidation.validatePriority(5), 5)
    }
    
    func testInvalidPriority() {
        XCTAssertThrowsError(try InputValidation.validatePriority(0)) { error in
            guard let validationError = error as? InputValidation.ValidationError else {
                XCTFail("Wrong error type")
                return
            }
            if case .invalidPriority = validationError {
                // Expected
            } else {
                XCTFail("Wrong validation error")
            }
        }
        
        XCTAssertThrowsError(try InputValidation.validatePriority(6))
    }
    
    // MARK: - Status Validation
    
    func testValidStatus() throws {
        XCTAssertEqual(try InputValidation.validateStatus(1), 1)
        XCTAssertEqual(try InputValidation.validateStatus(2), 2)
        XCTAssertEqual(try InputValidation.validateStatus(3), 3)
    }
    
    func testInvalidStatus() {
        XCTAssertThrowsError(try InputValidation.validateStatus(0))
        XCTAssertThrowsError(try InputValidation.validateStatus(4))
    }
    
    // MARK: - Deadline Validation
    
    func testFutureDeadline() throws {
        let futureDate = Date().addingTimeInterval(3600) // 1 hour from now
        let result = try InputValidation.validateDeadline(futureDate)
        XCTAssertEqual(result, futureDate)
    }
    
    func testNilDeadline() throws {
        let result = try InputValidation.validateDeadline(nil)
        XCTAssertNil(result)
    }
    
    func testPastDeadline() {
        let pastDate = Date().addingTimeInterval(-3600) // 1 hour ago
        
        XCTAssertThrowsError(try InputValidation.validateDeadline(pastDate)) { error in
            guard let validationError = error as? InputValidation.ValidationError else {
                XCTFail("Wrong error type")
                return
            }
            if case .deadlineInPast = validationError {
                // Expected
            } else {
                XCTFail("Wrong validation error")
            }
        }
    }
    
    func testPastDeadlineWithTolerance() throws {
        // Within 5 minute tolerance
        let recentDate = Date().addingTimeInterval(-60) // 1 minute ago
        let result = try InputValidation.validateDeadline(recentDate)
        XCTAssertNotNil(result)
    }
    
    func testPastDeadlineAllowed() throws {
        let pastDate = Date().addingTimeInterval(-3600)
        let config = InputValidation.Config(allowPastDeadlines: true)
        
        let result = try InputValidation.validateDeadline(pastDate, config: config)
        XCTAssertEqual(result, pastDate)
    }
    
    // MARK: - Notes Validation
    
    func testValidNotes() throws {
        let result = try InputValidation.validateNotes("These are my notes")
        XCTAssertEqual(result, "These are my notes")
    }
    
    func testNilNotes() throws {
        let result = try InputValidation.validateNotes(nil)
        XCTAssertEqual(result, "")
    }
    
    func testNotesTooLong() {
        let longNotes = String(repeating: "a", count: 10001)
        let config = InputValidation.Config(maxNotesLength: 10000)
        
        XCTAssertThrowsError(try InputValidation.validateNotes(longNotes, config: config))
    }
    
    // MARK: - Orb Name Validation
    
    func testValidOrbName() throws {
        let result = try InputValidation.validateOrbName("Work Projects")
        XCTAssertEqual(result, "Work Projects")
    }
    
    func testOrbNameTrimming() throws {
        let result = try InputValidation.validateOrbName("  Personal  ")
        XCTAssertEqual(result, "Personal")
    }
    
    func testEmptyOrbName() {
        XCTAssertThrowsError(try InputValidation.validateOrbName("")) { error in
            guard let validationError = error as? InputValidation.ValidationError else {
                XCTFail("Wrong error type")
                return
            }
            if case .emptyOrbName = validationError {
                // Expected
            } else {
                XCTFail("Wrong validation error")
            }
        }
    }
    
    func testOrbNameTooLong() {
        let longName = String(repeating: "a", count: 101)
        let config = InputValidation.Config(maxOrbNameLength: 100)
        
        XCTAssertThrowsError(try InputValidation.validateOrbName(longName, config: config))
    }
    
    // MARK: - Convenience Methods
    
    func testSanitize() {
        XCTAssertEqual(InputValidation.sanitize("  hello  ", maxLength: 100), "hello")
        XCTAssertEqual(InputValidation.sanitize("hello world", maxLength: 5), "hello")
        XCTAssertEqual(InputValidation.sanitize("test", maxLength: 10), "test")
    }
    
    func testIsValidInput() {
        XCTAssertTrue(InputValidation.isValidInput("valid"))
        XCTAssertTrue(InputValidation.isValidInput("  valid  "))
        XCTAssertFalse(InputValidation.isValidInput(""))
        XCTAssertFalse(InputValidation.isValidInput("   "))
    }
    
    // MARK: - Error Messages
    
    func testErrorDescriptions() {
        let emptyTitle = InputValidation.ValidationError.emptyTitle
        XCTAssertNotNil(emptyTitle.errorDescription)
        XCTAssertNotNil(emptyTitle.recoverySuggestion)
        
        let titleTooLong = InputValidation.ValidationError.titleTooLong(maxLength: 500)
        XCTAssertTrue(titleTooLong.errorDescription?.contains("500") ?? false)
    }
}
