import Foundation

public struct ActiveMountInfo: Identifiable, Equatable, Sendable {
    public var id: String { mountPoint }
    public let serverURL: String       // z.B. "//user@192.168.1.6/Daten"
    public let mountPoint: String      // z.B. "/Users/.../Mounts/Daten"
    public let fileSystemType: String  // z.B. "smbfs"
    
    public init(serverURL: String, mountPoint: String, fileSystemType: String) {
        self.serverURL = serverURL
        self.mountPoint = mountPoint
        self.fileSystemType = fileSystemType
    }
    
    /// Prüft ob diese Verbindung zu einem bestimmten Share (z.B. "/Daten" oder "Daten") gehört
    public func matches(shareName: String) -> Bool {
        let clean = shareName.trimmingCharacters(in: CharacterSet(charactersIn: "/ ")).lowercased()
        let urlLower = serverURL.lowercased()
        return urlLower.hasSuffix("/\(clean)") || urlLower.contains("/\(clean)@")
    }
}

public protocol MountExecutor: Sendable {
    func listMountedVolumes() async -> [ActiveMountInfo]
    func mountVolume(url: URL, mountPoint: String, username: String, password: String?) async throws
    func unmountVolume(mountPoint: String, force: Bool) async throws
}

public final class DefaultMountExecutor: MountExecutor, @unchecked Sendable {
    public static let shared = DefaultMountExecutor()
    
    public init() {}
    
    /// Liest alle aktuell gemounteten Dateisysteme über `/sbin/mount` aus
    public func listMountedVolumes() async -> [ActiveMountInfo] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/sbin/mount")
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        
        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            return DefaultMountExecutor.parseMountOutput(output)
        } catch {
            print("[Henga] ⚠️ Fehler beim Ausführen von /sbin/mount: \(error.localizedDescription)")
            return []
        }
    }
    
    /// Parst die Ausgabe von `/sbin/mount`
    public static func parseMountOutput(_ output: String) -> [ActiveMountInfo] {
        var results: [ActiveMountInfo] = []
        let lines = output.components(separatedBy: .newlines)
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }
            
            // Format: //user@host/share on /path/to/mount (smbfs, nodev, nosuid, mounted by user)
            let parts = trimmed.components(separatedBy: " on ")
            guard parts.count == 2 else { continue }
            
            let serverURL = parts[0].trimmingCharacters(in: .whitespaces)
            let rest = parts[1]
            
            guard let openParen = rest.range(of: " ("),
                  let closeParen = rest.range(of: ")", options: .backwards) else {
                continue
            }
            
            let mountPoint = String(rest[..<openParen.lowerBound]).trimmingCharacters(in: .whitespaces)
            let optionsStr = String(rest[openParen.upperBound..<closeParen.lowerBound])
            let fsType = optionsStr.components(separatedBy: ",").first?.trimmingCharacters(in: .whitespaces) ?? "unknown"
            
            if fsType == "smbfs" || serverURL.hasPrefix("//") {
                results.append(ActiveMountInfo(serverURL: serverURL, mountPoint: mountPoint, fileSystemType: fsType))
            }
        }
        return results
    }
    
    /// Mountet mit -o nobrowse (MNT_NOBROWSE Flag im Kernel VFS)
    /// Dadurch blendet der macOS Finder das Laufwerk in 'Computer' ('MacBook Air von Johannes') VOLLSTÄNDIG aus!
    /// Zugriff erfolgt 100% sauber und exklusiv über den Finder-Hub Ordner (~/DiskStation)!
    public func mountVolume(url: URL, mountPoint: String, username: String, password: String?) async throws {
        guard let host = url.host else {
            throw SynoClientError.invalidHost
        }
        let share = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        
        let fm = FileManager.default
        if !fm.fileExists(atPath: mountPoint) {
            try fm.createDirectory(atPath: mountPoint, withIntermediateDirectories: true)
        }
        
        var userPart = username
        if let pw = password, !pw.isEmpty {
            let encodedPw = pw.addingPercentEncoding(withAllowedCharacters: .urlPasswordAllowed) ?? pw
            let encodedUser = username.addingPercentEncoding(withAllowedCharacters: .urlUserAllowed) ?? username
            userPart = "\(encodedUser):\(encodedPw)"
        }
        
        let smbSource = "//\(userPart)@\(host)/\(share)"
        let safeLogSource = "//\(username):***@\(host)/\(share)"
        print("[Henga] ⚙️ Führe unsichtbaren Mount aus (-o nobrowse): \(safeLogSource) -> \(mountPoint)")
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/sbin/mount_smbfs")
        // -o nobrowse versteckt das Volume komplett vor Apples Disk Arbitration und Finder-Computer-Ansicht!
        process.arguments = ["-o", "nobrowse", smbSource, mountPoint]
        
        let errPipe = Pipe()
        process.standardError = errPipe
        process.standardOutput = FileHandle.nullDevice
        
        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            print("[Henga] ❌ mount_smbfs Prozessfehler: \(error.localizedDescription)")
            throw error
        }
        
        if process.terminationStatus != 0 {
            let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
            let errMsg = String(data: errData, encoding: .utf8) ?? "Unbekannter Fehler"
            let trimmedMsg = errMsg.trimmingCharacters(in: .whitespacesAndNewlines)
            print("[Henga] ❌ mount_smbfs fehlgeschlagen (Code \(process.terminationStatus)): \(trimmedMsg)")
            try? fm.removeItem(atPath: mountPoint)
            throw SynoClientError.networkError("Mount fehlgeschlagen (Code \(process.terminationStatus)): \(trimmedMsg)")
        } else {
            print("[Henga] 🎉 Unsichtbarer Mount (-o nobrowse) erfolgreich: \(mountPoint) (Systemübersicht ist 100% frei!)")
        }
    }
    
    /// Hängt Volume via `/sbin/umount` aus
    public func unmountVolume(mountPoint: String, force: Bool = false) async throws {
        print("[Henga] ⚙️ Führe /sbin/umount aus für: \(mountPoint) (Force: \(force))")
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/sbin/umount")
        process.arguments = force ? ["-f", mountPoint] : [mountPoint]
        
        let errPipe = Pipe()
        process.standardError = errPipe
        process.standardOutput = FileHandle.nullDevice
        
        try process.run()
        process.waitUntilExit()
        
        if process.terminationStatus != 0 {
            let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
            let errMsg = String(data: errData, encoding: .utf8) ?? "Fehler beim Aushängen"
            print("[Henga] ❌ umount Fehler: \(errMsg)")
            throw SynoClientError.networkError("umount fehlgeschlagen: \(errMsg)")
        }
        
        let fm = FileManager.default
        if let contents = try? fm.contentsOfDirectory(atPath: mountPoint), contents.isEmpty {
            try? fm.removeItem(atPath: mountPoint)
            print("[Henga] 🧹 Leeren Mountpoint entfernt: \(mountPoint)")
        }
    }
}
