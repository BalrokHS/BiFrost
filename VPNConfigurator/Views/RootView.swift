import SwiftUI

struct RootView: View {
    @Environment(VPNController.self) private var controller
    @Environment(PrivilegedHelperManager.self) private var helperManager

    @SceneStorage("showingSettings") private var showingSettings = false

    var body: some View {
        ZStack {
            AmbientBackdrop(
                accent: ambientAccent,
                secondary: ambientSecondary,
                intensity: controller.connectedProfiles.isEmpty ? 0 : 1
            )
            .animation(Theme.Motion.ambient, value: controller.connectedProfiles.count)

            if showingSettings {
                AppSettingsView {
                    withAnimation(Theme.Motion.state) { showingSettings = false }
                }
                .transition(.opacity.combined(with: .scale(scale: 0.992)))
            } else {
                DashboardView {
                    withAnimation(Theme.Motion.state) { showingSettings = true }
                }
                .transition(.opacity.combined(with: .scale(scale: 0.992)))
            }
        }
        .preferredColorScheme(.dark)
        .tint(Theme.Palette.brand)
        .onChange(of: helperManager.isEnabled) { _, enabled in
            if enabled { controller.reconcileSessions() }
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

    private var ambientAccent: Color {
        controller.connectedProfiles.first?.accent.tint ?? Theme.Palette.brand
    }

    private var ambientSecondary: Color {
        let connected = controller.connectedProfiles
        if connected.count > 1 { return connected[1].accent.tint }
        return connected.first?.accent.highlight ?? Theme.Palette.brandBright
    }
}
