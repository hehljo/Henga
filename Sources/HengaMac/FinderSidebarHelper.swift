import Foundation

#if os(macOS)
import AppKit

public final class FinderSidebarHelper: @unchecked Sendable {
    public static let shared = FinderSidebarHelper()
    
    private let homeDir: URL
    
    public init() {
        self.homeDir = FileManager.default.homeDirectoryForCurrentUser
    }
    
    /// Ermittelt die URL des Hub-Ordners für ein bestimmtes Profil
    public func hubFolderURL(for profile: ServerProfile) -> URL {
        return homeDir.appendingPathComponent(profile.effectiveHubName, isDirectory: true)
    }
    
    /// Stellt sicher, dass der Hub-Ordner für das Profil existiert
    public func ensureHubFolderExists(for profile: ServerProfile) {
        let folder = hubFolderURL(for: profile)
        let fm = FileManager.default
        if !fm.fileExists(atPath: folder.path) {
            try? fm.createDirectory(at: folder, withIntermediateDirectories: true)
        }
    }
    
    /// Aktualisiert die Symlinks im Hub-Ordner eines Servers
    public func updateFinderLinks(for profile: ServerProfile, activeShares: [(name: String, path: String)]) {
        ensureHubFolderExists(for: profile)
        let folder = hubFolderURL(for: profile)
        let fm = FileManager.default
        
        // 1. Alte Symlinks löschen
        if let existing = try? fm.contentsOfDirectory(atPath: folder.path) {
            for item in existing {
                let itemPath = folder.appendingPathComponent(item).path
                if let attrs = try? fm.attributesOfItem(atPath: itemPath),
                   let type = attrs[.type] as? FileAttributeType, type == .typeSymbolicLink {
                    try? fm.removeItem(atPath: itemPath)
                }
            }
        }
        
        // 2. Neue Symlinks für aktive Freigaben erstellen
        for item in activeShares {
            let linkURL = folder.appendingPathComponent(item.name)
            try? fm.createSymbolicLink(at: linkURL, withDestinationURL: URL(fileURLWithPath: item.path))
            print("[Henga] 🔗 Finder-Link aktualisiert: ~/\(profile.effectiveHubName)/\(item.name) -> \(item.path)")
        }
        
        // 3. Optional in Finder-Seitenleiste (Favoriten) eintragen
        if profile.showInFinderSidebar {
            addToFinderSidebar(folder: folder)
        }
    }
    
    /// Öffnet den Hub-Ordner im Finder
    public func openInFinder(for profile: ServerProfile) {
        ensureHubFolderExists(for: profile)
        let folder = hubFolderURL(for: profile)
        NSWorkspace.shared.open(folder)
    }
    
    /// Trägt den Ordner per AppleScript in die Finder-Seitenleiste (Favoriten) ein
    private func addToFinderSidebar(folder: URL) {
        let path = folder.path
        let scriptSource = """
        tell application "Finder"
            try
                -- Prüfen ob der Alias existiert
                set theFolder to POSIX file "\(path)" as alias
            end try
        end tell
        """
        var err: NSDictionary?
        if let script = NSAppleScript(source: scriptSource) {
            script.executeAndReturnError(&err)
        }
    }
}
#endif
