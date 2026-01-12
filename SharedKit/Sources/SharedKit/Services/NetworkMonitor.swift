import Foundation
import Network

/// Monitors network connectivity state and notifies observers of changes
@available(iOS 12.0, macOS 10.14, *)
public final class NetworkMonitor: ObservableObject {
    
    public static let shared = NetworkMonitor()
    
    // MARK: - Published State
    
    @Published public private(set) var isConnected: Bool = true
    @Published public private(set) var connectionType: ConnectionType = .unknown
    @Published public private(set) var isExpensive: Bool = false
    @Published public private(set) var isConstrained: Bool = false
    
    // MARK: - Types
    
    public enum ConnectionType: String {
        case wifi = "WiFi"
        case cellular = "Cellular"
        case ethernet = "Ethernet"
        case unknown = "Unknown"
        case none = "None"
    }
    
    public struct NetworkState: Equatable {
        public let isConnected: Bool
        public let connectionType: ConnectionType
        public let isExpensive: Bool
        public let isConstrained: Bool
        
        public static let disconnected = NetworkState(
            isConnected: false,
            connectionType: .none,
            isExpensive: false,
            isConstrained: false
        )
    }
    
    // MARK: - Callbacks
    
    public var onConnectionChanged: ((NetworkState) -> Void)?
    public var onConnectionRestored: (() -> Void)?
    public var onConnectionLost: (() -> Void)?
    
    // MARK: - Private Properties
    
    private let monitor: NWPathMonitor
    private let queue = DispatchQueue(label: "com.notchtodo.networkmonitor", qos: .utility)
    private var isMonitoring = false
    private var previouslyConnected = true
    
    // MARK: - Initialization
    
    private init() {
        monitor = NWPathMonitor()
        setupMonitor()
    }
    
    deinit {
        stopMonitoring()
    }
    
    // MARK: - Public Methods
    
    /// Start monitoring network changes
    public func startMonitoring() {
        guard !isMonitoring else { return }
        
        monitor.start(queue: queue)
        isMonitoring = true
        DebugLog.log("Network monitoring started", category: .sync)
    }
    
    /// Stop monitoring network changes
    public func stopMonitoring() {
        guard isMonitoring else { return }
        
        monitor.cancel()
        isMonitoring = false
        DebugLog.log("Network monitoring stopped", category: .sync)
    }
    
    /// Current network state
    public var currentState: NetworkState {
        return NetworkState(
            isConnected: isConnected,
            connectionType: connectionType,
            isExpensive: isExpensive,
            isConstrained: isConstrained
        )
    }
    
    /// Check if we should attempt network operations
    public var shouldAttemptNetworkOperations: Bool {
        return isConnected && !isConstrained
    }
    
    /// Check if we should download large content
    public var shouldDownloadLargeContent: Bool {
        return isConnected && !isExpensive && !isConstrained
    }
    
    // MARK: - Private Methods
    
    private func setupMonitor() {
        monitor.pathUpdateHandler = { [weak self] path in
            self?.handlePathUpdate(path)
        }
    }
    
    private func handlePathUpdate(_ path: NWPath) {
        let wasConnected = previouslyConnected
        let nowConnected = path.status == .satisfied
        
        // Update state on main thread for UI
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.isConnected = nowConnected
            self.connectionType = self.determineConnectionType(path)
            self.isExpensive = path.isExpensive
            self.isConstrained = path.isConstrained
            
            let state = self.currentState
            
            // Log state change
            DebugLog.log(
                "Network state: \(state.connectionType.rawValue), " +
                "connected=\(state.isConnected), " +
                "expensive=\(state.isExpensive), " +
                "constrained=\(state.isConstrained)",
                category: .sync
            )
            
            // Notify callbacks
            self.onConnectionChanged?(state)
            
            if !wasConnected && nowConnected {
                DebugLog.log("🌐 Network connection restored", category: .sync)
                self.onConnectionRestored?()
            } else if wasConnected && !nowConnected {
                DebugLog.log("📵 Network connection lost", category: .sync)
                self.onConnectionLost?()
            }
            
            self.previouslyConnected = nowConnected
        }
    }
    
    private func determineConnectionType(_ path: NWPath) -> ConnectionType {
        guard path.status == .satisfied else {
            return .none
        }
        
        if path.usesInterfaceType(.wifi) {
            return .wifi
        } else if path.usesInterfaceType(.cellular) {
            return .cellular
        } else if path.usesInterfaceType(.wiredEthernet) {
            return .ethernet
        } else {
            return .unknown
        }
    }
}

// MARK: - Notification Extension

public extension Notification.Name {
    /// Posted when network connectivity changes
    static let networkConnectionChanged = Notification.Name("NetworkConnectionChanged")
}

// MARK: - Convenience Methods

@available(iOS 12.0, macOS 10.14, *)
public extension NetworkMonitor {
    
    /// Execute an operation only when connected
    func whenConnected<T>(
        timeout: TimeInterval = 30,
        operation: @escaping () async throws -> T
    ) async throws -> T {
        if isConnected {
            return try await operation()
        }
        
        // Wait for connection
        return try await withCheckedThrowingContinuation { continuation in
            var fulfilled = false
            let timeoutTask = DispatchWorkItem { [weak self] in
                guard !fulfilled else { return }
                fulfilled = true
                self?.onConnectionRestored = nil
                continuation.resume(throwing: NetworkError.timeout)
            }
            
            queue.asyncAfter(deadline: .now() + timeout, execute: timeoutTask)
            
            onConnectionRestored = { [weak self] in
                guard !fulfilled else { return }
                fulfilled = true
                timeoutTask.cancel()
                self?.onConnectionRestored = nil
                
                Task {
                    do {
                        let result = try await operation()
                        continuation.resume(returning: result)
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }
        }
    }
    
    enum NetworkError: LocalizedError {
        case notConnected
        case timeout
        
        public var errorDescription: String? {
            switch self {
            case .notConnected:
                return "No network connection available"
            case .timeout:
                return "Network connection timeout"
            }
        }
    }
}
