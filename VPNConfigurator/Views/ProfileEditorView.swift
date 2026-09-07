import SwiftUI

struct ProfileEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(VPNController.self) private var controller

    private let existingProfile: VPNProfile?
    @State private var draft: ProfileDraft
    @State private var validationMessage: String?
    @State private var savedPasswordState = SavedPasswordState.checking

    init(profile: VPNProfile? = nil) {
        existingProfile = profile
        _draft = State(initialValue: ProfileDraft(profile: profile))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Connection") {
                    TextField("Name", text: $draft.name, prompt: Text("Company VPN"))
                    Picker("Client", selection: $draft.provider) {
                        ForEach(VPNProvider.allCases, id: \.self) { provider in
                            Label(provider.rawValue, systemImage: provider.symbol).tag(provider)
                        }
                    }
                    if draft.provider == .openVPN {
                        LabeledContent("Imported profile", value: openVPNImportName)
                        Text("The remote endpoint and TLS material come from the imported OpenVPN profile. Referenced credentials are ignored.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        TextField("Server", text: $draft.server, prompt: Text("vpn.example.com:443"))
                    }
                }

                Section("Authentication") {
                    Picker("Method", selection: $draft.authentication) {
                        ForEach(availableAuthenticationMethods, id: \.self) { method in
                            Text(method.rawValue).tag(method)
                        }
                    }
                    TextField("Username", text: $draft.username)
                    if draft.provider != .openVPN {
                        TextField(certificateFieldTitle, text: $draft.serverCertificatePin, prompt: Text(certificateFieldPrompt))
                    }
                    Text("Passwords can be saved in macOS Keychain when you connect. OTP values are never saved.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if let profile = existingProfile, profile.authentication != .saml {
                        switch savedPasswordState {
                        case .checking:
                            Label("Checking Keychain…", systemImage: "key")
                                .foregroundStyle(.secondary)
                        case .available:
                            Button(role: .destructive) {
                                forgetSavedPassword(profile.id)
                            } label: {
                                Label("Forget saved password", systemImage: "key.slash")
                            }
                        case .missing:
                            Label("No saved password in Keychain", systemImage: "key.slash")
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section("Network") {
                    TextField("DNS servers", text: $draft.dnsServers, prompt: Text("10.0.0.53, 10.0.0.54"))
                    TextField("DNS domains", text: $draft.dnsDomains, prompt: Text("internal.example, corp.local"))
                    Text("Configured domains are resolved only by this profile's DNS servers. VPN-advertised DNS is ignored. Leave both fields empty to make no DNS changes.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Appearance") {
                    Picker("Accent", selection: $draft.accent) {
                        ForEach(ProfileAccent.allCases, id: \.self) { accent in
                            Label(accent.rawValue.capitalized, systemImage: "circle.fill")
                                .foregroundStyle(accent.color)
                                .tag(accent)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }
            .formStyle(.grouped)
            .navigationTitle(existingProfile == nil ? "New VPN Profile" : "Edit VPN Profile")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .buttonStyle(.glassProminent)
                }
            }
            .alert("Profile needs attention", isPresented: Binding(
                get: { validationMessage != nil },
                set: { if !$0 { validationMessage = nil } }
            )) {
                Button("OK") { validationMessage = nil }
            } message: {
                Text(validationMessage ?? "")
            }
            .onChange(of: draft.provider) { _, provider in
                if provider != .openFortiVPN && draft.authentication == .saml {
                    draft.authentication = .password
                }
                if provider == .openVPN {
                    draft.authentication = .password
                }
            }
            .task(id: existingProfile?.id) {
                refreshSavedPasswordState()
            }
        }
        .frame(minWidth: 620, minHeight: 620)
    }

    private var availableAuthenticationMethods: [AuthenticationMethod] {
        switch draft.provider {
        case .openFortiVPN: AuthenticationMethod.allCases
        case .openConnect: [.password, .passwordAndOTP]
        case .openVPN: [.password]
        }
    }

    private var certificateFieldTitle: String {
        draft.provider == .openFortiVPN ? "Trusted certificate SHA-256" : "Server certificate pin"
    }

    private var certificateFieldPrompt: String {
        draft.provider == .openFortiVPN ? "Optional 64-character hex digest" : "Optional pin-sha256 value"
    }

    private var openVPNImportName: String {
        guard !draft.configurationPath.isEmpty else { return "Import required" }
        return URL(fileURLWithPath: draft.configurationPath).lastPathComponent
    }

    private func refreshSavedPasswordState() {
        guard let profile = existingProfile, profile.authentication != .saml else { return }
        do {
            savedPasswordState = try controller.hasSavedPassword(for: profile.id)
                ? .available
                : .missing
        } catch {
            savedPasswordState = .missing
            validationMessage = error.localizedDescription
        }
    }

    private func forgetSavedPassword(_ profileID: VPNProfile.ID) {
        do {
            try controller.removeSavedPassword(for: profileID)
            savedPasswordState = .missing
        } catch {
            validationMessage = error.localizedDescription
        }
    }

    private func save() {
        guard !draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            validationMessage = "Give the profile a name."
            return
        }
        guard draft.provider == .openVPN ||
                !draft.server.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            validationMessage = "Enter the VPN server."
            return
        }
        guard draft.provider != .openVPN || !draft.configurationPath.isEmpty else {
            validationMessage = "Create OpenVPN profiles with the Import button so their endpoint and TLS material can be stored securely."
            return
        }
        let hasDNSServers = !draft.list(draft.dnsServers).isEmpty
        let hasDNSDomains = !draft.list(draft.dnsDomains).isEmpty
        guard hasDNSServers == hasDNSDomains else {
            validationMessage = "Split DNS requires both DNS servers and DNS domains. Leave both empty if this VPN should not change DNS."
            return
        }

        let profile = draft.makeProfile(id: existingProfile?.id ?? UUID())
        if existingProfile == nil {
            controller.add(profile)
        } else {
            controller.replace(profile)
        }
        dismiss()
    }
}

private enum SavedPasswordState {
    case checking
    case available
    case missing
}

private struct ProfileDraft {
    var name = ""
    var server = ""
    var provider = VPNProvider.openFortiVPN
    var authentication = AuthenticationMethod.password
    var username = ""
    var configurationPath = ""
    var serverCertificatePin = ""
    var dnsServers = ""
    var dnsDomains = ""
    var accent = ProfileAccent.blue

    init(profile: VPNProfile?) {
        guard let profile else { return }
        name = profile.name
        server = profile.server
        provider = profile.provider
        authentication = profile.authentication
        username = profile.username
        configurationPath = profile.configurationPath ?? ""
        serverCertificatePin = profile.serverCertificatePin ?? ""
        dnsServers = profile.dnsServers.joined(separator: ", ")
        dnsDomains = profile.dnsDomains.joined(separator: ", ")
        accent = profile.accent
    }

    func makeProfile(id: UUID) -> VPNProfile {
        VPNProfile(
            id: id,
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            server: server.trimmingCharacters(in: .whitespacesAndNewlines),
            provider: provider,
            authentication: authentication,
            username: username.trimmingCharacters(in: .whitespacesAndNewlines),
            configurationPath: provider == .openVPN ? optional(configurationPath) : nil,
            serverCertificatePin: optional(serverCertificatePin),
            dnsDomains: list(dnsDomains),
            dnsServers: list(dnsServers),
            accent: accent
        )
    }

    fileprivate func list(_ value: String) -> [String] {
        value.split(separator: ",").map {
            $0.trimmingCharacters(in: .whitespacesAndNewlines)
        }.filter { !$0.isEmpty }
    }

    private func optional(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
