#if canImport(AppKit) && canImport(SwiftUI)
import SwiftUI
import AppKit
#if canImport(SynologyMountCore)
import SynologyMountCore
#endif

struct SettingsView: View {
    @Environment(MountAppStore.self) private var store
    @State private var selectedProfileId: UUID?
    
    var body: some View {
        NavigationSplitView {
            sidebarSection
        } detail: {
            detailSection
        }
        .frame(minWidth: 720, minHeight: 480)
        .onAppear {
            if selectedProfileId == nil, let first = store.profiles.first {
                selectedProfileId = first.id
            }
        }
    }
    
    @ViewBuilder
    private var sidebarSection: some View {
        VStack(spacing: 0) {
            List(selection: $selectedProfileId) {
                Section(String(localized: "tab_servers", defaultValue: "Synology Server")) {
                    ForEach(store.profiles) { profile in
                        NavigationLink(value: profile.id) {
                            HStack {
                                Image(systemName: "server.rack")
                                    .foregroundColor(profile.isEnabled ? .primary : .secondary)
                                VStack(alignment: .leading) {
                                    Text(profile.name)
                                        .font(.system(size: 13, weight: .medium))
                                    Text(profile.cleanHost)
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                }
            }
            .listStyle(.sidebar)
            
            Divider()
            
            // Fester Footer-Button in der Sidebar (wie in Apple Mail / Xcode)
            HStack {
                Button {
                    createNewProfile()
                } label: {
                    Label(String(localized: "btn_add_server", defaultValue: "Server hinzufügen"), systemImage: "plus")
                }
                .buttonStyle(.borderless)
                .controlSize(.small)
                
                Spacer()
            }
            .padding(10)
            .background(Color(NSColor.controlBackgroundColor))
        }
    }
    
    @ViewBuilder
    private var detailSection: some View {
        if let pid = selectedProfileId, let profile = store.profiles.first(where: { $0.id == pid }) {
            ProfileDetailEditView(profile: profile) { updated in
                store.saveProfile(updated)
            } onDelete: {
                store.deleteProfile(id: pid)
                selectedProfileId = store.profiles.first?.id
            }
        } else {
            VStack(spacing: 16) {
                Image(systemName: "externaldrive.connected.to.line.below")
                    .font(.system(size: 56))
                    .foregroundColor(.accentColor)
                
                Text(String(localized: "settings_title", defaultValue: "SynologyMount Einstellungen"))
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text(String(localized: "lbl_select_server_placeholder", defaultValue: "Kein Server ausgewählt. Klicken Sie auf den Button, um Ihre DiskStation hinzuzufügen:"))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                
                Button {
                    createNewProfile()
                } label: {
                    Label(String(localized: "btn_add_server", defaultValue: "Server hinzufügen"), systemImage: "plus.circle.fill")
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
    
    private func createNewProfile() {
        let newP = ServerProfile(name: "Meine DiskStation", host: "diskstation.local", username: "admin")
        store.saveProfile(newP)
        selectedProfileId = newP.id
    }
}

struct ProfileDetailEditView: View {
    @State var profile: ServerProfile
    var onSave: (ServerProfile) -> Void
    var onDelete: () -> Void
    
    @State private var password = ""
    @State private var otpCode = ""
    @State private var rememberDevice = true
    @State private var showOtpPrompt = false
    @State private var isDetectingShares = false
    @State private var detectionError: String?
    
    var body: some View {
        Form {
            Section(header: Text(String(localized: "lbl_server_info_section", defaultValue: "Server-Informationen"))) {
                TextField(String(localized: "lbl_server_name", defaultValue: "Servername"), text: $profile.name)
                TextField(String(localized: "lbl_server_host", defaultValue: "Host / IP"), text: $profile.host)
                TextField(String(localized: "lbl_username", defaultValue: "Benutzername"), text: $profile.username)
                SecureField(String(localized: "lbl_password", defaultValue: "Passwort"), text: $password)
                
                if profile.deviceID != nil {
                    HStack {
                        Image(systemName: "checkmark.shield.fill")
                            .foregroundColor(.green)
                        Text(String(localized: "lbl_device_trusted_status", defaultValue: "Dieses Gerät ist vertrauenswürdig (2FA hinterlegt)"))
                            .font(.caption)
                    }
                }
                
                if showOtpPrompt {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(String(localized: "lbl_otp_prompt", defaultValue: "2FA erforderlich"))
                            .font(.caption)
                            .foregroundColor(.orange)
                        
                        HStack {
                            TextField(String(localized: "lbl_otp_code", defaultValue: "2FA / OTP Code"), text: $otpCode)
                                .textFieldStyle(.roundedBorder)
                            Button(String(localized: "btn_detect_shares", defaultValue: "Bestätigen")) {
                                detectShares()
                            }
                        }
                        
                        Toggle(String(localized: "lbl_remember_device", defaultValue: "Dieses Gerät dauerhaft merken"), isOn: $rememberDevice)
                            .font(.caption)
                    }
                    .padding(.vertical, 4)
                }
                
                Toggle(String(localized: "lbl_automount", defaultValue: "Server aktiv"), isOn: $profile.isEnabled)
            }
            
            Section(header: Text(String(localized: "menu_shares", defaultValue: "Freigaben (Shares)"))) {
                if profile.shares.isEmpty {
                    Text(String(localized: "lbl_no_shares", defaultValue: "Noch keine Freigaben hinzugefügt."))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                ForEach($profile.shares) { $share in
                    HStack {
                        VStack(alignment: .leading) {
                            TextField("Name", text: $share.name)
                            TextField("Remote Pfad (z.B. video)", text: $share.remotePath)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Toggle("Auto", isOn: $share.autoMount)
                            .labelsHidden()
                        Button {
                            removeShare(share.id)
                        } label: {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.plain)
                    }
                }
                
                HStack {
                    Button(String(localized: "btn_add_share", defaultValue: "Freigabe manuell hinzufügen")) {
                        profile.shares.append(ShareMount(name: "Neue Freigabe", remotePath: "share"))
                    }
                    
                    Spacer()
                    
                    Button(String(localized: "btn_detect_shares", defaultValue: "Freigaben automatisch erkennen")) {
                        detectShares()
                    }
                    .disabled(isDetectingShares || profile.cleanHost.isEmpty)
                }
            }
            
            if let err = detectionError {
                Text(err)
                    .foregroundColor(.red)
                    .font(.caption)
            }
            
            Section {
                HStack {
                    Button(String(localized: "btn_delete", defaultValue: "Löschen"), role: .destructive) {
                        onDelete()
                    }
                    Spacer()
                    Button(String(localized: "btn_save", defaultValue: "Speichern")) {
                        if !password.isEmpty {
                            _ = KeychainHelper.shared.savePassword(password, for: profile.username)
                        }
                        onSave(profile)
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .padding(16)
        .onAppear {
            if let savedPw = KeychainHelper.shared.getPassword(for: profile.username) {
                self.password = savedPw
            }
        }
    }
    
    private func removeShare(_ id: UUID) {
        profile.shares.removeAll(where: { $0.id == id })
    }
    
    private func detectShares() {
        isDetectingShares = true
        detectionError = nil
        
        Task {
            let client = SynologyClient(profile: profile)
            do {
                let currentOtp = otpCode.isEmpty ? nil : otpCode
                let (_, did) = try await client.login(password: password, otpCode: currentOtp, rememberDevice: rememberDevice)
                
                if let savedToken = did, rememberDevice {
                    self.profile.deviceID = savedToken
                }
                
                let folders = try await client.listSharedFolders()
                
                await MainActor.run {
                    for f in folders {
                        if !profile.shares.contains(where: { $0.cleanRemotePath.lowercased() == f.shareName.lowercased() }) {
                            profile.shares.append(ShareMount(name: f.name, remotePath: f.shareName, autoMount: true))
                        }
                    }
                    self.showOtpPrompt = false
                    self.otpCode = ""
                    self.isDetectingShares = false
                    self.onSave(self.profile)
                }
            } catch SynoClientError.twoFactorRequired {
                await MainActor.run {
                    self.showOtpPrompt = true
                    self.detectionError = SynoClientError.twoFactorRequired.localizedDescription
                    self.isDetectingShares = false
                }
            } catch SynoClientError.invalidTwoFactorCode {
                await MainActor.run {
                    self.showOtpPrompt = true
                    self.detectionError = SynoClientError.invalidTwoFactorCode.localizedDescription
                    self.isDetectingShares = false
                }
            } catch {
                await MainActor.run {
                    self.detectionError = error.localizedDescription
                    self.isDetectingShares = false
                }
            }
        }
    }
}
#endif
