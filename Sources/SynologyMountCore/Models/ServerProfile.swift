import Foundation

public struct ServerProfile: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var name: String                // z.B. "DiskStation Heimnetz"
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
    
    /// Bereinigt Hostnamen von führenden Protokoll-Angaben ("smb://", "http://", etc.)
    public var cleanHost: String {
        var h = host.trimmingCharacters(in: .whitespacesAndNewlines)
        if h.hasPrefix("smb://") { h = String(h.dropFirst(6)) }
        if h.hasPrefix("http://") { h = String(h.dropFirst(7)) }
        if h.hasPrefix("https://") { h = String(h.dropFirst(8)) }
        if let slashIdx = h.firstIndex(of: "/") {
            h = String(h[..<slashIdx])
        }
        if let colonIdx = h.firstIndex(of: ":") {
            h = String(h[..<colonIdx])
        }
        return h
    }
    
    /// Erstellt eine saubere SMB-URL für eine bestimmte Freigabe
    public func smbURL(for share: ShareMount) -> URL? {
        let ch = cleanHost
        guard !ch.isEmpty else { return nil }
        let sharePath = share.cleanRemotePath
        guard !sharePath.isEmpty else { return nil }
        
        let portPart = (smbPort == 445) ? "" : ":\(smbPort)"
        let rawUrl = "smb://\(ch)\(portPart)/\(sharePath)"
        return URL(string: rawUrl)
    }
    
    /// Basis-URL für DSM FileStation API Aufrufe
    public var dsmBaseURL: URL? {
        let ch = cleanHost
        guard !ch.isEmpty else { return nil }
        let proto = useHTTPSForDSM ? "https" : "http"
        return URL(string: "\(proto)://\(ch):\(dsmPort)/webapi")
    }
}
