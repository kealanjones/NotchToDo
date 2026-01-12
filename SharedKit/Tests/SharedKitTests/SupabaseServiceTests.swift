import XCTest
@testable import SharedKit

final class SupabaseServiceTests: XCTestCase {
    
    // MARK: - Configuration Tests
    
    func testConfigurationInit() {
        let config = SupabaseService.Configuration(
            projectURL: "https://example.supabase.co",
            apiKey: "test-api-key"
        )
        
        XCTAssertEqual(config.projectURL, "https://example.supabase.co")
        XCTAssertEqual(config.apiKey, "test-api-key")
    }
    
    func testConfigurationFromEnvironment() {
        // This tests the factory method exists
        // Actual values depend on environment/keychain
        let config = SupabaseService.Configuration.fromEnvironment()
        // May or may not be nil depending on environment
        _ = config
    }
    
    // MARK: - HTTP Method Tests
    
    func testHTTPMethodRawValues() {
        XCTAssertEqual(SupabaseService.HTTPMethod.GET.rawValue, "GET")
        XCTAssertEqual(SupabaseService.HTTPMethod.POST.rawValue, "POST")
        XCTAssertEqual(SupabaseService.HTTPMethod.PUT.rawValue, "PUT")
        XCTAssertEqual(SupabaseService.HTTPMethod.PATCH.rawValue, "PATCH")
        XCTAssertEqual(SupabaseService.HTTPMethod.DELETE.rawValue, "DELETE")
    }
    
    // MARK: - Service Error Tests
    
    func testServiceErrorDescriptions() {
        let invalidConfig = SupabaseService.ServiceError.invalidConfiguration
        XCTAssertNotNil(invalidConfig.errorDescription)
        
        let missingCreds = SupabaseService.ServiceError.missingCredentials
        XCTAssertNotNil(missingCreds.errorDescription)
        
        let invalidResponse = SupabaseService.ServiceError.invalidResponse(status: 404, body: "Not Found")
        XCTAssertTrue(invalidResponse.errorDescription?.contains("404") ?? false)
        
        let network = SupabaseService.ServiceError.networkError(URLError(.notConnectedToInternet))
        XCTAssertNotNil(network.errorDescription)
    }
    
    func testServiceErrorIsRetryable() {
        // 5xx errors are retryable
        let server500 = SupabaseService.ServiceError.invalidResponse(status: 500, body: "")
        XCTAssertTrue(server500.isRetryable)
        
        let server503 = SupabaseService.ServiceError.invalidResponse(status: 503, body: "")
        XCTAssertTrue(server503.isRetryable)
        
        // 4xx errors are generally not retryable
        let client400 = SupabaseService.ServiceError.invalidResponse(status: 400, body: "")
        XCTAssertFalse(client400.isRetryable)
        
        let client401 = SupabaseService.ServiceError.invalidResponse(status: 401, body: "")
        XCTAssertFalse(client401.isRetryable)
        
        // 429 is retryable (rate limited)
        let rateLimited = SupabaseService.ServiceError.invalidResponse(status: 429, body: "")
        XCTAssertTrue(rateLimited.isRetryable)
        
        // Network errors are retryable
        let networkError = SupabaseService.ServiceError.networkError(URLError(.timedOut))
        XCTAssertTrue(networkError.isRetryable)
    }
    
    // MARK: - Date Formatter Tests
    
    func testISO8601Formatter() {
        let formatter = SupabaseService.iso8601Formatter
        
        let date = Date(timeIntervalSince1970: 0)
        let formatted = formatter.string(from: date)
        
        XCTAssertTrue(formatted.contains("1970-01-01"))
    }
    
    func testISO8601FormatterWithFractionalSeconds() {
        let formatter = SupabaseService.iso8601FormatterWithFractionalSeconds
        
        let date = Date(timeIntervalSince1970: 0.123)
        let formatted = formatter.string(from: date)
        
        XCTAssertTrue(formatted.contains("1970-01-01"))
        // Should include fractional seconds
        XCTAssertTrue(formatted.contains("."))
    }
    
    // MARK: - Request Creation Tests
    
    func testCreateRequestWithValidConfig() throws {
        let config = SupabaseService.Configuration(
            projectURL: "https://example.supabase.co",
            apiKey: "test-api-key"
        )
        
        let request = try SupabaseService.createRequest(
            path: "/rest/v1/tasks",
            method: .GET,
            accessToken: "test-token",
            configuration: config
        )
        
        XCTAssertEqual(request.httpMethod, "GET")
        XCTAssertEqual(request.url?.host, "example.supabase.co")
        XCTAssertTrue(request.url?.path.contains("tasks") ?? false)
        XCTAssertEqual(request.value(forHTTPHeaderField: "apikey"), "test-api-key")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer test-token")
    }
    
    func testCreateRequestWithQueryItems() throws {
        let config = SupabaseService.Configuration(
            projectURL: "https://example.supabase.co",
            apiKey: "test-api-key"
        )
        
        let queryItems = [
            URLQueryItem(name: "select", value: "*"),
            URLQueryItem(name: "id", value: "eq.123")
        ]
        
        let request = try SupabaseService.createRequest(
            path: "/rest/v1/tasks",
            method: .GET,
            queryItems: queryItems,
            accessToken: "token",
            configuration: config
        )
        
        XCTAssertTrue(request.url?.absoluteString.contains("select=") ?? false)
        XCTAssertTrue(request.url?.absoluteString.contains("id=eq.123") ?? false)
    }
    
    func testCreateRequestWithBody() throws {
        let config = SupabaseService.Configuration(
            projectURL: "https://example.supabase.co",
            apiKey: "test-api-key"
        )
        
        struct TaskPayload: Encodable {
            let title: String
        }
        
        let payload = TaskPayload(title: "Test Task")
        
        let request = try SupabaseService.createRequest(
            path: "/rest/v1/tasks",
            method: .POST,
            body: payload,
            accessToken: "token",
            configuration: config
        )
        
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertNotNil(request.httpBody)
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
    }
    
    func testCreateRequestWithPreferHeader() throws {
        let config = SupabaseService.Configuration(
            projectURL: "https://example.supabase.co",
            apiKey: "test-api-key"
        )
        
        let request = try SupabaseService.createRequest(
            path: "/rest/v1/tasks",
            method: .POST,
            preferReturn: .representation,
            accessToken: "token",
            configuration: config
        )
        
        XCTAssertEqual(request.value(forHTTPHeaderField: "Prefer"), "return=representation")
    }
    
    func testCreateRequestInvalidURL() {
        let config = SupabaseService.Configuration(
            projectURL: "not a valid url",
            apiKey: "test-api-key"
        )
        
        XCTAssertThrowsError(try SupabaseService.createRequest(
            path: "/test",
            method: .GET,
            accessToken: "token",
            configuration: config
        ))
    }
}
