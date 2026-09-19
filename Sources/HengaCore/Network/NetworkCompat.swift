#if canImport(FoundationNetworking)
@_exported import FoundationNetworking
#endif
@_exported import Foundation

#if canImport(FoundationNetworking)
// Async URLSession extension helper für Linux Swift FoundationNetworking
extension URLSession {
    public func data(from url: URL) async throws -> (Data, URLResponse) {
        try await withCheckedThrowingContinuation { continuation in
            let task = self.dataTask(with: url) { data, response, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let data = data, let response = response else {
                    continuation.resume(throwing: URLError(.badServerResponse))
                    return
                }
                continuation.resume(returning: (data, response))
            }
            task.resume()
        }
    }
}
#endif
