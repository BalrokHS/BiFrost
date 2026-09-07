import SwiftUI
import UniformTypeIdentifiers

struct DashboardView: View {
    @Environment(VPNController.self) private var controller
    let openSettings: () -> Void

    @State private var showingNewProfile = false
    @State private var showingImporter = false
    @State private var importError: String?

    private let columns = [
        GridItem(.adaptive(minimum: 330, maximum: 460), spacing: 16)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                hero
                    .appearLift(0)

                if controller.profiles.isEmpty {
                    emptyState
                        .appearLift(0.04)
                } else {
                    VStack(alignment: .leading, spacing: 14) {
                        SectionHeading(title: "Connections", count: controller.profiles.count)

                        GlassEffectContainer(spacing: 16) {
                            LazyVGrid(columns: columns, alignment: .leading, spacing: 16) {
                                ForEach(controller.profiles) { profile in
                                    VPNCard(profile: profile)
                                }
                            }
                        }
                    }
                    .appearLift(0.04)
                }
            }
            .padding(.horizontal, 34)
            .padding(.top, 38)
            .padding(.bottom, 44)
            .frame(maxWidth: 1180, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .scrollContentBackground(.hidden)
        .navigationTitle("Dashboard")
        .sheet(isPresented: $showingNewProfile) {
            ProfileEditorView()
                .environment(controller)
        }
        .fileImporter(
            isPresented: $showingImporter,
            allowedContentTypes: [.data, .plainText],
            allowsMultipleSelection: true,
            onCompletion: importFiles
        )
        .alert("Import failed", isPresented: Binding(
            get: { importError != nil },
            set: { if !$0 { importError = nil } }
        )) {
            Button("OK") { importError = nil }
        } message: {
            Text(importError ?? "")
        }
    }

    // MARK: - Hero

    private var hero: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image("BifrostMark")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 25, height: 25)
                    .accessibilityHidden(true)

                Text("Bifrost")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.Palette.textPrimary)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Bifrost")

            HStack(alignment: .bottom, spacing: 20) {
                VStack(alignment: .leading, spacing: 9) {
                    Text("Your private networks")
                        .font(.heroTitle)
                        .tracking(-0.4)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Theme.Palette.textPrimary, Theme.Palette.textPrimary.opacity(0.68)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )

                    HStack(spacing: 8) {
                        StatusDot(state: aggregateState, size: 6)
                        Text(summary)
                            .font(.body13)
                            .foregroundStyle(Theme.Palette.textSecondary)
                    }
                }

                Spacer(minLength: 0)

                GlassEffectContainer(spacing: 10) {
                    HStack(spacing: 10) {
                    if !controller.disconnectableProfiles.isEmpty {
                        Button("Disconnect all") { controller.disconnectAll() }
                            .buttonStyle(.quiet)
                    }

                    Menu {
                        Button("New profile", systemImage: "plus") {
                            showingNewProfile = true
                        }
                        .keyboardShortcut("n", modifiers: .command)

                        Button("Import configuration", systemImage: "square.and.arrow.down") {
                            showingImporter = true
                        }
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 14, weight: .semibold))
                            .frame(width: 34, height: 34)
                    }
                    .menuIndicator(.hidden)
                    .buttonStyle(.glassProminent)
                    .buttonBorderShape(.circle)
                    .tint(Theme.Palette.brand)
                    .help("Add or import a VPN profile")

                    Button(action: openSettings) {
                        Image(systemName: "gearshape")
                            .font(.system(size: 13, weight: .medium))
                            .frame(width: 34, height: 34)
                    }
                    .buttonStyle(.glass)
                    .buttonBorderShape(.circle)
                    .keyboardShortcut(",", modifiers: .command)
                    .help("Settings")
                    }
                }
                .animation(Theme.Motion.state, value: controller.disconnectableProfiles.count)
            }
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 16) {
            IconBadge(
                symbol: "shield.slash",
                tint: Theme.Palette.brand,
                highlight: Theme.Palette.brandBright,
                size: 58
            )

            VStack(spacing: 6) {
                Text("No VPN profiles yet")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Theme.Palette.textPrimary)

                Text("Create one from scratch, or import an existing OpenVPN, OpenConnect or OpenFortiVPN configuration.")
                    .font(.body13)
                    .foregroundStyle(Theme.Palette.textSecondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 380)
            }

            Button {
                showingNewProfile = true
            } label: {
                Label("Add VPN", systemImage: "plus")
            }
            .buttonStyle(.accent(Theme.Palette.brand))
            .padding(.top, 2)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 62)
        .glassCard(interactive: false)
    }

    // MARK: - Copy

    /// One line that stands in for the whole grid, matching the aggregate dot.
    private var summary: String {
        let count = controller.connectedProfiles.count
        if controller.profiles.contains(where: { controller.state(for: $0) == .degraded }) {
            return "Some VPN connection states could not be confirmed."
        }
        if count == 0, !controller.busyProfiles.isEmpty { return "Checking or changing VPN connections…" }
        if count == 0 { return "No VPN connections are active." }
        return "\(count) VPN connection\(count == 1 ? " is" : "s are") active."
    }

    private var aggregateState: ConnectionState {
        let states = controller.profiles.map { controller.state(for: $0) }
        if states.contains(.degraded) { return .degraded }
        if states.contains(.connected) { return .connected }
        if states.contains(where: \.isBusy) { return .connecting }
        if states.contains(.failed) { return .failed }
        return .disconnected
    }

    private func importFiles(_ result: Result<[URL], Error>) {
        do {
            for url in try result.get() {
                let accessed = url.startAccessingSecurityScopedResource()
                defer { if accessed { url.stopAccessingSecurityScopedResource() } }
                try controller.importConfiguration(at: url)
            }
        } catch {
            importError = error.localizedDescription
        }
    }
}
