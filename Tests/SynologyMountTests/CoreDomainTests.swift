import Testing
import Foundation
@testable import SynologyMountCore

@Suite("SynologyMount Core Domain Tests")
struct CoreDomainTests {
    
    @Test("ServerProfile host cleaning handles smb, https and port prefixes")
    func testHostCleaning() {
        let p1 = ServerProfile(name: "Test", host: "smb://192.168.1.50/", username: "user")
        #expect(p1.cleanHost == "192.168.1.50")
        
        let p2 = ServerProfile(name: "Test", host: "https://nas.local:5001/webapi", username: "user")
        #expect(p2.cleanHost == "nas.local")
        
        let p3 = ServerProfile(name: "Test", host: "   diskstation   ", username: "user")
        #expect(p3.cleanHost == "diskstation")
    }
    
    @Test("ServerProfile SMB URL generation")
    func testSmbURLGeneration() {
        let p = ServerProfile(name: "Test", host: "nas.local", smbPort: 445, username: "admin")
        let share = ShareMount(name: "Media", remotePath: "/video/")
        
        let url = p.smbURL(for: share)
        #expect(url?.absoluteString == "smb://nas.local/video")
    }
    
    @Test("ServerProfile Custom SMB Port generation")
    func testCustomSmbPortURL() {
        let p = ServerProfile(name: "Test", host: "nas.local", smbPort: 1445, username: "admin")
        let share = ShareMount(name: "Media", remotePath: "video")
        
        let url = p.smbURL(for: share)
        #expect(url?.absoluteString == "smb://nas.local:1445/video")
    }
    
    @Test("MountPointSanitizer produces standard /Volumes/ path without collisions")
    func testMountPointSanitizer() {
        let share = ShareMount(name: "My Photos", remotePath: "/photos/2026/")
        let path = MountPointSanitizer.resolveMountPoint(for: share)
        #expect(path == "/Volumes/photos_2026")
        
        let customShare = ShareMount(name: "Backup", remotePath: "backup", customLocalMountPoint: "/Users/test/NAS_Backup")
        let customPath = MountPointSanitizer.resolveMountPoint(for: customShare)
        #expect(customPath == "/Users/test/NAS_Backup")
    }
    
    @Test("Mount output parser extracts smbfs mounts accurately")
    func testMountParser() {
        let sampleOutput = """
        /dev/disk3s1s1 on / (apfs, sealed, local, read-only, crypt)
        devfs on /dev (devfs, local, nobrowse)
        //admin@nas.local/video on /Volumes/video (smbfs, nodev, nosuid, mounted by user)
        //admin@192.168.1.100/backup on /Volumes/backup (smbfs, nodev, nosuid, mounted by user)
        map auto_home on /System/Volumes/Data/home (autofs, automounted, nobrowse)
        """
        
        let mounts = DefaultMountExecutor.parseMountOutput(sampleOutput)
        #expect(mounts.count == 2)
        #expect(mounts[0].mountPoint == "/Volumes/video")
        #expect(mounts[0].fileSystemType == "smbfs")
        #expect(mounts[1].mountPoint == "/Volumes/backup")
    }
    
    @Test("ProfileManager persistence cycle")
    func testProfilePersistence() {
        let tempDir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("profile_test_\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        let manager = ProfileManager(customStorageURL: tempDir)
        #expect(manager.getProfiles().isEmpty)
        
        let profile = ServerProfile(name: "Home NAS", host: "192.168.1.10", username: "alice")
        manager.addOrUpdateProfile(profile)
        
        #expect(manager.getProfiles().count == 1)
        #expect(manager.getProfiles().first?.name == "Home NAS")
    }
    
    @Test("SynoClientError descriptions properly map 2FA codes 403 and 404")
    func testTwoFactorErrorDescriptions() {
        let err403 = SynoClientError.twoFactorRequired
        #expect(err403.errorDescription?.contains("403") == true)
        
        let err404 = SynoClientError.invalidTwoFactorCode
        #expect(err404.errorDescription?.contains("404") == true)
    }
}
