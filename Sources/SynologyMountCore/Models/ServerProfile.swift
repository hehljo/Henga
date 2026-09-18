import Foundation

public struct ServerProfile: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var name: String                // z.B. "DiskStation Heimnetz"
    public var hubFolderName: String?      // Frei wählbarer Name für den Finder-Hub (Standard: name)
    public var showInFinderSidebar: Bool   // Direkt in Finder-Seitenleiste (Favoriten) eintragen?
    public var host: String                // z.B. "diskstation.local" oder "192.168.178.50"
    public var smbPort: Int                // Standard: 445
    public var dsmPort: Int                // Standard: 5001 (HTTPS) oder 5000 (HTTP)
    public var useHTTPSForDSM: Bool        // true für Port 5001
    public var username: String            // SMB & DSM Benutzer
    public var shares: [ShareMount]        // Konfigurierte Freigaben
    public var isEnabled: Bool             // Profil aktiv?
    public var wakeOnLanMAC: String?       // Optional: MAC-Adresse für WOL
    public var deviceID: String?           // Gespeicherter 2FA did Token (Gerät merken)
    public var deviceName: String          // Name dieses Macs bei DSM
    
    public init(
        id: UUID = UUID(),
        name: String,
        hubFolderName: String? = nil,
        showInFinderSidebar: Bool = true,
        host: String,
        smbPort: Int = 445,
        dsmPort: Int = 5001,
        useHTTPSForDSM: Bool = true,
        username: String,
        shares: [ShareMount] = [],
        isEnabled: Bool = true,
        wakeOnLanMAC: String? = nil,
        deviceID: String? = nil,
        deviceName: String = "SynologyMount Mac"
    ) {
        self.id = id
        self.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        self.hubFolderName = hubFolderName?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.showInFinderSidebar = showInFinderSidebar
        self.host = host.trimmingCharacters(in: .whitespacesAndNewlines)
        self.smbPort = smbPort
        self.dsmPort = dsmPort
        self.useHTTPSForDSM = useHTTPSForDSM
        self.username = username.trimmingCharacters(in: .whitespacesAndNewlines)
        self.shares = shares
        self.isEnabled = isEnabled
        self.wakeOnLanMAC = wakeOnLanMAC
        self.deviceID = deviceID
        self.deviceName = deviceName
    }
    
    /// Gibt den effektiven Ordnernamen für den Finder-Hub zurück
    public var effectiveHubName: String {
        if let custom = hubFolderName, !custom.isEmpty {
            return custom
        }
        return name.isEmpty ? AppConfig.brandName : name
    }
    
    /// Bereinigt Hostnamen von führenden Protokoll-Angaben ("smb://", "http://", etc.)
    public var cleanHost: String {
        var h = host.trimmingCharacters(in: .whitespacesAndNewlines)
        if h.hasPrefix("smb://") { h = String(h.dropFirst(6)) }
        if h.hasPrefix("http://") { h = String(h.dropFirst(7)) }
        if h.hasPrefix("https://") { h = String(h.dropFirst(8)) }
        if let idx = h.firstIndex(of: ":") {
            h = String(h[..<idx])
        }
        return h.trimmingCharacters(in: CharacterSet(charactersIn: "/ "))
    }
    
    /// Liefert die Basis-URL für DSM WebAPI Anfragen
    public var dsmBaseURL: URL? {
        let ch = cleanHost
        guard !ch.isEmpty else { return nil }
        let scheme = useHTTPSForDSM ? "https" : "http"
        return URL(string: "\(scheme)://\(ch):\(dsmPort)/webapi/")
    }
    
    /// Liefert die SMB-URL für eine bestimmte Freigabe
    public func smbURL(for share: ShareMount) -> URL? {
        let ch = cleanHost
        guard !ch.isEmpty else { return nil }
        let sharePath = share.cleanRemotePath
        guard !sharePath.isEmpty else { return nil }
        
        var comp = URLComponents()
        comp.scheme = "smb"
        comp.host = ch
        if smbPort != 445 {
            comp.port = smbPort
        }
        comp.path = "/\(sharePath)"
        return comp.url
    }
}
