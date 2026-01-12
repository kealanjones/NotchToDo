import CoreData
import Foundation

/// Utilities for optimizing Core Data fetch requests
enum FetchRequestOptimizer {
    
    // MARK: - Fetch Request Configuration
    
    /// Configures a fetch request for optimal performance
    static func optimize<T: NSManagedObject>(_ request: NSFetchRequest<T>, configuration: FetchConfiguration = .default) {
        // Set batch size for memory efficiency
        request.fetchBatchSize = configuration.batchSize
        
        // Only fetch properties we need (if specified)
        if !configuration.propertiesToFetch.isEmpty {
            request.propertiesToFetch = configuration.propertiesToFetch
            request.resultType = .managedObjectResultType
        }
        
        // Set prefetch relationships to avoid faults
        if !configuration.relationshipKeyPathsForPrefetching.isEmpty {
            request.relationshipKeyPathsForPrefetching = configuration.relationshipKeyPathsForPrefetching
        }
        
        // Only return distinct results if needed
        request.returnsDistinctResults = configuration.returnsDistinctResults
        
        // Include pending changes from context
        request.includesPendingChanges = configuration.includesPendingChanges
        
        // Return objects as faults (lazy loading) unless we need properties immediately
        request.returnsObjectsAsFaults = configuration.returnsObjectsAsFaults
        
        // Limit results if specified
        if let limit = configuration.fetchLimit {
            request.fetchLimit = limit
        }
    }
    
    // MARK: - Configuration
    
    struct FetchConfiguration {
        var batchSize: Int
        var propertiesToFetch: [String]
        var relationshipKeyPathsForPrefetching: [String]
        var returnsDistinctResults: Bool
        var includesPendingChanges: Bool
        var returnsObjectsAsFaults: Bool
        var fetchLimit: Int?
        
        static let `default` = FetchConfiguration(
            batchSize: 20,
            propertiesToFetch: [],
            relationshipKeyPathsForPrefetching: [],
            returnsDistinctResults: false,
            includesPendingChanges: true,
            returnsObjectsAsFaults: true,
            fetchLimit: nil
        )
        
        /// Configuration for listing items (e.g., in a table view)
        static let list = FetchConfiguration(
            batchSize: 20,
            propertiesToFetch: [],
            relationshipKeyPathsForPrefetching: [],
            returnsDistinctResults: false,
            includesPendingChanges: true,
            returnsObjectsAsFaults: true,
            fetchLimit: nil
        )
        
        /// Configuration for detailed view (need all properties)
        static let detail = FetchConfiguration(
            batchSize: 1,
            propertiesToFetch: [],
            relationshipKeyPathsForPrefetching: [],
            returnsDistinctResults: false,
            includesPendingChanges: true,
            returnsObjectsAsFaults: false,
            fetchLimit: 1
        )
        
        /// Configuration for sync operations (need IDs and sync metadata)
        static let sync = FetchConfiguration(
            batchSize: 50,
            propertiesToFetch: [],
            relationshipKeyPathsForPrefetching: [],
            returnsDistinctResults: false,
            includesPendingChanges: true,
            returnsObjectsAsFaults: false,
            fetchLimit: nil
        )
        
        /// Configuration for count queries
        static let count = FetchConfiguration(
            batchSize: 0,
            propertiesToFetch: [],
            relationshipKeyPathsForPrefetching: [],
            returnsDistinctResults: false,
            includesPendingChanges: true,
            returnsObjectsAsFaults: true,
            fetchLimit: nil
        )
    }
    
    // MARK: - Orb-specific Optimizations
    
    /// Creates an optimized fetch request for orbs
    static func orbsFetchRequest(
        includeDeleted: Bool = false,
        configuration: FetchConfiguration = .list
    ) -> NSFetchRequest<OrbEntity> {
        let request: NSFetchRequest<OrbEntity> = OrbEntity.fetchRequest()
        
        // Filter soft-deleted
        if !includeDeleted {
            request.predicate = NSPredicate(format: "deletedAt == nil")
        }
        
        // Sort by sortOrder
        request.sortDescriptors = [
            NSSortDescriptor(key: "sortOrder", ascending: true),
            NSSortDescriptor(key: "createdAt", ascending: false)
        ]
        
        // Prefetch tasks relationship
        var config = configuration
        if config.relationshipKeyPathsForPrefetching.isEmpty {
            config.relationshipKeyPathsForPrefetching = ["tasks"]
        }
        
        optimize(request, configuration: config)
        return request
    }
    
