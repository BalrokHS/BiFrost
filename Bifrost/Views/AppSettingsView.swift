import AppKit
import SwiftUI

struct AppSettingsView: View {
    @Environment(PrivilegedHelperManager.self) private var helperManager

    @Environment(AppUpdateInstaller.self) private var updater

    let onClose: () -> Void

    @AppStorage("launchAtLogin") private var launchAtLogin = false
    @AppStorage("showNotifications") private var showNotifications = true
    @AppStorage("engineAutoRefresh") private var engineAutoRefresh = true
    @AppStorage("engineRefreshInterval") private var engineRefreshInterval = 300

    @State private var inventory: EngineInventory?
    @State private var selection: SettingsDestination = .general
    @State private var selectedEngine: VPNEngine = .openFortiVPN
    @State private var lastRefresh = Date.now

    private enum SettingsDestination: String, CaseIterable, Identifiable {
        case general = "General"
        case engines = "VPN Engines"

        var id: Self { self }

        var symbol: String {
            switch self {
            case .general: "slider.horizontal.3"
            case .engines: "cpu"
            }
        }

    }

    var body: some View {
        VStack(spacing: 0) {
            settingsHeader
            HairlineRule()

            HStack(alignment: .top, spacing: 0) {
                settingsRail
                HairlineRule().frame(width: 1)
                content
            }
        }
        .background(Theme.Palette.canvasDeep.opacity(0.22))
        .navigationTitle("Settings")
        .toggleStyle(.switch)
        .tint(Theme.Palette.brand)
        .onAppear {
            helperManager.refreshStatus()
            let inventory = inventory ?? EngineInventory(helper: helperManager)
            self.inventory = inventory
            refreshEngines()
        }
        .task(id: engineAutoRefresh) {
            guard engineAutoRefresh else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(engineRefreshInterval))
                guard !Task.isCancelled else { return }
                refreshEngines()
            }
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

