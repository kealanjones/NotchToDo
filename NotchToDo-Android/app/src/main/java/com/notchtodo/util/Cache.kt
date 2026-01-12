package com.notchtodo.util

import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.TimeUnit

/**
 * Thread-safe generic cache with TTL support.
 */
class Cache<K : Any, V : Any>(
    private val defaultTTLMillis: Long? = null,
    private val maxEntries: Int? = null
) {
    private data class CacheEntry<V>(
        val value: V,
        val expirationTime: Long?
    ) {
        val isExpired: Boolean
            get() = expirationTime != null && System.currentTimeMillis() > expirationTime
    }
    
    private val storage = ConcurrentHashMap<K, CacheEntry<V>>()
    
    /**
     * Gets a value from the cache.
     */
    fun get(key: K): V? {
        val entry = storage[key] ?: return null
        
        if (entry.isExpired) {
            storage.remove(key)
            return null
        }
        
        return entry.value
    }
    
    /**
     * Sets a value in the cache.
     */
    fun set(key: K, value: V, ttlMillis: Long? = null) {
        val effectiveTTL = ttlMillis ?: defaultTTLMillis
        val expiration = effectiveTTL?.let { System.currentTimeMillis() + it }
        
        storage[key] = CacheEntry(value, expiration)
        
        // Evict if over limit
        maxEntries?.let { max ->
            while (storage.size > max) {
                storage.keys.firstOrNull()?.let { storage.remove(it) }
            }
        }
    }
    
    /**
     * Gets a value or computes and caches it if missing.
     */
    inline fun getOrCompute(key: K, ttlMillis: Long? = null, compute: () -> V): V {
        get(key)?.let { return it }
        
        val value = compute()
        set(key, value, ttlMillis)
        return value
    }
    
    /**
     * Async version of getOrCompute.
     */
    suspend inline fun getOrComputeAsync(
        key: K,
        ttlMillis: Long? = null,
        crossinline compute: suspend () -> V
    ): V {
        get(key)?.let { return it }
        
        val value = compute()
        set(key, value, ttlMillis)
        return value
    }
    
    /**
     * Removes a value from the cache.
     */
    fun remove(key: K) {
        storage.remove(key)
    }
    
    /**
     * Clears all entries from the cache.
     */
    fun clear() {
        storage.clear()
    }
    
    /**
     * Removes all expired entries.
     */
    fun purgeExpired() {
        val keysToRemove = storage.filter { it.value.isExpired }.keys
        keysToRemove.forEach { storage.remove(it) }
    }
    
    /**
     * Current number of entries.
     */
    val size: Int get() = storage.size
    
    /**
     * Check if a key exists (and is not expired).
     */
    fun contains(key: K): Boolean = get(key) != null
    
    companion object {
        /**
         * Creates a cache with TTL in seconds.
         */
        fun <K : Any, V : Any> withTTLSeconds(
            seconds: Long,
            maxEntries: Int? = null
        ): Cache<K, V> {
            return Cache(TimeUnit.SECONDS.toMillis(seconds), maxEntries)
        }
        
        /**
         * Creates a cache with TTL in minutes.
         */
        fun <K : Any, V : Any> withTTLMinutes(
            minutes: Long,
            maxEntries: Int? = null
        ): Cache<K, V> {
            return Cache(TimeUnit.MINUTES.toMillis(minutes), maxEntries)
        }
    }
}

/**
 * Memoizes a function with a single argument.
 */
fun <I : Any, O : Any> memoize(
    ttlMillis: Long? = null,
    function: (I) -> O
): (I) -> O {
    val cache = Cache<I, O>(ttlMillis)
    return { input -> cache.getOrCompute(input) { function(input) } }
}

/**
 * Cache for expensive computed properties.
 */
class ComputedCache<V : Any>(
    private val ttlMillis: Long? = null
) {
    @Volatile
    private var cachedValue: V? = null
    
    @Volatile
    private var lastComputedAt: Long? = null
    
    private val lock = Any()
    
    fun get(compute: () -> V): V {
        synchronized(lock) {
            // Check if cached value is still valid
            cachedValue?.let { value ->
                val ttl = ttlMillis
                val lastComputed = lastComputedAt
                
                if (ttl == null) {
                    return value
                }
                
                if (lastComputed != null && System.currentTimeMillis() - lastComputed < ttl) {
                    return value
                }
            }
            
            // Compute and cache
            val value = compute()
            cachedValue = value
            lastComputedAt = System.currentTimeMillis()
            return value
        }
    }
    
    suspend fun getAsync(compute: suspend () -> V): V {
        // Check cache first without lock
        cachedValue?.let { value ->
            val ttl = ttlMillis
            val lastComputed = lastComputedAt
            
            if (ttl == null) {
                return value
            }
            
            if (lastComputed != null && System.currentTimeMillis() - lastComputed < ttl) {
                return value
            }
        }
        
        // Compute (potentially expensive)
        val value = compute()
        
        // Update cache with lock
        synchronized(lock) {
            cachedValue = value
            lastComputedAt = System.currentTimeMillis()
        }
        
        return value
    }
    
    fun invalidate() {
        synchronized(lock) {
            cachedValue = null
            lastComputedAt = null
        }
    }
}
