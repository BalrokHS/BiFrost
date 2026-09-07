import SwiftUI

@main
struct VPNConfiguratorApp: App {
    @State private var controller: VPNController
    @State private var helperManager: PrivilegedHelperManager

    init() {
        let helperManager = PrivilegedHelperManager()
        _helperManager = State(initialValue: helperManager)
        _controller = State(initialValue: VPNController(helperManager: helperManager))
    }

    var body: some Scene {
        WindowGroup(id: "main") {
            RootView()
                .environment(controller)
                .environment(helperManager)
                .frame(minWidth: 920, minHeight: 620)
        }
        .defaultSize(width: 1100, height: 720)

        MenuBarExtra {
            MenuBarView()
                .environment(controller)
        } label: {
            Image(systemName: controller.connectedProfiles.isEmpty ? "shield" : "shield.fill")
        }
        .menuBarExtraStyle(.window)
    }
}
