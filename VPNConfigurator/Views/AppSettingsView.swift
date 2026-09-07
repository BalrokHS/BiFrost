import SwiftUI

struct AppSettingsView: View {
    @Environment(PrivilegedHelperManager.self) private var helperManager
    @AppStorage("launchAtLogin") private var launchAtLogin = false
    @AppStorage("showNotifications") private var showNotifications = true
    @State private var inventory: EngineInventory?

    var body: some View {
        Form {
            Section("General") {
                Toggle("Launch at login", isOn: $launchAtLogin)
                Toggle("Show connection notifications", isOn: $showNotifications)
            }

            Section("DNS") {
                LabeledContent("Current mode", value: "Profile-configured split DNS")
                LabeledContent("VPN-advertised DNS", value: "Ignored")
                Text("Each connected profile owns resolver rules only for its configured domains. Public DNS remains unchanged.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Privileged connection service") {
                LabeledContent("Status") {
                    HStack(spacing: 7) {
                        Circle()
                            .fill(helperManager.status == .enabled ? .green : .secondary)
                            .frame(width: 8, height: 8)
                        Text(helperManager.statusTitle)
                    }
                }

                Text(helperManager.statusDetail)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack {
                    switch helperManager.status {
                    case .notRegistered:
                        Button("Register helper", systemImage: "lock.shield") {
                            helperManager.register()
                        }
                        .buttonStyle(.glassProminent)
                        .disabled(helperManager.isChangingRegistration)
                    case .requiresApproval:
                        Button("Open Login Items", systemImage: "gearshape") {
                            helperManager.openApprovalSettings()
                        }
                        .buttonStyle(.glassProminent)
                    case .enabled:
                        Button("Check health", systemImage: "waveform.path.ecg") {
                            helperManager.checkHealth()
                        }
                        .disabled(helperManager.isCheckingHealth || helperManager.isUpdatingHelper)

                        Button("Unregister", systemImage: "trash", role: .destructive) {
                            helperManager.unregister()
                        }
                        .disabled(helperManager.isChangingRegistration || helperManager.isUpdatingHelper)
                    case .notFound:
                        Button("Try registration", systemImage: "lock.shield") {
                            helperManager.register()
                        }
                        .buttonStyle(.glassProminent)
                    @unknown default:
                        EmptyView()
                    }

                    if helperManager.isCheckingHealth || helperManager.isChangingRegistration || helperManager.isUpdatingHelper {
                        ProgressView().controlSize(.small)
                    }

                    Spacer()

                    Button("Refresh", systemImage: "arrow.clockwise") {
                        helperManager.refreshStatus()
                    }
                }
            }

            Section("VPN engines") {
                if let inventory {
                    ForEach(inventory.reports) { report in
                        EngineRow(report: report, inventory: inventory)
                    }

                    HStack {
                        Text("VPN Configurator runs the clients you installed yourself, in place. Approving one pins its executable and every library it loads, and the helper rechecks those before each connection. A package upgrade replaces those files, so it asks you to approve again.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("Refresh", systemImage: "arrow.clockwise") {
                            inventory.refresh()
                        }
                        .disabled(inventory.isRefreshing)
                    }
                } else {
                    ProgressView().controlSize(.small)
                }
            }

            Section("Current safety boundary") {
                Text("Engines stay where their package manager installed them, which on macOS is a prefix your user account can write to. Approval pins their bytes so a silently replaced engine stops working instead of running as root, but it cannot stop an attacker who already runs code as you and races the moment between the check and the launch. OpenFortiVPN SAML browser handoff and profile-scoped macOS resolver rules are enabled. The embedded DNS proxy is not enabled yet.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Settings")
        .onAppear {
            helperManager.refreshStatus()
            let inventory = inventory ?? EngineInventory(helper: helperManager)
            self.inventory = inventory
            inventory.refresh()
        }
        .alert("Connection service", isPresented: Binding(
            get: { helperManager.errorMessage != nil },
            set: { if !$0 { helperManager.errorMessage = nil } }
        )) {
            Button("OK") { helperManager.errorMessage = nil }
        } message: {
            Text(helperManager.errorMessage ?? "")
        }
        .alert("VPN engines", isPresented: Binding(
            get: { inventory?.errorMessage != nil },
            set: { if !$0 { inventory?.errorMessage = nil } }
        )) {
            Button("OK") { inventory?.errorMessage = nil }
        } message: {
            Text(inventory?.errorMessage ?? "")
        }
        .alert("VPN engines", isPresented: Binding(
            get: { inventory?.successMessage != nil },
            set: { if !$0 { inventory?.successMessage = nil } }
        )) {
            Button("OK") { inventory?.successMessage = nil }
        } message: {
            Text(inventory?.successMessage ?? "")
        }
    }
}

private struct EngineRow: View {
    let report: EngineReport
    let inventory: EngineInventory

    private var indicator: Color {
        switch report.state {
        case .ready: .green
        case .changed: .orange
        case .notApproved, .unavailable: .secondary
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 7) {
                Circle()
                    .fill(indicator)
                    .frame(width: 8, height: 8)
                Text(report.engine.displayName)
                Spacer()
                Text(report.statusTitle)
                    .foregroundStyle(.secondary)
            }

            if let path = report.executablePath {
                Text(path)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
            if let version = report.version {
                Text(version)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text(report.detail)
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack {
                if report.canApprove {
                    Button(report.state == .changed ? "Approve again" : "Approve") {
                        inventory.approve(report.engine)
                    }
                    .buttonStyle(.glassProminent)
                    .disabled(inventory.busyEngine != nil)
                }
                if report.state == .ready || report.state == .changed {
                    Button("Withdraw approval", role: .destructive) {
                        inventory.revoke(report.engine)
                    }
                    .disabled(inventory.busyEngine != nil)
                }
                if inventory.busyEngine == report.engine {
                    ProgressView().controlSize(.small)
                }
            }
            .padding(.top, 2)
        }
        .padding(.vertical, 3)
    }
}
