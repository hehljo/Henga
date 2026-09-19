import Foundation

public struct SynoApiResponse<T: Codable & Sendable>: Codable, Sendable {
    public let success: Bool
    public let data: T?
    public let error: SynoApiErrorPayload?
}

public struct SynoApiErrorPayload: Codable, Sendable {
    public let code: Int
    public let errors: SynoErrorDetail?
}

public struct SynoErrorDetail: Codable, Sendable {
    public let token: String?
    public let types: [SynoErrorType]?
}

public struct SynoErrorType: Codable, Sendable {
    public let type: String?
}

public struct SynoAuthResponse: Codable, Sendable {
    public let sid: String
    public let synotoken: String?
    public let did: String?
    public let deviceId: String?
    
    enum CodingKeys: String, CodingKey {
        case sid
        case synotoken
        case did
        case deviceId = "device_id"
    }
}

public struct SynoSharedFoldersData: Codable, Sendable {
    public let shares: [SynoFolderEntry]
    public let total: Int
}

public struct SynoFolderEntry: Codable, Sendable {
    public let isdir: Bool
    public let name: String
    public let path: String
}
