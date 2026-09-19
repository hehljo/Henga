import Foundation

public enum MountState: String, Codable, Sendable {
    case disconnected
    case connecting
    case mounted
    case error
    case unmounting
    case unknown
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try? container.decode(String.self)
        self = MountState(rawValue: raw ?? "") ?? .unknown
    }
    
    public var isMounted: Bool {
        self == .mounted
    }
}

public struct ShareRuntimeStatus: Identifiable, Equatable, Sendable {
    public var id: UUID { share.id }
    public let share: ShareMount
    public let profileId: UUID
    public var state: MountState
    public var mountPoint: String?
    public var lastMountedAt: Date?
    public var lastError: String?
    
    public init(
        share: ShareMount,
        profileId: UUID,
        state: MountState = .disconnected,
        mountPoint: String? = nil,
        lastMountedAt: Date? = nil,
        lastError: String? = nil
    ) {
        self.share = share
        self.profileId = profileId
        self.state = state
        self.mountPoint = mountPoint
        self.lastMountedAt = lastMountedAt
        self.lastError = lastError
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
        autoMount: Bool = false,
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
