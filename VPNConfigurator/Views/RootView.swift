import SwiftUI

struct RootView: View {
    @Environment(VPNController.self) private var controller
    @Environment(PrivilegedHelperManager.self) private var helperManager

    enum Destination: String, CaseIterable, Identifiable {
        case dashboard = "Dashboard"
        case profiles = "Profiles"
        case settings = "Settings"

        var id: Self { self }

        var symbol: String {
            switch self {
            case .dashboard: "square.grid.2x2"
            case .profiles: "shield.lefthalf.filled"
            case .settings: "gearshape"
            }
        }
    }

    @State private var selection: Destination? = .dashboard

    var body: some View {
        NavigationSplitView {
            List(Destination.allCases, selection: $selection) { destination in
                Label(destination.rawValue, systemImage: destination.symbol)
                    .tag(destination)
            }
            .navigationTitle("VPN Configurator")
            .navigationSplitViewColumnWidth(min: 190, ideal: 220)
        } detail: {
            switch selection ?? .dashboard {
            case .dashboard:
                DashboardView()
            case .profiles:
                ProfilesView()
            case .settings:
                AppSettingsView()
            }
        }
        .onChange(of: helperManager.isEnabled) { _, enabled in
            if enabled { controller.reconcileSessions() }
        }
        .alert("VPN Configurator", isPresented: Binding(
            get: { controller.storageErrorMessage != nil },
            set: { if !$0 { controller.storageErrorMessage = nil } }
        )) {
            Button("OK") { controller.storageErrorMessage = nil }
        } message: {
            Text(controller.storageErrorMessage ?? "")
        }
        .sheet(item: Binding(
            get: { controller.authenticationRequest },
            set: { controller.authenticationRequest = $0 }
        )) { request in
            CredentialPromptView(request: request)
                .environment(controller)
        }
    }
}
