import SwiftUI

struct DashboardView: View {
    @Environment(VPNController.self) private var controller
    let openSettings: () -> Void

    @State private var showingNewProfile = false

    private let columns = [
        GridItem(.adaptive(minimum: 330, maximum: 460), spacing: 16)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                header
                    .appearLift(0)

                if controller.profiles.isEmpty {
                    emptyState
                        .appearLift(0.04)
                } else {
                    GlassEffectContainer(spacing: 16) {
                        LazyVGrid(columns: columns, alignment: .leading, spacing: 16) {
                            ForEach(controller.profiles) { profile in
                                VPNCard(profile: profile)
                            }
                        }
                    }
                    .appearLift(0.04)
                }
            }
            .padding(.horizontal, 38)
            .padding(.top, 34)
            .padding(.bottom, 44)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollContentBackground(.hidden)
        .navigationTitle("Dashboard")
        .sheet(isPresented: $showingNewProfile) {
            ProfileEditorView()
                .environment(controller)
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .center, spacing: 24) {
            VStack(alignment: .leading, spacing: 2) {
                Image("BifrostFullLogo")
                    .resizable()
                    .scaledToFill()
                    .frame(width: 354, height: 99)
                    .clipped()
                    .accessibilityHidden(true)

                Text("Manage and connect to your private networks.")
                    .font(.system(size: 12.5, weight: .regular))
                    .foregroundStyle(Theme.Palette.textSecondary)
                    .padding(.leading, 25)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Bifrost. Manage and connect to your private networks.")

            Spacer(minLength: 24)

            HStack(spacing: 18) {
                if !controller.disconnectableProfiles.isEmpty {
                    Button("Disconnect all") { controller.disconnectAll() }
                        .buttonStyle(.quiet)
                }

                HStack(spacing: 16) {
                    Button {
                        showingNewProfile = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 18, weight: .medium))
                            .frame(width: 28, height: 28)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Theme.Palette.textPrimary)
                    .keyboardShortcut("n", modifiers: .command)
                    .help("Add a VPN profile")

                    Button(action: openSettings) {
                        Image(systemName: "gearshape")
                            .font(.system(size: 17, weight: .medium))
                            .frame(width: 28, height: 28)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Theme.Palette.textPrimary)
                    .keyboardShortcut(",", modifiers: .command)
                    .help("Settings")
                }
                .padding(.horizontal, 13)
                .padding(.vertical, 8)
                .glassEffect(
                    .regular
                        .tint(Theme.Palette.brand.opacity(0.16))
                        .interactive(),
                    in: Capsule()
                )
                .overlay(
                    Capsule()
                        .strokeBorder(Theme.Palette.brandBright.opacity(0.14), lineWidth: 1)
                )
            }
            .animation(Theme.Motion.state, value: controller.disconnectableProfiles.count)
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

}
