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
        VStack(spacing: 0) {
            sheetHeader
            HairlineRule()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    connectionCard
                    authenticationCard
                    networkCard
                    appearanceCard
                }
                .padding(22)
            }
            .scrollContentBackground(.hidden)

            HairlineRule()
            footer
        }
        .frame(width: 640, height: 680)
        .background(Theme.Palette.canvas)
        .preferredColorScheme(.dark)
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

    // MARK: - Chrome

    private var sheetHeader: some View {
        HStack(spacing: 12) {
            IconBadge(
                symbol: draft.provider.symbol,
                tint: draft.accent.tint,
                highlight: draft.accent.highlight,
                size: 36
            )

            VStack(alignment: .leading, spacing: 2) {
                Text(existingProfile == nil ? "New VPN profile" : "Edit VPN profile")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.Palette.textPrimary)
                Text(draft.name.isEmpty ? "Unnamed" : draft.name)
                    .font(.caption12)
                    .foregroundStyle(Theme.Palette.textSecondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 16)
        .animation(Theme.Motion.state, value: draft.accent)
    }

    private var footer: some View {
        HStack(spacing: 10) {
            Spacer()
            Button("Cancel") { dismiss() }
                .buttonStyle(.quiet)
                .keyboardShortcut(.cancelAction)
            Button("Save") { save() }
                .buttonStyle(.accent(draft.accent.tint))
                .keyboardShortcut(.defaultAction)
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 14)
    }

    // MARK: - Sections

    private var connectionCard: some View {
        SettingsCard("Connection", symbol: "point.3.connected.trianglepath.dotted") {
            SettingsRow("Name") {
                TextField("", text: $draft.name, prompt: Text("Company VPN"))
                    .textFieldStyle(.plain)
                    .fieldChrome()
                    .frame(width: 280)
            }

            HairlineRule()

            VStack(alignment: .leading, spacing: 9) {
                Text("Client")
                    .font(.body13)
                    .foregroundStyle(Theme.Palette.textPrimary)

                ChipPicker(
                    options: VPNProvider.allCases,
                    selection: $draft.provider,
                    tint: draft.accent.tint,
                    title: \.rawValue,
                    symbol: \.symbol
                )
            }

            HairlineRule()

            if draft.provider == .openVPN {
                SettingsRow("Imported profile") {
                    Text(openVPNImportName)
                        .font(.readout)
                        .foregroundStyle(Theme.Palette.textSecondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                SettingsNote("The remote endpoint and TLS material come from the imported OpenVPN profile. Referenced credentials are ignored.")
            } else {
                SettingsRow("Server") {
                    TextField("", text: $draft.server, prompt: Text("vpn.example.com:443"))
                        .textFieldStyle(.plain)
                        .fieldChrome()
                        .frame(width: 280)
                }
            }
        }
    }

    private var authenticationCard: some View {
        SettingsCard("Authentication", symbol: "person.badge.key.fill") {
            VStack(alignment: .leading, spacing: 9) {
                Text("Method")
                    .font(.body13)
                    .foregroundStyle(Theme.Palette.textPrimary)

                ChipPicker(
                    options: availableAuthenticationMethods,
                    selection: $draft.authentication,
                    tint: draft.accent.tint,
                    title: \.rawValue,
                    symbol: nil
                )
            }

            HairlineRule()

            SettingsRow("Username") {
                TextField("", text: $draft.username)
                    .textFieldStyle(.plain)
                    .fieldChrome()
                    .frame(width: 280)
            }

            if draft.provider != .openVPN {
                SettingsRow(certificateFieldTitle) {
                    TextField("", text: $draft.serverCertificatePin, prompt: Text(certificateFieldPrompt))
                        .textFieldStyle(.plain)
                        .fieldChrome()
                        .frame(width: 280)
                }
            }

            SettingsNote("Passwords can be saved in macOS Keychain when you connect. OTP values are never saved.")

            if let profile = existingProfile, profile.authentication != .saml {
                HairlineRule()

                switch savedPasswordState {
                case .checking:
                    Label("Checking Keychain…", systemImage: "key")
                        .font(.caption12)
                        .foregroundStyle(Theme.Palette.textTertiary)
                case .available:
                    HStack {
                        Label("A password is saved in your Keychain", systemImage: "key.fill")
                            .font(.caption12)
                            .foregroundStyle(Theme.Palette.textSecondary)
                        Spacer()
                        Button("Forget") { forgetSavedPassword(profile.id) }
                            .buttonStyle(QuietActionStyle(compact: true, destructive: true))
                    }
                case .missing:
                    Label("No saved password in Keychain", systemImage: "key.slash")
                        .font(.caption12)
                        .foregroundStyle(Theme.Palette.textTertiary)
                }
            }
        }
    }

    private var networkCard: some View {
        SettingsCard("Network", symbol: "arrow.triangle.branch", tint: Color(hex: 0x2DC7B4)) {
            SettingsRow("DNS servers") {
                TextField("", text: $draft.dnsServers, prompt: Text("10.0.0.53, 10.0.0.54"))
                    .textFieldStyle(.plain)
                    .fieldChrome()
                    .frame(width: 280)
            }

            SettingsRow("DNS domains") {
                TextField("", text: $draft.dnsDomains, prompt: Text("internal.example, corp.local"))
                    .textFieldStyle(.plain)
                    .fieldChrome()
                    .frame(width: 280)
            }

            SettingsNote("Configured domains are resolved only by this profile's DNS servers. VPN-advertised DNS is ignored. Leave both fields empty to make no DNS changes.")
        }
    }

    private var appearanceCard: some View {
        SettingsCard("Appearance", symbol: "paintpalette", tint: draft.accent.tint) {
            SettingsRow("Accent", detail: "Tints this profile's card and the window while it is connected.") {
                HStack(spacing: 8) {
                    ForEach(ProfileAccent.allCases, id: \.self) { accent in
                        AccentSwatch(accent: accent, isSelected: draft.accent == accent) {
                            withAnimation(Theme.Motion.state) { draft.accent = accent }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Derived

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

    // MARK: - Actions

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

// MARK: - Controls

/// A row of selectable chips. Replaces `Picker` for the two- and three-way
/// choices in the editor, where seeing all the options at once is worth more
/// than the space a menu would save.
private struct ChipPicker<Option: Hashable>: View {
    let options: [Option]
    @Binding var selection: Option
    let tint: Color
    let title: KeyPath<Option, String>
    let symbol: KeyPath<Option, String>?

    var body: some View {
        HStack(spacing: 7) {
            ForEach(options, id: \.self) { option in
                let isSelected = option == selection
                Button {
                    withAnimation(Theme.Motion.state) { selection = option }
                } label: {
                    HStack(spacing: 6) {
                        if let symbol {
                            Image(systemName: option[keyPath: symbol])
                                .font(.system(size: 10.5, weight: .semibold))
                        }
                        Text(option[keyPath: title])
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundStyle(isSelected ? Theme.Palette.textPrimary : Theme.Palette.textSecondary)
                    .padding(.horizontal, 11)
                    .padding(.vertical, 7)
                    .background {
                        let shape = RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous)
                        shape.fill(isSelected ? tint.opacity(0.20) : Theme.Palette.surface)
                            .overlay(
                                shape.strokeBorder(
                                    isSelected ? tint.opacity(0.5) : Theme.Palette.hairline,
                                    lineWidth: 1
                                )
                            )
                    }
                    .contentShape(RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous))
                }
                .buttonStyle(.plain)
            }

            Spacer(minLength: 0)
        }
    }
}

private struct AccentSwatch: View {
    let accent: ProfileAccent
    let isSelected: Bool
    let action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Circle()
                .fill(accent.gradient)
                .frame(width: 18, height: 18)
                .overlay(Circle().strokeBorder(.white.opacity(0.25), lineWidth: 1))
                .padding(3)
                .overlay(
                    Circle().strokeBorder(
                        isSelected ? accent.highlight : (hovering ? Theme.Palette.hairlineBright : .clear),
                        lineWidth: 1.5
                    )
                )
                .shadow(color: accent.tint.opacity(isSelected ? 0.6 : 0), radius: 6)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .animation(Theme.Motion.hover, value: hovering)
        .help(accent.rawValue.capitalized)
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
