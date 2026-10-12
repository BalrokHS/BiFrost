import AppKit
import SwiftUI

struct AppSettingsView: View {
    @Environment(PrivilegedHelperManager.self) private var helperManager

    @Environment(AppUpdateInstaller.self) private var updater
    @AppStorage("automaticUpdateChecks") private var automaticUpdateChecks = true

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
        case engines = "VPN engines"

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
        HStack(spacing: 8) {
            Button(action: onClose) {
                Label("Back to dashboard", systemImage: "chevron.left")
            }
            .buttonStyle(.iconAction)
            .keyboardShortcut(.cancelAction)
            .help("Back to dashboard")

            Text("Settings")
                .font(.viewTitle)
                .foregroundStyle(Theme.Palette.textPrimary)

            Spacer(minLength: 20)

            BrandLockup()
        }
        // Clears the window controls, which sit over the hidden title bar.
        .padding(.leading, 78)
        .padding(.trailing, Theme.Metrics.gutter)
        .frame(height: Theme.Metrics.headerHeight)
    }

    private var settingsRail: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(spacing: 2) {
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
        .padding(10)
        .frame(width: 200)
        .frame(maxHeight: .infinity)
        .background(Theme.Palette.sidebar)
    }

    @ViewBuilder
    private var content: some View {
        switch selection {
        case .engines:
            enginesContent
                .padding(Theme.Metrics.gutter)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        case .general:
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    generalContent
                }
                .padding(Theme.Metrics.gutter)
                .frame(maxWidth: 920, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
            .scrollContentBackground(.hidden)
        }
    }

    private func pageTitle(_ title: String, _ detail: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.viewTitle)
                .foregroundStyle(Theme.Palette.textPrimary)
            Text(detail)
                .font(.caption12)
                .foregroundStyle(Theme.Palette.textSecondary)
        }
    }

    private var generalContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            pageTitle("General", "Choose how the app behaves between sessions.")
            helperCard
            updateCard

            SettingsCard("Startup and notifications") {
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

            SettingsCard("Background checks") {
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
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .bottom, spacing: 16) {
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
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Engines")
                        .font(.panelTitle)
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
            .padding(8)
            .frame(width: 240)
            .frame(maxHeight: .infinity, alignment: .top)
            .mattePanel(fill: Theme.Palette.canvasDeep)

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
            .padding(16)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .mattePanel()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var helperCard: some View {
        SettingsCard("VPN connection service") {
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
        SettingsCard("Bifrost updates") {
            SettingsNote(updater.detail)
            HStack {
                if case .ready = updater.phase {
                    Button("Install and reopen") { updater.install() }.buttonStyle(.accent)
                } else if updater.available != nil {
                    Button("Download update") { updater.downloadAndStage() }
                        .buttonStyle(.accent)
                        .disabled(updater.isBusy || helperManager.isChangingRegistration)
                } else {
                    Button("Check for updates") { Task { await updater.checkForUpdates() } }
                        .buttonStyle(.quiet)
                        .disabled(updater.isBusy)
                }
                if case .ready = updater.phase {} else {
                    Button("Choose downloaded app…") { updater.chooseRelease() }
                        .buttonStyle(.quiet)
                        .disabled(updater.isBusy || helperManager.isChangingRegistration)
                }
                if updater.canCancel {
                    Button("Cancel update") { updater.cancel() }.buttonStyle(.quiet)
                }
            }
            Toggle("Check for updates automatically", isOn: $automaticUpdateChecks)
                .toggleStyle(.checkbox)
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
            HStack(spacing: 8) {
                Image(systemName: symbol)
                    .font(.system(size: 12, weight: .medium))
                    .frame(width: 16)
                    .foregroundStyle(selected ? Theme.Palette.textPrimary : Theme.Palette.textTertiary)
                Text(title)
                    .font(.rowTitle)
                    .foregroundStyle(selected ? Theme.Palette.textPrimary : Theme.Palette.textSecondary)
                Spacer()
            }
            .padding(.horizontal, 10)
            .frame(height: 32)
            .background {
                RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous)
                    .fill(selected ? Theme.Palette.surfaceActive : (hovering ? Theme.Palette.surfaceHover : .clear))
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .animation(Theme.Motion.hover, value: hovering)
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
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(selected ? Theme.Palette.textPrimary : Theme.Palette.textSecondary)
                    .frame(width: 16)

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
                StatusDot(tone: tone, size: 6)
            }
            .padding(.horizontal, 10)
            .frame(height: 40)
            .background(RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous).fill(selected ? Theme.Palette.surfaceActive : (hovering ? Theme.Palette.surfaceHover : .clear)))
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
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(report.engine.displayName)
                        .font(.viewTitle)
                        .foregroundStyle(Theme.Palette.textPrimary)
                    Text(report.version ?? "Version unavailable")
                        .font(.caption11)
                        .monospacedDigit()
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
                        .buttonStyle(.iconAction)
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
            .mattePanel(radius: Theme.Radius.control, fill: Theme.Palette.canvasDeep)

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
        .padding(10)
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
