import Foundation
#if canImport(Network)
import Network
#endif

public final class NetworkReachability: @unchecked Sendable {
    public static let shared = NetworkReachability()
    
    #if canImport(Network)
    private var pathMonitor: NWPathMonitor?
    private let monitorQueue = DispatchQueue(label: "de.condriano.SynologyMount.reachability")
    #endif
    
    private let lock = NSLock()
    private var _isConnected: Bool = true
    
    public var isConnected: Bool {
        lock.lock()
        defer { lock.unlock() }
        return _isConnected
    }
    
    public init() {
        #if canImport(Network)
        let monitor = NWPathMonitor()
        monitor.pathUpdateHandler = { [weak self] path in
            guard let self = self else { return }
            self.lock.lock()
            self._isConnected = (path.status == .satisfied)
            self.lock.unlock()
        }
        monitor.start(queue: monitorQueue)
        self.pathMonitor = monitor
        #else
        self._isConnected = true
        #endif
    }
    
    deinit {
        #if canImport(Network)
        pathMonitor?.cancel()
        #endif
    }
    
    /// Prüft ob ein TCP-Port (z.B. SMB Port 445) auf dem Zielhost erreichbar ist
    public func checkHostReachable(host: String, port: Int = 445, timeoutSeconds: TimeInterval = AppConfig.pingTimeoutSeconds) async -> Bool {
        guard !host.isEmpty else { return false }
        
        #if canImport(Network)
        return await withCheckedContinuation { continuation in
            let endpoint = NWEndpoint.hostPort(host: NWEndpoint.Host(host), port: NWEndpoint.Port(rawValue: UInt16(port)) ?? 445)
            let params = NWParameters.tcp
            params.prohibitExpensivePaths = false
            let connection = NWConnection(to: endpoint, using: params)
            
            var didResume = false
            let resumeOnce: (Bool) -> Void = { result in
                if !didResume {
                    didResume = true
                    connection.cancel()
                    continuation.resume(returning: result)
                }
            }
            
            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    resumeOnce(true)
                case .failed, .cancelled:
                    resumeOnce(false)
                default:
                    break
                }
            }
            
            connection.start(queue: self.monitorQueue)
            
            // Timeout Guard
            self.monitorQueue.asyncAfter(deadline: .now() + timeoutSeconds) {
                resumeOnce(false)
            }
        }
        #else
        // Fallback Linux: Host ist potentiell erreichbar
        return true
        #endif
    }
}
