import Testing
import Foundation
@testable import SynologyMountCore

@Suite("Adversarial & Sabotage Tests for SynologyMount (Mutation & Resiliency)")
struct MountSabotageTests {
    
    @Test("Sabotage: Malformed DSM API JSON must safely fail decoding without crash")
    func testMalformedApiResponse() {
        let corruptData = "{ \"success\": \"invalid\", \"data\": 404 }".data(using: .utf8)!
        let decoded = try? JSONDecoder().decode(SynoApiResponse<SynoAuthResponse>.self, from: corruptData)
        #expect(decoded == nil, "Korruptes JSON darf niemals erfolgreich decodiert werden!")
    }
    
    @Test("Sabotage: DSM 7 2FA 403 response with JWT token payload must decode cleanly into SynoApiResponse")
    func testDsm7TwoFactorPayloadDecoding() throws {
        let dsm7ErrorJson = """
        {
            "error": {
                "code": 403,
                "errors": {
                    "token": "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJhdWQiOiIyRkEiLCJleHAiOjE3ODk3MjU1ODQsImlhdCI6MTc4OTcyNTI4NCwic3ViIjoic2Nobml0emVsIn0.sample_signature",
                    "types": [
                        { "type": "authenticator" },
                        { "type": "otp" }
                    ]
                }
            },
            "success": false
        }
        """.data(using: .utf8)!
        
        let response = try JSONDecoder().decode(SynoApiResponse<SynoAuthResponse>.self, from: dsm7ErrorJson)
        #expect(response.success == false)
        #expect(response.error?.code == 403)
        #expect(response.error?.errors?.token != nil)
        #expect(response.error?.errors?.types?.count == 2)
    }
    
    @Test("Sabotage: Empty and corrupt mount output parsing returns empty array")
    func testCorruptedMountOutput() {
        let corrupt = "random string without matching pattern\n\n   on \n(/)"
        let mounts = DefaultMountExecutor.parseMountOutput(corrupt)
        #expect(mounts.isEmpty, "Fehlerhafte Zeilen dürfen keine ungültigen Mount-Objekte erzeugen")
    }
    
    @Test("Sabotage: Host with whitespace, missing parts or invalid URLs must be rejected")
    func testInvalidHostScenarios() {
        let p1 = ServerProfile(name: "Bad", host: "", username: "user")
        #expect(p1.cleanHost.isEmpty)
        #expect(p1.smbURL(for: ShareMount(name: "s", remotePath: "s")) == nil)
        
        let p2 = ServerProfile(name: "Bad2", host: "   ", username: "user")
        #expect(p2.cleanHost.isEmpty)
    }
    
    @Test("Sabotage: Path traversal and injection attacks in remotePath must be sanitized")
    func testPathInjection() {
        let maliciousShare = ShareMount(name: "Evil", remotePath: "../../../etc/passwd")
        let sanitized = MountPointSanitizer.resolveMountPoint(for: maliciousShare)
        #expect(!sanitized.contains("etc/passwd"))
        #expect(sanitized.contains("SynologyMount/Mounts"))
    }
    
    @Test("Sabotage: Orphaned directory check protects non-empty folders")
    func testOrphanedProtection() throws {
        let fm = FileManager.default
        let tempDir = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try fm.createDirectory(at: tempDir, withIntermediateDirectories: true)
        
        let dummyFile = tempDir.appendingPathComponent("important_data.txt")
        try "nicht löschen!".write(to: dummyFile, atomically: true, encoding: .utf8)
        
        let isOrphaned = MountPointSanitizer.isOrphanedDirectory(at: tempDir.path, activeMounts: [])
        #expect(!isOrphaned, "Ein Ordner mit Inhalten darf NIEMALS als verwaist eingestuft werden!")
        
        try? fm.removeItem(at: tempDir)
    }
}
