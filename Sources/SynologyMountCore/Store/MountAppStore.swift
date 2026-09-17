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
    private var timer: Timer?
    
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
        await mountManager.runAutoMountCycle(profiles: profiles)
        let all = await mountManager.getAllStatuses()
        await MainActor.run {
            for st in all {
                self.statuses[st.share.id] = st
            }
            self.lastSyncTime = Date()
            self.isNetworkOnline = self.reachability.isConnected
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
