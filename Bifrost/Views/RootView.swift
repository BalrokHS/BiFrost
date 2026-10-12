import SwiftUI

struct RootView: View {
    @Environment(VPNController.self) private var controller
    @Environment(PrivilegedHelperManager.self) private var helperManager

    @SceneStorage("showingSettings") private var showingSettings = false
    @State private var settingsStart = SettingsDestination.general

    var body: some View {
        ZStack {
            Theme.Palette.canvas
                .ignoresSafeArea()

            // The window controls sit over the hidden title bar, so the views
            // start below a strip of that height and can align to the left edge.
            VStack(spacing: 0) {
                Color.clear.frame(height: Theme.Metrics.titleBarHeight)

                if showingSettings {
                    AppSettingsView(start: settingsStart) {
                        withAnimation(Theme.Motion.state) { showingSettings = false }
                    }
                    .transition(.opacity)
                } else {
                    DashboardView { destination in
                        settingsStart = destination
                        withAnimation(Theme.Motion.state) { showingSettings = true }
                    }
                    .transition(.opacity)
                }
            }
        }
        .preferredColorScheme(.dark)
        .tint(Theme.Palette.brand)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            helperManager.refreshStatus()
            if helperManager.isEnabled && !helperManager.isHealthy && !helperManager.isUpdatingHelper {
                helperManager.checkHealth()
            }
        }
        .onChange(of: helperManager.isEnabled) { _, enabled in
            if enabled { controller.reconcileSessions() }
        }
        .alert("Enable VPN connections first", isPresented: Bindable(controller).serviceSetupRequired) {
            Button("Cancel", role: .cancel) {}
            Button("Enable VPN connections") { helperManager.register() }
        } message: {
            Text("Bifrost starts tunnels through a background connection service. Enable it, then connect again. macOS may ask you to approve it in System Settings.")
        }
        .alert("Bifrost", isPresented: Binding(
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
