import SwiftUI

@main
struct BifrostApp: App {
    @NSApplicationDelegateAdaptor(BifrostAppDelegate.self) private var appDelegate
    @State private var controller: VPNController
    @State private var updater: AppUpdateInstaller
    @State private var helperManager: PrivilegedHelperManager

    init() {
        let helperManager = PrivilegedHelperManager()
        _helperManager = State(initialValue: helperManager)
        _updater = State(initialValue: AppUpdateInstaller(helper: helperManager))
        _controller = State(initialValue: VPNController(helperManager: helperManager))
    }

    var body: some Scene {
        Window("Bifrost", id: "main") {
            RootView()
                .environment(controller)
                .environment(helperManager)
                .environment(updater)
                .onAppear { appDelegate.updater = updater }
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

@MainActor
final class BifrostAppDelegate: NSObject, NSApplicationDelegate {
    var updater: AppUpdateInstaller?

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        // Keep the swap/rollback transaction intact even if Quit is selected.
        updater?.phase == .installing ? .terminateCancel : .terminateNow
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // The menu bar and active connections remain available until explicit Quit.
        false
    }
}
