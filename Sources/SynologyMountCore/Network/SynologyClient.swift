import Foundation

public enum SynoClientError: Error, LocalizedError, Equatable {
    case invalidHost
    case networkError(String)
    case serverError(Int, String?)
    case twoFactorRequired
    case invalidTwoFactorCode
    case unauthenticated
    case decodingError(String)
    
    public var errorDescription: String? {
        switch self {
        case .invalidHost:
            return "Ungültige NAS-Adresse."
        case .networkError(let msg):
            return "Netzwerkfehler: \(msg)"
        case .twoFactorRequired:
            return "2-Faktor-Authentifizierung (2FA) erforderlich. Bitte 6-stelligen OTP Code eingeben (403)."
        case .invalidTwoFactorCode:
            return "Ungültiger 2FA / OTP Code. Bitte Code prüfen (404)."
        case .serverError(let code, let msg):
            let detail = msg != nil ? " - \(msg!)" : ""
            switch code {
            case 400: return "Ungültiger Benutzername oder Passwort (400)\(detail)"
            case 403: return "2-Faktor-Authentifizierung (2FA) aktiv: Bitte 6-stelligen OTP-Code eingeben (403)\(detail)"
            case 404: return "Ungültiger 2FA / OTP Code. Bitte Code prüfen (404)\(detail)"
            default: return "Synology Fehlercode \(code)\(detail)"
            }
        case .unauthenticated:
            return "Authentifizierung fehlgeschlagen."
        case .decodingError(let raw):
            return "Antwortformat unerwartet: \(raw)"
        }
    }
}

public struct SynoApiInfoResult: Codable, Sendable {
    public let path: String
    public let minVersion: Int
    public let maxVersion: Int
    public let requestFormat: String?
}

