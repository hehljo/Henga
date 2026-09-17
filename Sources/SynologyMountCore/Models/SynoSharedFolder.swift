import Foundation

public struct SynoSharedFolder: Identifiable, Codable, Equatable, Sendable {
    public var id: String { path }
    public let name: String
    public let path: String
    public let isDir: Bool
    
    public init(name: String, path: String, isDir: Bool = true) {
        self.name = name
        self.path = path
        self.isDir = isDir
    }
    
    /// Reiner Freigabename ohne führenden Slash
    public var shareName: String {
        name.trimmingCharacters(in: CharacterSet(charactersIn: "/ "))
    }
}
