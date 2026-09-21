#if canImport(AppKit) && canImport(SwiftUI)
import SwiftUI
import AppKit
#if canImport(HengaCore)
import HengaCore
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
        .padding(14)
        .frame(width: 340)
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
            VStack(spacing: 8) {
                ForEach(store.profiles) { profile in
                    serverRow(profile: profile)
                }
            }
        }
    }
    
    @ViewBuilder
    private func serverRow(profile: ServerProfile) -> some View {
        let autoShares = profile.shares.filter { $0.autoMount }
        // Fallback: Wenn keine Shares auf Auto stehen, nimm alle konfigurierten Shares des Profils
        let relevantShares = autoShares.isEmpty ? profile.shares : autoShares
        
        let mountedCount = relevantShares.filter { store.statuses[$0.id]?.state == .mounted }.count
        let allMounted = !relevantShares.isEmpty && mountedCount == relevantShares.count
        let partiallyMounted = mountedCount > 0 && !allMounted
        
        HStack(spacing: 10) {
            // Status-Punkt
            Circle()
                .fill(allMounted ? Color.green : (partiallyMounted ? Color.orange : Color.gray))
                .frame(width: 10, height: 10)
                .help(allMounted ? "\(mountedCount)/\(relevantShares.count) Freigaben verbunden" : (partiallyMounted ? "\(mountedCount)/\(relevantShares.count) Freigaben verbunden" : "Getrennt"))
            
            VStack(alignment: .leading, spacing: 2) {
                Text(profile.effectiveHubName)
                    .font(.system(size: 13, weight: .bold))
                
                Text("\(mountedCount) von \(relevantShares.count) Freigaben aktiv")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // 1. Finder-Hub öffnen
            Button {
                FinderSidebarHelper.shared.openInFinder(for: profile)
            } label: {
                Image(systemName: "folder")
                    .font(.system(size: 14))
            }
            .buttonStyle(.borderless)
            .help("Im Finder öffnen (Hub-Ordner)")
            .accessibilityLabel("Ordner im Finder öffnen")
            
            // 2. Ausgewählte Freigaben verbinden
            Button {
                mountSelected(for: profile)
            } label: {
                Image(systemName: allMounted ? "checkmark.circle.fill" : "play.circle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(allMounted ? .green : .accentColor)
            }
            .buttonStyle(.borderless)
            .help("Freigaben dieses Servers verbinden")
            .accessibilityLabel("Verbinden")
            
            // 3. Freigaben dieses Servers trennen
            Button {
                unmountAll(for: profile)
            } label: {
                Image(systemName: "eject.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.borderless)
            .help("Alle Freigaben dieses Servers trennen")
            .accessibilityLabel("Trennen")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.6))
        .cornerRadius(8)
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
            .accessibilityLabel("Aktualisieren")
            
            Button(String(localized: "menu_quit", defaultValue: "Beenden")) {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .help("Henga beenden")
        }
    }
    
    private func openSettingsWindow() {
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
            let auto = profile.shares.filter { $0.autoMount }
            let targets = auto.isEmpty ? profile.shares : auto
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
