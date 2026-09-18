import Foundation
import Observation

@Observable
public final class MountAppStore: @unchecked Sendable {
    public var profiles: [ServerProfile] = []
    public var statuses: [UUID: ShareRuntimeStatus] = [:]
    public var isNetworkOnline: Bool = true
    public var lastSyncTime: Date?
    
    private let profileManager: ProfileManager
    private let mountManager: MountManager
    private let reachability: NetworkReachability
    private var isSyncing = false
    
    public init(
        profileManager: ProfileManager = .shared,
        mountManager: MountManager = .shared,
        reachability: NetworkReachability = .shared
    ) {
        self.profileManager = profileManager
        self.mountManager = mountManager
        self.reachability = reachability
        self.profiles = profileManager.getProfiles()
    }
    
    public func reloadProfiles() {
        self.profiles = profileManager.getProfiles()
    }
    
    public func saveProfile(_ profile: ServerProfile) {
        profileManager.addOrUpdateProfile(profile)
        reloadProfiles()
        Task {
            await syncMounts()
        }
    }
    
    public func deleteProfile(id: UUID) {
        profileManager.deleteProfile(id: id)
        reloadProfiles()
    }
    
    public func syncMounts() async {
        let shouldProceed = await MainActor.run { () -> Bool in
            if self.isSyncing { return false }
            self.isSyncing = true
            return true
        }
        guard shouldProceed else { return }
        
        defer {
            Task { @MainActor in
                self.isSyncing = false
            }
        }
        
        await mountManager.runAutoMountCycle(profiles: profiles)
        let all = await mountManager.getAllStatuses()
        let online = reachability.isConnected
        let now = Date()
        
        await MainActor.run {
            for st in all {
                self.statuses[st.share.id] = st
            }
            self.lastSyncTime = now
            self.isNetworkOnline = online
        }
    }
    
    public func mountShare(_ share: ShareMount, from profile: ServerProfile) async throws {
        try await mountManager.mount(share: share, profile: profile)
        if let st = await mountManager.getStatus(for: share.id) {
            await MainActor.run {
                self.statuses[share.id] = st
            }
        }
    }
    
    public func unmountShare(_ share: ShareMount, from profile: ServerProfile) async throws {
        try await mountManager.unmount(share: share, profileId: profile.id)
        if let st = await mountManager.getStatus(for: share.id) {
            await MainActor.run {
                self.statuses[share.id] = st
            }
        }
    }
}