    private var settingsHeader: some View {
        HStack(spacing: 14) {
            Button(action: onClose) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 11, weight: .semibold))
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.circle)
            .keyboardShortcut(.cancelAction)
            .help("Back to dashboard")

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 7) {
                    Text("Settings")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.Palette.textPrimary)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(Theme.Palette.textTertiary)
                    Text(selection.rawValue)
                        .font(.caption12)
                        .foregroundStyle(Theme.Palette.textSecondary)
                }

                Text("Configure how Bifrost works on this Mac.")
                    .font(.caption11)
                    .foregroundStyle(Theme.Palette.textTertiary)
            }

            Spacer(minLength: 20)

            BifrostWordmark(style: .monochrome, height: 30)
        }
        .padding(.leading, 28)
        .padding(.trailing, 22)
        .frame(height: 68)
    }

    private var settingsRail: some View {
        VStack(alignment: .leading, spacing: 14) {
            Eyebrow("Configuration")
                .padding(.horizontal, 10)

            VStack(spacing: 3) {
                ForEach(SettingsDestination.allCases) { destination in
                    SettingsRailRow(
                        title: destination.rawValue,
                        symbol: destination.symbol,
                        selected: selection == destination
                    ) {
                        withAnimation(Theme.Motion.state) { selection = destination }
                    }
                }
            }

            Spacer()
        }
        .padding(16)
        .frame(width: 224)
        .frame(maxHeight: .infinity)
        .background(Theme.Palette.canvasDeep.opacity(0.36))
    }

    @ViewBuilder
    private var content: some View {
        switch selection {
        case .engines:
            enginesContent
                .padding(.horizontal, 28)
                .padding(.vertical, 26)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        case .general:
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    generalContent
                }
                .padding(.horizontal, 28)
                .padding(.vertical, 26)
                .frame(maxWidth: 920, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
            .scrollContentBackground(.hidden)
        }
    }

    private func pageTitle(_ title: String, _ detail: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.heroTitle)
                .tracking(-0.5)
                .foregroundStyle(
                    LinearGradient(
                        colors: [Theme.Palette.textPrimary, Theme.Palette.textPrimary.opacity(0.62)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            Text(detail)
                .font(.body13)
                .foregroundStyle(Theme.Palette.textSecondary)
        }
    }

    private var generalContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            pageTitle("General", "Choose how the app behaves between sessions.")
            helperCard
            updateCard

            SettingsCard("Startup & notifications", symbol: "switch.2") {
                SettingsRow(
                    "Launch at login",
                    detail: "Keep your VPN profiles one click away after restarting your Mac."
                ) {
                    Toggle("", isOn: $launchAtLogin).labelsHidden()
                }
                HairlineRule()
                SettingsRow(
                    "Connection notifications",
                    detail: "Show a notification when a tunnel connects, disconnects, or fails."
                ) {
                    Toggle("", isOn: $showNotifications).labelsHidden()
                }
            }

            SettingsCard("Background checks", symbol: "arrow.triangle.2.circlepath", tint: Color(hex: 0x45CFBA)) {
                SettingsRow(
                    "Refresh engine status",
                    detail: "Recheck installed clients, versions and approval state automatically."
                ) {
                    Toggle("", isOn: $engineAutoRefresh).labelsHidden()
                }

                if engineAutoRefresh {
                    HairlineRule()
                    SettingsRow("Check interval") {
                        Picker("", selection: $engineRefreshInterval) {
                            Text("Every minute").tag(60)
                            Text("Every 5 minutes").tag(300)
                            Text("Every 15 minutes").tag(900)
                        }
                        .labelsHidden()
                        .frame(width: 150)
                    }
                }
            }
        }
    }

    private var enginesContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .bottom, spacing: 18) {
                pageTitle("VPN engines", "Manage installed clients and their privileged approval.")
                Spacer(minLength: 12)
                Button { refreshEngines() } label: {
                    HStack(spacing: 7) {
                        if inventory?.isRefreshing == true {
                            ProgressView().controlSize(.mini)
                        } else {
                            Image(systemName: "arrow.clockwise")
                        }
                        Text(inventory?.isRefreshing == true ? "Checking…" : "Refresh")
                    }
                }
                .buttonStyle(.quiet)
                .disabled(inventory?.isRefreshing == true)
            }

            engineWorkspace
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var engineWorkspace: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Engines")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.Palette.textPrimary)
                    Text(inventory?.isRefreshing == true ? "Checking status…" : "Last checked \(lastRefresh.formatted(date: .omitted, time: .shortened))")
                        .font(.caption11)
                        .foregroundStyle(Theme.Palette.textTertiary)
                }
                .padding(.horizontal, 9)
                .padding(.top, 5)

                if let inventory, !inventory.reports.isEmpty {
                    ForEach(inventory.reports) { report in
                        EnginePickerRow(report: report, selected: selectedEngine == report.engine) {
                            withAnimation(Theme.Motion.state) { selectedEngine = report.engine }
                        }
                    }
                } else {
                    HStack(spacing: 8) {
                        ProgressView().controlSize(.mini)
                        Text("Discovering clients…")
                            .font(.caption11)
                            .foregroundStyle(Theme.Palette.textSecondary)
                    }
                    .padding(18)
                }

                Spacer(minLength: 0)
            }
            .padding(10)
            .frame(width: 260)
            .frame(maxHeight: .infinity, alignment: .top)
            .mattePanel(radius: Theme.Radius.card, fill: Theme.Palette.canvasDeep.opacity(0.38))

            Group {
                if let report = inventory?.reports.first(where: { $0.engine == selectedEngine }),
                   let inventory {
                    EngineDetail(report: report, inventory: inventory)
                } else {
                    VStack(spacing: 10) {
                        ProgressView().controlSize(.small)
                        Text("Reading provider status…")
                            .font(.caption12)
                            .foregroundStyle(Theme.Palette.textSecondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .mattePanel(radius: Theme.Radius.card, fill: Theme.Palette.surface)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var helperCard: some View {
        SettingsCard("VPN connection service", symbol: "network") {
            SettingsRow(
                helperManager.isHealthy ? "Ready" : helperManager.statusTitle,
                detail: helperManager.isHealthy
                    ? "Bifrost can manage VPN connections on this Mac."
                    : helperManager.statusDetail
            ) {
                if helperManager.isCheckingHealth || helperManager.isChangingRegistration || helperManager.isUpdatingHelper {
                    ProgressView().controlSize(.small)
                }
            }
            switch helperManager.status {
            case .notRegistered, .notFound:
                Button("Enable VPN connections") { helperManager.register() }
                    .buttonStyle(.accent)
                    .disabled(helperManager.isChangingRegistration || updater.isBusy)
            case .requiresApproval:
                Button("Approve in System Settings") { helperManager.openApprovalSettings() }
                    .buttonStyle(.accent)
            case .enabled:
                DisclosureGroup("Troubleshooting") {
                    VStack(alignment: .leading, spacing: 10) {
                        SettingsNote(helperManager.helperVersion ?? "The service has not responded yet.")
                        HStack {
                            Button("Check connection service") { helperManager.checkHealth() }
                                .buttonStyle(.quiet)
                            Button("Disable VPN connections") { helperManager.unregister() }
                                .buttonStyle(.quietDestructive)
                        }
                        .disabled(helperManager.isCheckingHealth || helperManager.isChangingRegistration || updater.isBusy)
                    }
                    .padding(.top, 8)
                }
            @unknown default:
                EmptyView()
            }
        }
    }

    private var updateCard: some View {
        SettingsCard("Bifrost updates", symbol: "arrow.down.app") {
            SettingsNote(updater.detail)
            HStack {
                if case .ready = updater.phase {
                    Button("Install and reopen") { updater.install() }.buttonStyle(.accent)
                } else {
                    Button("Choose downloaded app…") { updater.chooseRelease() }
                        .buttonStyle(.quiet)
                        .disabled(updater.isBusy || helperManager.isChangingRegistration)
                }
                if updater.canCancel {
                    Button("Cancel update") { updater.cancel() }.buttonStyle(.quiet)
                }
            }
        }
        .alert("Bifrost update", isPresented: Binding(
            get: { updater.errorMessage != nil },
            set: { if !$0 { updater.errorMessage = nil } }
        )) {
            Button("OK") { updater.errorMessage = nil }
        } message: { Text(updater.errorMessage ?? "") }
    }

    private func refreshEngines() {
        inventory?.refresh()
        lastRefresh = .now
    }
}

private struct SettingsRailRow: View {
    let title: String
    let symbol: String
    let selected: Bool
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 9) {
                Image(systemName: symbol)
                    .font(.system(size: 13, weight: .medium))
                    .frame(width: 18)
                    .foregroundStyle(selected ? Theme.Palette.brandBright : Theme.Palette.textTertiary)
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(selected ? Theme.Palette.textPrimary : Theme.Palette.textSecondary)
                Spacer()
            }
            .padding(.horizontal, 12)
            .frame(height: 40)
            .background {
                RoundedRectangle(cornerRadius: Theme.Radius.control)
                    .fill(selected ? Theme.Palette.brand.opacity(0.18) : (hovering ? Theme.Palette.surfaceHover : .clear))
            }
            .overlay {
                RoundedRectangle(cornerRadius: Theme.Radius.control)
                    .strokeBorder(selected ? Theme.Palette.brand.opacity(0.28) : .clear)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .animation(Theme.Motion.hover, value: hovering)
    }
}

private struct StatusLabel: View {
    let title: String
    let tone: Color

    var body: some View {
        HStack(spacing: 6) {
            Circle().fill(tone).frame(width: 6, height: 6)
            Text(title).font(.caption11).foregroundStyle(tone)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Capsule().fill(tone.opacity(0.11)))
        .overlay(Capsule().strokeBorder(tone.opacity(0.2)))
    }
}

private struct EnginePickerRow: View {
    let report: EngineReport
    let selected: Bool
    let action: () -> Void
    @State private var hovering = false

    private var tone: Color {
        switch report.state {
        case .ready: ConnectionState.connected.tone
        case .changed, .notApproved: ConnectionState.connecting.tone
        case .unavailable: Theme.Palette.textTertiary
        }
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: engineSymbol)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(selected ? Theme.Palette.brandBright : Theme.Palette.textSecondary)
                    .frame(width: 28, height: 28)
                    .background(RoundedRectangle(cornerRadius: 8).fill(selected ? Theme.Palette.brand.opacity(0.16) : Theme.Palette.surface))

                VStack(alignment: .leading, spacing: 2) {
                    Text(report.engine.displayName)
                        .font(.rowTitle)
                        .foregroundStyle(Theme.Palette.textPrimary)
                    Text(report.version ?? report.statusTitle)
                        .font(.caption11)
                        .foregroundStyle(Theme.Palette.textTertiary)
                        .lineLimit(1)
                }
                Spacer(minLength: 4)
                Circle()
                    .fill(tone)
                    .frame(width: 6, height: 6)
                    .shadow(color: tone.opacity(report.state == .ready ? 0.7 : 0), radius: 4)
            }
            .padding(.horizontal, 9)
            .frame(height: 48)
            .background(RoundedRectangle(cornerRadius: Theme.Radius.row).fill(selected ? Theme.Palette.surfaceActive : (hovering ? Theme.Palette.surfaceHover : .clear)))
            .overlay(RoundedRectangle(cornerRadius: Theme.Radius.row).strokeBorder(selected ? Theme.Palette.hairlineBright : .clear))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .animation(Theme.Motion.hover, value: hovering)
    }

    private var engineSymbol: String {
        switch report.engine {
        case .openFortiVPN: "building.2.crop.circle"
        case .openVPN: "key.horizontal.fill"
        case .openConnect: "link"
        }
    }
}

