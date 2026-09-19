import Foundation
#if canImport(HengaCore)
import HengaCore
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
            window.orderFrontRegardless()
            return
        }
        
        let settingsView = SettingsView().environment(store)
        let hostingController = NSHostingController(rootView: settingsView)
        
        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 750, height: 520),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        win.center()
        win.title = "\(AppConfig.brandName) Einstellungen"
        win.contentViewController = hostingController
        win.isReleasedWhenClosed = false
        
        let wc = NSWindowController(window: win)
        self.windowController = wc
        
        NSApp.activate(ignoringOtherApps: true)
        win.makeKeyAndOrderFront(nil)
        win.orderFrontRegardless()
    }
}

@main
struct HengaApp: App {
    @State private var store = MountAppStore()
    
    var body: some Scene {
        MenuBarExtra {
            MenuBarContentView()
                .environment(store)
        } label: {
            HStack(spacing: 4) {
                // Lädt primär das Custom Template-Asset "MenuBarIcon" mit Fallback auf SF-Symbol
                if let nsImage = NSImage(named: "MenuBarIcon") {
                    Image(nsImage: nsImage)
                        .renderingMode(.template)
                } else {
                    Image(systemName: "link")
                        .renderingMode(.template)
                }
            }
        }
        .menuBarExtraStyle(.window)
    }
}
#else
@main
struct HengaAppStub {
    static func main() {
        print("\(AppConfig.brandName) Mac App Target (Linux-Build/CLI Stub)")
    }
}
#endif
