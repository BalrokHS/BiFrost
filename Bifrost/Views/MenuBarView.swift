import SwiftUI

struct MenuBarView: View {
    @Environment(VPNController.self) private var controller
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(.horizontal, 12)
                .padding(.vertical, 10)

            HairlineRule()

            if controller.profiles.isEmpty {
                Text("No profiles yet.")
                    .font(.caption12)
                    .foregroundStyle(Theme.Palette.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 14)
            } else {
                VStack(spacing: 0) {
                    ForEach(controller.profiles) { profile in
                        MenuProfileRow(
                            profile: profile,
                            state: controller.state(for: profile),
                            toggle: { toggle(profile) }
                        )
                    }
                }
                .padding(6)
            }

            HairlineRule()

            footer
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
        }
        .frame(width: 300)
        .background(Theme.Palette.canvas)
        .preferredColorScheme(.dark)
    }

    private var header: some View {
        HStack(spacing: 10) {
            BrandMark(height: 20)

            VStack(alignment: .leading, spacing: 1) {
                Text("Bifrost")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.Palette.textPrimary)
                Text(controller.connectedProfiles.isEmpty
                     ? "Nothing connected"
                     : "\(controller.connectedProfiles.count) active")
                    .font(.caption11)
                    .foregroundStyle(Theme.Palette.textTertiary)
            }

            Spacer(minLength: 0)

            Button {
                openWindow(id: "main")
                NSApplication.shared.activate()
            } label: {
                Label("Open", systemImage: "macwindow")
            }
            .buttonStyle(.iconAction)
            .help("Open Bifrost")
        }
    }

    private var footer: some View {
        HStack(spacing: 9) {
            Button("Disconnect all") { controller.disconnectAll() }
                .buttonStyle(.quietCompact)
                .disabled(controller.disconnectableProfiles.isEmpty)

            Spacer(minLength: 0)

            Button("Quit") { NSApplication.shared.terminate(nil) }
                .buttonStyle(.quietCompact)
        }
    }

    private func toggle(_ profile: VPNProfile) {
        controller.toggle(profile)
        if controller.authenticationRequest != nil || controller.serviceSetupRequired {
            openWindow(id: "main")
            NSApplication.shared.activate()
        }
    }
}

private struct MenuProfileRow: View {
    let profile: VPNProfile
    let state: ConnectionState
    let toggle: () -> Void

    @State private var hovering = false

    var body: some View {
        HStack(spacing: 10) {
            StatusDot(state: state)

            VStack(alignment: .leading, spacing: 1) {
                Text(profile.name)
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(Theme.Palette.textPrimary)
                    .lineLimit(1)
                Text(state.shortLabel)
                    .font(.caption11)
                    .foregroundStyle(Theme.Palette.textTertiary)
            }

            Spacer(minLength: 8)

            if state == .connecting || state == .disconnecting {
                ProgressView().controlSize(.mini)
            } else {
                Toggle("", isOn: Binding(
                    get: { state.isDisconnectable },
                    set: { _ in toggle() }
                ))
                .toggleStyle(.switch)
                .labelsHidden()
                .controlSize(.mini)
                .tint(Theme.Palette.brand)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous)
                .fill(hovering ? Theme.Palette.surfaceHover : .clear)
        )
        .onHover { hovering = $0 }
        .animation(Theme.Motion.hover, value: hovering)
    }
}