private struct EngineDetail: View {
    let report: EngineReport
    let inventory: EngineInventory
    @State private var copied = false

    private var tone: Color {
        switch report.state {
        case .ready: ConnectionState.connected.tone
        case .changed, .notApproved: ConnectionState.connecting.tone
        case .unavailable: Theme.Palette.textTertiary
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                IconBadge(symbol: "terminal.fill", tint: tone, size: 34)
                VStack(alignment: .leading, spacing: 3) {
                    Text(report.engine.displayName)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.Palette.textPrimary)
                    Text(report.version ?? "Version unavailable")
                        .font(.readoutSmall)
                        .foregroundStyle(Theme.Palette.textTertiary)
                }
                Spacer()
                StatusLabel(title: report.statusTitle, tone: tone)
            }

            VStack(alignment: .leading, spacing: 0) {
                detailRow("Binary path", detail: report.executablePath ?? "Not discovered") {
                    if report.executablePath != nil {
                        Button {
                            copyPath()
                        } label: {
                            Image(systemName: copied ? "checkmark" : "doc.on.doc")
                        }
                        .buttonStyle(.iconAction(size: 25))
                        .help("Copy binary path")
                    }
                }
                HairlineRule()
                detailRow("Approval", detail: report.detail) { EmptyView() }
                if report.engine.needsVPNCScript {
                    HairlineRule()
                    detailRow("vpnc-script", detail: report.vpncScriptPath ?? "Not installed") { EmptyView() }
                }
            }
            .mattePanel(radius: Theme.Radius.row, fill: Theme.Palette.canvasDeep.opacity(0.34))

