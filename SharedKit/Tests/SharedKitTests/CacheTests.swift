import XCTest
@testable import SharedKit

final class CacheTests: XCTestCase {
    
    // MARK: - Basic Cache Tests
    
    func testCacheSetAndGet() {
        let cache = Cache<String, Int>()
        
        cache.set(42, forKey: "answer")
        
        XCTAssertEqual(cache.get("answer"), 42)
        XCTAssertNil(cache.get("nonexistent"))
    }
    
    func testCacheOverwrite() {
        let cache = Cache<String, String>()
        
        cache.set("first", forKey: "key")
        cache.set("second", forKey: "key")
        
        XCTAssertEqual(cache.get("key"), "second")
    }
    
    func testCacheRemove() {
        let cache = Cache<String, Int>()
        
        cache.set(100, forKey: "value")
        XCTAssertEqual(cache.get("value"), 100)
        
        cache.remove("value")
        XCTAssertNil(cache.get("value"))
    }
    
    func testCacheClear() {
        let cache = Cache<String, Int>()
        
        cache.set(1, forKey: "a")
        cache.set(2, forKey: "b")
        cache.set(3, forKey: "c")
        
        XCTAssertEqual(cache.count, 3)
        
        cache.clear()
        
        XCTAssertEqual(cache.count, 0)
        XCTAssertNil(cache.get("a"))
    }
    
    func testCacheContains() {
        let cache = Cache<String, Int>()
        
        cache.set(1, forKey: "exists")
        
        XCTAssertTrue(cache.contains("exists"))
        XCTAssertFalse(cache.contains("missing"))
    }
    
    // MARK: - TTL Tests
    
    func testCacheTTLExpiration() {
        let cache = Cache<String, Int>(defaultTTL: 0.1) // 100ms TTL
        
        cache.set(42, forKey: "expiring")
        XCTAssertEqual(cache.get("expiring"), 42)
        
        // Wait for expiration
        Thread.sleep(forTimeInterval: 0.15)
        
        XCTAssertNil(cache.get("expiring"))
    }
    
    func testCacheCustomTTL() {
        let cache = Cache<String, Int>(defaultTTL: 1.0) // 1s default
        
        cache.set(1, forKey: "short", ttl: 0.1) // 100ms override
        cache.set(2, forKey: "default") // uses 1s default
        
        Thread.sleep(forTimeInterval: 0.15)
        
        XCTAssertNil(cache.get("short")) // Should be expired
        XCTAssertEqual(cache.get("default"), 2) // Should still exist
    }
    
    func testCachePurgeExpired() {
        let cache = Cache<String, Int>(defaultTTL: 0.1)
        
        cache.set(1, forKey: "a")
        cache.set(2, forKey: "b")
        
        Thread.sleep(forTimeInterval: 0.15)
        
        // Add a non-expired entry
        cache.set(3, forKey: "c", ttl: 10.0)
        
        cache.purgeExpired()
        
        XCTAssertEqual(cache.count, 1)
        XCTAssertEqual(cache.get("c"), 3)
    }
    
    // MARK: - Max Entries Tests
    
    func testCacheMaxEntries() {
        let cache = Cache<Int, String>(maxEntries: 3)
        
        cache.set("one", forKey: 1)
        cache.set("two", forKey: 2)
        cache.set("three", forKey: 3)
        cache.set("four", forKey: 4)
        
        XCTAssertEqual(cache.count, 3)
        // First entry should be evicted
        XCTAssertNil(cache.get(1))
        XCTAssertEqual(cache.get(4), "four")
    }
    
    // MARK: - GetOrCompute Tests
    
    func testCacheGetOrCompute() {
        let cache = Cache<String, Int>()
        var computeCount = 0
        
        let result1 = cache.getOrCompute("key") {
            computeCount += 1
            return 42
        }
        
        let result2 = cache.getOrCompute("key") {
            computeCount += 1
            return 99
        }
        
        XCTAssertEqual(result1, 42)
        XCTAssertEqual(result2, 42) // Should return cached value
        XCTAssertEqual(computeCount, 1) // Should only compute once
    }
    
    func testCacheGetOrComputeAsync() async {
        let cache = Cache<String, Int>()
        var computeCount = 0
        
        let result1 = await cache.getOrCompute("key") {
            computeCount += 1
            return 42
        }
        
        let result2 = await cache.getOrCompute("key") {
            computeCount += 1
            return 99
        }
        
        XCTAssertEqual(result1, 42)
        XCTAssertEqual(result2, 42)
        XCTAssertEqual(computeCount, 1)
    }
    
    // MARK: - ComputedCache Tests
    
    func testComputedCache() {
        let computedCache = ComputedCache<Int>()
        var computeCount = 0
        
        let value1 = computedCache.get {
            computeCount += 1
            return 100
        }
        
        let value2 = computedCache.get {
            computeCount += 1
            return 200
        }
        
        XCTAssertEqual(value1, 100)
        XCTAssertEqual(value2, 100) // Should return cached
        XCTAssertEqual(computeCount, 1)
    }
    
    func testComputedCacheInvalidate() {
        let computedCache = ComputedCache<Int>()
        var computeCount = 0
        
        _ = computedCache.get {
            computeCount += 1
            return 100
        }
        
        computedCache.invalidate()
        
        let value = computedCache.get {
            computeCount += 1
            return 200
        }
        
        XCTAssertEqual(value, 200)
        XCTAssertEqual(computeCount, 2)
    }
    
    func testComputedCacheTTL() {
        let computedCache = ComputedCache<Int>(ttl: 0.1)
        var computeCount = 0
        
        _ = computedCache.get {
            computeCount += 1
            return 100
        }
        
        Thread.sleep(forTimeInterval: 0.15)
        
        let value = computedCache.get {
            computeCount += 1
            return 200
        }
        
        XCTAssertEqual(value, 200)
        XCTAssertEqual(computeCount, 2)
    }
    
    // MARK: - Memoization Tests
    
    func testMemoize() {
        var callCount = 0
        
        let expensiveFunction = memoize { (x: Int) -> Int in
            callCount += 1
            return x * x
        }
        
        XCTAssertEqual(expensiveFunction(5), 25)
        XCTAssertEqual(expensiveFunction(5), 25)
        XCTAssertEqual(expensiveFunction(3), 9)
        
        XCTAssertEqual(callCount, 2) // 5 and 3, not 5 twice
    }
    
    // MARK: - Thread Safety Tests
    
    func testCacheThreadSafety() {
        let cache = Cache<Int, Int>()
        let expectation = XCTestExpectation(description: "Concurrent access")
        expectation.expectedFulfillmentCount = 100
        
        DispatchQueue.concurrentPerform(iterations: 100) { i in
            cache.set(i, forKey: i)
            _ = cache.get(i)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5.0)
        XCTAssertGreaterThan(cache.count, 0)
    }
}
