import Testing
import Foundation
@testable import HengaCore

@Suite("Henga Core Domain Tests")
struct CoreDomainTests {
    
    @Test("ServerProfile host cleaning handles smb, https and port prefixes")
    func testHostCleaning() {
        let p1 = ServerProfile(name: "Test", host: "smb://192.168.1.50:445", username: "user")
        #expect(p1.cleanHost == "192.168.1.50")
        
        let p2 = ServerProfile(name: "Test", host: "https://nas.local:5001/", username: "user")
        #expect(p2.cleanHost == "nas.local")
    }
    
    @Test("ServerProfile SMB URL generation")
    func testSmbURLGeneration() {
        let p = ServerProfile(name: "Test", host: "192.168.1.10", username: "admin")
        let share = ShareMount(name: "Video", remotePath: "video/movies")
        
        let url = p.smbURL(for: share)
        #expect(url?.absoluteString == "smb://192.168.1.10/video/movies")
    }
    
    @Test("ServerProfile Custom SMB Port generation")
    func testCustomSmbPort() {
        let p = ServerProfile(name: "Test", host: "192.168.1.10", smbPort: 1445, username: "admin")
        let share = ShareMount(name: "Video", remotePath: "video")
        
        let url = p.smbURL(for: share)
        #expect(url?.absoluteString == "smb://192.168.1.10:1445/video")
    }
    
    @Test("MountPointSanitizer produces isolated application support path without collisions")
    func testMountPointSanitizer() {
        let share = ShareMount(name: "My Photos", remotePath: "photos:2026")
        let path = MountPointSanitizer.resolveMountPoint(for: share)
        #expect(path.hasSuffix("My Photos"))
        #expect(path.contains("Henga/Mounts"))
    }
    
    @Test("Mount output parser extracts smbfs mounts accurately")
    func testMountOutputParser() {
        let sample = """
        /dev/disk3s1s1 on / (apfs, sealed, local, read-only)
        devfs on /dev (devfs, local, nobrowse)
        //admin@192.168.1.10/video on /Volumes/video (smbfs, nodev, nosuid, mounted by admin)
        """
        
        let mounts = DefaultMountExecutor.parseMountOutput(sample)
        #expect(mounts.count == 1)
        #expect(mounts.first?.mountPoint == "/Volumes/video")
        #expect(mounts.first?.fileSystemType == "smbfs")
    }
    
    @Test("ProfileManager persistence cycle")
    func testProfileManagerPersistence() {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let pm = ProfileManager(customStorageURL: tempDir.appendingPathComponent("profiles.json"))
        
        let profile = ServerProfile(name: "Home NAS", host: "192.168.1.2", username: "user")
        pm.addOrUpdateProfile(profile)
        
        let retrieved = pm.getProfiles()
        #expect(retrieved.count == 1)
        #expect(retrieved.first?.name == "Home NAS")
    }
    
    @Test("SynoClientError descriptions properly map 2FA codes 403 and 404")
    func testSynoError2FAMapping() {
        let err403 = SynoClientError.serverError(403, nil)
        #expect(err403.localizedDescription.contains("2FA"))
        
        let err404 = SynoClientError.serverError(404, nil)
        #expect(err404.localizedDescription.contains("OTP"))
    }
}
