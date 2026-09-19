import Foundation

public struct AppConfig: Sendable {
    public static let brandName = "Henga"
    public static let appVersion = "1.0.0"
    public static let defaultMountRoot = "/Volumes"
    public static let bundleIdentifier = "com.hehljo.Henga"
    public static let keychainService = "com.hehljo.Henga.keychain"
    public static let appSupportDirectoryName = "Henga"
    public static let defaultSMBPort = 445
    public static let defaultDSMPort = 5001
    public static let pingTimeoutSeconds: TimeInterval = 2.0
}
