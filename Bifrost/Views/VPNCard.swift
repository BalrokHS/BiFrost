import SwiftUI

/// One profile in the dashboard list: identity, server, live status and the
/// actions, on a single row.
struct VPNProfileRow: View {
    @Environment(VPNController.self) private var controller
    let profile: VPNProfile

    @State private var showingLogs = false
    @State private var showingEditor = false
    @State private var confirmingDeletion = false
    @State private var hovering = false

    private var state: ConnectionState { controller.state(for: profile) }
    private var hasLogs: Bool { !(controller.connectionLogs[profile.id] ?? "").isEmpty }

    var body: some View {
        HStack(spacing: 12) {
            IconBadge(
                symbol: profile.provider.symbol,
                tint: state == .connected ? profile.accent.tint : Theme.Palette.textSecondary
            )

            identity
                .frame(minWidth: 120, maxWidth: .infinity, alignment: .leading)

            serverColumn
                .frame(minWidth: 120, maxWidth: .infinity, alignment: .leading)

            StatusLabel(state: state)
                .frame(width: 112, alignment: .leading)

            sessionColumn
                .frame(width: 76, alignment: .leading)

            actions
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(minHeight: 48)
        .background(hovering ? Theme.Palette.surface : .clear)
        .onHover { hovering = $0 }
        .animation(Theme.Motion.hover, value: hovering)
        .sheet(isPresented: $showingLogs) {
            VPNLogView(profileID: profile.id, profileName: profile.name)
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

    // MARK: - Columns

    private var identity: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(profile.name)
                .font(.rowTitle)
                .foregroundStyle(Theme.Palette.textPrimary)
                .lineLimit(1)

            Text("\(profile.provider.rawValue) · \(profile.authentication.rawValue)")
                .font(.caption11)
                .foregroundStyle(Theme.Palette.textTertiary)
                .lineLimit(1)
        }
    }

    private var serverColumn: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(profile.server)
                .font(.caption12)
                .foregroundStyle(Theme.Palette.textSecondary)
                .lineLimit(1)
                .truncationMode(.middle)

            Text(profile.dnsDomains.isEmpty
                 ? "No split DNS"
                 : "DNS: \(profile.dnsDomains.joined(separator: ", "))")
                .font(.caption11)
                .foregroundStyle(Theme.Palette.textTertiary)
                .lineLimit(1)
                .truncationMode(.tail)
        }
    }

    private var sessionColumn: some View {
        VStack(alignment: .leading, spacing: 2) {
            if let since = controller.connectedSince(for: profile) {
                ElapsedTime(since: since)
                    .font(.caption12)
                    .foregroundStyle(Theme.Palette.textSecondary)
            }

            if let interfaceName = controller.interfaceName(for: profile) {
                Text(interfaceName)
                    .font(.caption11)
                    .foregroundStyle(Theme.Palette.textTertiary)
                    .lineLimit(1)
            }
        }
    }

    // MARK: - Actions

    private var actions: some View {
        HStack(spacing: 4) {
            Group {
                if state == .connecting || state == .disconnecting {
                    HStack(spacing: 6) {
                        ProgressView()
                            .controlSize(.small)
                            .scaleEffect(0.7)
                        Text(state.rawValue)
                            .font(.caption12)
                            .foregroundStyle(Theme.Palette.textSecondary)
                    }
                } else if state.isDisconnectable {
                    Button("Disconnect") { controller.toggle(profile) }
                        .buttonStyle(.quietDestructive)
                } else {
                    Button("Connect") { controller.toggle(profile) }
                        .buttonStyle(.accent)
                }
            }
            .frame(width: 96, alignment: .trailing)

            Button {
                showingLogs = true
            } label: {
                Label("Logs", systemImage: "text.alignleft")
            }
            .buttonStyle(.iconAction)
            .help("Show the connection log")
            .opacity(hasLogs ? 1 : 0)
            .allowsHitTesting(hasLogs)
            .accessibilityHidden(!hasLogs)

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

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Connection log")
                        .font(.viewTitle)
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
            .mattePanel(radius: Theme.Radius.panel, fill: Theme.Palette.canvasDeep)
        }
        .padding(20)
        .frame(minWidth: 740, minHeight: 480)
        .background(Theme.Palette.canvas)
        .preferredColorScheme(.dark)
    }
}
