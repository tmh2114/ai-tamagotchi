import Foundation
import Network
import Combine

/// Network connectivity monitor for offline support
public class NetworkMonitor: ObservableObject {
    
    // MARK: - Properties
    
    /// Shared instance
    static let shared = NetworkMonitor()
    
    /// Network path monitor
    private let monitor: NWPathMonitor
    
    /// Dispatch queue for network monitoring
    private let queue = DispatchQueue(label: "com.aitamagotchi.networkmonitor", qos: .background)
    
    /// Current connection status
    @Published public var isConnected: Bool = true
    
    /// Current connection type
    @Published public var connectionType: ConnectionType = .unknown
    
    /// Path status
    @Published public var pathStatus: NWPath.Status = .satisfied
    
    /// Is expensive connection (cellular)
    @Published public var isExpensive: Bool = false
    
    /// Is constrained connection (low data mode)
    @Published public var isConstrained: Bool = false
    
    // MARK: - Initialization
    
    init() {
        self.monitor = NWPathMonitor()
        startMonitoring()
    }
    
    deinit {
        stopMonitoring()
    }
    
    // MARK: - Monitoring
    
    /// Start network monitoring
    private func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.updatePath(path)
            }
        }
        
        monitor.start(queue: queue)
    }
    
    /// Stop network monitoring
    public func stopMonitoring() {
        monitor.cancel()
    }
    
    /// Update path information
    private func updatePath(_ path: NWPath) {
        self.pathStatus = path.status
        self.isConnected = path.status == .satisfied
        self.isExpensive = path.isExpensive
        self.isConstrained = path.isConstrained
        
        // Determine connection type
        if path.usesInterfaceType(.wifi) {
            self.connectionType = .wifi
        } else if path.usesInterfaceType(.cellular) {
            self.connectionType = .cellular
        } else if path.usesInterfaceType(.wiredEthernet) {
            self.connectionType = .ethernet
        } else {
            self.connectionType = .unknown
        }
        
        // Post notification for legacy code
        NotificationCenter.default.post(
            name: .networkStatusChanged,
            object: nil,
            userInfo: [
                "isConnected": isConnected,
                "connectionType": connectionType,
                "isExpensive": isExpensive
            ]
        )
    }
    
    // MARK: - Public Methods
    
    /// Check if we should sync (connected and not constrained)
    public var shouldSync: Bool {
        return isConnected && !isConstrained
    }
    
    /// Check if we should use reduced data (expensive or constrained)
    public var shouldReduceData: Bool {
        return isExpensive || isConstrained
    }
}

// MARK: - Connection Type

/// Network connection type
public enum ConnectionType: String, CaseIterable {
    case wifi = "WiFi"
    case cellular = "Cellular"
    case ethernet = "Ethernet"
    case unknown = "Unknown"
    
    var icon: String {
        switch self {
        case .wifi:
            return "wifi"
        case .cellular:
            return "antenna.radiowaves.left.and.right"
        case .ethernet:
            return "cable.connector"
        case .unknown:
            return "questionmark.circle"
        }
    }
}

// MARK: - Notifications

extension Notification.Name {
    static let networkStatusChanged = Notification.Name("networkStatusChanged")
}