import SwiftUI

struct MenuBarView: View {
    @Environment(VPNController.self) private var controller
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "shield.lefthalf.filled")
                    .foregroundStyle(.blue)
                Text("VPN Configurator")
                    .font(.headline)
                Spacer()
                Text("\(controller.connectedProfiles.count) active")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Divider()

            ForEach(controller.profiles) { profile in
                let state = controller.state(for: profile)
                HStack {
                    Circle()
                        .fill(state.color)
                        .frame(width: 7, height: 7)
                    Text(profile.name)
                    Spacer()

                    if state == .connecting || state == .disconnecting {
                        ProgressView().controlSize(.mini)
                    } else {
                        Toggle(
                            "",
                            isOn: Binding(
                                get: { state.isDisconnectable },
                                set: { _ in
                                    controller.toggle(profile)
                                    if controller.authenticationRequest != nil {
                                        openWindow(id: "main")
                                        NSApplication.shared.activate()
                                    }
                                }
                            )
                        )
                        .toggleStyle(.switch)
                        .labelsHidden()
                        .controlSize(.small)
                    }
                }
            }

            Divider()

            HStack {
                Button("Disconnect all") {
                    controller.disconnectAll()
                }
                .disabled(controller.disconnectableProfiles.isEmpty)

                Spacer()

                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
            }
        }
        .padding(14)
        .frame(width: 330)
    }
}
