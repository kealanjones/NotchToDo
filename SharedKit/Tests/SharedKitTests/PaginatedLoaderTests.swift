import XCTest
@testable import SharedKit

@MainActor
final class PaginatedLoaderTests: XCTestCase {
    
    // MARK: - Initial Load Tests
    
    func testLoadInitial() async {
        let loader = PaginatedLoader<Int>(pageSize: 10)
        
        await loader.loadInitial { offset, limit in
            XCTAssertEqual(offset, 0)
            XCTAssertEqual(limit, 10)
            return Array(1...10)
        }
        
        XCTAssertEqual(loader.items.count, 10)
        XCTAssertEqual(loader.loadState, .idle)
        XCTAssertTrue(loader.hasMore)
    }
    
    func testLoadInitialPartialPage() async {
        let loader = PaginatedLoader<Int>(pageSize: 10)
        
        await loader.loadInitial { _, _ in
            return Array(1...5) // Less than page size
        }
        
        XCTAssertEqual(loader.items.count, 5)
        XCTAssertEqual(loader.loadState, .endReached)
        XCTAssertFalse(loader.hasMore)
    }
    
    func testLoadInitialEmpty() async {
        let loader = PaginatedLoader<Int>(pageSize: 10)
        
        await loader.loadInitial { _, _ in
            return []
        }
        
        XCTAssertTrue(loader.items.isEmpty)
        XCTAssertEqual(loader.loadState, .endReached)
        XCTAssertFalse(loader.hasMore)
    }
    
    func testLoadInitialError() async {
        let loader = PaginatedLoader<Int>(pageSize: 10)
        
        await loader.loadInitial { _, _ in
            throw TestError.generic
        }
        
        XCTAssertTrue(loader.items.isEmpty)
        if case .error = loader.loadState {
            // Expected
        } else {
            XCTFail("Expected error state")
        }
    }
    
    // MARK: - Load More Tests
    
    func testLoadMore() async {
        let loader = PaginatedLoader<Int>(pageSize: 5)
        
        // Initial load
        await loader.loadInitial { _, _ in Array(1...5) }
        
        // Load more
        await loader.loadMore { offset, limit in
            XCTAssertEqual(offset, 5)
            XCTAssertEqual(limit, 5)
            return Array(6...10)
        }
        
        XCTAssertEqual(loader.items.count, 10)
        XCTAssertEqual(loader.items, Array(1...10))
    }
    
    func testLoadMoreAtEnd() async {
        let loader = PaginatedLoader<Int>(pageSize: 10)
        
        await loader.loadInitial { _, _ in Array(1...5) } // Partial = end reached
        
        var loadMoreCalled = false
        await loader.loadMore { _, _ in
            loadMoreCalled = true
            return []
        }
        
        XCTAssertFalse(loadMoreCalled)
    }
    
    // MARK: - Should Load More Tests
    
    func testShouldLoadMore() async {
        let loader = PaginatedLoader<Int>(pageSize: 10, prefetchDistance: 3)
        
        await loader.loadInitial { _, _ in Array(1...10) }
        
        // Far from end
        XCTAssertFalse(loader.shouldLoadMore(lastVisibleIndex: 0))
        XCTAssertFalse(loader.shouldLoadMore(lastVisibleIndex: 5))
        
        // Near end (within prefetch distance)
        XCTAssertTrue(loader.shouldLoadMore(lastVisibleIndex: 7))
        XCTAssertTrue(loader.shouldLoadMore(lastVisibleIndex: 9))
    }
    
    // MARK: - Refresh Tests
    
    func testRefresh() async {
        let loader = PaginatedLoader<Int>(pageSize: 5)
        
        await loader.loadInitial { _, _ in Array(1...5) }
        await loader.loadMore { _, _ in Array(6...10) }
        
        XCTAssertEqual(loader.items.count, 10)
        
        await loader.refresh { _, _ in Array(100...104) }
        
        XCTAssertEqual(loader.items.count, 5)
        XCTAssertEqual(loader.items.first, 100)
    }
    
    // MARK: - Reset Tests
    
    func testReset() async {
        let loader = PaginatedLoader<Int>(pageSize: 10)
        
        await loader.loadInitial { _, _ in Array(1...10) }
        XCTAssertEqual(loader.items.count, 10)
        
        loader.reset()
        
        XCTAssertTrue(loader.items.isEmpty)
        XCTAssertEqual(loader.loadState, .idle)
        XCTAssertTrue(loader.hasMore)
    }
    
    // MARK: - Item Manipulation Tests
    
    func testUpdateItem() async {
        let loader = PaginatedLoader<Int>(pageSize: 10)
        
        await loader.loadInitial { _, _ in Array(1...5) }
        
        loader.updateItem(where: { $0 == 3 }, with: { _ in 300 })
        
        XCTAssertEqual(loader.items, [1, 2, 300, 4, 5])
    }
    
    func testRemoveItem() async {
        let loader = PaginatedLoader<Int>(pageSize: 10)
        
        await loader.loadInitial { _, _ in Array(1...5) }
        
        loader.removeItem(where: { $0 == 3 })
        
        XCTAssertEqual(loader.items, [1, 2, 4, 5])
    }
    
    func testPrependItem() async {
        let loader = PaginatedLoader<Int>(pageSize: 10)
        
        await loader.loadInitial { _, _ in Array(1...3) }
        
        loader.prependItem(0)
        
        XCTAssertEqual(loader.items, [0, 1, 2, 3])
    }
    
    func testAppendItem() async {
        let loader = PaginatedLoader<Int>(pageSize: 10)
        
        await loader.loadInitial { _, _ in Array(1...3) }
        
        loader.appendItem(4)
        
        XCTAssertEqual(loader.items, [1, 2, 3, 4])
    }
    
    // MARK: - Load State Tests
    
    func testLoadStateEquality() {
        XCTAssertEqual(PaginatedLoader<Int>.LoadState.idle, .idle)
        XCTAssertEqual(PaginatedLoader<Int>.LoadState.loading, .loading)
        XCTAssertEqual(PaginatedLoader<Int>.LoadState.error("A"), .error("A"))
        XCTAssertNotEqual(PaginatedLoader<Int>.LoadState.error("A"), .error("B"))
        XCTAssertNotEqual(PaginatedLoader<Int>.LoadState.idle, .loading)
    }
}

// MARK: - Test Helpers

private enum TestError: Error {
    case generic
}
