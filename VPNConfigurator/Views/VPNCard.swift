import SwiftUI

struct VPNCard: View {
    @Environment(VPNController.self) private var controller
    let profile: VPNProfile

    @State private var showingLogs = false
    @State private var showingEditor = false
    @State private var confirmingDeletion = false
    @State private var hovering = false

    private var state: ConnectionState { controller.state(for: profile) }
    private var accent: Color { profile.accent.tint }
    private var hasLogs: Bool { !(controller.connectionLogs[profile.id] ?? "").isEmpty }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            fullBleedDivider
                .padding(.vertical, 15)

            metrics

            Spacer(minLength: 16)

            actions
        }
        .padding(18)
        .frame(maxWidth: .infinity, minHeight: 214, alignment: .topLeading)
        .background {
            // A soft bloom of the profile's own colour, lit only while the
            // tunnel is up. It is what makes a live card read across the room.
            RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                .fill(accent)
                .blur(radius: 32)
                .scaleEffect(0.92)
                .opacity(state == .connected ? 0.24 : 0)
        }
        .glassCard(tint: state == .connected ? accent.opacity(0.14) : nil)
        .overlay(alignment: .top) {
            // A lit top edge: present only on live cards, and faded at both
            // ends so it never looks like a border.
            LinearGradient(
                colors: [.clear, profile.accent.highlight.opacity(0.85), .clear],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(height: 1)
            .padding(.horizontal, 24)
            .opacity(state == .connected ? 1 : 0)
        }
        .shadow(color: .black.opacity(hovering ? 0.4 : 0.28), radius: hovering ? 20 : 13, y: hovering ? 8 : 5)
        .scaleEffect(hovering ? 1.006 : 1)
        .animation(Theme.Motion.state, value: state)
        .animation(Theme.Motion.hover, value: hovering)
        .onHover { hovering = $0 }
        .sheet(isPresented: $showingLogs) {
            VPNLogView(profileID: profile.id, profileName: profile.name, accent: accent)
                .environment(controller)
        }
        .sheet(isPresented: $showingEditor) {
            ProfileEditorView(profile: profile)
                .environment(controller)
        }
        .alert("Delete \(profile.name)?", isPresented: $confirmingDeletion) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) { controller.delete(profile.id) }
        } message: {
            Text("The saved profile and its Keychain password will be removed.")
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            IconBadge(
                symbol: profile.provider.symbol,
                tint: accent,
                highlight: profile.accent.highlight,
                size: 38
            )

            VStack(alignment: .leading, spacing: 3) {
                Text(profile.name)
                    .font(.cardTitle)
                    .foregroundStyle(Theme.Palette.textPrimary)
                    .lineLimit(1)

                Text(profile.provider.rawValue)
                    .font(.caption11)
                    .foregroundStyle(Theme.Palette.textTertiary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            StatusPill(state: state, compact: true)
        }
    }

    private var fullBleedDivider: some View {
        Rectangle()
            .fill(Theme.Palette.hairline)
            .frame(height: 1)
            .padding(.horizontal, -18)
    }

    // MARK: - Readouts

    private var metrics: some View {
        VStack(alignment: .leading, spacing: 8) {
            MetricRow(label: "Server", value: profile.server, symbol: "server.rack")

            MetricRow(
                label: "Auth",
                value: profile.authentication.rawValue,
                symbol: "person.badge.key.fill"
            )

            if let interfaceName = controller.interfaceName(for: profile) {
                MetricRow(
                    label: "Interface",
                    value: interfaceName,
                    tone: ConnectionState.connected.tone,
                    symbol: "network"
                )
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            if let since = controller.connectedSince(for: profile) {
                MetricRow(label: "Uptime", symbol: "clock") {
                    ElapsedTime(since: since)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            } else if profile.dnsDomains.isEmpty {
                MetricRow(
                    label: "Split DNS",
                    value: "Not configured",
                    tone: Theme.Palette.textTertiary,
                    symbol: "arrow.triangle.branch"
                )
            } else {
                MetricRow(
                    label: "Split DNS",
                    value: profile.dnsDomains.joined(separator: ", "),
                    symbol: "arrow.triangle.branch"
                )
            }
        }
    }

    // MARK: - Actions

    private var actions: some View {
        HStack(spacing: 9) {
            if state == .connecting || state == .disconnecting {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                        .scaleEffect(0.8)
                    Text(state.rawValue)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(state.tone)
                }
                .padding(.vertical, 8)
            } else if state.isDisconnectable {
                Button {
                    controller.toggle(profile)
                } label: {
                    Label("Disconnect", systemImage: "stop.fill")
                }
                .buttonStyle(.quietDestructive)
            } else {
                Button {
                    controller.toggle(profile)
                } label: {
                    Label("Connect", systemImage: "play.fill")
                }
                .buttonStyle(.accent(accent))
            }

            Spacer(minLength: 0)

            if hasLogs {
                Button {
                    showingLogs = true
                } label: {
                    Label("Logs", systemImage: "text.alignleft")
                }
                .buttonStyle(.iconAction)
                .help("Show the connection log")
            }

            Menu {
                Button("Edit profile", systemImage: "pencil") {
                    showingEditor = true
                }
                Button("Delete profile", systemImage: "trash", role: .destructive) {
                    confirmingDeletion = true
                }
                .disabled(!canDelete)
            } label: {
                Label("Profile actions", systemImage: "ellipsis")
            }
            .menuIndicator(.hidden)
            .buttonStyle(.iconAction)
            .help("Profile actions")
        }
    }

    private var canDelete: Bool {
        state == .disconnected || state == .failed
    }
}

private struct VPNLogView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(VPNController.self) private var controller

    let profileID: VPNProfile.ID
    let profileName: String
    let accent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .center, spacing: 12) {
                IconBadge(symbol: "text.alignleft", tint: accent, size: 34)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Connection log")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Theme.Palette.textPrimary)
                    Text(profileName)
                        .font(.caption12)
                        .foregroundStyle(Theme.Palette.textSecondary)
                }

                Spacer()

                Button("Done") { dismiss() }
                    .buttonStyle(.quiet)
                    .keyboardShortcut(.cancelAction)
            }

            ScrollView {
                Text(controller.connectionLogs[profileID] ?? "Waiting for output…")
                    .font(.system(size: 11.5, design: .monospaced))
                    .foregroundStyle(Theme.Palette.textSecondary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .padding(16)
            }
            .scrollContentBackground(.hidden)
            .mattePanel(radius: Theme.Radius.panel, fill: Theme.Palette.canvasDeep.opacity(0.6))
        }
        .padding(22)
        .frame(minWidth: 740, minHeight: 480)
        .background(Theme.Palette.canvas)
        .preferredColorScheme(.dark)
    }
}