public actor SynologyClient {
    private var profile: ServerProfile
    private var sid: String?
    private let session: URLSession
    private let sessionDelegate: SynologySessionDelegate
    private var apiInfoCache: [String: SynoApiInfoResult] = [:]
    
    public init(profile: ServerProfile) {
        self.profile = profile
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10.0
        config.timeoutIntervalForResource = 15.0
        
        let delegate = SynologySessionDelegate(allowSelfSigned: true)
        self.sessionDelegate = delegate
        #if os(macOS)
        self.session = URLSession(configuration: config, delegate: delegate, delegateQueue: nil)
        #else
        self.session = URLSession(configuration: config)
        #endif
    }
    
    /// Ruft SYNO.API.Info ab (Meta-Discovery laut Guideline)
    public func discoverApis(query: String = "SYNO.FileStation,SYNO.API.Auth") async -> [String: SynoApiInfoResult] {
        guard let baseURL = profile.dsmBaseURL else { return [:] }
        var comp = URLComponents(url: baseURL.appendingPathComponent("query.cgi"), resolvingAgainstBaseURL: false)
        comp?.queryItems = [
            URLQueryItem(name: "api", value: "SYNO.API.Info"),
            URLQueryItem(name: "version", value: "1"),
            URLQueryItem(name: "method", value: "query"),
            URLQueryItem(name: "query", value: query)
        ]
        guard let url = comp?.url else { return [:] }
        
        print("[SynologyMount] 🔍 Sende SYNO.API.Info Discovery an: \(url)")
        guard let (data, _) = try? await session.data(from: url) else {
            print("[SynologyMount] ⚠️ SYNO.API.Info Anfrage fehlgeschlagen (Netzwerk/Timeout)")
            return [:]
        }
        
        let rawStr = String(data: data, encoding: .utf8) ?? ""
        print("[SynologyMount] 📥 SYNO.API.Info Antwort: \(rawStr.prefix(200))")
        
        struct InfoResponse: Codable {
            let success: Bool
            let data: [String: SynoApiInfoResult]?
        }
        
        if let decoded = try? JSONDecoder().decode(InfoResponse.self, from: data), decoded.success, let map = decoded.data {
            self.apiInfoCache = map
            return map
        }
        return [:]
    }
    
    /// Login bei Synology DSM WebAPI mit 2FA/OTP- und "Gerät merken" (did) Unterstützung
    public func login(password: String, otpCode: String? = nil, rememberDevice: Bool = true) async throws -> (sid: String, did: String?) {
        guard let baseURL = profile.dsmBaseURL else {
            throw SynoClientError.invalidHost
        }
        
        var queryItems = [
            URLQueryItem(name: "api", value: "SYNO.API.Auth"),
            URLQueryItem(name: "version", value: "3"),
            URLQueryItem(name: "method", value: "login"),
            URLQueryItem(name: "account", value: profile.username),
            URLQueryItem(name: "passwd", value: password),
            URLQueryItem(name: "session", value: "FileStation"),
            URLQueryItem(name: "format", value: "sid"),
            URLQueryItem(name: "device_name", value: profile.deviceName)
        ]
        
        if let savedDid = profile.deviceID, !savedDid.isEmpty {
            queryItems.append(URLQueryItem(name: "device_id", value: savedDid))
            print("[SynologyMount] 🔑 Verwende gespeicherten 2FA-Geräte-Token (did) – kein OTP nötig.")
        } else if let otp = otpCode?.trimmingCharacters(in: .whitespacesAndNewlines), !otp.isEmpty {
            queryItems.append(URLQueryItem(name: "otp_code", value: otp))
            print("[SynologyMount] 🔢 Sende OTP Code für 2FA...")
        }
        
        var comp = URLComponents(url: baseURL.appendingPathComponent("auth.cgi"), resolvingAgainstBaseURL: false)
        comp?.queryItems = queryItems
        
        guard let url = comp?.url else {
            throw SynoClientError.invalidHost
        }
        
        print("[SynologyMount] 🔐 Sende Login-Anfrage an \(baseURL) (User: \(profile.username), 2FA-Token: \(profile.deviceID != nil ? "Ja" : "Nein"))...")
        
        let (data, response) = try await session.data(from: url)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw SynoClientError.networkError("HTTP Status ungültig")
        }
        
        let rawStr = String(data: data, encoding: .utf8) ?? ""
        print("[SynologyMount] 📥 Login-Antwort: \(rawStr)")
        
        let apiResp: SynoApiResponse<SynoAuthResponse>
        do {
            apiResp = try JSONDecoder().decode(SynoApiResponse<SynoAuthResponse>.self, from: data)
        } catch {
            print("[SynologyMount] ❌ JSON-Decode Fehler beim Login: \(rawStr)")
            throw SynoClientError.decodingError("Login-Antwort: \(rawStr)")
        }
        
        guard apiResp.success, let authData = apiResp.data else {
            let code = apiResp.error?.code ?? -1
            print("[SynologyMount] ⚠️ Login schlug fehl mit Synology Fehlercode: \(code)")
            if code == 403 {
                throw SynoClientError.twoFactorRequired
            } else if code == 404 {
                throw SynoClientError.invalidTwoFactorCode
            }
            throw SynoClientError.serverError(code, nil)
        }
        
        self.sid = authData.sid
        let did = authData.did ?? authData.deviceId
        if let token = did, !token.isEmpty {
            self.profile.deviceID = token
            print("[SynologyMount] 🏷️ 2FA-Gerätetoken (did) erhalten und gespeichert.")
        }
        print("[SynologyMount] ✅ Login erfolgreich! Session ID erhalten.")
        return (authData.sid, did)
    }
    
    /// Holt Liste aller freigegebenen gemeinsamen Ordner (Shared Folders)
    public func listSharedFolders() async throws -> [SynoSharedFolder] {
        guard let baseURL = profile.dsmBaseURL else {
            throw SynoClientError.invalidHost
        }
        guard let currentSid = self.sid else {
            throw SynoClientError.unauthenticated
        }
        
        if apiInfoCache.isEmpty {
            _ = await discoverApis(query: "SYNO.FileStation.List")
        }
        
        let targetVersion = String(apiInfoCache["SYNO.FileStation.List"]?.maxVersion ?? 2)
        let cgiPath = apiInfoCache["SYNO.FileStation.List"]?.path ?? "entry.cgi"
        
        let queryItems = [
            URLQueryItem(name: "api", value: "SYNO.FileStation.List"),
            URLQueryItem(name: "version", value: targetVersion),
            URLQueryItem(name: "method", value: "list_share"),
            URLQueryItem(name: "_sid", value: currentSid)
        ]
        
        var comp = URLComponents(url: baseURL.appendingPathComponent(cgiPath), resolvingAgainstBaseURL: false)
        comp?.queryItems = queryItems
        
        guard let url = comp?.url else {
            throw SynoClientError.invalidHost
        }
        
        print("[SynologyMount] 📡 Rufe Freigaben ab via \(url)...")
        let (data, _) = try await session.data(from: url)
        let rawStr = String(data: data, encoding: .utf8) ?? ""
        print("[SynologyMount] 📥 list_share Antwort: \(rawStr.prefix(300))")
        
        // Variante A: { "data": { "shares": [ ... ] } }
        if let apiResp = try? JSONDecoder().decode(SynoApiResponse<SynoSharedFoldersData>.self, from: data),
           apiResp.success, let shareData = apiResp.data {
            print("[SynologyMount] ✅ \(shareData.shares.count) Freigaben gefunden (Format A)!")
            return shareData.shares.map {
                SynoSharedFolder(name: $0.name, path: $0.path, isDir: $0.isdir)
            }
        }
        
        // Variante B: { "data": [ { "name": "...", "path": "..." } ] }
        struct DirectListResponse: Codable {
            let success: Bool
            let data: [SynoFolderEntry]?
            let error: SynoApiErrorPayload?
        }
        if let directResp = try? JSONDecoder().decode(DirectListResponse.self, from: data),
           directResp.success, let entries = directResp.data {
            print("[SynologyMount] ✅ \(entries.count) Freigaben gefunden (Format B)!")
            return entries.map {
                SynoSharedFolder(name: $0.name, path: $0.path, isDir: $0.isdir)
            }
        }
        
        struct GenericErrorResp: Codable {
            let success: Bool
            let error: SynoApiErrorPayload?
        }
        if let errResp = try? JSONDecoder().decode(GenericErrorResp.self, from: data), !errResp.success {
            let code = errResp.error?.code ?? -1
            print("[SynologyMount] ❌ Fehler von FileStation.list_share: \(code)")
            throw SynoClientError.serverError(code, "FileStation list_share")
        }
        
        print("[SynologyMount] ❌ Unbekannte Antwortstruktur: \(rawStr)")
        throw SynoClientError.decodingError(rawStr)
    }
}
