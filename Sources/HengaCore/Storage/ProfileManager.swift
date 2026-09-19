import Foundation

public final class ProfileManager: @unchecked Sendable {
    public static let shared = ProfileManager()
    
    private let storageURL: URL
    private let lock = NSLock()
    private var cachedProfiles: [ServerProfile] = []
    
    public init(customStorageURL: URL? = nil) {
        if let url = customStorageURL {
            self.storageURL = url
        } else {
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? URL(fileURLWithPath: NSTemporaryDirectory())
            let dir = appSupport.appendingPathComponent(AppConfig.brandName, isDirectory: true)
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            self.storageURL = dir.appendingPathComponent("profiles.json")
        }
        loadProfiles()
    }
    
    public func getProfiles() -> [ServerProfile] {
        lock.lock()
        defer { lock.unlock() }
        return cachedProfiles
    }
    
    public func saveProfiles(_ profiles: [ServerProfile]) {
        lock.lock()
        defer { lock.unlock() }
        cachedProfiles = profiles
        if let data = try? JSONEncoder().encode(profiles) {
            try? data.write(to: storageURL, options: .atomic)
        }
    }
    
    public func addOrUpdateProfile(_ profile: ServerProfile) {
        lock.lock()
        defer { lock.unlock() }
        if let idx = cachedProfiles.firstIndex(where: { $0.id == profile.id }) {
            cachedProfiles[idx] = profile
        } else {
            cachedProfiles.append(profile)
        }
        if let data = try? JSONEncoder().encode(cachedProfiles) {
            try? data.write(to: storageURL, options: .atomic)
        }
    }
    
    public func deleteProfile(id: UUID) {
        lock.lock()
        defer { lock.unlock() }
        cachedProfiles.removeAll(where: { $0.id == id })
        if let data = try? JSONEncoder().encode(cachedProfiles) {
            try? data.write(to: storageURL, options: .atomic)
        }
    }
    
    private func loadProfiles() {
        guard let data = try? Data(contentsOf: storageURL),
              let loaded = try? JSONDecoder().decode([ServerProfile].self, from: data) else {
            cachedProfiles = []
            return
        }
        cachedProfiles = loaded
    }
}
