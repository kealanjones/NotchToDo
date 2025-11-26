import Foundation

/// Performance monitoring and timing utilities
public final class PerformanceMonitor {
    
    public static let shared = PerformanceMonitor()
    
    // MARK: - Configuration
    
    public struct Config {
        public var isEnabled: Bool
        public var slowOperationThresholdMs: Double
        public var logSlowOperations: Bool
        public var collectMetrics: Bool
        
        public static let `default` = Config(
            isEnabled: true,
            slowOperationThresholdMs: 100,
            logSlowOperations: true,
            collectMetrics: true
        )
        
        public init(
            isEnabled: Bool = true,
            slowOperationThresholdMs: Double = 100,
            logSlowOperations: Bool = true,
            collectMetrics: Bool = true
        ) {
            self.isEnabled = isEnabled
            self.slowOperationThresholdMs = slowOperationThresholdMs
            self.logSlowOperations = logSlowOperations
            self.collectMetrics = collectMetrics
        }
    }
    
    public var config: Config = .default
    
    // MARK: - Metrics Storage
    
    public struct OperationMetrics {
        public let name: String
        public let count: Int
        public let totalDurationMs: Double
        public let averageDurationMs: Double
        public let minDurationMs: Double
        public let maxDurationMs: Double
        public let slowCount: Int
    }
    
    private struct MetricsAccumulator {
        var count: Int = 0
        var totalDuration: Double = 0
        var minDuration: Double = .infinity
        var maxDuration: Double = 0
        var slowCount: Int = 0
    }
    
    private var metrics: [String: MetricsAccumulator] = [:]
    private let metricsLock = NSLock()
    
    private init() {}
    
    // MARK: - Timing Operations
    
    /// Measure the execution time of a synchronous operation
    @discardableResult
    public func measure<T>(
        _ name: String,
        operation: () throws -> T
    ) rethrows -> T {
        guard config.isEnabled else {
            return try operation()
        }
        
        let startTime = CFAbsoluteTimeGetCurrent()
        let result = try operation()
        let endTime = CFAbsoluteTimeGetCurrent()
        
        let durationMs = (endTime - startTime) * 1000
        recordMetric(name: name, durationMs: durationMs)
        
        return result
    }
    
    /// Measure the execution time of an async operation
    @discardableResult
    public func measureAsync<T>(
        _ name: String,
        operation: () async throws -> T
    ) async rethrows -> T {
        guard config.isEnabled else {
            return try await operation()
        }
        
        let startTime = CFAbsoluteTimeGetCurrent()
        let result = try await operation()
        let endTime = CFAbsoluteTimeGetCurrent()
        
        let durationMs = (endTime - startTime) * 1000
        recordMetric(name: name, durationMs: durationMs)
        
        return result
    }
    
    /// Start a timer for manual timing
    public func startTimer() -> Timer {
        return Timer()
    }
    
    /// Timer class for manual timing
    public final class Timer {
        private let startTime: CFAbsoluteTime
        
        fileprivate init() {
            startTime = CFAbsoluteTimeGetCurrent()
        }
        
        /// Get elapsed time in milliseconds
        public var elapsedMs: Double {
            return (CFAbsoluteTimeGetCurrent() - startTime) * 1000
        }
        
        /// Stop the timer and record the metric
        public func stop(name: String) {
            PerformanceMonitor.shared.recordMetric(name: name, durationMs: elapsedMs)
        }
    }
    
    // MARK: - Metrics Recording
    
    private func recordMetric(name: String, durationMs: Double) {
        // Log slow operations
        if config.logSlowOperations && durationMs > config.slowOperationThresholdMs {
            DebugLog.log("⚠️ SLOW: \(name) took \(String(format: "%.2f", durationMs))ms", category: .app)
        }
        
        // Collect metrics
        if config.collectMetrics {
            metricsLock.lock()
            defer { metricsLock.unlock() }
            
            var acc = metrics[name] ?? MetricsAccumulator()
            acc.count += 1
            acc.totalDuration += durationMs
            acc.minDuration = min(acc.minDuration, durationMs)
            acc.maxDuration = max(acc.maxDuration, durationMs)
            if durationMs > config.slowOperationThresholdMs {
                acc.slowCount += 1
            }
            metrics[name] = acc
        }
    }
    
    // MARK: - Metrics Retrieval
    
    /// Get metrics for a specific operation
    public func getMetrics(for name: String) -> OperationMetrics? {
        metricsLock.lock()
        defer { metricsLock.unlock() }
        
        guard let acc = metrics[name], acc.count > 0 else { return nil }
        
        return OperationMetrics(
            name: name,
            count: acc.count,
            totalDurationMs: acc.totalDuration,
            averageDurationMs: acc.totalDuration / Double(acc.count),
            minDurationMs: acc.minDuration,
            maxDurationMs: acc.maxDuration,
            slowCount: acc.slowCount
        )
    }
    
    /// Get all recorded metrics
    public func getAllMetrics() -> [OperationMetrics] {
        metricsLock.lock()
        defer { metricsLock.unlock() }
        
        return metrics.compactMap { name, acc in
            guard acc.count > 0 else { return nil }
            return OperationMetrics(
                name: name,
                count: acc.count,
                totalDurationMs: acc.totalDuration,
                averageDurationMs: acc.totalDuration / Double(acc.count),
                minDurationMs: acc.minDuration,
                maxDurationMs: acc.maxDuration,
                slowCount: acc.slowCount
            )
        }
    }
    
    /// Generate a summary report
    public func generateReport() -> String {
        let allMetrics = getAllMetrics().sorted { $0.totalDurationMs > $1.totalDurationMs }
        
        var report = "=== Performance Report ===\n"
        report += "Operations: \(allMetrics.count)\n\n"
        
        for metric in allMetrics {
            report += "[\(metric.name)]\n"
            report += "  Count: \(metric.count)\n"
            report += "  Total: \(String(format: "%.2f", metric.totalDurationMs))ms\n"
            report += "  Avg: \(String(format: "%.2f", metric.averageDurationMs))ms\n"
            report += "  Min: \(String(format: "%.2f", metric.minDurationMs))ms\n"
            report += "  Max: \(String(format: "%.2f", metric.maxDurationMs))ms\n"
            if metric.slowCount > 0 {
                report += "  Slow: \(metric.slowCount) (\(Int(Double(metric.slowCount) / Double(metric.count) * 100))%)\n"
            }
            report += "\n"
        }
        
        return report
    }
    
    /// Reset all metrics
    public func reset() {
        metricsLock.lock()
        defer { metricsLock.unlock() }
        metrics.removeAll()
    }
}

// MARK: - Convenience Functions

/// Measure a synchronous operation
@discardableResult
public func measurePerformance<T>(
    _ name: String,
    operation: () throws -> T
) rethrows -> T {
    return try PerformanceMonitor.shared.measure(name, operation: operation)
}

/// Measure an async operation
@discardableResult
public func measurePerformanceAsync<T>(
    _ name: String,
    operation: () async throws -> T
) async rethrows -> T {
    return try await PerformanceMonitor.shared.measureAsync(name, operation: operation)
}
