package com.notchtodo.util

import android.content.Context
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.net.NetworkRequest
import kotlinx.coroutines.channels.awaitClose
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.callbackFlow
import kotlinx.coroutines.flow.distinctUntilChanged
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.coroutines.withTimeoutOrNull
import kotlin.coroutines.resume

/**
 * Monitors network connectivity state and notifies observers of changes.
 */
class NetworkMonitor(context: Context) {
    
    private val connectivityManager = context.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
    
    // MARK: - State
    
    data class NetworkState(
        val isConnected: Boolean,
        val connectionType: ConnectionType,
        val isMetered: Boolean,
        val hasInternet: Boolean
    ) {
        companion object {
            val DISCONNECTED = NetworkState(
                isConnected = false,
                connectionType = ConnectionType.NONE,
                isMetered = false,
                hasInternet = false
            )
        }
    }
    
    enum class ConnectionType {
        WIFI,
        CELLULAR,
        ETHERNET,
        VPN,
        UNKNOWN,
        NONE
    }
    
    private val _networkState = MutableStateFlow(getCurrentNetworkState())
    val networkState: StateFlow<NetworkState> = _networkState.asStateFlow()
    
    val isConnected: Boolean get() = _networkState.value.isConnected
    val connectionType: ConnectionType get() = _networkState.value.connectionType
    
    // MARK: - Callbacks
    
    var onConnectionChanged: ((NetworkState) -> Unit)? = null
    var onConnectionRestored: (() -> Unit)? = null
    var onConnectionLost: (() -> Unit)? = null
    
    private var isMonitoring = false
    private var previouslyConnected = true
    private var networkCallback: ConnectivityManager.NetworkCallback? = null
    
    // MARK: - Public Methods
    
    /**
     * Start monitoring network changes.
     */
    fun startMonitoring() {
        if (isMonitoring) return
        
        val request = NetworkRequest.Builder()
            .addCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
            .build()
        
        networkCallback = object : ConnectivityManager.NetworkCallback() {
            override fun onAvailable(network: Network) {
                updateNetworkState()
            }
            
            override fun onLost(network: Network) {
                updateNetworkState()
            }
            
            override fun onCapabilitiesChanged(network: Network, capabilities: NetworkCapabilities) {
                updateNetworkState()
            }
        }
        
        connectivityManager.registerNetworkCallback(request, networkCallback!!)
        isMonitoring = true
        DebugLog.log("Network monitoring started", DebugLog.Category.SYNC)
    }
    
    /**
     * Stop monitoring network changes.
     */
    fun stopMonitoring() {
        if (!isMonitoring) return
        
        networkCallback?.let {
            connectivityManager.unregisterNetworkCallback(it)
        }
        networkCallback = null
        isMonitoring = false
        DebugLog.log("Network monitoring stopped", DebugLog.Category.SYNC)
    }
    
    /**
     * Check if we should attempt network operations.
     */
    val shouldAttemptNetworkOperations: Boolean
        get() = isConnected
    
    /**
     * Check if we should download large content.
     */
    val shouldDownloadLargeContent: Boolean
        get() = isConnected && !_networkState.value.isMetered
    
    /**
     * Flow that emits network state changes.
     */
    fun observeNetworkState(): Flow<NetworkState> = callbackFlow {
        val callback = object : ConnectivityManager.NetworkCallback() {
            override fun onAvailable(network: Network) {
                trySend(getCurrentNetworkState())
            }
            
            override fun onLost(network: Network) {
                trySend(NetworkState.DISCONNECTED)
            }
            
            override fun onCapabilitiesChanged(network: Network, capabilities: NetworkCapabilities) {
                trySend(getCurrentNetworkState())
            }
        }
        
        val request = NetworkRequest.Builder()
            .addCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
            .build()
        
        connectivityManager.registerNetworkCallback(request, callback)
        
        // Emit initial state
        trySend(getCurrentNetworkState())
        
        awaitClose {
            connectivityManager.unregisterNetworkCallback(callback)
        }
    }.distinctUntilChanged()
    
    /**
     * Execute an operation when connected, waiting if necessary.
     */
    suspend fun <T> whenConnected(
        timeoutMs: Long = 30000,
        operation: suspend () -> T
    ): T? {
        if (isConnected) {
            return operation()
        }
        
        // Wait for connection
        return withTimeoutOrNull(timeoutMs) {
            suspendCancellableCoroutine { continuation ->
                val callback = object : ConnectivityManager.NetworkCallback() {
                    override fun onAvailable(network: Network) {
                        connectivityManager.unregisterNetworkCallback(this)
                        continuation.resume(Unit)
                    }
                }
                
                val request = NetworkRequest.Builder()
                    .addCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
                    .build()
                
                connectivityManager.registerNetworkCallback(request, callback)
                
                continuation.invokeOnCancellation {
                    try {
                        connectivityManager.unregisterNetworkCallback(callback)
                    } catch (_: Exception) {}
                }
            }
            operation()
        }
    }
    
    // MARK: - Private Methods
    
    private fun updateNetworkState() {
        val wasConnected = previouslyConnected
        val state = getCurrentNetworkState()
        val nowConnected = state.isConnected
        
        _networkState.value = state
        
        DebugLog.log(
            "Network state: ${state.connectionType}, " +
            "connected=${state.isConnected}, " +
            "metered=${state.isMetered}, " +
            "hasInternet=${state.hasInternet}",
            DebugLog.Category.SYNC
        )
        
        onConnectionChanged?.invoke(state)
        
        if (!wasConnected && nowConnected) {
            DebugLog.log("🌐 Network connection restored", DebugLog.Category.SYNC)
            onConnectionRestored?.invoke()
        } else if (wasConnected && !nowConnected) {
            DebugLog.log("📵 Network connection lost", DebugLog.Category.SYNC)
            onConnectionLost?.invoke()
        }
        
        previouslyConnected = nowConnected
    }
    
    private fun getCurrentNetworkState(): NetworkState {
        val activeNetwork = connectivityManager.activeNetwork
            ?: return NetworkState.DISCONNECTED
        
        val capabilities = connectivityManager.getNetworkCapabilities(activeNetwork)
            ?: return NetworkState.DISCONNECTED
        
        val isConnected = capabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
        val hasInternet = capabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_VALIDATED)
        val isMetered = !capabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_NOT_METERED)
        
        val connectionType = when {
            capabilities.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) -> ConnectionType.WIFI
            capabilities.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR) -> ConnectionType.CELLULAR
            capabilities.hasTransport(NetworkCapabilities.TRANSPORT_ETHERNET) -> ConnectionType.ETHERNET
            capabilities.hasTransport(NetworkCapabilities.TRANSPORT_VPN) -> ConnectionType.VPN
            else -> ConnectionType.UNKNOWN
        }
        
        return NetworkState(
            isConnected = isConnected,
            connectionType = connectionType,
            isMetered = isMetered,
            hasInternet = hasInternet
        )
    }
}
