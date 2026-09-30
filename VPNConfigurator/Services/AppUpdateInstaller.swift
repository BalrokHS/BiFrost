import AppKit
import Foundation
import Observation
import Security
import UniformTypeIdentifiers

struct AppUpdateFailure: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

/// Local, user-selected releases only. Signature validation establishes integrity,
/// not publisher authenticity: there is no network downloader or implicit trust
/// in an unsigned app's bundle identifier.
enum UnsignedRelease {
    static func buildNumber(_ value: Any?) -> Int64? {
        guard let text = value as? String, !text.isEmpty,
              text.utf8.allSatisfy({ (48...57).contains($0) }),
              let number = Int64(text), number > 0 else { return nil }
        return number
    }

    static func validate(_ url: URL, newerThan currentBuild: Int64) throws -> Int64 {
        guard let bundle = Bundle(url: url),
              bundle.bundleIdentifier == HelperConstants.mainAppIdentifier,
              bundle.object(forInfoDictionaryKey: "BifrostDistribution") as? String == "adhoc-v1",
              let build = buildNumber(bundle.object(forInfoDictionaryKey: "CFBundleVersion")),
              build > currentBuild else {
            throw AppUpdateFailure(message: "Choose a newer unsigned Bifrost release from its mounted disk image.")
        }
        let plistName = "com.klianos.VPNConfigurator.helper.unsigned.\(build).plist"
        guard bundle.object(forInfoDictionaryKey: "BifrostHelperDaemonPlist") as? String == plistName else {
            throw AppUpdateFailure(message: "This release has inconsistent connection-service metadata.")
        }
        let plistURL = url.appendingPathComponent("Contents/Library/LaunchDaemons/\(plistName)")
        let plist = try PropertyListSerialization.propertyList(from: Data(contentsOf: plistURL), format: nil) as? [String: Any]
        guard plist?["Label"] as? String == String(plistName.dropLast(6)),
              plist?["BundleProgram"] as? String == "Contents/Resources/VPNConfiguratorHelper",
              (plist?["MachServices"] as? [String: Bool]) == [HelperConstants.machServiceName: true],
              plist?["Program"] == nil, plist?["ProgramArguments"] == nil else {
            throw AppUpdateFailure(message: "This release has an invalid connection-service definition.")
        }
        let helper = url.appendingPathComponent("Contents/Resources/VPNConfiguratorHelper")
        guard helper.resolvingSymlinksInPath().path.hasPrefix(url.resolvingSymlinksInPath().path + "/") else {
            throw AppUpdateFailure(message: "The connection service must be inside the app.")
        }
        try validateSignature(url, identifier: HelperConstants.mainAppIdentifier)
        try validateSignature(helper, identifier: "com.klianos.VPNConfigurator.helper")
        return build
    }

    private static func validateSignature(_ url: URL, identifier: String) throws {
        var code: SecStaticCode?
        guard SecStaticCodeCreateWithPath(url as CFURL, [], &code) == errSecSuccess, let code,
              SecStaticCodeCheckValidity(code, SecCSFlags(rawValue: kSecCSCheckAllArchitectures | kSecCSStrictValidate | kSecCSCheckNestedCode), nil) == errSecSuccess else {
            throw AppUpdateFailure(message: "The selected release is damaged or its code signature is invalid.")
        }
        var raw: CFDictionary?
        guard SecCodeCopySigningInformation(code, SecCSFlags(rawValue: kSecCSSigningInformation), &raw) == errSecSuccess,
              let info = raw as? [String: Any],
              info[kSecCodeInfoIdentifier as String] as? String == identifier,
              let flags = info[kSecCodeInfoFlags as String] as? UInt32,
              flags & 0x0002 != 0, flags & 0x10000 != 0 else {
            throw AppUpdateFailure(message: "Select the unsigned release build, not an Xcode development build.")
        }
        let entitlements = info[kSecCodeInfoEntitlementsDict as String] as? [String: Any] ?? [:]
        for name in ["com.apple.security.get-task-allow", "com.apple.security.cs.disable-library-validation", "com.apple.security.cs.allow-dyld-environment-variables"] {
            guard entitlements[name] as? Bool != true else {
                throw AppUpdateFailure(message: "The selected release contains development-only security entitlements.")
            }
        }
    }
}

/// Both moves occur on the destination volume. Existing signed files are never
/// overwritten in place. The old bundle stays available for recovery.
struct AppBundleReplacement {
    let destination: URL
    let staged: URL
    let previous: URL

    func install() throws {
        let files = FileManager.default
        try files.moveItem(at: destination, to: previous)
        do {
            try files.moveItem(at: staged, to: destination)
        } catch {
            do { try files.moveItem(at: previous, to: destination) }
            catch {
                throw AppUpdateFailure(message: "Installation and rollback failed. Your previous app is at \(previous.path). Move it back to \(destination.path).")
            }
            throw error
        }
    }

    func rollback() throws {
        let files = FileManager.default
        try files.moveItem(at: destination, to: staged)
        do { try files.moveItem(at: previous, to: destination) }
        catch {
            try? files.moveItem(at: staged, to: destination)
            throw error
        }
    }
}

