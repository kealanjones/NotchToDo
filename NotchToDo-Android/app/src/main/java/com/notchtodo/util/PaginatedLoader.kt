package com.notchtodo.util

import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock

/**
 * Generic paginated/lazy loader for lists.
 * Supports both offset-based and cursor-based pagination.
 */
class PaginatedLoader<T>(
    private val pageSize: Int = 20,
    private val prefetchDistance: Int = 5
) {
    
    sealed class LoadState {
        object Idle : LoadState()
        object Loading : LoadState()
        object LoadingMore : LoadState()
        data class Error(val error: Throwable) : LoadState()
        object EndReached : LoadState()
    }
    
    data class PagedData<T>(
        val items: List<T>,
        val loadState: LoadState,
        val hasMore: Boolean,
        val totalLoaded: Int
    )
    
    private val _items = MutableStateFlow<List<T>>(emptyList())
    val items: StateFlow<List<T>> = _items.asStateFlow()
    
    private val _loadState = MutableStateFlow<LoadState>(LoadState.Idle)
    val loadState: StateFlow<LoadState> = _loadState.asStateFlow()
    
    private val _hasMore = MutableStateFlow(true)
    val hasMore: StateFlow<Boolean> = _hasMore.asStateFlow()
    
    private var currentOffset = 0
    private val mutex = Mutex()
    
    /**
     * Load the first page of data.
     */
    suspend fun loadInitial(
        loader: suspend (offset: Int, limit: Int) -> List<T>
    ) {
        mutex.withLock {
            _loadState.value = LoadState.Loading
            currentOffset = 0
            
            try {
                val results = loader(0, pageSize)
                _items.value = results
                currentOffset = results.size
                _hasMore.value = results.size >= pageSize
                _loadState.value = if (results.size < pageSize) LoadState.EndReached else LoadState.Idle
                
                DebugLog.log("Loaded initial ${results.size} items", DebugLog.Category.DATA)
            } catch (e: Exception) {
                _loadState.value = LoadState.Error(e)
                DebugLog.error("Failed to load initial items", e, DebugLog.Category.DATA)
            }
        }
    }
    
    /**
     * Load the next page of data.
     */
    suspend fun loadMore(
        loader: suspend (offset: Int, limit: Int) -> List<T>
    ) {
        if (!_hasMore.value || _loadState.value == LoadState.LoadingMore) {
            return
        }
        
        mutex.withLock {
            _loadState.value = LoadState.LoadingMore
            
            try {
                val results = loader(currentOffset, pageSize)
                _items.value = _items.value + results
                currentOffset += results.size
                _hasMore.value = results.size >= pageSize
                _loadState.value = if (results.size < pageSize) LoadState.EndReached else LoadState.Idle
                
                DebugLog.log("Loaded ${results.size} more items, total: $currentOffset", DebugLog.Category.DATA)
            } catch (e: Exception) {
                _loadState.value = LoadState.Error(e)
                DebugLog.error("Failed to load more items", e, DebugLog.Category.DATA)
            }
        }
    }
    
    /**
     * Check if more data should be loaded based on visible item index.
     * Call this when the user scrolls near the end of the list.
     */
    fun shouldLoadMore(lastVisibleIndex: Int): Boolean {
        val totalItems = _items.value.size
        return _hasMore.value && 
               _loadState.value == LoadState.Idle &&
               lastVisibleIndex >= totalItems - prefetchDistance
    }
    
    /**
     * Refresh the data (reload from beginning).
     */
    suspend fun refresh(
        loader: suspend (offset: Int, limit: Int) -> List<T>
    ) {
        _hasMore.value = true
        loadInitial(loader)
    }
    
    /**
     * Reset the loader state.
     */
    fun reset() {
        _items.value = emptyList()
        _loadState.value = LoadState.Idle
        _hasMore.value = true
        currentOffset = 0
    }
    
    /**
     * Update an item in the list.
     */
    fun updateItem(predicate: (T) -> Boolean, update: (T) -> T) {
        _items.value = _items.value.map { item ->
            if (predicate(item)) update(item) else item
        }
    }
    
    /**
     * Remove an item from the list.
     */
    fun removeItem(predicate: (T) -> Boolean) {
        _items.value = _items.value.filterNot(predicate)
        currentOffset = _items.value.size
    }
    
    /**
     * Add an item to the beginning of the list.
     */
    fun prependItem(item: T) {
        _items.value = listOf(item) + _items.value
        currentOffset++
    }
    
    /**
     * Add an item to the end of the list.
     */
    fun appendItem(item: T) {
        _items.value = _items.value + item
        currentOffset++
    }
}

/**
 * Cursor-based pagination loader.
 */
class CursorPaginatedLoader<T, C>(
    private val pageSize: Int = 20
) {
    
    sealed class LoadState {
        object Idle : LoadState()
        object Loading : LoadState()
        object LoadingMore : LoadState()
        data class Error(val error: Throwable) : LoadState()
        object EndReached : LoadState()
    }
    
    data class PageResult<T, C>(
        val items: List<T>,
        val nextCursor: C?,
        val hasMore: Boolean
    )
    
    private val _items = MutableStateFlow<List<T>>(emptyList())
    val items: StateFlow<List<T>> = _items.asStateFlow()
    
    private val _loadState = MutableStateFlow<LoadState>(LoadState.Idle)
    val loadState: StateFlow<LoadState> = _loadState.asStateFlow()
    
    private var nextCursor: C? = null
    private val mutex = Mutex()
    
    /**
     * Load the first page of data.
     */
    suspend fun loadInitial(
        loader: suspend (cursor: C?, limit: Int) -> PageResult<T, C>
    ) {
        mutex.withLock {
            _loadState.value = LoadState.Loading
            
            try {
                val result = loader(null, pageSize)
                _items.value = result.items
                nextCursor = result.nextCursor
                _loadState.value = if (result.hasMore) LoadState.Idle else LoadState.EndReached
                
                DebugLog.log("Loaded initial ${result.items.size} items", DebugLog.Category.DATA)
            } catch (e: Exception) {
                _loadState.value = LoadState.Error(e)
                DebugLog.error("Failed to load initial items", e, DebugLog.Category.DATA)
            }
        }
    }
    
    /**
     * Load the next page of data.
     */
    suspend fun loadMore(
        loader: suspend (cursor: C?, limit: Int) -> PageResult<T, C>
    ) {
        val cursor = nextCursor ?: return
        if (_loadState.value == LoadState.LoadingMore || _loadState.value == LoadState.EndReached) {
            return
        }
        
        mutex.withLock {
            _loadState.value = LoadState.LoadingMore
            
            try {
                val result = loader(cursor, pageSize)
                _items.value = _items.value + result.items
                nextCursor = result.nextCursor
                _loadState.value = if (result.hasMore) LoadState.Idle else LoadState.EndReached
                
                DebugLog.log("Loaded ${result.items.size} more items", DebugLog.Category.DATA)
            } catch (e: Exception) {
                _loadState.value = LoadState.Error(e)
                DebugLog.error("Failed to load more items", e, DebugLog.Category.DATA)
            }
        }
    }
    
    /**
     * Refresh the data.
     */
    suspend fun refresh(
        loader: suspend (cursor: C?, limit: Int) -> PageResult<T, C>
    ) {
        nextCursor = null
        loadInitial(loader)
    }
    
    /**
     * Reset the loader state.
     */
    fun reset() {
        _items.value = emptyList()
        _loadState.value = LoadState.Idle
        nextCursor = null
    }
}
