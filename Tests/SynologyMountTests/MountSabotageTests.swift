import Testing
import Foundation
@testable import SynologyMountCore

@Suite("Adversarial & Sabotage Tests for SynologyMount (Mutation & Resiliency)")
struct MountSabotageTests {
    
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
        // Versuch von ../../../ Verzeichnis-Traversal
        let evilShare = ShareMount(name: "Evil", remotePath: "../../etc/shadow")
        let sanitized = MountPointSanitizer.resolveMountPoint(for: evilShare)
        
        // Muss im /Volumes/ Pfad bleiben und darf keine relativen Traversals enthalten
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
        // Verzeichnis mit Inhalt darf NIE als verwaist markiert werden
        let tempDir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("orphan_test_\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let dummyFile = tempDir.appendingPathComponent("important_data.txt")
        try? "wichtig".data(using: .utf8)?.write(to: dummyFile)
        
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        let isOrphan = MountPointSanitizer.isOrphanedDirectory(at: tempDir.path, activeMounts: [])
        #expect(isOrphan == false)
    }
}