            HStack(spacing: 8) {
                if report.canApprove {
                    Button(report.state == .changed ? "Approve update" : "Approve engine") {
                        inventory.approve(report.engine)
                    }
                    .buttonStyle(.accent)
                    .disabled(inventory.busyEngine != nil)
                }
                if report.state == .ready || report.state == .changed {
                    Button("Withdraw approval") {
                        inventory.revoke(report.engine)
                    }
                    .buttonStyle(.quietDestructive)
                    .disabled(inventory.busyEngine != nil)
                }
                if inventory.busyEngine == report.engine {
                    ProgressView().controlSize(.small)
                }
                Spacer()
            }
        }
    }

    private func detailRow<Accessory: View>(
        _ title: String,
        detail: String,
        @ViewBuilder accessory: () -> Accessory
    ) -> some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.rowTitle).foregroundStyle(Theme.Palette.textPrimary)
                Text(detail)
                    .font(.caption11)
                    .foregroundStyle(Theme.Palette.textTertiary)
                    .lineLimit(2)
                    .truncationMode(.middle)
                    .textSelection(.enabled)
            }
            Spacer(minLength: 10)
            accessory()
        }
        .padding(12)
    }

    private func copyPath() {
        guard let path = report.executablePath else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(path, forType: .string)
        copied = true
        Task {
            try? await Task.sleep(for: .seconds(1.4))
            copied = false
        }
    }
}
