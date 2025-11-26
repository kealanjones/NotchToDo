package com.notchtodo.util

import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.runTest
import org.junit.After
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import kotlin.concurrent.thread

@OptIn(ExperimentalCoroutinesApi::class)
class CacheTest {

    private lateinit var cache: Cache<String, Int>

    @Before
    fun setUp() {
        cache = Cache()
    }

    @After
    fun tearDown() {
        cache.clear()
    }

    // MARK: - Basic Tests

    @Test
    fun `set and get returns cached value`() {
        cache.set("answer", 42)
        assertEquals(42, cache.get("answer"))
    }

    @Test
    fun `get returns null for missing key`() {
        assertNull(cache.get("nonexistent"))
    }

    @Test
    fun `set overwrites existing value`() {
        cache.set("key", 1)
        cache.set("key", 2)
        assertEquals(2, cache.get("key"))
    }

    @Test
    fun `remove deletes entry`() {
        cache.set("key", 100)
        cache.remove("key")
        assertNull(cache.get("key"))
    }

    @Test
    fun `clear removes all entries`() {
        cache.set("a", 1)
        cache.set("b", 2)
        cache.set("c", 3)
        
        assertEquals(3, cache.count)
        cache.clear()
        
        assertEquals(0, cache.count)
        assertNull(cache.get("a"))
    }

    @Test
    fun `contains returns true for existing key`() {
        cache.set("exists", 1)
        assertTrue(cache.contains("exists"))
        assertFalse(cache.contains("missing"))
    }

    // MARK: - TTL Tests

    @Test
    fun `expired entries return null`() {
        val shortTtlCache = Cache<String, Int>(defaultTtlMs = 50)
        shortTtlCache.set("expiring", 42)
        
        assertEquals(42, shortTtlCache.get("expiring"))
        Thread.sleep(100)
        
        assertNull(shortTtlCache.get("expiring"))
    }

    @Test
    fun `custom TTL overrides default`() {
        val longTtlCache = Cache<String, Int>(defaultTtlMs = 5000)
        longTtlCache.set("short", 1, ttlMs = 50)
        longTtlCache.set("default", 2)
        
        Thread.sleep(100)
        
        assertNull(longTtlCache.get("short"))
        assertEquals(2, longTtlCache.get("default"))
    }

    @Test
    fun `purgeExpired removes only expired entries`() {
        val cache = Cache<String, Int>(defaultTtlMs = 50)
        cache.set("a", 1)
        cache.set("b", 2)
        
        Thread.sleep(100)
        cache.set("c", 3, ttlMs = 10000)
        
        cache.purgeExpired()
        
        assertEquals(1, cache.count)
        assertEquals(3, cache.get("c"))
    }

    // MARK: - Max Entries Tests

    @Test
    fun `max entries evicts oldest when exceeded`() {
        val limitedCache = Cache<Int, String>(maxEntries = 3)
        
        limitedCache.set(1, "one")
        limitedCache.set(2, "two")
        limitedCache.set(3, "three")
        limitedCache.set(4, "four")
        
        assertEquals(3, limitedCache.count)
        assertNull(limitedCache.get(1))
        assertEquals("four", limitedCache.get(4))
    }

    // MARK: - GetOrCompute Tests

    @Test
    fun `getOrCompute computes on miss`() {
        var computeCount = 0
        
        val result1 = cache.getOrCompute("key") {
            computeCount++
            42
        }
        
        val result2 = cache.getOrCompute("key") {
            computeCount++
            99
        }
        
        assertEquals(42, result1)
        assertEquals(42, result2)
        assertEquals(1, computeCount)
    }

    @Test
    fun `getOrComputeAsync computes on miss`() = runTest {
        val cache = Cache<String, Int>()
        var computeCount = 0
        
        val result1 = cache.getOrComputeAsync("key") {
            computeCount++
            42
        }
        
        val result2 = cache.getOrComputeAsync("key") {
            computeCount++
            99
        }
        
        assertEquals(42, result1)
        assertEquals(42, result2)
        assertEquals(1, computeCount)
    }

    // MARK: - Thread Safety Tests

    @Test
    fun `concurrent access is thread safe`() {
        val cache = Cache<Int, Int>()
        val latch = CountDownLatch(100)
        
        repeat(100) { i ->
            thread {
                cache.set(i, i)
                cache.get(i)
                latch.countDown()
            }
        }
        
        assertTrue(latch.await(5, TimeUnit.SECONDS))
        assertTrue(cache.count > 0)
    }

    // MARK: - ComputedCache Tests

    @Test
    fun `computedCache returns cached value`() {
        val computedCache = ComputedCache<Int>()
        var computeCount = 0
        
        val value1 = computedCache.get {
            computeCount++
            100
        }
        
        val value2 = computedCache.get {
            computeCount++
            200
        }
        
        assertEquals(100, value1)
        assertEquals(100, value2)
        assertEquals(1, computeCount)
    }

    @Test
    fun `computedCache invalidate clears cache`() {
        val computedCache = ComputedCache<Int>()
        var computeCount = 0
        
        computedCache.get {
            computeCount++
            100
        }
        
        computedCache.invalidate()
        
        val value = computedCache.get {
            computeCount++
            200
        }
        
        assertEquals(200, value)
        assertEquals(2, computeCount)
    }

    @Test
    fun `computedCache respects TTL`() {
        val computedCache = ComputedCache<Int>(ttlMs = 50)
        var computeCount = 0
        
        computedCache.get {
            computeCount++
            100
        }
        
        Thread.sleep(100)
        
        val value = computedCache.get {
            computeCount++
            200
        }
        
        assertEquals(200, value)
        assertEquals(2, computeCount)
    }

    // MARK: - Memoization Tests

    @Test
    fun `memoize caches function results`() {
        var callCount = 0
        
        val expensiveFunction = memoize<Int, Int> { x ->
            callCount++
            x * x
        }
        
        assertEquals(25, expensiveFunction(5))
        assertEquals(25, expensiveFunction(5))
        assertEquals(9, expensiveFunction(3))
        
        assertEquals(2, callCount)
    }
}
