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
            actionsSection
        }
        .padding(14)
        .frame(width: 330)
        .onAppear {
            Task {
                await store.syncMounts()
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
                
                Button(String(localized: "btn_add_server", defaultValue: "Server hinzufügen")) {
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
                        Task { await store.syncMounts() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.caption2)
                    }
                    .buttonStyle(.borderless)
                }
                
                ForEach(allShares, id: \.share.id) { item in
                    shareRow(profile: item.profile, share: item.share)
                }
            }
        }
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
                    .font(.system(size: 13, weight: .medium))
                Text(profile.name)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if status == .mounted {
                Button {
                    openInFinder(share: share)
                } label: {
                    Image(systemName: "folder")
                }
                .buttonStyle(.borderless)
                .help(String(localized: "open_in_finder", defaultValue: "Im Finder öffnen"))
                
                Button {
                    Task { try? await store.unmountShare(share, from: profile) }
                } label: {
                    Image(systemName: "eject.fill")
                }
                .buttonStyle(.borderless)
            } else {
                Button {
                    Task { try? await store.mountShare(share, from: profile) }
                } label: {
                    Image(systemName: "play.circle")
                }
                .buttonStyle(.borderless)
            }
        }
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
}
#endif
