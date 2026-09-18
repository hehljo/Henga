#if canImport(AppKit) && canImport(SwiftUI)
import SwiftUI
import AppKit
#if canImport(SynologyMountCore)
import SynologyMountCore
#endif

struct MenuBarContentView: View {
    @Environment(MountAppStore.self) private var store
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            headerSection
            Divider()
            serversSection
            Divider()
            actionsSection
        }
        .padding(12)
        .frame(width: 320)
        .onAppear {
            store.reloadProfiles()
            Task {
                await store.syncMounts()
                updateAllFinderLinks()
            }
        }
    }
    
    @ViewBuilder
    private var headerSection: some View {
        HStack {
            Text(AppConfig.brandName)
                .font(.headline)
                .fontWeight(.bold)
            Spacer()
            Circle()
                .fill(store.isNetworkOnline ? Color.green : Color.red)
                .frame(width: 8, height: 8)
                .help(store.isNetworkOnline ? "Netzwerk verbunden" : "Netzwerk offline")
        }
    }
    
    @ViewBuilder
    private var serversSection: some View {
        if store.profiles.isEmpty {
            VStack(spacing: 8) {
                Text(String(localized: "lbl_no_shares", defaultValue: "Keine Server konfiguriert"))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Button(String(localized: "btn_add_server", defaultValue: "Server konfigurieren")) {
                    openSettingsWindow()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .help("Öffnet die Einstellungen zum Anlegen eines neuen NAS-Servers")
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 10)
        } else {
            ScrollView(.vertical) {
                VStack(spacing: 6) {
                    ForEach(store.profiles) { profile in
                        serverRow(profile: profile)
                    }
                }
            }
            .frame(maxHeight: 260)
        }
    }
    
    @ViewBuilder
    private func serverRow(profile: ServerProfile) -> some View {
        let autoShares = profile.shares.filter { $0.autoMount }
        let mountedCount = autoShares.filter { store.statuses[$0.id]?.state == .mounted }.count
        let allMounted = !autoShares.isEmpty && mountedCount == autoShares.count
        let partiallyMounted = mountedCount > 0 && !allMounted
        
        HStack(spacing: 8) {
            // Status-Punkt pro Server
            Circle()
                .fill(allMounted ? Color.green : (partiallyMounted ? Color.orange : Color.gray))
                .frame(width: 8, height: 8)
                .help(allMounted ? "\(mountedCount)/\(autoShares.count) Freigaben verbunden" : (partiallyMounted ? "\(mountedCount)/\(autoShares.count) Freigaben verbunden" : "Getrennt"))
            
            VStack(alignment: .leading, spacing: 1) {
                Text(profile.effectiveHubName)
                    .font(.system(size: 13, weight: .semibold))
                
                Text(autoShares.isEmpty ? "Keine Auto-Mounts" : "\(mountedCount) von \(autoShares.count) aktiv")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // 1. Finder-Hub öffnen
            Button {
                FinderSidebarHelper.shared.openInFinder(for: profile)
            } label: {
                Image(systemName: "folder")
            }
            .buttonStyle(.borderless)
            .help("Im Finder öffnen (Hub-Ordner)")
            
            // 2. Ausgewählte Auto-Mounts verbinden
            Button {
                mountSelected(for: profile)
            } label: {
                Image(systemName: allMounted ? "checkmark.circle.fill" : "play.circle.fill")
                    .foregroundColor(allMounted ? .green : .accentColor)
            }
            .buttonStyle(.borderless)
            .help("Ausgewählte Freigaben verbinden (Auto-Mounts)")
            
            // 3. Freigaben dieses Servers trennen
            Button {
                unmountAll(for: profile)
            } label: {
                Image(systemName: "eject.fill")
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.borderless)
            .help("Alle Freigaben dieses Servers trennen")
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
        .cornerRadius(6)
    }
    
    @ViewBuilder
    private var actionsSection: some View {
        HStack {
            Button(String(localized: "menu_settings", defaultValue: "Einstellungen…")) {
                openSettingsWindow()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .help("Öffnet das Einstellungsfenster")
            
            Spacer()
            
            Button {
                store.reloadProfiles()
                Task {
                    await store.syncMounts()
                    updateAllFinderLinks()
                }
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .help("Status aller Server und Freigaben aktualisieren")
            
            Button(String(localized: "menu_quit", defaultValue: "Beenden")) {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .help("SynologyMount beenden")
        }
    }
    
    private func openSettingsWindow() {
        // Schließe das schwebende MenuBar-Popup-Fenster, wenn Einstellungen geöffnet werden
        for window in NSApp.windows {
            if let className = Optional(String(describing: type(of: window))),
               className.contains("MenuBarExtra") || className.contains("Panel") {
                window.orderOut(nil)
            }
        }
        
        SettingsWindowManager.shared.showSettings(store: store)
    }
    
    private func updateAllFinderLinks() {
        for profile in store.profiles {
            var active: [(name: String, path: String)] = []
            for share in profile.shares {
                if store.statuses[share.id]?.state == .mounted {
                    let path = MountPointSanitizer.resolveMountPoint(for: share)
                    active.append((name: share.name, path: path))
                }
            }
            FinderSidebarHelper.shared.updateFinderLinks(for: profile, activeShares: active)
        }
    }
    
    private func mountSelected(for profile: ServerProfile) {
        Task {
            let targets = profile.shares.filter { $0.autoMount }
            for share in targets {
                try? await store.mountShare(share, from: profile)
            }
            updateAllFinderLinks()
        }
    }
    
    private func unmountAll(for profile: ServerProfile) {
        Task {
            for share in profile.shares {
                try? await store.unmountShare(share, from: profile)
            }
            updateAllFinderLinks()
        }
    }
}
#endif
