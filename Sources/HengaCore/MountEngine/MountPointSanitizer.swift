import Foundation

public final class MountPointSanitizer: @unchecked Sendable {
    
    /// Ermittelt den Ziel-Mountpoint im Benutzerverzeichnis (unter ~/Library/Caches/Henga/Mounts/)
    /// Dadurch entfällt das /Volumes/-Root-Rechteproblem UND die Systemübersicht bleibt 100% sauber!
    public static func resolveMountPoint(for share: ShareMount, defaultRoot: String? = nil) -> String {
        if let custom = share.customLocalMountPoint, !custom.isEmpty {
            return (custom as NSString).standardizingPath
        }
        
        let safeName = sanitizeFolderName(share.name.isEmpty ? share.cleanRemotePath : share.name)
        
        if let root = defaultRoot {
            return (root as NSString).appendingPathComponent(safeName)
        }
        
        // Isoliertes Verzeichnis im User-Home
        let home = FileManager.default.homeDirectoryForCurrentUser
        let isolatedMounts = home.appendingPathComponent("Library/Application Support/Henga/Mounts", isDirectory: true)
        return isolatedMounts.appendingPathComponent(safeName).path
    }
    
    /// Bereinigt Namen von Sonderzeichen für Dateipfade
    public static func sanitizeFolderName(_ name: String) -> String {
        let invalidCharacters = CharacterSet(charactersIn: "\\/:*?\"<>|")
        let cleaned = name.components(separatedBy: invalidCharacters).joined(separator: "_")
        let trimmed = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Share" : trimmed
    }
    
    /// Prüft ob ein Verzeichnis ein toter/verwaister Mountpoint ist
    public static func isOrphanedDirectory(at path: String, activeMounts: [ActiveMountInfo]) -> Bool {
        let fm = FileManager.default
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: path, isDirectory: &isDir), isDir.boolValue else {
            return false
        }
        
        // Wenn es aktiv gemountet ist -> NICHT verwaist
        if activeMounts.contains(where: { $0.mountPoint == path }) {
            return false
        }
        
        // Wenn es nicht gemountet ist, aber leer ist -> verwaist!
        if let contents = try? fm.contentsOfDirectory(atPath: path) {
            return contents.isEmpty
        }
        
        return false
    }
    
    /// Räumt verwaiste Geister-Ordner vor einem neuen Mount-Versuch auf
    public static func cleanupOrphanedMountPointIfNeeded(at path: String, activeMounts: [ActiveMountInfo]) {
        if isOrphanedDirectory(at: path, activeMounts: activeMounts) {
            try? FileManager.default.removeItem(atPath: path)
            print("[Henga] 🧹 Verwaister toter Mountpoint entfernt: \(path)")
        }
    }
}
