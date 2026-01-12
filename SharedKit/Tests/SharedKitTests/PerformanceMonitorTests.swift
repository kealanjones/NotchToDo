import XCTest
@testable import SharedKit

final class PerformanceMonitorTests: XCTestCase {
    
    var monitor: PerformanceMonitor!
    
    override func setUp() {
        super.setUp()
        monitor = PerformanceMonitor.shared
        monitor.reset()
        monitor.config = .default
    }
    
    override func tearDown() {
        monitor.reset()
        super.tearDown()
    }
    
    // MARK: - Basic Measurement Tests
    
    func testMeasureSyncOperation() {
        let result = monitor.measure("testOp") {
            Thread.sleep(forTimeInterval: 0.05)
            return 42
        }
        
        XCTAssertEqual(result, 42)
        
        let metrics = monitor.getMetrics(for: "testOp")
        XCTAssertNotNil(metrics)
        XCTAssertEqual(metrics?.count, 1)
        XCTAssertGreaterThanOrEqual(metrics?.totalDurationMs ?? 0, 40)
    }
    
    func testMeasureAsyncOperation() async {
        let result = await monitor.measureAsync("asyncOp") {
            try? await Task.sleep(nanoseconds: 50_000_000) // 50ms
            return "done"
        }
        
        XCTAssertEqual(result, "done")
        
        let metrics = monitor.getMetrics(for: "asyncOp")
        XCTAssertNotNil(metrics)
        XCTAssertGreaterThanOrEqual(metrics?.totalDurationMs ?? 0, 40)
    }
    
    func testMeasureThrowingOperation() {
        struct TestError: Error {}
        
        XCTAssertThrowsError(try monitor.measure("throwingOp") {
            throw TestError()
        })
        
        // Should still record the metric even if it throws
        let metrics = monitor.getMetrics(for: "throwingOp")
        XCTAssertNotNil(metrics)
    }
    
    // MARK: - Timer Tests
    
    func testManualTimer() {
        let timer = monitor.startTimer()
        Thread.sleep(forTimeInterval: 0.05)
        
        XCTAssertGreaterThanOrEqual(timer.elapsedMs, 40)
        
        timer.stop(name: "manualTimer")
        
        let metrics = monitor.getMetrics(for: "manualTimer")
        XCTAssertNotNil(metrics)
    }
    
    // MARK: - Metrics Aggregation Tests
    
    func testMetricsAggregation() {
        for _ in 0..<5 {
            _ = monitor.measure("repeated") {
                Thread.sleep(forTimeInterval: 0.01)
                return true
            }
        }
        
        let metrics = monitor.getMetrics(for: "repeated")
        XCTAssertNotNil(metrics)
        XCTAssertEqual(metrics?.count, 5)
        XCTAssertGreaterThan(metrics?.totalDurationMs ?? 0, 0)
        XCTAssertGreaterThan(metrics?.averageDurationMs ?? 0, 0)
        XCTAssertLessThanOrEqual(metrics?.minDurationMs ?? 0, metrics?.maxDurationMs ?? 0)
    }
    
    func testSlowOperationTracking() {
        monitor.config.slowOperationThresholdMs = 10
        
        // Fast operation
        _ = monitor.measure("fastOp") { return 1 }
        
        // Slow operation
        _ = monitor.measure("slowOp") {
            Thread.sleep(forTimeInterval: 0.02) // 20ms
            return 2
        }
        
        let fastMetrics = monitor.getMetrics(for: "fastOp")
        let slowMetrics = monitor.getMetrics(for: "slowOp")
        
        XCTAssertEqual(fastMetrics?.slowCount, 0)
        XCTAssertEqual(slowMetrics?.slowCount, 1)
    }
    
    // MARK: - Configuration Tests
    
    func testDisabledMonitoring() {
        monitor.config.isEnabled = false
        
        let result = monitor.measure("disabled") {
            Thread.sleep(forTimeInterval: 0.01)
            return 42
        }
        
        XCTAssertEqual(result, 42)
        XCTAssertNil(monitor.getMetrics(for: "disabled"))
    }
    
    func testMetricsCollectionDisabled() {
        monitor.config.collectMetrics = false
        
        _ = monitor.measure("noCollect") { return 1 }
        
        XCTAssertNil(monitor.getMetrics(for: "noCollect"))
    }
    
    // MARK: - Report Generation Tests
    
    func testGenerateReport() {
        _ = monitor.measure("op1") { Thread.sleep(forTimeInterval: 0.01) }
        _ = monitor.measure("op2") { Thread.sleep(forTimeInterval: 0.02) }
        _ = monitor.measure("op1") { Thread.sleep(forTimeInterval: 0.01) }
        
        let report = monitor.generateReport()
        
        XCTAssertTrue(report.contains("Performance Report"))
        XCTAssertTrue(report.contains("op1"))
        XCTAssertTrue(report.contains("op2"))
        XCTAssertTrue(report.contains("Count:"))
        XCTAssertTrue(report.contains("Avg:"))
    }
    
    // MARK: - GetAllMetrics Tests
    
    func testGetAllMetrics() {
        _ = monitor.measure("a") { return 1 }
        _ = monitor.measure("b") { return 2 }
        _ = monitor.measure("c") { return 3 }
        
        let allMetrics = monitor.getAllMetrics()
        
        XCTAssertEqual(allMetrics.count, 3)
        XCTAssertTrue(allMetrics.contains { $0.name == "a" })
        XCTAssertTrue(allMetrics.contains { $0.name == "b" })
        XCTAssertTrue(allMetrics.contains { $0.name == "c" })
    }
    
    // MARK: - Reset Tests
    
    func testReset() {
        _ = monitor.measure("beforeReset") { return 1 }
        XCTAssertNotNil(monitor.getMetrics(for: "beforeReset"))
        
        monitor.reset()
        
        XCTAssertNil(monitor.getMetrics(for: "beforeReset"))
        XCTAssertTrue(monitor.getAllMetrics().isEmpty)
    }
    
    // MARK: - Convenience Function Tests
    
    func testGlobalMeasurePerformance() {
        let result = measurePerformance("globalTest") {
            return 123
        }
        
        XCTAssertEqual(result, 123)
    }
    
    func testGlobalMeasurePerformanceAsync() async {
        let result = await measurePerformanceAsync("globalAsyncTest") {
            return "async result"
        }
        
        XCTAssertEqual(result, "async result")
    }
}
