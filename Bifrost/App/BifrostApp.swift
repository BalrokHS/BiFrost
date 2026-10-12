import SwiftUI
import UserNotifications

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
        let controller = VPNController(helperManager: helperManager)
        controller.onCodeRequested = { profileName in
            CodeRequestNotifier.notify(profileName: profileName)
        }
        _controller = State(initialValue: controller)
    }

    var body: some Scene {
        Window("Bifrost", id: "main") {
            RootView()
                .environment(controller)
                .environment(helperManager)
                .environment(updater)
                .onAppear { appDelegate.updater = updater }
                .task { await updater.checkAutomaticallyIfDue() }
                .frame(minWidth: 940, minHeight: 640)
        }
        .defaultSize(width: 1140, height: 760)
        // The flat canvas runs edge to edge; the views draw their own header.
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

/// Tells a user who is in another app that a connection is waiting for a code.
/// The first request asks macOS for permission; without it the window still
/// opens from the menu bar.
@MainActor
enum CodeRequestNotifier {
    static func notify(profileName: String) {
        guard !NSApp.isActive else { return }
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            guard granted else { return }
            let content = UNMutableNotificationContent()
            content.title = "Enter the code for \(profileName)"
            content.body = "The server asked for a one-time password. Open Bifrost to finish connecting."
            content.sound = .default
            center.add(UNNotificationRequest(identifier: "otp-\(profileName)", content: content, trigger: nil))
        }
    }
}
