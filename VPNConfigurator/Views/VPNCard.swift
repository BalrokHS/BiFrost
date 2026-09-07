import SwiftUI

struct VPNCard: View {
    @Environment(VPNController.self) private var controller
    let profile: VPNProfile
    @State private var showingLogs = false

    var body: some View {
        let state = controller.state(for: profile)
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                Image(systemName: profile.provider.symbol)
                    .font(.title2)
                    .foregroundStyle(profile.accent.color)
                    .frame(width: 42, height: 42)
                    .background(profile.accent.color.opacity(0.12), in: .circle)

                VStack(alignment: .leading, spacing: 3) {
                    Text(profile.name)
                        .font(.title3.weight(.semibold))
                    Text(profile.provider.rawValue)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Circle()
                    .fill(state.color)
                    .frame(width: 9, height: 9)
                    .shadow(color: state.color.opacity(0.7), radius: 5)
                    .padding(.top, 8)
            }

            VStack(alignment: .leading, spacing: 8) {
                Label(profile.server, systemImage: "server.rack")
                Label(profile.authentication.rawValue, systemImage: "person.badge.key.fill")

                if let interfaceName = controller.interfaceName(for: profile) {
                    Label(interfaceName, systemImage: "network")
                        .foregroundStyle(.green)
                }
            }
            .font(.callout)
            .foregroundStyle(.secondary)
            .lineLimit(1)

            HStack {
                Text(state.rawValue)
                    .font(.callout.weight(.medium))
                    .foregroundStyle(state.color)

                Spacer()

                if !(controller.connectionLogs[profile.id] ?? "").isEmpty {
                    Button("Logs", systemImage: "terminal") {
                        showingLogs = true
                    }
                    .buttonStyle(.glass)
                }

                if state == .connecting || state == .disconnecting {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Button {
                        controller.toggle(profile)
                    } label: {
                        Label(
                            state.isDisconnectable ? "Disconnect" : "Connect",
                            systemImage: state.isDisconnectable ? "stop.fill" : "play.fill"
                        )
                    }
                    .buttonStyle(.glassProminent)
                    .tint(state.isDisconnectable ? .red : profile.accent.color)
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, minHeight: 230, alignment: .topLeading)
        .glassEffect(
            .regular.tint(state == .connected ? profile.accent.color.opacity(0.12) : nil).interactive(),
            in: RoundedRectangle(cornerRadius: 24, style: .continuous)
        )
        .animation(.smooth, value: state)
        .sheet(isPresented: $showingLogs) {
            VPNLogView(profileID: profile.id, profileName: profile.name)
                .environment(controller)
        }
    }
}

private struct VPNLogView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(VPNController.self) private var controller

    let profileID: VPNProfile.ID
    let profileName: String

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Connection log")
                        .font(.title2.bold())
                    Text(profileName)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }

            ScrollView {
                Text(controller.connectionLogs[profileID] ?? "Waiting for output…")
                    .font(.system(.callout, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .padding(14)
            }
            .background(.black.opacity(0.28), in: RoundedRectangle(cornerRadius: 12))
        }
        .padding(22)
        .frame(minWidth: 720, minHeight: 460)
    }
}
