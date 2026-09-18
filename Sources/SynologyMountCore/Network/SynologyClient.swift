import Foundation

public enum SynoClientError: Error, LocalizedError, Equatable {
    case invalidHost
    case networkError(String)
    case serverError(Int)
    case twoFactorRequired
    case invalidTwoFactorCode
    case unauthenticated
    case decodingError
    
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
        case .serverError(let code):
            switch code {
            case 400: return "Ungültiger Benutzername oder Passwort (400)"
            case 403: return "2-Faktor-Authentifizierung (2FA) aktiv: Bitte 6-stelligen OTP-Code eingeben (403)"
            case 404: return "Ungültiger 2FA / OTP Code. Bitte Code prüfen (404)"
            default: return "Synology Fehlercode: \(code)"
            }
        case .unauthenticated:
            return "Authentifizierung fehlgeschlagen."
        case .decodingError:
            return "Antwort konnte nicht verarbeitet werden."
        }
    }
}

public actor SynologyClient {
    private var profile: ServerProfile
    private var sid: String?
    private let session: URLSession
    private let sessionDelegate: SynologySessionDelegate
    
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
        
        // Gespeicherten Token (did) mitsenden falls vorhanden
        if let savedDid = profile.deviceID, !savedDid.isEmpty {
            queryItems.append(URLQueryItem(name: "device_id", value: savedDid))
        } else if let otp = otpCode?.trimmingCharacters(in: .whitespacesAndNewlines), !otp.isEmpty {
            queryItems.append(URLQueryItem(name: "otp_code", value: otp))
        }
        
        var comp = URLComponents(url: baseURL.appendingPathComponent("auth.cgi"), resolvingAgainstBaseURL: false)
        comp?.queryItems = queryItems
        
        guard let url = comp?.url else {
            throw SynoClientError.invalidHost
        }
        
        let (data, response) = try await session.data(from: url)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw SynoClientError.networkError("HTTP Status ungültig")
        }
        
        let apiResp = try JSONDecoder().decode(SynoApiResponse<SynoAuthResponse>.self, from: data)
        guard apiResp.success, let authData = apiResp.data else {
            let code = apiResp.error?.code ?? -1
            if code == 403 {
                throw SynoClientError.twoFactorRequired
            } else if code == 404 {
                throw SynoClientError.invalidTwoFactorCode
            }
            throw SynoClientError.serverError(code)
        }
        
        self.sid = authData.sid
        let did = authData.did ?? authData.deviceId
        if let token = did, !token.isEmpty {
            self.profile.deviceID = token
        }
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
        
        let queryItems = [
            URLQueryItem(name: "api", value: "SYNO.FileStation.List"),
            URLQueryItem(name: "version", value: "2"),
            URLQueryItem(name: "method", value: "list_share"),
            URLQueryItem(name: "_sid", value: currentSid)
        ]
        
        var comp = URLComponents(url: baseURL.appendingPathComponent("entry.cgi"), resolvingAgainstBaseURL: false)
        comp?.queryItems = queryItems
        
        guard let url = comp?.url else {
            throw SynoClientError.invalidHost
        }
        
        let (data, _) = try await session.data(from: url)
        let apiResp = try JSONDecoder().decode(SynoApiResponse<SynoSharedFoldersData>.self, from: data)
        
        guard apiResp.success, let shareData = apiResp.data else {
            let code = apiResp.error?.code ?? -1
            throw SynoClientError.serverError(code)
        }
        
        return shareData.shares.map {
            SynoSharedFolder(name: $0.name, path: $0.path, isDir: $0.isdir)
        }
    }
}
