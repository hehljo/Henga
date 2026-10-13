import Testing
import Foundation
@testable import HengaCore

/// Attrappe: liefert feste System-Mounts und merkt sich Aushänge-Aufrufe
actor FakeMountExecutor: MountExecutor {
    let mounts: [ActiveMountInfo]
    private(set) var unmounted: [String] = []
    
    init(mounts: [ActiveMountInfo]) { self.mounts = mounts }
    
    func listMountedVolumes() async -> [ActiveMountInfo] { mounts }
    func mountVolume(url: URL, mountPoint: String, username: String, password: String?) async throws {}
    func unmountVolume(mountPoint: String, force: Bool) async throws { unmounted.append(mountPoint) }
}

@Suite("Fremde Einbindungen derselben Freigabe")
struct ForeignMountTests {
    // Belegt am Mac (13.10.2026): ein anderes Werkzeug bindet Backup unter ~/nas_Backup ein
    let backup = ShareMount(name: "Backup", remotePath: "Backup")
    var profile: ServerProfile {
        var p = ServerProfile(name: "DiskStation", host: "192.168.1.6", username: "user")
        p.shares = [backup]
        return p
    }
    let foreign = ActiveMountInfo(serverURL: "//user@DiskStation.local/Backup", mountPoint: "/Users/user/nas_Backup", fileSystemType: "smbfs")
    
    @Test("Fremder Mount zählt nicht als eigene Verbindung")
    func foreignMountIsNotMounted() async {
        let manager = MountManager(executor: FakeMountExecutor(mounts: [foreign]))
        await manager.refreshMountStatuses(profiles: [profile])
        #expect(await manager.getStatus(for: backup.id)?.state == .disconnected)
    }
    
    @Test("Eigener Zielpfad zählt als verbunden")
    func ownMountIsMounted() async {
        let own = ActiveMountInfo(serverURL: "//user@192.168.1.6/Backup", mountPoint: MountPointSanitizer.resolveMountPoint(for: backup), fileSystemType: "smbfs")
        let manager = MountManager(executor: FakeMountExecutor(mounts: [foreign, own]))
        await manager.refreshMountStatuses(profiles: [profile])
        let status = await manager.getStatus(for: backup.id)
        #expect(status?.state == .mounted)
        #expect(status?.mountPoint == own.mountPoint)
    }
    
    @Test("Aushängen fasst die fremde Einbindung nicht an")
    func unmountLeavesForeignMount() async throws {
        let executor = FakeMountExecutor(mounts: [foreign])
        let manager = MountManager(executor: executor)
        try await manager.unmount(share: backup, profileId: profile.id)
        let calls = await executor.unmounted
        #expect(calls == [MountPointSanitizer.resolveMountPoint(for: backup)])
    }
}