    /// Creates an optimized fetch request for a single orb by ID
    static func orbByIdFetchRequest(id: UUID) -> NSFetchRequest<OrbEntity> {
        let request: NSFetchRequest<OrbEntity> = OrbEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        optimize(request, configuration: .detail)
        return request
    }
    
    /// Creates an optimized fetch request for orbs needing sync
    static func orbsNeedingSyncFetchRequest() -> NSFetchRequest<OrbEntity> {
        let request: NSFetchRequest<OrbEntity> = OrbEntity.fetchRequest()
        request.predicate = NSPredicate(format: "needsSync == YES")
        request.sortDescriptors = [NSSortDescriptor(key: "updatedAt", ascending: true)]
        optimize(request, configuration: .sync)
        return request
    }
    
    // MARK: - Task-specific Optimizations
    
    /// Creates an optimized fetch request for tasks
    static func tasksFetchRequest(
        orbId: UUID? = nil,
        includeDeleted: Bool = false,
        configuration: FetchConfiguration = .list
    ) -> NSFetchRequest<TaskEntity> {
        let request: NSFetchRequest<TaskEntity> = TaskEntity.fetchRequest()
        
        // Build predicate
        var predicates: [NSPredicate] = []
        
        if !includeDeleted {
            predicates.append(NSPredicate(format: "deletedAt == nil"))
        }
        
        if let orbId = orbId {
            predicates.append(NSPredicate(format: "orb.id == %@", orbId as CVarArg))
        }
        
        if !predicates.isEmpty {
            request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        }
        
        // Sort by sortOrder within orb
        request.sortDescriptors = [
            NSSortDescriptor(key: "sortOrder", ascending: true),
            NSSortDescriptor(key: "createdAt", ascending: false)
        ]
        
        // Prefetch orb relationship
        var config = configuration
        if config.relationshipKeyPathsForPrefetching.isEmpty {
            config.relationshipKeyPathsForPrefetching = ["orb"]
        }
        
        optimize(request, configuration: config)
        return request
    }
    
    /// Creates an optimized fetch request for a single task by ID
    static func taskByIdFetchRequest(id: UUID) -> NSFetchRequest<TaskEntity> {
        let request: NSFetchRequest<TaskEntity> = TaskEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        var config = FetchConfiguration.detail
        config.relationshipKeyPathsForPrefetching = ["orb"]
        optimize(request, configuration: config)
        return request
    }
    
    /// Creates an optimized fetch request for tasks needing sync
    static func tasksNeedingSyncFetchRequest() -> NSFetchRequest<TaskEntity> {
        let request: NSFetchRequest<TaskEntity> = TaskEntity.fetchRequest()
        request.predicate = NSPredicate(format: "needsSync == YES")
        request.sortDescriptors = [NSSortDescriptor(key: "updatedAt", ascending: true)]
        
        var config = FetchConfiguration.sync
        config.relationshipKeyPathsForPrefetching = ["orb"]
        optimize(request, configuration: config)
        return request
    }
    
    // MARK: - Outbox Optimizations
    
    /// Creates an optimized fetch request for outbox items
    static func outboxFetchRequest(limit: Int = 50) -> NSFetchRequest<SyncOutboxItem> {
        let request: NSFetchRequest<SyncOutboxItem> = SyncOutboxItem.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: true)]
        
        var config = FetchConfiguration.sync
        config.fetchLimit = limit
        optimize(request, configuration: config)
        return request
    }
    
    // MARK: - Async Fetch Helpers
    
    /// Performs an async fetch with performance logging
    static func fetch<T: NSManagedObject>(
        _ request: NSFetchRequest<T>,
        in context: NSManagedObjectContext,
        operationName: String? = nil
    ) async throws -> [T] {
        let name = operationName ?? "CoreData fetch \(T.entity().name ?? "Unknown")"
        
        return try await measurePerformanceAsync(name) {
            try await context.perform {
                try context.fetch(request)
            }
        }
    }
    
    /// Performs a count query efficiently
    static func count<T: NSManagedObject>(
        _ request: NSFetchRequest<T>,
        in context: NSManagedObjectContext
    ) throws -> Int {
        return try context.count(for: request)
    }
}

// MARK: - NSFetchRequest Extension

extension NSFetchRequest {
    /// Convenience method to apply optimization
    @discardableResult
    func optimized(configuration: FetchRequestOptimizer.FetchConfiguration = .default) -> Self {
        FetchRequestOptimizer.optimize(self as! NSFetchRequest<NSManagedObject>, configuration: configuration)
        return self
    }
}
