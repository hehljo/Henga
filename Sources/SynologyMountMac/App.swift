import Foundation
#if canImport(SynologyMountCore)
import SynologyMountCore
#endif

#if canImport(AppKit) && canImport(SwiftUI)
import SwiftUI
import AppKit

@MainActor
public final class SettingsWindowManager: ObservableObject {
    public static let shared = SettingsWindowManager()
    
    private var windowController: NSWindowController?
    
    public func showSettings(store: MountAppStore) {
        if let wc = windowController, let window = wc.window {
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
            return
        }
        
        let settingsView = SettingsView().environment(store)
        let hostingController = NSHostingController(rootView: settingsView)
        
        let window = NSWindow(contentViewController: hostingController)
        window.title = "SynologyMount Einstellungen"
        window.setContentSize(NSSize(width: 740, height: 500))
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.center()
        window.isReleasedWhenClosed = false
        
        let wc = NSWindowController(window: window)
        self.windowController = wc
        
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }
}

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
