import Foundation

public struct ShareRuntimeStatus: Identifiable, Equatable, Sendable {
    public var id: UUID { share.id }
    public let share: ShareMount
    public let profileId: UUID
    public var state: MountState
    public var mountPoint: String
    public var lastError: String?
    
    public init(
        share: ShareMount,
        profileId: UUID,
        state: MountState = .disconnected,
        mountPoint: String,
        lastError: String? = nil
    ) {
        self.share = share
        self.profileId = profileId
        self.state = state
        self.mountPoint = mountPoint
        self.lastError = lastError
    }
}

public actor MountManager {
    public static let shared = MountManager()
    
    private let executor: MountExecuting
    private let reachability: NetworkReachability
    private let keychain: KeychainHelper
    private var isLoopRunning = false
    
    // Status-Tracking
    private var statuses: [UUID: ShareRuntimeStatus] = [:]
    
    public init(
        executor: MountExecuting = DefaultMountExecutor(),
        reachability: NetworkReachability = .shared,
        keychain: KeychainHelper = .shared
    ) {
        self.executor = executor
        self.reachability = reachability
        self.keychain = keychain
    }
    
    public func getStatus(for shareId: UUID) -> ShareRuntimeStatus? {
        statuses[shareId]
    }
    
    public func getAllStatuses() -> [ShareRuntimeStatus] {
        Array(statuses.values)
    }
    
    /// Synchronisiert den aktuellen Zustand aller konfigurierten Shares mit den echten macOS Mounts
    public func refreshMountStatuses(profiles: [ServerProfile]) async {
        let activeMounts = await executor.listMountedVolumes()
        
        for profile in profiles {
            for share in profile.shares {
                let targetPath = MountPointSanitizer.resolveMountPoint(for: share)
                let isMounted = activeMounts.contains { $0.mountPoint == targetPath }
                
                var status = statuses[share.id] ?? ShareRuntimeStatus(
                    share: share,
                    profileId: profile.id,
                    state: .disconnected,
                    mountPoint: targetPath
                )
                
                if isMounted {
                    status.state = .mounted
                    status.lastError = nil
                } else if status.state == .mounted {
                    // War gemountet, ist jetzt weg
                    status.state = .disconnected
                }
                
                status.mountPoint = targetPath
                statuses[share.id] = status
            }
        }
    }
    
    /// Mountet eine spezifische Freigabe
    public func mount(share: ShareMount, profile: ServerProfile, password: String? = nil) async throws {
        guard let url = profile.smbURL(for: share) else {
            throw SynoClientError.invalidHost
        }
        
        let targetPath = MountPointSanitizer.resolveMountPoint(for: share)
        let activeMounts = await executor.listMountedVolumes()
        
        // 1. Bereits am Ziel gemountet?
        if activeMounts.contains(where: { $0.mountPoint == targetPath }) {
            var status = statuses[share.id] ?? ShareRuntimeStatus(share: share, profileId: profile.id, state: .mounted, mountPoint: targetPath)
            status.state = .mounted
            status.lastError = nil
            statuses[share.id] = status
            return
        }
        
        // 2. Geister-Ordner vorab aufräumen
        MountPointSanitizer.cleanupOrphanedMountPointIfNeeded(at: targetPath, activeMounts: activeMounts)
        
        // 3. Status auf connecting setzen
        var status = statuses[share.id] ?? ShareRuntimeStatus(share: share, profileId: profile.id, state: .connecting, mountPoint: targetPath)
        status.state = .connecting
        status.lastError = nil
        statuses[share.id] = status
        
        // 4. Passwort ermitteln (übergeben oder aus Keychain)
        let pw = password ?? keychain.getPassword(for: profile.username)
        
        do {
            try await executor.mountVolume(url: url, mountPoint: targetPath, username: profile.username, password: pw)
            status.state = .mounted
            status.lastError = nil
            statuses[share.id] = status
        } catch {
            status.state = .error
            status.lastError = error.localizedDescription
            statuses[share.id] = status
            throw error
        }
    }
    
    /// Hängt eine Freigabe aus
    public func unmount(share: ShareMount, profileId: UUID, force: Bool = false) async throws {
        let targetPath = MountPointSanitizer.resolveMountPoint(for: share)
        
        var status = statuses[share.id] ?? ShareRuntimeStatus(share: share, profileId: profileId, state: .unmounting, mountPoint: targetPath)
        status.state = .unmounting
        statuses[share.id] = status
        
        do {
            try await executor.unmountVolume(mountPoint: targetPath, force: force)
            status.state = .disconnected
            status.lastError = nil
            statuses[share.id] = status
        } catch {
            status.state = .error
            status.lastError = error.localizedDescription
            statuses[share.id] = status
            throw error
        }
    }
    
    /// Führt die Auto-Mount-Schleife für alle aktiven Profile aus
    public func runAutoMountCycle(profiles: [ServerProfile]) async {
        await refreshMountStatuses(profiles: profiles)
        
        for profile in profiles where profile.isEnabled {
            // Prüfen ob Host im Netzwerk antwortet
            let isReachable = await reachability.checkHostReachable(host: profile.cleanHost, port: profile.smbPort)
            guard isReachable else { continue }
            
            for share in profile.shares where share.autoMount {
                let current = statuses[share.id]?.state ?? .disconnected
                if current == .disconnected || current == .error {
                    try? await mount(share: share, profile: profile)
                }
            }
        }
    }
}
