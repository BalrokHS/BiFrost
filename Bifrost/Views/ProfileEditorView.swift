import LocalAuthentication
import SwiftUI
import UniformTypeIdentifiers

struct ProfileEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(VPNController.self) private var controller

    private let existingProfile: VPNProfile?
    @State private var draft: ProfileDraft
    @State private var validationMessage: String?
    @State private var savedPasswordState = SavedPasswordState.checking
    @State private var revealedPassword: String?
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
                VStack(spacing: 14) {
                    connectionCard.id(EditorStep.connection)
                    authenticationCard.id(EditorStep.authentication)
                    networkCard.id(EditorStep.network)
                    appearanceCard.id(EditorStep.appearance)
                }
                .frame(maxWidth: 760)
                .padding(.horizontal, 28)
                .padding(.vertical, 20)
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
            .transition(.opacity)
            .frame(maxWidth: 760)
            .padding(.horizontal, 28)
            .padding(.vertical, 20)
            .frame(maxWidth: .infinity)
        }
        .scrollContentBackground(.hidden)
    }

    // MARK: - Chrome

    private var sheetHeader: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(existingProfile == nil ? "New VPN profile" : "Edit VPN profile")
                    .font(.viewTitle)
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
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
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
                                .fill(step.rawValue <= currentStep.rawValue ? Theme.Palette.brand.opacity(0.20) : Theme.Palette.surface)
                                .frame(width: 30, height: 30)
                            Circle()
                                .strokeBorder(step.rawValue <= currentStep.rawValue ? Theme.Palette.brand : Theme.Palette.hairlineBright)
                                .frame(width: 30, height: 30)
                            if step.rawValue < currentStep.rawValue {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 11, weight: .bold))
                            } else {
                                Text("\(step.rawValue + 1)")
                                    .font(.system(size: 11, weight: .semibold))
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
                        .fill(step.rawValue < currentStep.rawValue ? Theme.Palette.brand : Theme.Palette.hairline)
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
                    .buttonStyle(.accent)
                    .keyboardShortcut(.defaultAction)
            } else {
                Button("Continue", systemImage: "chevron.right") { moveForward() }
                    .buttonStyle(.accent)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    // MARK: - Sections

    private var connectionCard: some View {
        SettingsCard("Connection", dense: true, fillsHeight: !isEditing) {
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
                    tint: Theme.Palette.brand,
                    title: \.rawValue,
                    symbol: \.symbol
                )
            }

            HairlineRule()

            if draft.provider == .openVPN {
                SettingsRow("Imported profile") {
                    HStack(spacing: 9) {
                        Text(openVPNImportName)
                            .font(.caption12)
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
        SettingsCard("Authentication", dense: true, fillsHeight: !isEditing) {
            VStack(alignment: .leading, spacing: 7) {
                Text("Method")
                    .font(.body13)
                    .foregroundStyle(Theme.Palette.textPrimary)

                ChipPicker(
                    options: availableAuthenticationMethods,
                    selection: $draft.authentication,
                    tint: Theme.Palette.brand,
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

            SettingsNote(draft.authentication == .passwordAndOTP && draft.provider == .openFortiVPN
                         ? "Passwords can be saved in macOS Keychain. Bifrost connects first and asks for the code when the server sends one. Codes are never saved."
                         : "Passwords can be saved in macOS Keychain when you connect. OTP values are never saved.")

            if let profile = existingProfile, profile.authentication != .saml {
                HairlineRule()

                switch savedPasswordState {
                case .checking:
                    Label("Checking Keychain…", systemImage: "key")
                        .font(.caption12)
                        .foregroundStyle(Theme.Palette.textTertiary)
                case .available:
                    HStack(spacing: 8) {
                        if let revealedPassword {
                            Text(revealedPassword)
                                .font(.body13)
                                .foregroundStyle(Theme.Palette.textPrimary)
                                .textSelection(.enabled)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        } else {
                            Label("A password is saved in your Keychain", systemImage: "key.fill")
                                .font(.caption12)
                                .foregroundStyle(Theme.Palette.textSecondary)
                        }
                        Spacer()
                        Button(revealedPassword == nil ? "Show" : "Hide") {
                            if revealedPassword == nil {
                                revealSavedPassword(profile.id)
                            } else {
                                revealedPassword = nil
                            }
                        }
                        .buttonStyle(.quietCompact)
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
        SettingsCard("Network", dense: true, fillsHeight: !isEditing) {
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

            SettingsRow(
                "Keep-alive host",
                detail: "Bifrost pings this address through the tunnel every minute while connected, so the gateway's idle timeout does not end it. Leave empty to turn it off."
            ) {
                TextField("", text: $draft.keepAliveHost, prompt: Text("10.0.0.53"))
                    .textFieldStyle(.plain)
                    .fieldChrome()
                    .frame(maxWidth: 360)
            }

            SettingsNote("Configured domains are resolved only by this profile's DNS servers. VPN-advertised DNS is ignored. Leave both fields empty to make no DNS changes.")
        }
    }

    private var appearanceCard: some View {
        SettingsCard("Appearance", dense: true, fillsHeight: !isEditing) {
            SettingsRow(
                "Icon",
                detail: "Shown on the profile row. Without a picture, Bifrost draws an avatar from the profile name."
            ) {
                HStack(spacing: 12) {
                    ProfileAvatar(
                        name: draft.name,
                        icon: draft.icon,
                        image: draft.iconImage,
                        tint: draft.accent.tint,
                        size: 48
                    )
                    ChipPicker(
                        options: IconKind.allCases,
                        selection: iconKind,
                        tint: Theme.Palette.brand,
                        title: \.rawValue,
                        symbol: nil
                    )
                }
            }

            switch draft.icon {
            case .avatar:
                EmptyView()
            case .symbol(let selected):
                LazyVGrid(columns: Array(repeating: GridItem(.fixed(32), spacing: 6), count: 7), alignment: .leading, spacing: 6) {
                    ForEach(ProfileIcon.symbols, id: \.self) { name in
                        SymbolChoice(name: name, isSelected: name == selected) {
                            withAnimation(Theme.Motion.state) { draft.icon = .symbol(name) }
                        }
                    }
                }
            case .image:
                HStack(spacing: 8) {
                    Button(draft.iconImage == nil ? "Choose image" : "Replace image") {
                        chooseIcon()
                    }
                    .buttonStyle(.quietCompact)

                    if draft.iconImage != nil {
                        Button("Remove image") {
                            withAnimation(Theme.Motion.state) {
                                draft.iconImage = nil
                                draft.icon = .avatar
                            }
                        }
                        .buttonStyle(.quietCompact)
                    }

                    Text("PNG, JPEG or HEIC. It is cropped to a square.")
                        .font(.caption11)
                        .foregroundStyle(Theme.Palette.textTertiary)
                }
            }

            HairlineRule()

            SettingsRow("Accent", detail: "Colours this profile's icon and its background wave while it is connected.") {
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

    private enum IconKind: String, CaseIterable {
        case avatar = "Avatar"
        case symbol = "Symbol"
        case image = "Picture"
    }

    private var iconKind: Binding<IconKind> {
        Binding {
            switch draft.icon {
            case .avatar: .avatar
            case .symbol: .symbol
            case .image: .image
            }
        } set: { kind in
            switch kind {
            case .avatar: draft.icon = .avatar
            case .symbol:
                if case .symbol = draft.icon { return }
                draft.icon = .symbol(ProfileIcon.symbols[0])
            case .image: draft.icon = .image
            }
        }
    }

    /// A plain open panel: a second `.fileImporter` in the same view tree never presents.
    private func chooseIcon() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.message = "Choose a picture for this profile"
        panel.prompt = "Choose"
        guard panel.runModal() == .OK, let url = panel.url else { return }

        guard let image = NSImage(contentsOf: url), image.isValid, image.size.width > 0 else {
            validationMessage = "That file is not an image Bifrost can read. Choose a PNG, JPEG or HEIC file."
            return
        }
        // Normalise now so the preview matches what will be stored.
        guard let data = ProfileIconStore.normalizedPNG(from: image), let square = NSImage(data: data) else {
            validationMessage = "That image could not be used. Choose a different one."
            return
        }
        withAnimation(Theme.Motion.state) {
            draft.iconImage = square
            draft.icon = .image
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
            let selectedIcon = draft.icon
            let selectedIconImage = draft.iconImage
            draft = ProfileDraft(profile: imported)
            if !enteredName.isEmpty { draft.name = enteredName }
            draft.accent = selectedAccent
            draft.icon = selectedIcon
            draft.iconImage = selectedIconImage
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
            if message == nil, !VPNKeepAlive.isValid(host: draft.keepAliveHost) {
                validationMessage = "Enter the keep-alive host as an IP address or host name, or leave it empty."
                withAnimation(Theme.Motion.state) { currentStep = step }
                return false
            }
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

    private func revealSavedPassword(_ profileID: VPNProfile.ID) {
        Task {
            let context = LAContext()
            do {
                try await context.evaluatePolicy(
                    .deviceOwnerAuthentication,
                    localizedReason: "reveal the saved VPN password"
                )
                revealedPassword = try controller.savedPassword(for: profileID)
            } catch let error as LAError where error.code == .userCancel
                || error.code == .appCancel
                || error.code == .systemCancel {
                return
            } catch {
                validationMessage = error.localizedDescription
            }
        }
    }

    private func forgetSavedPassword(_ profileID: VPNProfile.ID) {
        do {
            try controller.removeSavedPassword(for: profileID)
            revealedPassword = nil
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
        if profile.icon == .image, let image = draft.iconImage {
            do {
                try ProfileIconStore.save(image, for: profile.id)
            } catch {
                validationMessage = "The icon could not be saved. Choose a different image or use an avatar."
                return
            }
        } else {
            ProfileIconStore.remove(for: profile.id)
        }
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
                    .padding(.horizontal, 10)
                    .frame(minHeight: 28)
                    .background {
                        let shape = RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous)
                        shape.fill(isSelected ? tint.opacity(0.18) : Theme.Palette.surface)
                            .overlay(
                                shape.strokeBorder(
                                    isSelected ? tint.opacity(0.6) : Theme.Palette.hairline,
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
                .fill(accent.tint)
                .frame(width: 16, height: 16)
                .padding(4)
                .overlay(
                    Circle().strokeBorder(
                        isSelected ? Theme.Palette.textPrimary : (hovering ? Theme.Palette.hairlineBright : .clear),
                        lineWidth: 1.5
                    )
                )
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .animation(Theme.Motion.hover, value: hovering)
        .help(accent.rawValue.capitalized)
    }
}

private struct SymbolChoice: View {
    let name: String
    let isSelected: Bool
    let action: () -> Void

    @State private var hovering = false

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous)
        Button(action: action) {
            Image(systemName: name)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(isSelected ? Theme.Palette.textPrimary : Theme.Palette.textSecondary)
                .frame(width: 32, height: 32)
                .background(shape.fill(isSelected ? Theme.Palette.surfaceActive : (hovering ? Theme.Palette.surfaceHover : Theme.Palette.surface)))
                .overlay(shape.strokeBorder(isSelected ? Theme.Palette.brand : Theme.Palette.hairline, lineWidth: 1))
                .contentShape(shape)
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .animation(Theme.Motion.hover, value: hovering)
        .accessibilityLabel(name)
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
    var keepAliveHost = ""
    var accent = ProfileAccent.blue
    var icon = ProfileIcon.avatar
    /// The picture chosen in the editor, written to disk only when the profile is saved.
    var iconImage: NSImage?

    init(profile: VPNProfile?) {
        guard let profile else { return }
        icon = profile.icon
        if profile.icon == .image { iconImage = ProfileIconStore.load(profile.id) }
        name = profile.name
        server = profile.server
        provider = profile.provider
        authentication = profile.authentication
        username = profile.username
        configurationPath = profile.configurationPath ?? ""
        serverCertificatePin = profile.serverCertificatePin ?? ""
        dnsServers = profile.dnsServers.joined(separator: ", ")
        dnsDomains = profile.dnsDomains.joined(separator: ", ")
        keepAliveHost = profile.keepAliveHost ?? ""
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
            keepAliveHost: optional(keepAliveHost),
            accent: accent,
            // A picture icon with no picture falls back to the avatar.
            icon: icon == .image && iconImage == nil ? .avatar : icon
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
