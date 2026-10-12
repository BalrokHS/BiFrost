import SwiftUI

struct DashboardView: View {
    @Environment(VPNController.self) private var controller
    @Environment(PrivilegedHelperManager.self) private var helperManager
    let openSettings: (SettingsDestination) -> Void

    @State private var showingNewProfile = false
    @State private var promptingForService = false
    @State private var inventory: EngineInventory?
    @AppStorage("profileLayout") private var layout = ProfileLayout.list

    var body: some View {
        VStack(spacing: 0) {
            header
            HairlineRule()

            ScrollView {
                Group {
                    if controller.profiles.isEmpty {
                        emptyState
                    } else {
                        profileList
                    }
                }
                .padding(Theme.Metrics.gutter)
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .scrollContentBackground(.hidden)
            .sheet(isPresented: $showingNewProfile) {
                ProfileEditorView()
                    .environment(controller)
            }
        }
        .background(alignment: .bottom) {
            ConnectionWaves(profiles: controller.connectedProfiles)
        }
        .navigationTitle("Dashboard")
        .alert("Enable VPN connections first", isPresented: $promptingForService) {
            Button("Cancel", role: .cancel) {}
            Button("Enable VPN connections") { enableService(thenAddProfile: true) }
        } message: {
            Text("Bifrost starts tunnels through a background connection service. Enable it, then add your profile. macOS may ask you to approve it in System Settings.")
        }
        .onChange(of: helperManager.isEnabled) { _, enabled in
            // The service came up while the prompt was open, so it is stale.
            if enabled { promptingForService = false }
        }
        .task(id: guideIsVisible && helperManager.isEnabled) {
            guard guideIsVisible, helperManager.isEnabled else { return }
            let inventory = inventory ?? EngineInventory(helper: helperManager)
            self.inventory = inventory
            inventory.refresh()
        }
    }

    // MARK: - Actions

    /// Adding a profile needs the connection service, so ask for it up front
    /// rather than letting the first connection fail later.
    private func addProfile() {
        helperManager.refreshStatus()
        if helperManager.isEnabled {
            showingNewProfile = true
        } else {
            promptingForService = true
        }
    }

    private func enableService(thenAddProfile: Bool = false) {
        helperManager.register()
        if thenAddProfile, helperManager.isEnabled {
            showingNewProfile = true
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 10) {
            BrandLockup()

            Rectangle()
                .fill(Theme.Palette.hairlineBright)
                .frame(width: 1, height: 16)

            Text("Profiles")
                .font(.viewTitle)
                .foregroundStyle(Theme.Palette.textPrimary)

            if !controller.profiles.isEmpty {
                Text("\(controller.profiles.count)")
                    .font(.caption12)
                    .monospacedDigit()
                    .foregroundStyle(Theme.Palette.textTertiary)
            }

            Spacer(minLength: 16)

            if !controller.profiles.isEmpty {
                layoutPicker
            }

            if !controller.disconnectableProfiles.isEmpty {
                Button("Disconnect all") { controller.disconnectAll() }
                    .buttonStyle(.quietCompact)
            }

            Button(action: addProfile) {
                Label("Add profile", systemImage: "plus")
            }
            .buttonStyle(.accentCompact)
            .keyboardShortcut("n", modifiers: .command)
            .help("Add a VPN profile")

            Button { openSettings(.general) } label: {
                Label("Settings", systemImage: "gearshape")
            }
            .buttonStyle(.iconAction)
            .keyboardShortcut(",", modifiers: .command)
            .help("Settings")
        }
        .padding(.horizontal, Theme.Metrics.gutter)
        .frame(height: Theme.Metrics.headerHeight)
        .animation(Theme.Motion.state, value: controller.disconnectableProfiles.count)
    }

    // MARK: - Profiles

    private var layoutPicker: some View {
        HStack(spacing: 2) {
            ForEach(ProfileLayout.allCases, id: \.self) { option in
                Button {
                    withAnimation(Theme.Motion.state) { layout = option }
                } label: {
                    Label(option.title, systemImage: option.symbol)
                }
                .buttonStyle(.iconAction)
                .background(
                    RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous)
                        .fill(layout == option ? Theme.Palette.surfaceActive : .clear)
                )
                .help("\(option.title) view")
            }
        }
    }

    @ViewBuilder
    private var profileList: some View {
        switch layout {
        case .list:
            VStack(spacing: 0) {
                ForEach(Array(controller.profiles.enumerated()), id: \.element.id) { index, profile in
                    if index > 0 { HairlineRule() }
                    VPNProfileRow(profile: profile)
                }
            }
            .mattePanel()
        case .grid:
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 232, maximum: 320), spacing: 12, alignment: .top)],
                spacing: 12
            ) {
                ForEach(controller.profiles) { profile in
                    VPNProfileRow(profile: profile, layout: .grid)
                }
            }
        }
    }

    // MARK: - Getting started

    private var guideIsVisible: Bool { controller.profiles.isEmpty }

    private var serviceDone: Bool { helperManager.isEnabled }

    private var engineDone: Bool {
        inventory?.reports.contains { $0.state == .ready } == true
    }

    private var emptyState: some View {
        SettingsCard("Get started") {
            SettingsNote("Three steps to your first connection.")

            HairlineRule()

            guideStep(
                1,
                done: serviceDone,
                title: "Enable VPN connections",
                detail: "Turns on the background service Bifrost uses to start tunnels."
            ) {
                switch helperManager.status {
                case .requiresApproval:
                    guideButton("Approve in System Settings", primary: true) {
                        helperManager.openApprovalSettings()
                    }
                default:
                    guideButton("Enable VPN connections", primary: true) { enableService() }
                }
            }

            HairlineRule()

            guideStep(
                2,
                done: engineDone,
                title: "Approve a VPN client",
                detail: "Pick an installed OpenFortiVPN, OpenVPN or OpenConnect client that Bifrost may run."
            ) {
                guideButton("Open VPN engines", primary: serviceDone) { openSettings(.engines) }
            }

            HairlineRule()

            guideStep(
                3,
                done: false,
                title: "Add your first profile",
                detail: "Create one from scratch, or import an existing OpenVPN configuration."
            ) {
                guideButton("Add profile", primary: serviceDone && engineDone, action: addProfile)
            }
        }
    }

    /// Only the step the user should do next gets the accent.
    @ViewBuilder
    private func guideButton(_ title: String, primary: Bool, action: @escaping () -> Void) -> some View {
        if primary {
            Button(title, action: action).buttonStyle(.accentCompact)
        } else {
            Button(title, action: action).buttonStyle(.quietCompact)
        }
    }

    private func guideStep<Control: View>(
        _ number: Int,
        done: Bool,
        title: String,
        detail: String,
        @ViewBuilder control: @escaping () -> Control
    ) -> some View {
        HStack(alignment: .top, spacing: 12) {
            StepMarker(number: number, done: done)
                .padding(.top, 1)

            SettingsRow(title, detail: detail) {
                if !done { control() }
            }
        }
    }
}
