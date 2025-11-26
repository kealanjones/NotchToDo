import Foundation

/// Thread-safe generic cache with TTL support
public final class Cache<Key: Hashable, Value> {
    
    private struct CacheEntry {
        let value: Value
        let expirationDate: Date?
        
        var isExpired: Bool {
            guard let expiration = expirationDate else { return false }
            return Date() > expiration
        }
    }
    
    private var storage: [Key: CacheEntry] = [:]
    private let lock = NSLock()
    private let defaultTTL: TimeInterval?
    private let maxEntries: Int?
    
    /// Creates a new cache
    /// - Parameters:
    ///   - defaultTTL: Default time-to-live for entries (nil = no expiration)
    ///   - maxEntries: Maximum number of entries (nil = unlimited)
    public init(defaultTTL: TimeInterval? = nil, maxEntries: Int? = nil) {
        self.defaultTTL = defaultTTL
        self.maxEntries = maxEntries
    }
    
    /// Gets a value from the cache
    public func get(_ key: Key) -> Value? {
        lock.lock()
        defer { lock.unlock() }
        
        guard let entry = storage[key] else { return nil }
        
        if entry.isExpired {
            storage.removeValue(forKey: key)
            return nil
        }
        
        return entry.value
    }
    
    /// Sets a value in the cache
    /// - Parameters:
    ///   - value: The value to cache
    ///   - key: The cache key
    ///   - ttl: Time-to-live for this entry (overrides default)
    public func set(_ value: Value, forKey key: Key, ttl: TimeInterval? = nil) {
        lock.lock()
        defer { lock.unlock() }
        
        let effectiveTTL = ttl ?? defaultTTL
        let expiration = effectiveTTL.map { Date().addingTimeInterval($0) }
        
        storage[key] = CacheEntry(value: value, expirationDate: expiration)
        
        // Evict oldest entries if over limit
        if let max = maxEntries, storage.count > max {
            evictOldestEntries(keepCount: max)
        }
    }
    
    /// Gets a value or computes and caches it if missing
    public func getOrCompute(_ key: Key, ttl: TimeInterval? = nil, compute: () -> Value) -> Value {
        if let cached = get(key) {
            return cached
        }
        
        let value = compute()
        set(value, forKey: key, ttl: ttl)
        return value
    }
    
    /// Async version of getOrCompute
    public func getOrCompute(_ key: Key, ttl: TimeInterval? = nil, compute: () async -> Value) async -> Value {
        if let cached = get(key) {
            return cached
        }
        
        let value = await compute()
        set(value, forKey: key, ttl: ttl)
        return value
    }
    
    /// Removes a value from the cache
    public func remove(_ key: Key) {
        lock.lock()
        defer { lock.unlock() }
        storage.removeValue(forKey: key)
    }
    
    /// Clears all entries from the cache
    public func clear() {
        lock.lock()
        defer { lock.unlock() }
        storage.removeAll()
    }
    
    /// Removes all expired entries
    public func purgeExpired() {
        lock.lock()
        defer { lock.unlock() }
        
        let keysToRemove = storage.filter { $0.value.isExpired }.map { $0.key }
        for key in keysToRemove {
            storage.removeValue(forKey: key)
        }
    }
    
    /// Current number of entries
    public var count: Int {
        lock.lock()
        defer { lock.unlock() }
        return storage.count
    }
    
    /// Check if a key exists (and is not expired)
    public func contains(_ key: Key) -> Bool {
        return get(key) != nil
    }
    
    private func evictOldestEntries(keepCount: Int) {
        // Simple eviction: remove entries until under limit
        // In a production app, you might want LRU eviction
        while storage.count > keepCount {
            if let firstKey = storage.keys.first {
                storage.removeValue(forKey: firstKey)
            }
        }
    }
}

// MARK: - Convenience Extensions

public extension Cache where Key == String {
    /// Gets or computes with automatic key generation from parameters
    func cached<P: CustomStringConvertible>(
        for params: P,
        ttl: TimeInterval? = nil,
        compute: () -> Value
    ) -> Value {
        let key = String(describing: params)
        return getOrCompute(key, ttl: ttl, compute: compute)
    }
}

// MARK: - Memoization Helper

/// Memoizes a function with a single hashable argument
public func memoize<Input: Hashable, Output>(
    ttl: TimeInterval? = nil,
    _ function: @escaping (Input) -> Output
) -> (Input) -> Output {
    let cache = Cache<Input, Output>(defaultTTL: ttl)
    return { input in
        cache.getOrCompute(input) { function(input) }
    }
}

/// Memoizes an async function with a single hashable argument
public func memoizeAsync<Input: Hashable, Output>(
    ttl: TimeInterval? = nil,
    _ function: @escaping (Input) async -> Output
) -> (Input) async -> Output {
    let cache = Cache<Input, Output>(defaultTTL: ttl)
    return { input in
        await cache.getOrCompute(input) { await function(input) }
    }
}

// MARK: - Computed Property Cache

/// Cache for expensive computed properties
public final class ComputedCache<Value> {
    private var cachedValue: Value?
    private var lastComputedAt: Date?
    private let ttl: TimeInterval?
    private let lock = NSLock()
    
    public init(ttl: TimeInterval? = nil) {
        self.ttl = ttl
    }
    
    public func get(compute: () -> Value) -> Value {
        lock.lock()
        defer { lock.unlock() }
        
        // Check if cached value is still valid
        if let value = cachedValue {
            if let ttl = ttl, let lastComputed = lastComputedAt {
                if Date().timeIntervalSince(lastComputed) < ttl {
                    return value
                }
            } else if ttl == nil {
                return value
            }
        }
        
        // Compute and cache
        let value = compute()
        cachedValue = value
        lastComputedAt = Date()
        return value
    }
    
    public func invalidate() {
        lock.lock()
        defer { lock.unlock() }
        cachedValue = nil
        lastComputedAt = nil
    }
}
