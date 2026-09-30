import SwiftUI

struct MenuBarView: View {
    @Environment(VPNController.self) private var controller
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(.horizontal, 14)
                .padding(.top, 13)
                .padding(.bottom, 12)

            HairlineRule()

            if controller.profiles.isEmpty {
                Text("No profiles yet.")
                    .font(.caption12)
                    .foregroundStyle(Theme.Palette.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 18)
            } else {
                VStack(spacing: 2) {
                    ForEach(controller.profiles) { profile in
                        MenuProfileRow(
                            profile: profile,
                            state: controller.state(for: profile),
                            toggle: { toggle(profile) }
                        )
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 8)
            }

            HairlineRule()

            footer
                .padding(.horizontal, 12)
                .padding(.vertical, 11)
        }
        .frame(width: 336)
        .background(Theme.Palette.canvas)
        .preferredColorScheme(.dark)
    }

    private var header: some View {
        HStack(spacing: 11) {
            Image("BifrostMark")
                .resizable()
                .scaledToFit()
                .frame(width: 32, height: 32)
                .accessibilityHidden(true)

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
            .buttonStyle(.iconAction(size: 26))
            .help("Open Bifrost")
        }
    }

    private var footer: some View {
        HStack(spacing: 9) {
            Button("Disconnect all") { controller.disconnectAll() }
                .buttonStyle(QuietActionStyle(compact: true))
                .disabled(controller.disconnectableProfiles.isEmpty)

            Spacer(minLength: 0)

            Button("Quit") { NSApplication.shared.terminate(nil) }
                .buttonStyle(QuietActionStyle(compact: true))
        }
    }

    private func toggle(_ profile: VPNProfile) {
        controller.toggle(profile)
        if controller.authenticationRequest != nil {
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
            Circle()
                .fill(profile.accent.gradient)
                .frame(width: 7, height: 7)
                .opacity(state == .disconnected ? 0.35 : 1)

            VStack(alignment: .leading, spacing: 1) {
                Text(profile.name)
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(Theme.Palette.textPrimary)
                    .lineLimit(1)
                Text(state.shortLabel)
                    .font(.caption11)
                    .foregroundStyle(state.tone)
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
                .tint(profile.accent.tint)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous)
                .fill(hovering ? Theme.Palette.surface : .clear)
        )
        .onHover { hovering = $0 }
        .animation(Theme.Motion.hover, value: hovering)
    }
}
