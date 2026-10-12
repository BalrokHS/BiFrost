import SwiftUI

/// How the dashboard lays out its profiles.
enum ProfileLayout: String, CaseIterable {
    case list
    case grid

    var title: String {
        switch self {
        case .list: "List"
        case .grid: "Grid"
        }
    }

    var symbol: String {
        switch self {
        case .list: "list.bullet"
        case .grid: "square.grid.2x2"
        }
    }
}

/// One profile on the dashboard: identity, server, live status and the
/// actions, as a single row or as a card.
struct VPNProfileRow: View {
    @Environment(VPNController.self) private var controller
    let profile: VPNProfile
    var layout = ProfileLayout.list

    @State private var showingLogs = false
    @State private var showingEditor = false
    @State private var confirmingDeletion = false
    @State private var hovering = false

    private var state: ConnectionState { controller.state(for: profile) }
    private var hasLogs: Bool { !(controller.connectionLogs[profile.id] ?? "").isEmpty }

    var body: some View {
        Group {
            switch layout {
            case .list: row
            case .grid: card
            }
        }
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

    // MARK: - Layouts

    private var avatar: some View {
        ProfileAvatar(
            name: profile.name,
            icon: profile.icon,
            image: profile.icon == .image ? ProfileIconStore.load(profile.id) : nil,
            tint: profile.accent.tint,
            connected: state == .connected,
            size: layout == .grid ? 88 : 48
        )
    }

    private var row: some View {
        HStack(spacing: 12) {
            avatar

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
        .frame(minHeight: 64)
        .background(hovering ? Theme.Palette.surface : .clear)
    }

    /// A contact-card layout: a large avatar and the name on top, then
    /// one tile per action.
    private var card: some View {
        VStack(spacing: 14) {
            avatar
                .padding(.top, 6)

            VStack(spacing: 3) {
                Text(profile.name)
                    .font(.viewTitle)
                    .foregroundStyle(Theme.Palette.textPrimary)
                    .lineLimit(1)

                Text("\(profile.provider.rawValue) · \(profile.authentication.rawValue)")
                    .font(.caption11)
                    .foregroundStyle(Theme.Palette.textTertiary)
                    .lineLimit(1)

                Text(profile.server)
                    .font(.caption12)
                    .foregroundStyle(Theme.Palette.textSecondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .padding(.top, 4)
            }

            HStack(spacing: 6) {
                StatusLabel(state: state)
                if let since = controller.connectedSince(for: profile) {
                    ElapsedTime(since: since)
                        .font(.caption12)
                        .foregroundStyle(Theme.Palette.textSecondary)
                }
            }
            .frame(minHeight: 16)

            HStack(spacing: 8) {
                primaryTile
                Button { showingLogs = true } label: {
                    TileLabel(symbol: "text.alignleft", title: "Logs")
                }
                .buttonStyle(.plain)
                .disabled(!hasLogs)
                .opacity(hasLogs ? 1 : 0.45)
                .help(hasLogs ? "Show the connection log" : "No log yet")

                Menu {
                    profileMenuItems
                } label: {
                    TileLabel(symbol: "ellipsis", title: "More")
                }
                .menuIndicator(.hidden)
                .buttonStyle(.plain)
                .help("Profile actions")
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .mattePanel(fill: hovering ? Theme.Palette.surfaceRaised : Theme.Palette.surface)
    }

    @ViewBuilder
    private var primaryTile: some View {
        if state == .connecting || state == .disconnecting {
            TileLabel(symbol: nil, title: state.rawValue)
        } else if state.isDisconnectable {
            Button { controller.toggle(profile) } label: {
                TileLabel(symbol: "xmark", title: "Disconnect", tint: Theme.Palette.danger)
            }
            .buttonStyle(.plain)
        } else {
            Button { controller.toggle(profile) } label: {
                TileLabel(symbol: "bolt.fill", title: "Connect", tint: Theme.Palette.brand, filled: true)
            }
            .buttonStyle(.plain)
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
            primaryAction
                .frame(width: 96, alignment: .trailing)
            logsButton
            profileMenu
        }
    }

    @ViewBuilder
    private var primaryAction: some View {
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

    private var logsButton: some View {
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
    }

    @ViewBuilder
    private var profileMenuItems: some View {
        Button("Edit profile", systemImage: "pencil") {
            showingEditor = true
        }
        Button("Delete profile", systemImage: "trash", role: .destructive) {
            confirmingDeletion = true
        }
        .disabled(!canDelete)
    }

    private var profileMenu: some View {
        Menu {
            profileMenuItems
        } label: {
            Label("Profile actions", systemImage: "ellipsis")
        }
        .menuIndicator(.hidden)
        .buttonStyle(.iconAction)
        .help("Profile actions")
    }

    private var canDelete: Bool {
        state == .disconnected || state == .failed
    }
}

/// An action tile on a profile card: an icon over a short label. `filled`
/// marks the one primary action.
private struct TileLabel: View {
    let symbol: String?
    let title: String
    var tint: Color = Theme.Palette.textSecondary
    var filled = false

    @State private var hovering = false

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Theme.Radius.panel, style: .continuous)
        VStack(spacing: 4) {
            if let symbol {
                Image(systemName: symbol)
                    .font(.system(size: 14, weight: .semibold))
            } else {
                ProgressView()
                    .controlSize(.small)
                    .scaleEffect(0.7)
            }
            Text(title)
                .font(.caption11)
                .lineLimit(1)
        }
        .foregroundStyle(filled ? Theme.Palette.textPrimary : tint)
        .frame(maxWidth: .infinity, minHeight: 52)
        .background(shape.fill(filled ? tint : (hovering ? Theme.Palette.surfaceActive : Theme.Palette.surfaceRaised)))
        .contentShape(shape)
        .onHover { hovering = $0 }
        .animation(Theme.Motion.hover, value: hovering)
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
