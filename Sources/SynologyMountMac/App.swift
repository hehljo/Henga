import Foundation
import SynologyMountCore

#if canImport(AppKit) && canImport(SwiftUI)
import SwiftUI
import AppKit

@main
struct SynologyMountApp: App {
    @State private var store = MountAppStore()
    
    var body: some Scene {
        MenuBarExtra {
            MenuBarContentView()
                .environment(store)
        } label: {
            HStack(spacing: 4) {
                Image(systemName: menuBarIconName)
            }
        }
        .menuBarExtraStyle(.window)
        
        Settings {
            SettingsView()
                .environment(store)
        }
    }
    
    private var menuBarIconName: String {
        let mountedCount = store.statuses.values.filter { $0.state == .mounted }.count
        let errorCount = store.statuses.values.filter { $0.state == .error }.count
        
        if errorCount > 0 {
            return "externaldrive.badge.xmark"
        } else if mountedCount > 0 {
            return "externaldrive.badge.checkmark"
        } else {
            return "externaldrive"
        }
    }
}
#else
@main
struct SynologyMountAppStub {
    static func main() {
        print("\(AppConfig.brandName) Mac App Target (Linux-Build/CLI Stub)")
    }
}
#endif
