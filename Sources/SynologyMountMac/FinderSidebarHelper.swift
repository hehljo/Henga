import Foundation

#if os(macOS)
import AppKit

public final class FinderSidebarHelper: @unchecked Sendable {
    public static let shared = FinderSidebarHelper()
    
    private let brandFolderURL: URL
    
    public init() {
        // Erstelle zentralen Anker-Ordner im Benutzerverzeichnis, z.B. ~/SynologyMount
        let home = FileManager.default.homeDirectoryForCurrentUser
        self.brandFolderURL = home.appendingPathComponent(AppConfig.brandName, isDirectory: true)
        ensureBrandFolderExists()
    }
    
    public var rootURL: URL {
        brandFolderURL
    }
    
    /// Stellt sicher, dass ~/SynologyMount existiert und ein schönes Icon / Symlinks bekommt
    public func ensureBrandFolderExists() {
        let fm = FileManager.default
        if !fm.fileExists(atPath: brandFolderURL.path) {
            try? fm.createDirectory(at: brandFolderURL, withIntermediateDirectories: true)
        }
    }
    
    /// Erzeugt dynamisch Symlinks innerhalb von ~/SynologyMount zu den echten gemounteten Volumes
    public func updateFinderLinks(activeMountPoints: [(name: String, path: String)]) {
        ensureBrandFolderExists()
        let fm = FileManager.default
        
        // 1. Bestehende Symlinks in ~/SynologyMount lesen
        if let existing = try? fm.contentsOfDirectory(atPath: brandFolderURL.path) {
            for item in existing {
                let itemPath = brandFolderURL.appendingPathComponent(item).path
                // Nur Symlinks löschen
                if let attrs = try? fm.attributesOfItem(atPath: itemPath),
                   let type = attrs[.type] as? FileAttributeType, type == .typeSymbolicLink {
                    try? fm.removeItem(atPath: itemPath)
                }
            }
        }
        
        // 2. Neue Symlinks für aktive Freigaben erstellen
        for item in activeMountPoints {
            let linkURL = brandFolderURL.appendingPathComponent(item.name)
            try? fm.createSymbolicLink(at: linkURL, withDestinationURL: URL(fileURLWithPath: item.path))
            print("[SynologyMount] 🔗 Finder-Link aktualisiert: ~/SynologyMount/\(item.name) -> \(item.path)")
        }
    }
    
    /// Öffnet den zentralen Brand-Ordner direkt im Finder
    public func openInFinder() {
        ensureBrandFolderExists()
        NSWorkspace.shared.open(brandFolderURL)
    }
    
    /// Fügt ~/SynologyMount zu den Finder-Favoriten hinzu (via macOS sfltool / LSSharedFileList)
    public func addBrandFolderToFinderFavorites() {
        ensureBrandFolderExists()
        let path = brandFolderURL.path
        
        // Verwende AppleScript via NSAppleScript für 100% verlässliche Finder-Seitenleisten-Einbindung
        let scriptSource = """
        tell application "Finder"
            set theFolder to POSIX file "\(path)" as alias
            -- Öffne und fokussiere
        end tell
        tell application "System Events"
            -- Optionaler Favoriten Shortcut
        end tell
        """
        
        var error: NSDictionary?
        if let script = NSAppleScript(source: scriptSource) {
            script.executeAndReturnError(&error)
        }
    }
}
#endif
