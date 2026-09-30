import SwiftUI
import UniformTypeIdentifiers

struct ProfileEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(VPNController.self) private var controller

    private let existingProfile: VPNProfile?
    @State private var draft: ProfileDraft
    @State private var validationMessage: String?
    @State private var savedPasswordState = SavedPasswordState.checking
    @State private var currentStep = EditorStep.connection
    @State private var showingConfigurationImporter = false
    @State private var temporaryConfigurationPath: String?
    @State private var didSave = false

    init(profile: VPNProfile? = nil) {
        existingProfile = profile
        _draft = State(initialValue: ProfileDraft(profile: profile))
    }

    var body: some View {
        VStack(spacing: 0) {
            sheetHeader
            HairlineRule()
            if isEditing {
                editForm
            } else {
                stepper
                HairlineRule()
                wizardContent
            }

            HairlineRule()
            footer
        }
        .frame(width: 920, height: 680)
        .background(Theme.Palette.canvas)
        .preferredColorScheme(.dark)
        .fileImporter(
            isPresented: $showingConfigurationImporter,
            allowedContentTypes: [.data, .plainText],
            allowsMultipleSelection: false,
            onCompletion: importOpenVPNConfiguration
        )
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
        .onDisappear {
            if !didSave {
                ConfigurationImporter.removeManagedOpenVPNConfiguration(at: temporaryConfigurationPath)
            }
        }
    }

    private var isEditing: Bool { existingProfile != nil }

    private var editForm: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 18) {
                    connectionCard.id(EditorStep.connection)
                    authenticationCard.id(EditorStep.authentication)
                    networkCard.id(EditorStep.network)
                    appearanceCard.id(EditorStep.appearance)
                }
                .frame(maxWidth: 760)
                .padding(.horizontal, 34)
                .padding(.vertical, 24)
                .frame(maxWidth: .infinity)
            }
            .scrollContentBackground(.hidden)
            .onChange(of: validationMessage) { _, message in
                guard message != nil else { return }
                withAnimation(Theme.Motion.state) {
                    proxy.scrollTo(currentStep, anchor: .top)
                }
            }
        }
    }

    private var wizardContent: some View {
        ScrollView {
            Group {
                switch currentStep {
                case .connection: connectionCard
                case .authentication: authenticationCard
                case .network: networkCard
                case .appearance: appearanceCard
                }
            }
            .id(currentStep)
            .transition(.opacity.combined(with: .move(edge: .trailing)))
            .frame(maxWidth: 760)
            .padding(.horizontal, 34)
            .padding(.vertical, 28)
            .frame(maxWidth: .infinity)
        }
        .scrollContentBackground(.hidden)
    }

    // MARK: - Chrome

    private var sheetHeader: some View {
        HStack(spacing: 12) {
            IconBadge(
                symbol: draft.provider.symbol,
                tint: draft.accent.tint,
                highlight: draft.accent.highlight,
                size: 30
            )

            VStack(alignment: .leading, spacing: 2) {
                Text(existingProfile == nil ? "New VPN profile" : "Edit VPN profile")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.Palette.textPrimary)
                Text(isEditing
                     ? (draft.name.isEmpty ? "Unnamed" : draft.name)
                     : "\(currentStep.title) · \(draft.name.isEmpty ? "Unnamed" : draft.name)")
                    .font(.caption12)
                    .foregroundStyle(Theme.Palette.textSecondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .animation(Theme.Motion.state, value: draft.accent)
    }

    private var stepper: some View {
        HStack(spacing: 0) {
            ForEach(EditorStep.allCases) { step in
                Button {
                    move(to: step)
                } label: {
                    VStack(spacing: 7) {
                        ZStack {
                            Circle()
                                .fill(step.rawValue <= currentStep.rawValue ? draft.accent.tint.opacity(0.20) : Theme.Palette.surface)
                                .frame(width: 30, height: 30)
                            Circle()
                                .strokeBorder(step.rawValue <= currentStep.rawValue ? draft.accent.tint.opacity(0.65) : Theme.Palette.hairlineBright)
                                .frame(width: 30, height: 30)
                            if step.rawValue < currentStep.rawValue {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 11, weight: .bold))
                            } else {
                                Text("\(step.rawValue + 1)")
                                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                            }
                        }
                        .foregroundStyle(step.rawValue <= currentStep.rawValue ? Theme.Palette.textPrimary : Theme.Palette.textTertiary)

                        Text(step.title)
                            .font(.system(size: 11.5, weight: step == currentStep ? .semibold : .medium))
                            .foregroundStyle(step == currentStep ? Theme.Palette.textPrimary : Theme.Palette.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if step != EditorStep.allCases.last {
                    Rectangle()
                        .fill(step.rawValue < currentStep.rawValue ? draft.accent.tint.opacity(0.55) : Theme.Palette.hairline)
                        .frame(maxWidth: 72, maxHeight: 1)
                        .offset(y: -11)
                }
            }
        }
        .padding(.horizontal, 46)
        .padding(.vertical, 17)
        .animation(Theme.Motion.state, value: currentStep)
    }

    private var footer: some View {
        HStack(spacing: 10) {
            if !isEditing {
                Text("Step \(currentStep.rawValue + 1) of \(EditorStep.allCases.count)")
                    .font(.caption12)
                    .foregroundStyle(Theme.Palette.textTertiary)
            }

            Spacer()

            Button("Cancel") { cancel() }
                .buttonStyle(.quiet)
                .keyboardShortcut(.cancelAction)

            if !isEditing && currentStep != .connection {
                Button("Back") { moveBack() }
                    .buttonStyle(.quiet)
            }

            if isEditing || currentStep == .appearance {
                Button(isEditing ? "Save changes" : "Save profile") { save() }
                    .buttonStyle(.accent(draft.accent.tint))
                    .keyboardShortcut(.defaultAction)
            } else {
                Button("Continue", systemImage: "chevron.right") { moveForward() }
                    .buttonStyle(.accent(draft.accent.tint))
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 14)
    }

    // MARK: - Sections

    private var connectionCard: some View {
        SettingsCard("Connection", symbol: "point.3.connected.trianglepath.dotted", dense: true, fillsHeight: !isEditing) {
            SettingsRow("Name") {
                TextField("", text: $draft.name, prompt: Text("Company VPN"))
                    .textFieldStyle(.plain)
                    .fieldChrome()
                    .frame(maxWidth: 360)
            }

            HairlineRule()

            VStack(alignment: .leading, spacing: 7) {
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
                    HStack(spacing: 9) {
                        Text(openVPNImportName)
                            .font(.readout)
                            .foregroundStyle(Theme.Palette.textSecondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Button(draft.configurationPath.isEmpty ? "Choose…" : "Replace…") {
                            showingConfigurationImporter = true
                        }
                        .buttonStyle(.quiet)
                    }
                    .frame(maxWidth: 390, alignment: .trailing)
                }
                SettingsNote("Choose an OpenVPN configuration here. Its endpoint and TLS material are stored securely; referenced credentials are ignored.")
            } else {
                SettingsRow("Server") {
                    TextField("", text: $draft.server, prompt: Text(draft.provider == .openFortiVPN ? "vpn.example.com:443/realm" : "vpn.example.com:443"))
                        .textFieldStyle(.plain)
                        .fieldChrome()
                        .frame(maxWidth: 360)
                }
                if draft.provider == .openFortiVPN {
                    SettingsNote("For an authentication realm, append /realm to the server, for example 193.41.150.166:443/UniSystems.")
                }
            }
        }
    }

    private var authenticationCard: some View {
        SettingsCard("Authentication", symbol: "person.badge.key.fill", dense: true, fillsHeight: !isEditing) {
            VStack(alignment: .leading, spacing: 7) {
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
                    .frame(maxWidth: 360)
            }

            if draft.provider != .openVPN {
                SettingsRow(certificateFieldTitle) {
                    TextField("", text: $draft.serverCertificatePin, prompt: Text(certificateFieldPrompt))
                        .textFieldStyle(.plain)
                        .fieldChrome()
                        .frame(maxWidth: 360)
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
        SettingsCard("Network", symbol: "arrow.triangle.branch", tint: Color(hex: 0x2DC7B4), dense: true, fillsHeight: !isEditing) {
            SettingsRow("DNS servers") {
                TextField("", text: $draft.dnsServers, prompt: Text("10.0.0.53, 10.0.0.54"))
                    .textFieldStyle(.plain)
                    .fieldChrome()
                    .frame(maxWidth: 360)
            }

            SettingsRow("DNS domains") {
                TextField("", text: $draft.dnsDomains, prompt: Text("internal.example, corp.local"))
                    .textFieldStyle(.plain)
                    .fieldChrome()
                    .frame(maxWidth: 360)
            }

            SettingsNote("Configured domains are resolved only by this profile's DNS servers. VPN-advertised DNS is ignored. Leave both fields empty to make no DNS changes.")
        }
    }

    private var appearanceCard: some View {
        SettingsCard("Appearance", symbol: "paintpalette", tint: draft.accent.tint, dense: true, fillsHeight: !isEditing) {
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

    private enum EditorStep: Int, CaseIterable, Identifiable {
        case connection
        case authentication
        case network
        case appearance

        var id: Self { self }

        var title: String {
            switch self {
            case .connection: "Connection"
            case .authentication: "Authentication"
            case .network: "Network"
            case .appearance: "Appearance"
            }
        }
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

    // MARK: - Actions

    private func move(to step: EditorStep) {
        guard step != currentStep else { return }
        if step.rawValue > currentStep.rawValue {
            for rawValue in currentStep.rawValue..<step.rawValue {
                guard let intermediate = EditorStep(rawValue: rawValue), validate(intermediate) else { return }
            }
        }
        withAnimation(Theme.Motion.state) { currentStep = step }
    }

    private func moveForward() {
        guard validate(currentStep),
              let next = EditorStep(rawValue: currentStep.rawValue + 1) else { return }
        withAnimation(Theme.Motion.state) { currentStep = next }
    }

    private func moveBack() {
        guard let previous = EditorStep(rawValue: currentStep.rawValue - 1) else { return }
        withAnimation(Theme.Motion.state) { currentStep = previous }
    }

    private func cancel() {
        ConfigurationImporter.removeManagedOpenVPNConfiguration(at: temporaryConfigurationPath)
        temporaryConfigurationPath = nil
        dismiss()
    }

    private func importOpenVPNConfiguration(_ result: Result<[URL], Error>) {
        do {
            guard let url = try result.get().first else { return }
            let accessed = url.startAccessingSecurityScopedResource()
            defer { if accessed { url.stopAccessingSecurityScopedResource() } }

            let imported = try ConfigurationImporter.profile(from: url)
            guard imported.provider == .openVPN else {
                validationMessage = "Choose an OpenVPN configuration file."
                return
            }

            ConfigurationImporter.removeManagedOpenVPNConfiguration(at: temporaryConfigurationPath)
            let enteredName = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
            let selectedAccent = draft.accent
            draft = ProfileDraft(profile: imported)
            if !enteredName.isEmpty { draft.name = enteredName }
            draft.accent = selectedAccent
            temporaryConfigurationPath = imported.configurationPath
        } catch {
            validationMessage = error.localizedDescription
        }
    }

    private func validate(_ step: EditorStep) -> Bool {
        let message: String?
        switch step {
        case .connection:
            if draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                message = "Give the profile a name."
            } else if draft.provider == .openVPN && draft.configurationPath.isEmpty {
                message = "Choose an OpenVPN configuration file."
            } else if draft.provider != .openVPN && draft.server.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                message = "Enter the VPN server."
            } else {
                message = nil
            }
        case .network:
            let hasDNSServers = !draft.list(draft.dnsServers).isEmpty
            let hasDNSDomains = !draft.list(draft.dnsDomains).isEmpty
            message = hasDNSServers == hasDNSDomains
                ? nil
                : "Split DNS requires both DNS servers and DNS domains. Leave both empty if this VPN should not change DNS."
        case .authentication, .appearance:
            message = nil
        }

        guard let message else { return true }
        withAnimation(Theme.Motion.state) { currentStep = step }
        validationMessage = message
        return false
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
        for step in EditorStep.allCases {
            guard validate(step) else { return }
        }

        let profile = draft.makeProfile(id: existingProfile?.id ?? UUID())
        if existingProfile == nil {
            controller.add(profile)
        } else {
            controller.replace(profile)
        }
        if existingProfile?.configurationPath != profile.configurationPath {
            ConfigurationImporter.removeManagedOpenVPNConfiguration(at: existingProfile?.configurationPath)
        }
        if temporaryConfigurationPath != profile.configurationPath {
            ConfigurationImporter.removeManagedOpenVPNConfiguration(at: temporaryConfigurationPath)
        }
        didSave = true
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
