import Foundation
#if canImport(SynologyMountCore)
import SynologyMountCore
#endif

#if canImport(AppKit) && canImport(SwiftUI)
import SwiftUI
import AppKit

@MainActor
public final class SettingsWindowManager: NSObject, NSWindowDelegate {
    public static let shared = SettingsWindowManager()
    
    private var window: NSWindow?
    
    public func showSettings(store: MountAppStore) {
        if let existing = window, existing.isVisible {
            NSApp.activate(ignoringOtherApps: true)
            existing.makeKeyAndOrderFront(nil)
            existing.orderFrontRegardless()
            return
        }
        
        let settingsView = SettingsView().environment(store)
        let hostingController = NSHostingController(rootView: settingsView)
        
        let win = NSWindow(contentViewController: hostingController)
        win.title = "SynologyMount Einstellungen"
        win.setContentSize(NSSize(width: 760, height: 540))
        win.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        win.isReleasedWhenClosed = false
        win.delegate = self
        win.center()
        
        self.window = win
        
        NSApp.activate(ignoringOtherApps: true)
        win.makeKeyAndOrderFront(nil)
        win.orderFrontRegardless()
    }
    
    public func windowWillClose(_ notification: Notification) {
        // Fenster behalten für schnelles Wiederöffnen
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
