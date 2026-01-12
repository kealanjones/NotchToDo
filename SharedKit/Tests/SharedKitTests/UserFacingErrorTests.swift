import XCTest
@testable import SharedKit

final class UserFacingErrorTests: XCTestCase {
    
    // MARK: - DisplayableError Tests
    
    func testDisplayableErrorProperties() {
        let error = UserFacingError.DisplayableError(
            title: "Test Title",
            message: "Test message",
            suggestion: "Test suggestion",
            isRetryable: true,
            underlyingError: nil
        )
        
        XCTAssertEqual(error.title, "Test Title")
        XCTAssertEqual(error.message, "Test message")
        XCTAssertEqual(error.suggestion, "Test suggestion")
        XCTAssertTrue(error.isRetryable)
        XCTAssertNil(error.underlyingError)
    }
    
    func testDisplayableErrorLocalizedDescription() {
        let error = UserFacingError.DisplayableError(
            title: "Title",
            message: "The error message",
            suggestion: nil,
            isRetryable: false
        )
        
        XCTAssertEqual(error.errorDescription, "The error message")
        XCTAssertNil(error.recoverySuggestion)
    }
    
    // MARK: - Pre-defined Error Tests
    
    func testNetworkUnavailable() {
        let error = UserFacingError.networkUnavailable
        
        XCTAssertEqual(error.title, "No Connection")
        XCTAssertTrue(error.isRetryable)
        XCTAssertNotNil(error.suggestion)
    }
    
    func testServerError() {
        let error = UserFacingError.serverError
        
        XCTAssertEqual(error.title, "Server Error")
        XCTAssertTrue(error.isRetryable)
    }
    
    func testTimeout() {
        let error = UserFacingError.timeout
        
        XCTAssertEqual(error.title, "Request Timed Out")
        XCTAssertTrue(error.isRetryable)
    }
    
    func testSessionExpired() {
        let error = UserFacingError.sessionExpired
        
        XCTAssertEqual(error.title, "Session Expired")
        XCTAssertFalse(error.isRetryable)
        XCTAssertNotNil(error.suggestion)
    }
    
    func testInvalidCredentials() {
        let error = UserFacingError.invalidCredentials
        
        XCTAssertEqual(error.title, "Invalid Credentials")
        XCTAssertFalse(error.isRetryable)
    }
    
    func testSyncFailed() {
        let error = UserFacingError.syncFailed
        
        XCTAssertEqual(error.title, "Sync Failed")
        XCTAssertTrue(error.isRetryable)
        XCTAssertTrue(error.message.contains("saved locally"))
    }
    
    func testConflictDetected() {
        let error = UserFacingError.conflictDetected
        
        XCTAssertEqual(error.title, "Sync Conflict")
        XCTAssertFalse(error.isRetryable)
    }
    
    func testTaskNotFound() {
        let error = UserFacingError.taskNotFound
        
        XCTAssertEqual(error.title, "Task Not Found")
        XCTAssertTrue(error.isRetryable)
    }
    
    func testOrbNotFound() {
        let error = UserFacingError.orbNotFound
        
        XCTAssertEqual(error.title, "Project Not Found")
        XCTAssertTrue(error.isRetryable)
    }
    
    func testSaveFailed() {
        let error = UserFacingError.saveFailed
        
        XCTAssertEqual(error.title, "Save Failed")
        XCTAssertTrue(error.isRetryable)
    }
    
    func testMicrophoneAccessDenied() {
        let error = UserFacingError.microphoneAccessDenied
        
        XCTAssertEqual(error.title, "Microphone Access Required")
        XCTAssertFalse(error.isRetryable)
        XCTAssertTrue(error.suggestion?.contains("Settings") ?? false)
    }
    
    // MARK: - Error Mapping Tests
    
    func testMapURLErrorNotConnected() {
        let urlError = URLError(.notConnectedToInternet)
        let mapped = UserFacingError.from(urlError)
        
        XCTAssertEqual(mapped.title, "No Connection")
        XCTAssertTrue(mapped.isRetryable)
    }
    
    func testMapURLErrorTimedOut() {
        let urlError = URLError(.timedOut)
        let mapped = UserFacingError.from(urlError)
        
        XCTAssertEqual(mapped.title, "Request Timed Out")
    }
    
    func testMapURLErrorCannotFindHost() {
        let urlError = URLError(.cannotFindHost)
        let mapped = UserFacingError.from(urlError)
        
        XCTAssertEqual(mapped.title, "Server Error")
    }
    
    func testMapValidationError() {
        let validationError = InputValidation.ValidationError.emptyTitle
        let mapped = UserFacingError.from(validationError)
        
        XCTAssertEqual(mapped.title, "Invalid Input")
        XCTAssertFalse(mapped.isRetryable)
    }
    
    func testMapUnknownError() {
        struct CustomError: Error {
            let message: String
        }
        
        let customError = CustomError(message: "Something went wrong")
        let mapped = UserFacingError.from(customError)
        
        XCTAssertEqual(mapped.title, "Error")
        XCTAssertTrue(mapped.isRetryable)
        XCTAssertNotNil(mapped.underlyingError)
    }
    
    // MARK: - Supabase Error Mapping Tests
    
    func testMapSupabase401Error() {
        let supabaseError = SupabaseService.ServiceError.invalidResponse(status: 401, body: "Unauthorized")
        let mapped = UserFacingError.from(supabaseError)
        
        XCTAssertEqual(mapped.title, "Session Expired")
        XCTAssertFalse(mapped.isRetryable)
    }
    
    func testMapSupabase403Error() {
        let supabaseError = SupabaseService.ServiceError.invalidResponse(status: 403, body: "Forbidden")
        let mapped = UserFacingError.from(supabaseError)
        
        XCTAssertEqual(mapped.title, "Access Denied")
        XCTAssertFalse(mapped.isRetryable)
    }
    
    func testMapSupabase404Error() {
        let supabaseError = SupabaseService.ServiceError.invalidResponse(status: 404, body: "Not Found")
        let mapped = UserFacingError.from(supabaseError)
        
        XCTAssertEqual(mapped.title, "Task Not Found")
    }
    
    func testMapSupabase429Error() {
        let supabaseError = SupabaseService.ServiceError.invalidResponse(status: 429, body: "Rate limited")
        let mapped = UserFacingError.from(supabaseError)
        
        XCTAssertEqual(mapped.title, "Too Many Requests")
        XCTAssertTrue(mapped.isRetryable)
    }
    
    func testMapSupabase500Error() {
        let supabaseError = SupabaseService.ServiceError.invalidResponse(status: 500, body: "Internal Error")
        let mapped = UserFacingError.from(supabaseError)
        
        XCTAssertEqual(mapped.title, "Server Error")
        XCTAssertTrue(mapped.isRetryable)
    }
    
    func testMapSupabaseConfigError() {
        let supabaseError = SupabaseService.ServiceError.invalidConfiguration
        let mapped = UserFacingError.from(supabaseError)
        
        XCTAssertEqual(mapped.title, "Configuration Error")
        XCTAssertFalse(mapped.isRetryable)
    }
    
    func testMapSupabaseMissingCredentials() {
        let supabaseError = SupabaseService.ServiceError.missingCredentials
        let mapped = UserFacingError.from(supabaseError)
        
        XCTAssertEqual(mapped.title, "Session Expired")
    }
}
