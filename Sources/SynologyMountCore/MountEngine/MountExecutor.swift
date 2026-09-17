import Foundation

public struct ActiveMountInfo: Identifiable, Equatable, Sendable {
    public var id: String { mountPoint }
    public let serverURL: String       // z.B. "smb://diskstation.local/video"
    public let mountPoint: String      // z.B. "/Volumes/video"
    public let fileSystemType: String  // z.B. "smbfs"
}

public protocol MountExecuting: Sendable {
    func listMountedVolumes() async -> [ActiveMountInfo]
    func mountVolume(url: URL, mountPoint: String, username: String, password: String?) async throws
    func unmountVolume(mountPoint: String, force: Bool) async throws
}

public final class DefaultMountExecutor: MountExecuting, @unchecked Sendable {
    public init() {}
    
    /// Ermittelt alle aktiven Dateisystem-Mounts via `mount` Command
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
            guard let output = String(data: data, encoding: .utf8) else { return [] }
            return Self.parseMountOutput(output)
        } catch {
            return []
        }
    }
    
    /// Parse-Helper für `mount` Output: `//user@host/share on /Volumes/share (smbfs, ...)`
    public static func parseMountOutput(_ output: String) -> [ActiveMountInfo] {
        var results: [ActiveMountInfo] = []
        let lines = output.components(separatedBy: .newlines)
        
        for line in lines {
            // Typisches macOS Format: `//username@host/share on /Volumes/share (smbfs, nodev, nosuid, mounted by ...)`
            guard line.contains(" on ") && line.contains(" (") else { continue }
            
            let parts = line.components(separatedBy: " on ")
            guard parts.count == 2 else { continue }
            
            let serverURL = parts[0].trimmingCharacters(in: .whitespaces)
            let rest = parts[1]
            
            guard let parenIndex = rest.firstIndex(of: "(") else { continue }
            let mountPoint = String(rest[..<parenIndex]).trimmingCharacters(in: .whitespaces)
            
            let optionsPart = String(rest[parenIndex...]).dropFirst().dropLast() // Klammern entfernen
            let fsType = optionsPart.components(separatedBy: ",").first?.trimmingCharacters(in: .whitespaces) ?? ""
            
            if fsType.lowercased() == "smbfs" || serverURL.hasPrefix("//") || serverURL.contains("@") {
                results.append(ActiveMountInfo(serverURL: serverURL, mountPoint: mountPoint, fileSystemType: fsType))
            }
        }
        return results
    }
    
    /// Mountet via `/sbin/mount_smbfs`
    public func mountVolume(url: URL, mountPoint: String, username: String, password: String?) async throws {
        // Sicherstellen, dass Mountpoint-Verzeichnis existiert
        let fm = FileManager.default
        if !fm.fileExists(atPath: mountPoint) {
            try fm.createDirectory(atPath: mountPoint, withIntermediateDirectories: true)
        }
        
        // Host & Share aus URL
        guard let host = url.host else {
            throw SynoClientError.invalidHost
        }
        let share = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        
        // URL-Codierte Credentials für mount_smbfs URL
        // //user:password@host/share
        var userPart = username
        if let pw = password, !pw.isEmpty {
            let encodedPw = pw.addingPercentEncoding(withAllowedCharacters: .urlPasswordAllowed) ?? pw
            let encodedUser = username.addingPercentEncoding(withAllowedCharacters: .urlUserAllowed) ?? username
            userPart = "\(encodedUser):\(encodedPw)"
        }
        
        let smbSource = "//\(userPart)@\(host)/\(share)"
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/sbin/mount_smbfs")
        process.arguments = [smbSource, mountPoint]
        
        let errPipe = Pipe()
        process.standardError = errPipe
        process.standardOutput = FileHandle.nullDevice
        
        try process.run()
        process.waitUntilExit()
        
        if process.terminationStatus != 0 {
            let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
            let errMsg = String(data: errData, encoding: .utf8) ?? "Unbekannter Fehler"
            throw SynoClientError.networkError("mount_smbfs fehlgeschlagen (Code \(process.terminationStatus)): \(errMsg.trimmingCharacters(in: .whitespacesAndNewlines))")
        }
    }
    
    /// Hängt Volume via `/sbin/umount` aus
    public func unmountVolume(mountPoint: String, force: Bool = false) async throws {
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
            throw SynoClientError.networkError("umount fehlgeschlagen: \(errMsg)")
        }
        
        // Leeren verwaisten Ordner unter /Volumes aufräumen, falls er noch leer existiert
        if mountPoint.hasPrefix("/Volumes/") {
            try? FileManager.default.removeItem(atPath: mountPoint)
        }
    }
}
