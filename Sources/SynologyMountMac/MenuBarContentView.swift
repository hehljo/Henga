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
            serversAndSharesSection
            Divider()
            actionsSection
        }
        .padding(14)
        .frame(width: 360)
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
        }
    }
    
    @ViewBuilder
    private var serversAndSharesSection: some View {
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
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 10)
        } else {
            ScrollView(.vertical) {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(store.profiles) { profile in
                        serverBlock(profile: profile)
                    }
                }
            }
            .frame(maxHeight: 320)
        }
    }
    
    @ViewBuilder
    private func serverBlock(profile: ServerProfile) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            // Header pro Server / Hub mit direktem Verbinden / Trennen
            HStack(spacing: 6) {
                Image(systemName: "server.rack")
                    .foregroundColor(profile.isEnabled ? .accentColor : .secondary)
                
                Text(profile.effectiveHubName)
                    .font(.system(size: 13, weight: .bold))
                
                Spacer()
                
                Button {
                    FinderSidebarHelper.shared.openInFinder(for: profile)
                } label: {
                    Image(systemName: "folder")
                }
                .buttonStyle(.borderless)
                .help(String(localized: "open_in_finder", defaultValue: "Im Finder öffnen"))
                
                Button {
                    mountSelected(for: profile)
                } label: {
                    Image(systemName: "play.circle")
                        .foregroundColor(.green)
                }
                .buttonStyle(.borderless)
                .help("Ausgewählte Freigaben verbinden")
                
                Button {
                    unmountAll(for: profile)
                } label: {
                    Image(systemName: "eject")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.borderless)
                .help("Alle Freigaben dieses Servers trennen")
            }
            .padding(.horizontal, 4)
            
            // Liste der Shares für diesen Server
            if profile.shares.isEmpty {
                Text("Keine Freigaben eingerichtet.")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(.leading, 8)
            } else {
                VStack(spacing: 4) {
                    ForEach(profile.shares) { share in
                        shareRow(profile: profile, share: share)
                    }
                }
                .padding(.leading, 8)
            }
        }
        .padding(8)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.4))
        .cornerRadius(8)
    }
    
    @ViewBuilder
    private func shareRow(profile: ServerProfile, share: ShareMount) -> some View {
        let status = store.statuses[share.id]?.state ?? .disconnected
        
        HStack(spacing: 8) {
            Circle()
                .fill(statusColor(status))
                .frame(width: 7, height: 7)
            
            VStack(alignment: .leading, spacing: 1) {
                Text(share.name)
                    .font(.system(size: 12, weight: .medium))
                Text(share.remotePath)
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if share.autoMount {
                Text("Auto")
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(Color.secondary.opacity(0.15))
                    .cornerRadius(4)
            }
            
            if status == .mounted {
                Button {
                    openInFinder(share: share)
                } label: {
                    Image(systemName: "arrow.up.forward.app")
                        .foregroundColor(.accentColor)
                }
                .buttonStyle(.borderless)
                .help(String(localized: "open_in_finder", defaultValue: "Im Finder öffnen"))
                
                Button {
                    Task {
                        try? await store.unmountShare(share, from: profile)
                        updateAllFinderLinks()
                    }
                } label: {
                    Image(systemName: "eject.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.borderless)
            } else {
                Button {
                    Task {
                        try? await store.mountShare(share, from: profile)
                        updateAllFinderLinks()
                    }
                } label: {
                    Image(systemName: "play.circle.fill")
                        .foregroundColor(.green)
                }
                .buttonStyle(.borderless)
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
    }
    
    @ViewBuilder
    private var actionsSection: some View {
        HStack {
            Button(String(localized: "menu_settings", defaultValue: "Einstellungen…")) {
                openSettingsWindow()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            
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
            .help("Aktualisieren")
            
            Button(String(localized: "menu_quit", defaultValue: "Beenden")) {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
    }
    
    private func statusColor(_ state: MountState) -> Color {
        switch state {
        case .mounted: return .green
        case .connecting, .unmounting: return .orange
        case .disconnected: return .gray
        case .error: return .red
        }
    }
    
    private func openInFinder(share: ShareMount) {
        let path = MountPointSanitizer.resolveMountPoint(for: share)
        let url = URL(fileURLWithPath: path)
        NSWorkspace.shared.open(url)
    }
    
    private func openSettingsWindow() {
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
    
    /// Verbindet nur die Shares, die auf "Auto" stehen (Vorauswahl)
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
