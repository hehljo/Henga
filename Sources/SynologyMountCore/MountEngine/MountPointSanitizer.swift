import Foundation

public final class MountPointSanitizer: @unchecked Sendable {
    
    /// Ermittelt den Ziel-Mountpoint und verhindert macOS-Doppelungen (`/Volumes/share-1`, etc.)
    public static func resolveMountPoint(for share: ShareMount, defaultRoot: String = AppConfig.defaultMountRoot) -> String {
        if let custom = share.customLocalMountPoint, !custom.isEmpty {
            return (custom as NSString).standardizingPath
        }
        
        let safeName = sanitizeFolderName(share.cleanRemotePath)
        return "\(defaultRoot)/\(safeName)"
    }
    
    /// Bereinigt Namen von ungültigen Zeichen für POSIX/macOS Pfade und verhindert Traversal
    public static func sanitizeFolderName(_ raw: String) -> String {
        var cleaned = raw.trimmingCharacters(in: CharacterSet(charactersIn: "/ "))
        // Path traversal Versuche eliminieren
        cleaned = cleaned.replacingOccurrences(of: "..", with: "")
        // Schräger Slash und Doppelpunkt durch Unterstrich ersetzen (z.B. homes/alice -> homes_alice)
        cleaned = cleaned.replacingOccurrences(of: "/", with: "_")
        cleaned = cleaned.replacingOccurrences(of: ":", with: "_")
        cleaned = cleaned.trimmingCharacters(in: CharacterSet(charactersIn: "_ "))
        return cleaned.isEmpty ? "share" : cleaned
    }
    
    /// Prüft ob ein Verzeichnis ein toter/verwaister Mountpoint ist (Verzeichnis existiert, aber ist nicht gemountet und leer)
    public static func isOrphanedDirectory(at path: String, activeMounts: [ActiveMountInfo]) -> Bool {
        let fm = FileManager.default
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: path, isDirectory: &isDir), isDir.boolValue else {
            return false
        }
        
        // Ist das Verzeichnis in der Liste der aktuell gemounteten Dateisysteme?
        let isActivelyMounted = activeMounts.contains { $0.mountPoint == path }
        if isActivelyMounted {
            return false
        }
        
        // Prüfen ob Verzeichnis leer ist
        guard let contents = try? fm.contentsOfDirectory(atPath: path), contents.isEmpty else {
            return false // Hat Inhalte, nicht löschen!
        }
        
        return true
    }
    
    /// Räumt verwaiste Geister-Ordner vor einem neuen Mount-Versuch auf
    public static func cleanupOrphanedMountPointIfNeeded(at path: String, activeMounts: [ActiveMountInfo]) {
        if isOrphanedDirectory(at: path, activeMounts: activeMounts) {
            try? FileManager.default.removeItem(atPath: path)
        }
    }
}
