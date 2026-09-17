import Foundation

public enum MountState: String, Codable, Sendable {
    case disconnected
    case connecting
    case mounted
    case error
    case unmounting
    
    public var isMounted: Bool {
        self == .mounted
    }
}

public struct ShareMount: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var name: String                // Anzeigename (z.B. "Video", "Backup")
    public var remotePath: String          // SMB Freigabename (z.B. "video" oder "homes/user")
    public var autoMount: Bool             // Automatisch mounten wenn NAS erreichbar
    public var customLocalMountPoint: String? // Optional benutzerdefinierter Pfad statt /Volumes/<Share>
    
    public init(
        id: UUID = UUID(),
        name: String,
        remotePath: String,
        autoMount: Bool = true,
        customLocalMountPoint: String? = nil
    ) {
        self.id = id
        self.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        self.remotePath = remotePath.trimmingCharacters(in: CharacterSet(charactersIn: "/ "))
        self.autoMount = autoMount
        self.customLocalMountPoint = customLocalMountPoint
    }
    
    public var cleanRemotePath: String {
        remotePath.trimmingCharacters(in: CharacterSet(charactersIn: "/ "))
    }
}
