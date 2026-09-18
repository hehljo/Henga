import Foundation

public struct ActiveMountInfo: Identifiable, Equatable, Sendable {
    public var id: String { mountPoint }
    public let serverURL: String       // z.B. "smb://diskstation.local/video"
    public let mountPoint: String      // z.B. "/Volumes/video"
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

#if os(macOS)
// Dynamisches Laden von NetFSMountURLSync via dlsym aus /System/Library/Frameworks/NetFS.framework/NetFS
private typealias NetFSMountFunc = @convention(c) (
    CFURL,
    CFURL?,
    CFString?,
    CFString?,
    CFMutableDictionary?,
    CFMutableDictionary?,
    UnsafeMutablePointer<Unmanaged<CFArray>?>?
) -> Int32

private func invokeNetFSMount(url: CFURL, user: CFString, pass: CFString, mountpoints: inout Unmanaged<CFArray>?) -> Int32? {
    guard let handle = dlopen("/System/Library/Frameworks/NetFS.framework/NetFS", RTLD_LAZY) else {
        return nil
    }
    defer { dlclose(handle) }
    
    guard let sym = dlsym(handle, "NetFSMountURLSync") else {
        return nil
    }
    
    // Unterdrücke das interaktive macOS-Authentifizierungs-Popup
    let openOptions = NSMutableDictionary()
    let mountOptions = NSMutableDictionary()
    mountOptions.setValue(kCFBooleanTrue, forKey: "UIOptionSuppress")
    
    let mountFunc = unsafeBitCast(sym, to: NetFSMountFunc.self)
    return mountFunc(url, nil, user, pass, openOptions as CFMutableDictionary, mountOptions as CFMutableDictionary, &mountpoints)
}
#endif

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
            print("[SynologyMount] ⚠️ Fehler beim Ausführen von /sbin/mount: \(error.localizedDescription)")
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
            
            // Format: //user@host/share on /Volumes/share (smbfs, nodev, nosuid, mounted by user)
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
    
    /// Mountet via Apple NetFS API (dynamisch) oder Fallback auf /sbin/mount_smbfs
    public func mountVolume(url: URL, mountPoint: String, username: String, password: String?) async throws {
        guard let host = url.host else {
            throw SynoClientError.invalidHost
        }
        let share = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        
        #if os(macOS)
        let smbUrlString = "smb://\(host)/\(share)"
        if let cfUrl = URL(string: smbUrlString) as CFURL? {
            print("[SynologyMount] 🍏 Führe Apple NetFS Mount aus: smb://\(username)@\(host)/\(share)...")
            let cfUser = username as CFString
            let cfPass = (password ?? "") as CFString
            var mountpoints: Unmanaged<CFArray>?
            
            if let status = invokeNetFSMount(url: cfUrl, user: cfUser, pass: cfPass, mountpoints: &mountpoints) {
                if status == 0 {
                    if let arrayRef = mountpoints?.takeRetainedValue() as? [String], let firstPath = arrayRef.first {
                        print("[SynologyMount] 🎉 NetFSMount erfolgreich! Gemountet unter: \(firstPath)")
                    } else {
                        print("[SynologyMount] 🎉 NetFSMount erfolgreich!")
                    }
                    return
                } else {
                    print("[SynologyMount] ⚠️ NetFSMount lieferte Status \(status). Verwende Fallback auf /sbin/mount_smbfs...")
                }
            } else {
                print("[SynologyMount] ℹ️ NetFS.framework nicht dynamisch ladbar, verwende /sbin/mount_smbfs...")
            }
        }
        #endif
        
        // Fallback: /sbin/mount_smbfs
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
        print("[SynologyMount] ⚙️ Fallback /sbin/mount_smbfs: //\(username):***@\(host)/\(share) -> \(mountPoint)")
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/sbin/mount_smbfs")
        process.arguments = [smbSource, mountPoint]
        
        let errPipe = Pipe()
        process.standardError = errPipe
        process.standardOutput = FileHandle.nullDevice
        
        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            print("[SynologyMount] ❌ mount_smbfs Prozessfehler: \(error.localizedDescription)")
            throw error
        }
        
        if process.terminationStatus != 0 {
            let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
            let errMsg = String(data: errData, encoding: .utf8) ?? "Unbekannter Fehler"
            let trimmedMsg = errMsg.trimmingCharacters(in: .whitespacesAndNewlines)
            print("[SynologyMount] ❌ mount_smbfs fehlgeschlagen (Code \(process.terminationStatus)): \(trimmedMsg)")
            try? fm.removeItem(atPath: mountPoint)
            throw SynoClientError.networkError("Mount fehlgeschlagen (Code \(process.terminationStatus)): \(trimmedMsg)")
        } else {
            print("[SynologyMount] 🎉 mount_smbfs erfolgreich beendet für \(mountPoint)")
        }
    }
    
    /// Hängt Volume via `/sbin/umount` aus
    public func unmountVolume(mountPoint: String, force: Bool = false) async throws {
        print("[SynologyMount] ⚙️ Führe /sbin/umount aus für: \(mountPoint) (Force: \(force))")
        
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
            print("[SynologyMount] ❌ umount Fehler: \(errMsg)")
            throw SynoClientError.networkError("umount fehlgeschlagen: \(errMsg)")
        }
        
        if mountPoint.hasPrefix("/Volumes/") {
            let fm = FileManager.default
            if let contents = try? fm.contentsOfDirectory(atPath: mountPoint), contents.isEmpty {
                try? fm.removeItem(atPath: mountPoint)
                print("[SynologyMount] 🧹 Leeren Mountpoint entfernt: \(mountPoint)")
            }
        }
    }
}
