import SwiftUI

@main
struct BifrostApp: App {
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
                .frame(minWidth: 940, minHeight: 640)
        }
        .defaultSize(width: 1140, height: 760)
        // The ambient backdrop runs edge to edge; a title bar chrome strip
        // across the top would cut it in half.
        .windowStyle(.hiddenTitleBar)

        MenuBarExtra {
            MenuBarView()
                .environment(controller)
        } label: {
            Image("BifrostStatusGlyph")
                .renderingMode(.template)
                .accessibilityLabel("Bifrost")
        }
        .menuBarExtraStyle(.window)
    }
}
