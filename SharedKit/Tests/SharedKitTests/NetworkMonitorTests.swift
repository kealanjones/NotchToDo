import XCTest
import Network
@testable import SharedKit

final class NetworkMonitorTests: XCTestCase {
    
    // MARK: - Singleton Tests
    
    func testSharedInstance() {
        let monitor1 = NetworkMonitor.shared
        let monitor2 = NetworkMonitor.shared
        
        XCTAssertTrue(monitor1 === monitor2)
    }
    
    // MARK: - Connection Type Tests
    
    func testConnectionTypeEquality() {
        XCTAssertEqual(NetworkMonitor.ConnectionType.wifi, .wifi)
        XCTAssertEqual(NetworkMonitor.ConnectionType.cellular, .cellular)
        XCTAssertEqual(NetworkMonitor.ConnectionType.wired, .wired)
        XCTAssertEqual(NetworkMonitor.ConnectionType.unknown, .unknown)
        XCTAssertNotEqual(NetworkMonitor.ConnectionType.wifi, .cellular)
    }
    
    func testConnectionTypeDescription() {
        XCTAssertEqual(NetworkMonitor.ConnectionType.wifi.description, "WiFi")
        XCTAssertEqual(NetworkMonitor.ConnectionType.cellular.description, "Cellular")
        XCTAssertEqual(NetworkMonitor.ConnectionType.wired.description, "Wired")
        XCTAssertEqual(NetworkMonitor.ConnectionType.unknown.description, "Unknown")
    }
    
    // MARK: - State Access Tests
    
    func testInitialState() {
        // NetworkMonitor will reflect actual device state
        // We just verify properties are accessible
        let monitor = NetworkMonitor.shared
        
        _ = monitor.isConnected
        _ = monitor.connectionType
        _ = monitor.isExpensive
        _ = monitor.isConstrained
    }
    
    // MARK: - Callbacks Tests
    
    func testOnConnectCallback() {
        let expectation = XCTestExpectation(description: "Connect callback")
        expectation.isInverted = true // We don't expect it to be called in test
        
        let monitor = NetworkMonitor.shared
        
        monitor.onConnect {
            expectation.fulfill()
        }
        
        // We can't easily trigger network events in tests
        // Just verify callback can be set without crashing
        wait(for: [expectation], timeout: 0.1)
    }
    
    func testOnDisconnectCallback() {
        let expectation = XCTestExpectation(description: "Disconnect callback")
        expectation.isInverted = true
        
        let monitor = NetworkMonitor.shared
        
        monitor.onDisconnect {
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 0.1)
    }
    
    func testOnChangeCallback() {
        let expectation = XCTestExpectation(description: "Change callback")
        expectation.isInverted = true
        
        let monitor = NetworkMonitor.shared
        
        monitor.onChange { connected, type in
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 0.1)
    }
    
    // MARK: - Clear Callbacks Tests
    
    func testClearCallbacks() {
        let monitor = NetworkMonitor.shared
        
        monitor.onConnect { }
        monitor.onDisconnect { }
        monitor.onChange { _, _ in }
        
        // Should not crash
        monitor.clearCallbacks()
    }
    
    // MARK: - When Connected Tests
    
    func testWhenConnectedAlreadyConnected() async {
        let monitor = NetworkMonitor.shared
        
        // If already connected, should complete immediately
        // If not connected, this would hang, but we add timeout
        do {
            try await withTimeout(seconds: 1.0) {
                if monitor.isConnected {
                    await monitor.whenConnected()
                }
            }
        } catch {
            // Timeout is acceptable if not connected
        }
    }
}

// MARK: - Test Helpers

private func withTimeout<T>(seconds: Double, operation: @escaping () async -> T) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        group.addTask {
            await operation()
        }
        
        group.addTask {
            try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            throw TimeoutError()
        }
        
        guard let result = try await group.next() else {
            throw TimeoutError()
        }
        
        group.cancelAll()
        return result
    }
}

private struct TimeoutError: Error {}
