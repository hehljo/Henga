import Testing
import Foundation
@testable import SynologyMountCore

@Suite("Adversarial & Sabotage Tests for SynologyMount (Mutation & Resiliency)")
struct MountSabotageTests {
    
    @Test("Sabotage: DSM 7 2FA 403 response with JWT token payload must decode cleanly into SynoApiResponse")
    func testDsm7TwoFactorPayloadDecoding() {
        let dsm7TwoFactorJson = """
        {
            "error": {
                "code": 403,
                "errors": {
                    "token": "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.test",
                    "types": [
                        { "type": "authenticator" },
                        { "type": "otp" }
                    ]
                }
            },
            "success": false
        }
        """.data(using: .utf8)!
        
        struct DummyData: Codable {}
        let response = try? JSONDecoder().decode(SynoApiResponse<DummyData>.self, from: dsm7TwoFactorJson)
        
        #expect(response != nil)
        #expect(response?.success == false)
        #expect(response?.error?.code == 403)
        #expect(response?.error?.errors?.token?.contains("eyJ") == true)
        #expect(response?.error?.errors?.types?.first?.type == "authenticator")
    }
    
    @Test("Sabotage: Malformed DSM API JSON must safely fail decoding without crash")
    func testMalformedApiResponse() {
        let corruptJson = """
        {
            "success": "not_a_boolean",
            "data": { "shares": "invalid" }
        }
        """.data(using: .utf8)!
        
        #expect(throws: Error.self) {
            _ = try JSONDecoder().decode(SynoApiResponse<SynoSharedFoldersData>.self, from: corruptJson)
        }
    }
    
    @Test("Sabotage: Host with whitespace, missing parts or invalid URLs must be rejected")
    func testHostSanitizationSabotage() {
        let emptyProfile = ServerProfile(name: "", host: "   ", username: "")
        #expect(emptyProfile.cleanHost.isEmpty)
        #expect(emptyProfile.dsmBaseURL == nil)
        
        let share = ShareMount(name: "", remotePath: "   ")
        #expect(emptyProfile.smbURL(for: share) == nil)
    }
    
    @Test("Sabotage: Path traversal and injection attacks in remotePath must be sanitized")
    func testPathInjectionSabotage() {
        let evilShare = ShareMount(name: "Evil", remotePath: "../../etc/shadow")
        let sanitized = MountPointSanitizer.resolveMountPoint(for: evilShare)
        
        #expect(!sanitized.contains(".."))
        #expect(sanitized.hasPrefix("/Volumes/"))
    }
    
    @Test("Sabotage: Empty and corrupt mount output parsing returns empty array")
    func testEmptyMountOutput() {
        #expect(DefaultMountExecutor.parseMountOutput("").isEmpty)
        #expect(DefaultMountExecutor.parseMountOutput("just some random text without mount structure").isEmpty)
        #expect(DefaultMountExecutor.parseMountOutput("on /Volumes/test (unknown)").isEmpty)
    }
    
    @Test("Sabotage: Orphaned directory check protects non-empty folders")
    func testOrphanedProtection() {
        let tempDir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("orphan_test_\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let dummyFile = tempDir.appendingPathComponent("important_data.txt")
        try? "wichtig".data(using: .utf8)?.write(to: dummyFile)
        
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        let isOrphan = MountPointSanitizer.isOrphanedDirectory(at: tempDir.path, activeMounts: [])
        #expect(isOrphan == false)
    }
}
