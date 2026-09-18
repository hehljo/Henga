import Foundation
#if canImport(Network)
import Network
#endif

public final class NetworkReachability: @unchecked Sendable {
    public static let shared = NetworkReachability()
    
    #if canImport(Network)
    private var pathMonitor: NWPathMonitor?
    private let monitorQueue = DispatchQueue(label: "com.hehljo.SynologyMount.reachability")
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
    
    /// Prüft ob ein TCP-Port erreichbar ist (mit POSIX non-blocking socket für absolute Verlässlichkeit)
    public func checkHostReachable(host: String, port: Int = 445, timeoutSeconds: TimeInterval = AppConfig.pingTimeoutSeconds) async -> Bool {
        guard !host.isEmpty else { return false }
        
        let task = Task.detached(priority: .utility) { () -> Bool in
            #if os(macOS) || os(Linux)
            var hints = addrinfo()
            hints.ai_family = AF_UNSPEC
            #if os(Linux)
            hints.ai_socktype = Int32(SOCK_STREAM.rawValue)
            #else
            hints.ai_socktype = SOCK_STREAM
            #endif
            hints.ai_protocol = Int32(IPPROTO_TCP)
            
            var res: UnsafeMutablePointer<addrinfo>?
            let portStr = String(port)
            let status = getaddrinfo(host, portStr, &hints, &res)
            guard status == 0, let firstAddr = res else {
                return false
            }
            defer { freeaddrinfo(res) }
            
            let sock = socket(firstAddr.pointee.ai_family, firstAddr.pointee.ai_socktype, firstAddr.pointee.ai_protocol)
            guard sock >= 0 else { return false }
            defer { close(sock) }
            
            // Setze non-blocking
            let flags = fcntl(sock, F_GETFL, 0)
            _ = fcntl(sock, F_SETFL, flags | O_NONBLOCK)
            
            let connectRes = connect(sock, firstAddr.pointee.ai_addr, firstAddr.pointee.ai_addrlen)
            if connectRes == 0 {
                return true
            }
            
            if errno != EINPROGRESS {
                return false
            }
            
            var pollFd = pollfd(fd: sock, events: Int16(POLLOUT), revents: 0)
            let pollTimeout = Int32(timeoutSeconds * 1000)
            let pollRes = poll(&pollFd, 1, pollTimeout)
            
            if pollRes > 0 && (pollFd.revents & Int16(POLLOUT)) != 0 {
                var err: Int32 = 0
                var len = socklen_t(MemoryLayout<Int32>.size)
                getsockopt(sock, SOL_SOCKET, SO_ERROR, &err, &len)
                return err == 0
            }
            
            return false
            #else
            return true
            #endif
        }
        return await task.value
    }
}
