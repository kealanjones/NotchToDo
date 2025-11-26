package com.notchtodo.util

import java.util.concurrent.ConcurrentHashMap
import kotlin.system.measureNanoTime

/**
 * Performance monitoring and timing utilities.
 */
object PerformanceMonitor {
    
    // MARK: - Configuration
    
    data class Config(
        var isEnabled: Boolean = true,
        var slowOperationThresholdMs: Double = 100.0,
        var logSlowOperations: Boolean = true,
        var collectMetrics: Boolean = true
    )
    
    var config = Config()
    
    // MARK: - Metrics
    
    data class OperationMetrics(
        val name: String,
        val count: Int,
        val totalDurationMs: Double,
        val averageDurationMs: Double,
        val minDurationMs: Double,
        val maxDurationMs: Double,
        val slowCount: Int
    )
    
    private data class MetricsAccumulator(
        var count: Int = 0,
        var totalDuration: Double = 0.0,
        var minDuration: Double = Double.MAX_VALUE,
        var maxDuration: Double = 0.0,
        var slowCount: Int = 0
    )
    
    private val metrics = ConcurrentHashMap<String, MetricsAccumulator>()
    
    // MARK: - Timing Operations
    
    /**
     * Measure the execution time of a synchronous operation.
     */
    inline fun <T> measure(name: String, operation: () -> T): T {
        if (!config.isEnabled) {
            return operation()
        }
        
        val result: T
        val durationNs = measureNanoTime {
            result = operation()
        }
        
        val durationMs = durationNs / 1_000_000.0
        recordMetric(name, durationMs)
        
        return result
    }
    
    /**
     * Measure the execution time of a suspending operation.
     */
    suspend inline fun <T> measureAsync(name: String, crossinline operation: suspend () -> T): T {
        if (!config.isEnabled) {
            return operation()
        }
        
        val startTime = System.nanoTime()
        val result = operation()
        val endTime = System.nanoTime()
        
        val durationMs = (endTime - startTime) / 1_000_000.0
        recordMetric(name, durationMs)
        
        return result
    }
    
    /**
     * Start a timer for manual timing.
     */
    fun startTimer(): Timer = Timer()
    
    /**
     * Timer class for manual timing.
     */
    class Timer {
        private val startTime = System.nanoTime()
        
        /**
         * Get elapsed time in milliseconds.
         */
        val elapsedMs: Double
            get() = (System.nanoTime() - startTime) / 1_000_000.0
        
        /**
         * Stop the timer and record the metric.
         */
        fun stop(name: String) {
            recordMetric(name, elapsedMs)
        }
    }
    
    // MARK: - Metrics Recording
    
    @PublishedApi
    internal fun recordMetric(name: String, durationMs: Double) {
        // Log slow operations
        if (config.logSlowOperations && durationMs > config.slowOperationThresholdMs) {
            DebugLog.log("⚠️ SLOW: $name took ${String.format("%.2f", durationMs)}ms", DebugLog.Category.APP)
        }
        
        // Collect metrics
        if (config.collectMetrics) {
            metrics.compute(name) { _, existing ->
                val acc = existing ?: MetricsAccumulator()
                acc.count++
                acc.totalDuration += durationMs
                acc.minDuration = minOf(acc.minDuration, durationMs)
                acc.maxDuration = maxOf(acc.maxDuration, durationMs)
                if (durationMs > config.slowOperationThresholdMs) {
                    acc.slowCount++
                }
                acc
            }
        }
    }
    
    // MARK: - Metrics Retrieval
    
    /**
     * Get metrics for a specific operation.
     */
    fun getMetrics(name: String): OperationMetrics? {
        val acc = metrics[name] ?: return null
        if (acc.count == 0) return null
        
        return OperationMetrics(
            name = name,
            count = acc.count,
            totalDurationMs = acc.totalDuration,
            averageDurationMs = acc.totalDuration / acc.count,
            minDurationMs = acc.minDuration,
            maxDurationMs = acc.maxDuration,
            slowCount = acc.slowCount
        )
    }
    
    /**
     * Get all recorded metrics.
     */
    fun getAllMetrics(): List<OperationMetrics> {
        return metrics.mapNotNull { (name, acc) ->
            if (acc.count == 0) return@mapNotNull null
            OperationMetrics(
                name = name,
                count = acc.count,
                totalDurationMs = acc.totalDuration,
                averageDurationMs = acc.totalDuration / acc.count,
                minDurationMs = acc.minDuration,
                maxDurationMs = acc.maxDuration,
                slowCount = acc.slowCount
            )
        }
    }
    
    /**
     * Generate a summary report.
     */
    fun generateReport(): String {
        val allMetrics = getAllMetrics().sortedByDescending { it.totalDurationMs }
        
        return buildString {
            appendLine("=== Performance Report ===")
            appendLine("Operations: ${allMetrics.size}")
            appendLine()
            
            for (metric in allMetrics) {
                appendLine("[${metric.name}]")
                appendLine("  Count: ${metric.count}")
                appendLine("  Total: ${String.format("%.2f", metric.totalDurationMs)}ms")
                appendLine("  Avg: ${String.format("%.2f", metric.averageDurationMs)}ms")
                appendLine("  Min: ${String.format("%.2f", metric.minDurationMs)}ms")
                appendLine("  Max: ${String.format("%.2f", metric.maxDurationMs)}ms")
                if (metric.slowCount > 0) {
                    val slowPercent = (metric.slowCount.toDouble() / metric.count * 100).toInt()
                    appendLine("  Slow: ${metric.slowCount} ($slowPercent%)")
                }
                appendLine()
            }
        }
    }
    
    /**
     * Reset all metrics.
     */
    fun reset() {
        metrics.clear()
    }
}

/**
 * Measure a synchronous operation.
 */
inline fun <T> measurePerformance(name: String, operation: () -> T): T {
    return PerformanceMonitor.measure(name, operation)
}

/**
 * Measure a suspending operation.
 */
suspend inline fun <T> measurePerformanceAsync(name: String, crossinline operation: suspend () -> T): T {
    return PerformanceMonitor.measureAsync(name, operation)
}
