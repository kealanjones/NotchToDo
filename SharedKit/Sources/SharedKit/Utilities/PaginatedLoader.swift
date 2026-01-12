import Foundation

#if canImport(Combine)
import Combine
#endif

/// Generic paginated/lazy loader for lists
@MainActor
public final class PaginatedLoader<T>: ObservableObject {
    
    public enum LoadState: Equatable {
        case idle
        case loading
        case loadingMore
        case error(String)
        case endReached
        
        public static func == (lhs: LoadState, rhs: LoadState) -> Bool {
            switch (lhs, rhs) {
            case (.idle, .idle), (.loading, .loading), (.loadingMore, .loadingMore), (.endReached, .endReached):
                return true
            case (.error(let l), .error(let r)):
                return l == r
            default:
                return false
            }
        }
    }
    
    @Published public private(set) var items: [T] = []
    @Published public private(set) var loadState: LoadState = .idle
    @Published public private(set) var hasMore: Bool = true
    
    public let pageSize: Int
    public let prefetchDistance: Int
    
    private var currentOffset: Int = 0
    private var isLoading: Bool = false
    
    /// Creates a new paginated loader
    /// - Parameters:
    ///   - pageSize: Number of items to load per page
    ///   - prefetchDistance: Start loading more when this many items from the end
    public init(pageSize: Int = 20, prefetchDistance: Int = 5) {
        self.pageSize = pageSize
        self.prefetchDistance = prefetchDistance
    }
    
    /// Load the first page of data
    public func loadInitial(loader: @escaping (Int, Int) async throws -> [T]) async {
        guard !isLoading else { return }
        
        isLoading = true
        loadState = .loading
        currentOffset = 0
        
        do {
            let results = try await loader(0, pageSize)
            items = results
            currentOffset = results.count
            hasMore = results.count >= pageSize
            loadState = results.count < pageSize ? .endReached : .idle
            
            DebugLog.log("Loaded initial \(results.count) items", category: .tasks)
        } catch {
            loadState = .error(error.localizedDescription)
            DebugLog.log("Failed to load initial items: \(error)", category: .tasks)
        }
        
        isLoading = false
    }
    
    /// Load the next page of data
    public func loadMore(loader: @escaping (Int, Int) async throws -> [T]) async {
        guard !isLoading, hasMore, loadState == .idle else { return }
        
        isLoading = true
        loadState = .loadingMore
        
        do {
            let results = try await loader(currentOffset, pageSize)
            items.append(contentsOf: results)
            currentOffset += results.count
            hasMore = results.count >= pageSize
            loadState = results.count < pageSize ? .endReached : .idle
            
            DebugLog.log("Loaded \(results.count) more items, total: \(currentOffset)", category: .tasks)
        } catch {
            loadState = .error(error.localizedDescription)
            DebugLog.log("Failed to load more items: \(error)", category: .tasks)
        }
        
        isLoading = false
    }
    
    /// Check if more data should be loaded based on visible item index
    public func shouldLoadMore(lastVisibleIndex: Int) -> Bool {
        return hasMore && loadState == .idle && lastVisibleIndex >= items.count - prefetchDistance
    }
    
    /// Refresh the data (reload from beginning)
    public func refresh(loader: @escaping (Int, Int) async throws -> [T]) async {
        hasMore = true
        await loadInitial(loader: loader)
    }
    
    /// Reset the loader state
    public func reset() {
        items = []
        loadState = .idle
        hasMore = true
        currentOffset = 0
        isLoading = false
    }
    
    /// Update an item in the list
    public func updateItem(where predicate: (T) -> Bool, with update: (T) -> T) {
        items = items.map { item in
            predicate(item) ? update(item) : item
        }
    }
    
    /// Remove an item from the list
    public func removeItem(where predicate: (T) -> Bool) {
        items.removeAll(where: predicate)
        currentOffset = items.count
    }
    
    /// Add an item to the beginning of the list
    public func prependItem(_ item: T) {
        items.insert(item, at: 0)
        currentOffset += 1
    }
    
    /// Add an item to the end of the list
    public func appendItem(_ item: T) {
        items.append(item)
        currentOffset += 1
    }
}

// MARK: - Cursor-based Pagination

/// Cursor-based pagination loader
@MainActor
public final class CursorPaginatedLoader<T, C>: ObservableObject {
    
    public struct PageResult {
        public let items: [T]
        public let nextCursor: C?
        public let hasMore: Bool
        
        public init(items: [T], nextCursor: C?, hasMore: Bool) {
            self.items = items
            self.nextCursor = nextCursor
            self.hasMore = hasMore
        }
    }
    
    public enum LoadState: Equatable {
        case idle
        case loading
        case loadingMore
        case error(String)
        case endReached
        
        public static func == (lhs: LoadState, rhs: LoadState) -> Bool {
            switch (lhs, rhs) {
            case (.idle, .idle), (.loading, .loading), (.loadingMore, .loadingMore), (.endReached, .endReached):
                return true
            case (.error(let l), .error(let r)):
                return l == r
            default:
                return false
            }
        }
    }
    
    @Published public private(set) var items: [T] = []
    @Published public private(set) var loadState: LoadState = .idle
    
    public let pageSize: Int
    private var nextCursor: C?
    private var isLoading: Bool = false
    
    public init(pageSize: Int = 20) {
        self.pageSize = pageSize
    }
    
    /// Load the first page of data
    public func loadInitial(loader: @escaping (C?, Int) async throws -> PageResult) async {
        guard !isLoading else { return }
        
        isLoading = true
        loadState = .loading
        
        do {
            let result = try await loader(nil, pageSize)
            items = result.items
            nextCursor = result.nextCursor
            loadState = result.hasMore ? .idle : .endReached
            
            DebugLog.log("Loaded initial \(result.items.count) items", category: .tasks)
        } catch {
            loadState = .error(error.localizedDescription)
            DebugLog.log("Failed to load initial items: \(error)", category: .tasks)
        }
        
        isLoading = false
    }
    
    /// Load the next page of data
    public func loadMore(loader: @escaping (C?, Int) async throws -> PageResult) async {
        guard !isLoading, let cursor = nextCursor, loadState == .idle else { return }
        
        isLoading = true
        loadState = .loadingMore
        
        do {
            let result = try await loader(cursor, pageSize)
            items.append(contentsOf: result.items)
            nextCursor = result.nextCursor
            loadState = result.hasMore ? .idle : .endReached
            
            DebugLog.log("Loaded \(result.items.count) more items", category: .tasks)
        } catch {
            loadState = .error(error.localizedDescription)
            DebugLog.log("Failed to load more items: \(error)", category: .tasks)
        }
        
        isLoading = false
    }
    
    /// Refresh the data
    public func refresh(loader: @escaping (C?, Int) async throws -> PageResult) async {
        nextCursor = nil
        await loadInitial(loader: loader)
    }
    
    /// Reset the loader state
    public func reset() {
        items = []
        loadState = .idle
        nextCursor = nil
        isLoading = false
    }
}
