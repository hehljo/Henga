import Foundation

#if os(macOS)
import Security

public final class SynologySessionDelegate: NSObject, URLSessionDelegate, @unchecked Sendable {
    public let allowSelfSigned: Bool
    
    public init(allowSelfSigned: Bool = true) {
        self.allowSelfSigned = allowSelfSigned
    }
    
    public func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        if allowSelfSigned && challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust {
            if let serverTrust = challenge.protectionSpace.serverTrust {
                completionHandler(.useCredential, URLCredential(trust: serverTrust))
                return
            }
        }
        completionHandler(.performDefaultHandling, nil)
    }
}
#else
public final class SynologySessionDelegate: NSObject, URLSessionDelegate, @unchecked Sendable {
    public let allowSelfSigned: Bool
    
    public init(allowSelfSigned: Bool = true) {
        self.allowSelfSigned = allowSelfSigned
    }
    
    public func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        completionHandler(.performDefaultHandling, nil)
    }
}
#endif
