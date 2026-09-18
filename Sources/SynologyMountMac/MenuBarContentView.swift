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
            sharesSection
            Divider()
            finderFolderSection
            Divider()
            actionsSection
        }
        .padding(14)
        .frame(width: 340)
        .onAppear {
            store.reloadProfiles()
            Task {
                await store.syncMounts()
                updateFinderLinks()
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
    private var sharesSection: some View {
        let allShares = store.profiles.flatMap { p in
            p.shares.map { (profile: p, share: $0) }
        }
        
        if allShares.isEmpty {
            VStack(spacing: 8) {
                Text(String(localized: "lbl_no_shares", defaultValue: "Keine Freigaben konfiguriert"))
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
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(String(localized: "menu_shares", defaultValue: "Freigaben"))
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                    
                    Text("(\(allShares.count))")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Button {
                        store.reloadProfiles()
                        Task { 
                            await store.syncMounts()
                            updateFinderLinks()
                        }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.caption2)
                    }
                    .buttonStyle(.borderless)
                    .help(String(localized: "menu_mount_all", defaultValue: "Alle aktualisieren / verbinden"))
                }
                
                ScrollView(.vertical) {
                    VStack(spacing: 4) {
                        ForEach(allShares, id: \.share.id) { item in
                            shareRow(profile: item.profile, share: item.share)
                        }
                    }
                }
                .frame(maxHeight: 240)
                
                HStack {
                    Button(String(localized: "menu_mount_all", defaultValue: "Alle verbinden")) {
                        mountAll()
                    }
                    .buttonStyle(.borderless)
                    .font(.caption2)
                    
                    Spacer()
                    
                    Button(String(localized: "menu_unmount_all", defaultValue: "Alle trennen")) {
                        unmountAll()
                    }
                    .buttonStyle(.borderless)
                    .font(.caption2)
                }
                .padding(.top, 4)
            }
        }
    }
    
    @ViewBuilder
    private var finderFolderSection: some View {
        HStack {
            Image(systemName: "folder.badge.gearshape")
                .foregroundColor(.accentColor)
            Text(AppConfig.brandName)
                .font(.system(size: 12, weight: .medium))
            Spacer()
            Button(String(localized: "open_in_finder", defaultValue: "Im Finder öffnen")) {
                FinderSidebarHelper.shared.openInFinder()
            }
            .buttonStyle(.bordered)
            .controlSize(.mini)
        }
        .padding(.vertical, 2)
    }
    
    @ViewBuilder
    private func shareRow(profile: ServerProfile, share: ShareMount) -> some View {
        let status = store.statuses[share.id]?.state ?? .disconnected
        
        HStack(spacing: 8) {
            Circle()
                .fill(statusColor(status))
                .frame(width: 8, height: 8)
            
            VStack(alignment: .leading, spacing: 1) {
                Text(share.name)
                    .font(.system(size: 13, weight: .medium))
                Text(share.remotePath)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if status == .mounted {
                Button {
                    openInFinder(share: share)
                } label: {
                    Image(systemName: "folder")
                        .foregroundColor(.accentColor)
                }
                .buttonStyle(.borderless)
                .help(String(localized: "open_in_finder", defaultValue: "Im Finder öffnen"))
                
                Button {
                    Task {
                        try? await store.unmountShare(share, from: profile)
                        updateFinderLinks()
                    }
                } label: {
                    Image(systemName: "eject.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.borderless)
                .help(String(localized: "menu_unmount_all", defaultValue: "Trennen"))
            } else {
                Button {
                    Task {
                        try? await store.mountShare(share, from: profile)
                        updateFinderLinks()
                    }
                } label: {
                    Image(systemName: "play.circle.fill")
                        .foregroundColor(.green)
                }
                .buttonStyle(.borderless)
                .help(String(localized: "menu_mount_all", defaultValue: "Verbinden"))
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
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
            
            Spacer()
            
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
    
    private func updateFinderLinks() {
        var active: [(name: String, path: String)] = []
        for profile in store.profiles {
            for share in profile.shares {
                if store.statuses[share.id]?.state == .mounted {
                    let path = MountPointSanitizer.resolveMountPoint(for: share)
                    active.append((name: share.name, path: path))
                }
            }
        }
        FinderSidebarHelper.shared.updateFinderLinks(activeMountPoints: active)
    }
    
    private func mountAll() {
        Task {
            for profile in store.profiles where profile.isEnabled {
                for share in profile.shares {
                    try? await store.mountShare(share, from: profile)
                }
            }
            updateFinderLinks()
        }
    }
    
    private func unmountAll() {
        Task {
            for profile in store.profiles {
                for share in profile.shares {
                    try? await store.unmountShare(share, from: profile)
                }
            }
            updateFinderLinks()
        }
    }
}
#endif
