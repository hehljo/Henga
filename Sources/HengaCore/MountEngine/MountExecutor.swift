import Foundation
#if canImport(NetFS)
import NetFS
#endif

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
    
    /// Mountet über NetFS mit MNT_DONTBROWSE (entspricht `-o nobrowse`): das Volume
    /// taucht nicht in Finder/Disk Arbitration auf, Zugriff nur über den Henga-Ordner.
    ///
    /// Kein `mount_smbfs`-Kindprozess: der erbt die App Sandbox und kann das SMB-Gerät
    /// im Kernel nicht öffnen ("1025 failures to open smb device"). NetFS mountet
    /// sandbox-kompatibel in den Container (belegt am 13.10.2026 mit einer sandboxed Probe).
    public func mountVolume(url: URL, mountPoint: String, username: String, password: String?) async throws {
        guard let host = url.host else {
            throw SynoClientError.invalidHost
        }
        let share = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let fm = FileManager.default
        if !fm.fileExists(atPath: mountPoint) {
            try fm.createDirectory(atPath: mountPoint, withIntermediateDirectories: true)
        }
        
        // Zugangsdaten gehen getrennt an NetFS, nie in die URL
        var components = URLComponents()
        components.scheme = "smb"
        components.host = host
        components.user = username
        components.path = "/\(share)"
        guard let smbURL = components.url else {
            throw SynoClientError.invalidHost
        }
        
        print("[Henga] ⚙️ Führe unsichtbaren NetFS-Mount aus (MNT_DONTBROWSE): //\(username)@\(host)/\(share) -> \(mountPoint)")
        
        #if canImport(NetFS)
        let pw = (password?.isEmpty == false) ? password : nil
        let rc = await Task.detached(priority: .userInitiated) {
            DefaultMountExecutor.netFSMount(url: smbURL, mountPoint: mountPoint, username: username, password: pw)
        }.value
        
        if rc != 0 {
            let reason = DefaultMountExecutor.describeNetFSError(rc)
            print("[Henga] ❌ NetFS-Mount fehlgeschlagen (Code \(rc)): \(reason)")
            if let contents = try? fm.contentsOfDirectory(atPath: mountPoint), contents.isEmpty {
                try? fm.removeItem(atPath: mountPoint)
            }
            throw SynoClientError.networkError("Mount fehlgeschlagen (Code \(rc)): \(reason)")
        }
        print("[Henga] 🎉 Unsichtbarer Mount erfolgreich: \(mountPoint)")
        #else
        throw SynoClientError.networkError("Mount wird nur unter macOS unterstützt")
        #endif
    }
    
    #if canImport(NetFS)
    /// Blockierender NetFS-Aufruf; läuft deshalb in einem eigenen Task.
    private static func netFSMount(url: URL, mountPoint: String, username: String, password: String?) -> Int32 {
        let openOptions = NSMutableDictionary()
        // Keine System-Anmeldedialoge: Henga verwaltet die Zugangsdaten selbst
        openOptions[kNAUIOptionKey] = kNAUIOptionNoUI
        let mountOptions = NSMutableDictionary()
        mountOptions[kNetFSMountFlagsKey] = MNT_DONTBROWSE
        mountOptions[kNetFSMountAtMountDirKey] = true
        
        var mountPoints: Unmanaged<CFArray>?
        let rc = NetFSMountURLSync(
            url as CFURL,
            URL(fileURLWithPath: mountPoint, isDirectory: true) as CFURL,
            username as CFString,
            password as CFString?,
            openOptions,
            mountOptions,
            &mountPoints
        )
        mountPoints?.release()
        return rc
    }
    
    /// Übersetzt NetFS-Rückgaben (errno oder NetAuth-Codes) in eine lesbare Ursache
    static func describeNetFSError(_ rc: Int32) -> String {
        switch rc {
        case EAUTH:
            return "Anmeldung abgelehnt – Benutzername oder Passwort prüfen"
        case ENOENT:
            return "Freigabe auf dem Server nicht gefunden"
        case EHOSTUNREACH, ETIMEDOUT, ECONNREFUSED:
            return "Server nicht erreichbar"
        case EPERM, EACCES:
            return "Keine Berechtigung für diese Freigabe"
        case let code where code > 0:
            return String(cString: strerror(code))
        default:
            return "NetFS-Fehler"
        }
    }
    #endif
    
    /// Hängt das Volume über FileManager aus – ohne `/sbin/umount`-Kindprozess,
    /// der in der Sandbox dieselben Grenzen hätte wie `mount_smbfs`.
    public func unmountVolume(mountPoint: String, force: Bool = false) async throws {
        print("[Henga] ⚙️ Hänge aus: \(mountPoint) (Force: \(force))")
        
        #if os(macOS)
        let fm = FileManager.default
        do {
            try await fm.unmountVolume(at: URL(fileURLWithPath: mountPoint, isDirectory: true), options: [.withoutUI])
        } catch {
            // Erzwingen nur als zweiter Versuch, direkt per Systemaufruf
            if force, Darwin.unmount(mountPoint, MNT_FORCE) == 0 {
                print("[Henga] ⚠️ Aushängen erzwungen: \(mountPoint)")
            } else {
                print("[Henga] ❌ Aushängen fehlgeschlagen: \(error.localizedDescription)")
                throw SynoClientError.networkError("Aushängen fehlgeschlagen: \(error.localizedDescription)")
            }
        }
        
        if let contents = try? fm.contentsOfDirectory(atPath: mountPoint), contents.isEmpty {
            try? fm.removeItem(atPath: mountPoint)
            print("[Henga] 🧹 Leeren Mountpoint entfernt: \(mountPoint)")
        }
        #else
        throw SynoClientError.networkError("Aushängen wird nur unter macOS unterstützt")
        #endif
    }
}