@MainActor
@Observable
final class AppUpdateInstaller {
    enum Phase: Equatable {
        case idle, staging, ready(Int64), waiting, installing, finished
    }
    private(set) var phase: Phase = .idle
    var errorMessage: String?
    private let helper: PrivilegedHelperManager
    private var transaction: AppBundleReplacement?
    private var stagingDirectory: URL?
    @ObservationIgnored private var updateTask: Task<Void, Never>?

    init(helper: PrivilegedHelperManager) { self.helper = helper }

    var isBusy: Bool { phase != .idle && phase != .finished }
    var canCancel: Bool {
        if case .ready = phase { return true }
        return phase == .waiting
    }
    var detail: String {
        switch phase {
        case .idle: "Mount a downloaded Bifrost disk image and choose the app inside it."
        case .staging: "Checking and staging the downloaded app…"
        case .ready(let build): "Build \(build) is ready. Install only a release you obtained from a trusted source; unsigned releases do not identify their publisher."
        case .waiting: "Waiting for VPN sessions to finish. Disconnect when convenient, or cancel to start new connections."
        case .installing: "Installing Bifrost and preparing its connection service…"
        case .finished: "The new Bifrost app is opening. macOS may ask you to approve its connection service."
        }
    }

    func chooseRelease() {
        guard phase == .idle else { return }
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.applicationBundle]
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Choose update"
        guard panel.runModal() == .OK, let source = panel.url else { return }
        phase = .staging
        errorMessage = nil
        Task {
            do {
                let destination = Bundle.main.bundleURL.resolvingSymlinksInPath()
                guard FileManager.default.isWritableFile(atPath: destination.deletingLastPathComponent().path),
                      FileManager.default.isWritableFile(atPath: destination.path),
                      let currentBuild = UnsignedRelease.buildNumber(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion")),
                      !source.resolvingSymlinksInPath().path.hasPrefix(destination.path + "/"),
                      source.resolvingSymlinksInPath() != destination else {
                    throw AppUpdateFailure(message: "Run Bifrost from a writable installed location, then choose a different, newer app from the downloaded disk image.")
                }
                let directory = destination.deletingLastPathComponent().appendingPathComponent(".Bifrost-update-\(UUID().uuidString)")
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false, attributes: [.posixPermissions: 0o700])
                stagingDirectory = directory
                let staged = directory.appendingPathComponent("Bifrost.app")
                let build = try await Task.detached {
                    try FileManager.default.copyItem(at: source, to: staged)
                    return try UnsignedRelease.validate(staged, newerThan: currentBuild)
                }.value
                transaction = AppBundleReplacement(destination: destination, staged: staged, previous: directory.appendingPathComponent("Previous.app"))
                phase = .ready(build)
            } catch { fail(error) }
        }
    }

    func install() {
        guard case .ready = phase, let transaction else { return }
        phase = .waiting
        helper.isUpdatingHelper = true
        updateTask = Task {
            var removedService = false
            var installed = false
            helper.refreshStatus()
            let restoreRegistration = helper.status != .notRegistered
            do {
                while try await !helper.prepareUpdate() {
                    try await Task.sleep(for: .seconds(1))
                }
                try Task.checkCancellation()
                phase = .installing
                // Recheck staged bytes after a potentially long wait, before any
                // registration or installed app changes.
                _ = try UnsignedRelease.validate(transaction.staged, newerThan: UnsignedRelease.buildNumber(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion")) ?? 0)
                try await helper.unregisterPreparedService()
                removedService = true
                try transaction.install()
                installed = true
                if restoreRegistration {
                    UserDefaults.standard.set(transaction.destination.path, forKey: "pendingHelperRegistration")
                    // The next process reads this immediately during initialization.
                    UserDefaults.standard.synchronize()
                }
                let configuration = NSWorkspace.OpenConfiguration()
                configuration.createsNewApplicationInstance = true
                _ = try await NSWorkspace.shared.openApplication(at: transaction.destination, configuration: configuration)
                phase = .finished
                NSApplication.shared.terminate(nil)
            } catch {
                UserDefaults.standard.removeObject(forKey: "pendingHelperRegistration")
                if installed {
                    do { try transaction.rollback() }
                    catch {
                        helper.isUpdatingHelper = false
                        errorMessage = "Could not reopen Bifrost or restore the previous app. The backup is at \(transaction.previous.path)."
                        phase = .idle
                        return
                    }
                }
                await helper.cancelUpdatePreparation()
                helper.isUpdatingHelper = false
                if removedService && restoreRegistration { helper.register() }
                if error is CancellationError { reset() }
                else { fail(error) }
            }
        }
    }

    func cancel() {
        if phase == .waiting { updateTask?.cancel() }
        else if canCancel { reset() }
    }

    private func fail(_ error: Error) {
        errorMessage = error.localizedDescription
        reset()
    }

    private func reset() {
        // Never discard the previous app after a failed rollback.
        if let stagingDirectory,
           !FileManager.default.fileExists(atPath: stagingDirectory.appendingPathComponent("Previous.app").path) {
            try? FileManager.default.removeItem(at: stagingDirectory)
        }
        stagingDirectory = nil
        transaction = nil
        updateTask = nil
        phase = .idle
    }
}
