package com.notchtodo.util

import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.runTest
import org.junit.After
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test

@OptIn(ExperimentalCoroutinesApi::class)
class PerformanceMonitorTest {

    @Before
    fun setUp() {
        PerformanceMonitor.reset()
        PerformanceMonitor.config = PerformanceMonitor.Config()
    }

    @After
    fun tearDown() {
        PerformanceMonitor.reset()
    }

    // MARK: - Basic Measurement Tests

    @Test
    fun `measure returns operation result`() {
        val result = PerformanceMonitor.measure("test") {
            Thread.sleep(10)
            42
        }
        
        assertEquals(42, result)
    }

    @Test
    fun `measure records metrics`() {
        PerformanceMonitor.measure("recordedOp") {
            Thread.sleep(10)
        }
        
        val metrics = PerformanceMonitor.getMetrics("recordedOp")
        
        assertNotNull(metrics)
        assertEquals(1, metrics?.count)
        assertTrue((metrics?.totalDurationMs ?: 0) >= 10)
    }

    @Test
    fun `measureAsync returns operation result`() = runTest {
        val result = PerformanceMonitor.measureAsync("asyncTest") {
            "async result"
        }
        
        assertEquals("async result", result)
    }

    @Test
    fun `throwing operations still record metrics`() {
        try {
            PerformanceMonitor.measure("throwingOp") {
                throw RuntimeException("Test error")
            }
        } catch (e: RuntimeException) {
            // Expected
        }
        
        val metrics = PerformanceMonitor.getMetrics("throwingOp")
        assertNotNull(metrics)
    }

    // MARK: - Timer Tests

    @Test
    fun `manual timer tracks elapsed time`() {
        val timer = PerformanceMonitor.startTimer()
        Thread.sleep(50)
        
        assertTrue(timer.elapsedMs >= 40)
        
        timer.stop("manualTimer")
        
        val metrics = PerformanceMonitor.getMetrics("manualTimer")
        assertNotNull(metrics)
    }

    // MARK: - Metrics Aggregation Tests

    @Test
    fun `multiple measurements aggregate correctly`() {
        repeat(5) {
            PerformanceMonitor.measure("repeated") {
                Thread.sleep(10)
            }
        }
        
        val metrics = PerformanceMonitor.getMetrics("repeated")
        
        assertNotNull(metrics)
        assertEquals(5, metrics?.count)
        assertTrue((metrics?.totalDurationMs ?: 0) >= 50)
        assertTrue((metrics?.averageDurationMs ?: 0.0) >= 10.0)
    }

    @Test
    fun `min and max are tracked correctly`() {
        // Short operation
        PerformanceMonitor.measure("varied") {
            Thread.sleep(10)
        }
        
        // Longer operation
        PerformanceMonitor.measure("varied") {
            Thread.sleep(50)
        }
        
        val metrics = PerformanceMonitor.getMetrics("varied")
        
        assertNotNull(metrics)
        assertTrue((metrics?.minDurationMs ?: 0) < (metrics?.maxDurationMs ?: 0))
    }

    @Test
    fun `slow operations are tracked`() {
        PerformanceMonitor.config = PerformanceMonitor.Config(slowOperationThresholdMs = 30)
        
        // Fast operation
        PerformanceMonitor.measure("speed") {
            Thread.sleep(10)
        }
        
        // Slow operation
        PerformanceMonitor.measure("speed") {
            Thread.sleep(50)
        }
        
        val metrics = PerformanceMonitor.getMetrics("speed")
        assertEquals(1, metrics?.slowCount)
    }

    // MARK: - Configuration Tests

    @Test
    fun `disabled monitoring skips recording`() {
        PerformanceMonitor.config = PerformanceMonitor.Config(isEnabled = false)
        
        val result = PerformanceMonitor.measure("disabled") {
            42
        }
        
        assertEquals(42, result)
        assertNull(PerformanceMonitor.getMetrics("disabled"))
    }

    @Test
    fun `disabled metrics collection skips recording`() {
        PerformanceMonitor.config = PerformanceMonitor.Config(collectMetrics = false)
        
        PerformanceMonitor.measure("noCollect") { }
        
        assertNull(PerformanceMonitor.getMetrics("noCollect"))
    }

    // MARK: - Report Generation Tests

    @Test
    fun `generateReport includes all operations`() {
        PerformanceMonitor.measure("op1") { Thread.sleep(10) }
        PerformanceMonitor.measure("op2") { Thread.sleep(10) }
        PerformanceMonitor.measure("op1") { Thread.sleep(10) }
        
        val report = PerformanceMonitor.generateReport()
        
        assertTrue(report.contains("Performance Report"))
        assertTrue(report.contains("op1"))
        assertTrue(report.contains("op2"))
        assertTrue(report.contains("Count:"))
    }

    // MARK: - getAllMetrics Tests

    @Test
    fun `getAllMetrics returns all operations`() {
        PerformanceMonitor.measure("a") { }
        PerformanceMonitor.measure("b") { }
        PerformanceMonitor.measure("c") { }
        
        val allMetrics = PerformanceMonitor.getAllMetrics()
        
        assertEquals(3, allMetrics.size)
        assertTrue(allMetrics.any { it.name == "a" })
        assertTrue(allMetrics.any { it.name == "b" })
        assertTrue(allMetrics.any { it.name == "c" })
    }

    // MARK: - Reset Tests

    @Test
    fun `reset clears all metrics`() {
        PerformanceMonitor.measure("beforeReset") { }
        assertNotNull(PerformanceMonitor.getMetrics("beforeReset"))
        
        PerformanceMonitor.reset()
        
        assertNull(PerformanceMonitor.getMetrics("beforeReset"))
        assertTrue(PerformanceMonitor.getAllMetrics().isEmpty())
    }
}
