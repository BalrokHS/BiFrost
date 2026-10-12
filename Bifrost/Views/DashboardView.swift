import SwiftUI

struct DashboardView: View {
    @Environment(VPNController.self) private var controller
    let openSettings: () -> Void

    @State private var showingNewProfile = false

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
        }
        .navigationTitle("Dashboard")
        .sheet(isPresented: $showingNewProfile) {
            ProfileEditorView()
                .environment(controller)
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

            if !controller.disconnectableProfiles.isEmpty {
                Button("Disconnect all") { controller.disconnectAll() }
                    .buttonStyle(.quietCompact)
            }

            Button {
                showingNewProfile = true
            } label: {
                Label("Add profile", systemImage: "plus")
            }
            .buttonStyle(.accentCompact)
            .keyboardShortcut("n", modifiers: .command)
            .help("Add a VPN profile")

            Button(action: openSettings) {
                Label("Settings", systemImage: "gearshape")
            }
            .buttonStyle(.iconAction)
            .keyboardShortcut(",", modifiers: .command)
            .help("Settings")
        }
        // Clears the window controls, which sit over the hidden title bar.
        .padding(.leading, 78)
        .padding(.trailing, Theme.Metrics.gutter)
        .frame(height: Theme.Metrics.headerHeight)
        .animation(Theme.Motion.state, value: controller.disconnectableProfiles.count)
    }

    // MARK: - Profiles

    private var profileList: some View {
        VStack(spacing: 0) {
            ForEach(Array(controller.profiles.enumerated()), id: \.element.id) { index, profile in
                if index > 0 { HairlineRule() }
                VPNProfileRow(profile: profile)
            }
        }
        .mattePanel()
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("No VPN profiles yet")
                    .font(.panelTitle)
                    .foregroundStyle(Theme.Palette.textPrimary)

                Text("Create one from scratch, or import an existing OpenVPN, OpenConnect or OpenFortiVPN configuration.")
                    .font(.caption12)
                    .foregroundStyle(Theme.Palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: 420, alignment: .leading)

            Button {
                showingNewProfile = true
            } label: {
                Label("Add profile", systemImage: "plus")
            }
            .buttonStyle(.accent)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .mattePanel()
    }
}
