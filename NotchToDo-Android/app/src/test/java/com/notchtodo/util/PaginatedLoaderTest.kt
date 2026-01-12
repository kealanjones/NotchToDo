package com.notchtodo.util

import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.test.runTest
import org.junit.Assert.*
import org.junit.Test

@OptIn(ExperimentalCoroutinesApi::class)
class PaginatedLoaderTest {

    // MARK: - Initial Load Tests

    @Test
    fun `loadInitial loads first page`() = runTest {
        val loader = PaginatedLoader<Int>(pageSize = 10)
        
        loader.loadInitial { offset, limit ->
            assertEquals(0, offset)
            assertEquals(10, limit)
            (1..10).toList()
        }
        
        assertEquals(10, loader.items.first().size)
        assertEquals(PaginatedLoader.LoadState.Idle, loader.loadState.first())
        assertTrue(loader.hasMore.first())
    }

    @Test
    fun `loadInitial partial page sets endReached`() = runTest {
        val loader = PaginatedLoader<Int>(pageSize = 10)
        
        loader.loadInitial { _, _ ->
            (1..5).toList()
        }
        
        assertEquals(5, loader.items.first().size)
        assertEquals(PaginatedLoader.LoadState.EndReached, loader.loadState.first())
        assertFalse(loader.hasMore.first())
    }

    @Test
    fun `loadInitial empty sets endReached`() = runTest {
        val loader = PaginatedLoader<Int>(pageSize = 10)
        
        loader.loadInitial { _, _ ->
            emptyList()
        }
        
        assertTrue(loader.items.first().isEmpty())
        assertEquals(PaginatedLoader.LoadState.EndReached, loader.loadState.first())
    }

    @Test
    fun `loadInitial error sets error state`() = runTest {
        val loader = PaginatedLoader<Int>(pageSize = 10)
        
        loader.loadInitial { _, _ ->
            throw RuntimeException("Network error")
        }
        
        val state = loader.loadState.first()
        assertTrue(state is PaginatedLoader.LoadState.Error)
        assertEquals("Network error", (state as PaginatedLoader.LoadState.Error).message)
    }

    // MARK: - Load More Tests

    @Test
    fun `loadMore appends items`() = runTest {
        val loader = PaginatedLoader<Int>(pageSize = 5)
        
        loader.loadInitial { _, _ -> (1..5).toList() }
        loader.loadMore { offset, limit ->
            assertEquals(5, offset)
            assertEquals(5, limit)
            (6..10).toList()
        }
        
        assertEquals((1..10).toList(), loader.items.first())
    }

    @Test
    fun `loadMore skipped when endReached`() = runTest {
        val loader = PaginatedLoader<Int>(pageSize = 10)
        
        loader.loadInitial { _, _ -> (1..5).toList() } // Partial = end reached
        
        var loadMoreCalled = false
        loader.loadMore { _, _ ->
            loadMoreCalled = true
            emptyList()
        }
        
        assertFalse(loadMoreCalled)
    }

    // MARK: - shouldLoadMore Tests

    @Test
    fun `shouldLoadMore returns false when far from end`() = runTest {
        val loader = PaginatedLoader<Int>(pageSize = 10, prefetchDistance = 3)
        
        loader.loadInitial { _, _ -> (1..10).toList() }
        
        assertFalse(loader.shouldLoadMore(0))
        assertFalse(loader.shouldLoadMore(5))
    }

    @Test
    fun `shouldLoadMore returns true when near end`() = runTest {
        val loader = PaginatedLoader<Int>(pageSize = 10, prefetchDistance = 3)
        
        loader.loadInitial { _, _ -> (1..10).toList() }
        
        assertTrue(loader.shouldLoadMore(7))
        assertTrue(loader.shouldLoadMore(9))
    }

    // MARK: - Refresh Tests

    @Test
    fun `refresh replaces items`() = runTest {
        val loader = PaginatedLoader<Int>(pageSize = 5)
        
        loader.loadInitial { _, _ -> (1..5).toList() }
        loader.loadMore { _, _ -> (6..10).toList() }
        
        assertEquals(10, loader.items.first().size)
        
        loader.refresh { _, _ -> (100..104).toList() }
        
        assertEquals(5, loader.items.first().size)
        assertEquals(100, loader.items.first().first())
    }

    // MARK: - Reset Tests

    @Test
    fun `reset clears state`() = runTest {
        val loader = PaginatedLoader<Int>(pageSize = 10)
        
        loader.loadInitial { _, _ -> (1..10).toList() }
        assertEquals(10, loader.items.first().size)
        
        loader.reset()
        
        assertTrue(loader.items.first().isEmpty())
        assertEquals(PaginatedLoader.LoadState.Idle, loader.loadState.first())
        assertTrue(loader.hasMore.first())
    }

    // MARK: - Item Manipulation Tests

    @Test
    fun `updateItem modifies existing item`() = runTest {
        val loader = PaginatedLoader<Int>(pageSize = 10)
        
        loader.loadInitial { _, _ -> (1..5).toList() }
        
        loader.updateItem(predicate = { it == 3 }) { 300 }
        
        assertEquals(listOf(1, 2, 300, 4, 5), loader.items.first())
    }

    @Test
    fun `removeItem removes matching item`() = runTest {
        val loader = PaginatedLoader<Int>(pageSize = 10)
        
        loader.loadInitial { _, _ -> (1..5).toList() }
        
        loader.removeItem { it == 3 }
        
        assertEquals(listOf(1, 2, 4, 5), loader.items.first())
    }

    @Test
    fun `prependItem adds to beginning`() = runTest {
        val loader = PaginatedLoader<Int>(pageSize = 10)
        
        loader.loadInitial { _, _ -> (1..3).toList() }
        
        loader.prependItem(0)
        
        assertEquals(listOf(0, 1, 2, 3), loader.items.first())
    }

    @Test
    fun `appendItem adds to end`() = runTest {
        val loader = PaginatedLoader<Int>(pageSize = 10)
        
        loader.loadInitial { _, _ -> (1..3).toList() }
        
        loader.appendItem(4)
        
        assertEquals(listOf(1, 2, 3, 4), loader.items.first())
    }

    // MARK: - CursorPaginatedLoader Tests

    @Test
    fun `cursorLoader loads with cursor`() = runTest {
        val loader = CursorPaginatedLoader<Int, String>(pageSize = 5)
        
        loader.loadInitial { limit ->
            assertEquals(5, limit)
            CursorPaginatedLoader.Page(items = (1..5).toList(), nextCursor = "cursor1")
        }
        
        assertEquals((1..5).toList(), loader.items.first())
        assertTrue(loader.hasMore.first())
    }

    @Test
    fun `cursorLoader uses cursor for loadMore`() = runTest {
        val loader = CursorPaginatedLoader<Int, String>(pageSize = 5)
        
        loader.loadInitial { _ ->
            CursorPaginatedLoader.Page(items = (1..5).toList(), nextCursor = "cursor1")
        }
        
        loader.loadMore { cursor, limit ->
            assertEquals("cursor1", cursor)
            assertEquals(5, limit)
            CursorPaginatedLoader.Page(items = (6..10).toList(), nextCursor = null)
        }
        
        assertEquals((1..10).toList(), loader.items.first())
        assertFalse(loader.hasMore.first())
    }
}
