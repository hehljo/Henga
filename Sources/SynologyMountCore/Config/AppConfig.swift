import Foundation

public enum AppConfig {
    public static let brandName = "SynologyMount"
    public static let appVersion = "1.0.0"
    public static let bundleIdentifier = "de.condriano.SynologyMount"
    public static let keychainService = "de.condriano.SynologyMount.keychain"
    
    // Default Mount Options
    public static let defaultMountRoot = "/Volumes"
    public static let reconnectIntervalSeconds: TimeInterval = 15.0
    public static let pingTimeoutSeconds: TimeInterval = 3.0
}
