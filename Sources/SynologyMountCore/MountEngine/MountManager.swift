import Foundation

public actor MountManager {
    public static let shared = MountManager()
    
    private let executor: MountExecutor
    private let reachability: NetworkReachability
    private let keychain: KeychainHelper
    
    private var statuses: [UUID: ShareRuntimeStatus] = [:]
    
    public init(
        executor: MountExecutor = DefaultMountExecutor.shared,
        reachability: NetworkReachability = .shared,
        keychain: KeychainHelper = .shared
    ) {
        self.executor = executor
        self.reachability = reachability
        self.keychain = keychain
    }
    
    public func getStatus(for shareId: UUID) -> ShareRuntimeStatus? {
        return statuses[shareId]
    }
    
    public func getAllStatuses() -> [ShareRuntimeStatus] {
        return Array(statuses.values)
    }
    
    /// Synchronisiert die internen Status mit den tatsächlichen OS-Mounts
    public func refreshMountStatuses(profiles: [ServerProfile]) async {
        let activeMounts = await executor.listMountedVolumes()
        print("[SynologyMount] 🔍 Aktive System-Mounts gefunden (\(activeMounts.count)): \(activeMounts.map { "\($0.mountPoint) (\($0.fileSystemType))" })")
        
        for profile in profiles {
            for share in profile.shares {
                let targetPath = MountPointSanitizer.resolveMountPoint(for: share)
                let isMounted = activeMounts.contains { $0.mountPoint == targetPath }
                
                var status = statuses[share.id] ?? ShareRuntimeStatus(
                    share: share,
                    profileId: profile.id,
                    state: isMounted ? .mounted : .disconnected,
                    mountPoint: targetPath
                )
                
                status.state = isMounted ? .mounted : (status.state == .connecting ? .connecting : .disconnected)
                if isMounted {
                    status.lastMountedAt = Date()
                    status.lastError = nil
                }
                statuses[share.id] = status
            }
        }
    }
    
    /// Mountet eine bestimmte Freigabe
    public func mount(share: ShareMount, profile: ServerProfile, password: String? = nil) async throws {
        guard let url = profile.smbURL(for: share) else {
            print("[SynologyMount] ❌ Ungültige SMB-URL für '\(share.name)': Host oder Pfad leer")
            throw SynoClientError.invalidHost
        }
        
        let targetPath = MountPointSanitizer.resolveMountPoint(for: share)
        let activeMounts = await executor.listMountedVolumes()
        
        // 1. Bereits am Ziel gemountet?
        if activeMounts.contains(where: { $0.mountPoint == targetPath }) {
            print("[SynologyMount] ℹ️ Freigabe '\(share.name)' ist bereits unter \(targetPath) gemountet.")
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
        if pw == nil || pw?.isEmpty == true {
            print("[SynologyMount] ⚠️ Kein Passwort im Keychain für User '\(profile.username)' hinterlegt.")
        }
        
        do {
            try await executor.mountVolume(url: url, mountPoint: targetPath, username: profile.username, password: pw)
            status.state = .mounted
            status.lastError = nil
            status.lastMountedAt = Date()
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
            let autoShares = profile.shares.filter { $0.autoMount }
            guard !autoShares.isEmpty else { continue }
            
            // Prüfen ob Host im Netzwerk antwortet (Port 445 oder DSM Port)
            let isSmbReachable = await reachability.checkHostReachable(host: profile.cleanHost, port: profile.smbPort)
            print("[SynologyMount] 🌐 Host \(profile.cleanHost):\(profile.smbPort) SMB-Port-Check: \(isSmbReachable ? "OFFEN ✅" : "BLOCKIERT/OFFLINE ❌")")
            
            for share in autoShares {
                let current = statuses[share.id]?.state ?? .disconnected
                if current == .disconnected || current == .error {
                    print("[SynologyMount] 🔄 Versuche Auto-Mount für '\(share.name)'...")
                    try? await mount(share: share, profile: profile)
                }
            }
        }
    }
}
