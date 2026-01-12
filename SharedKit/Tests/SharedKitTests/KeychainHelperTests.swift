import XCTest
@testable import SharedKit

final class KeychainHelperTests: XCTestCase {
    
    let testKey = "com.notchtodo.test.key"
    let testData = "test-secret-data"
    
    override func tearDown() {
        // Clean up test key
        try? KeychainHelper.delete(key: testKey)
        super.tearDown()
    }
    
    // MARK: - Save and Retrieve Tests
    
    func testSaveAndRetrieveString() throws {
        try KeychainHelper.save(testData, forKey: testKey)
        
        let retrieved = try KeychainHelper.load(key: testKey)
        XCTAssertEqual(retrieved, testData)
    }
    
    func testSaveAndRetrieveData() throws {
        let data = testData.data(using: .utf8)!
        try KeychainHelper.saveData(data, forKey: testKey)
        
        let retrievedData = try KeychainHelper.loadData(key: testKey)
        XCTAssertEqual(retrievedData, data)
    }
    
    // MARK: - Update Tests
    
    func testUpdateExisting() throws {
        try KeychainHelper.save("original", forKey: testKey)
        try KeychainHelper.save("updated", forKey: testKey)
        
        let retrieved = try KeychainHelper.load(key: testKey)
        XCTAssertEqual(retrieved, "updated")
    }
    
    // MARK: - Delete Tests
    
    func testDelete() throws {
        try KeychainHelper.save(testData, forKey: testKey)
        try KeychainHelper.delete(key: testKey)
        
        XCTAssertThrowsError(try KeychainHelper.load(key: testKey))
    }
    
    // MARK: - Not Found Tests
    
    func testLoadNonexistent() {
        XCTAssertThrowsError(try KeychainHelper.load(key: "nonexistent.key")) { error in
            if let keychainError = error as? KeychainHelper.KeychainError {
                if case .itemNotFound = keychainError {
                    // Expected
                } else {
                    XCTFail("Wrong keychain error: \(keychainError)")
                }
            }
        }
    }
    
    // MARK: - Error Tests
    
    func testKeychainErrorDescription() {
        let notFound = KeychainHelper.KeychainError.itemNotFound
        XCTAssertNotNil(notFound.errorDescription)
        
        let unexpected = KeychainHelper.KeychainError.unexpectedError(status: -25300)
        XCTAssertTrue(unexpected.errorDescription?.contains("-25300") ?? false)
    }
    
    // MARK: - Convenience Method Tests
    
    func testExistsMethod() throws {
        XCTAssertFalse(KeychainHelper.exists(key: testKey))
        
        try KeychainHelper.save(testData, forKey: testKey)
        
        XCTAssertTrue(KeychainHelper.exists(key: testKey))
    }
    
    func testLoadOptionalMethod() throws {
        // Non-existent
        XCTAssertNil(KeychainHelper.loadOptional(key: testKey))
        
        // Existing
        try KeychainHelper.save(testData, forKey: testKey)
        XCTAssertEqual(KeychainHelper.loadOptional(key: testKey), testData)
    }
}
