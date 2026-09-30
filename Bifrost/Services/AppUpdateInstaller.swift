import AppKit
import Foundation
import Observation
import Security
import UniformTypeIdentifiers

struct AppUpdateFailure: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

/// Signature validation of the app bundle establishes integrity, not publisher
/// authenticity. Downloaded releases are authenticated separately by `UpdateFeed`
/// (pinned Ed25519 key); a bundle identifier is never trusted on its own.
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
        let plistName = "gr.klianos.bifrost.helper.unsigned.\(build).plist"
        guard bundle.object(forInfoDictionaryKey: "BifrostHelperDaemonPlist") as? String == plistName else {
            throw AppUpdateFailure(message: "This release has inconsistent connection-service metadata.")
        }
        let plistURL = url.appendingPathComponent("Contents/Library/LaunchDaemons/\(plistName)")
        let plist = try PropertyListSerialization.propertyList(from: Data(contentsOf: plistURL), format: nil) as? [String: Any]
        guard plist?["Label"] as? String == String(plistName.dropLast(6)),
              plist?["BundleProgram"] as? String == "Contents/Resources/BifrostHelper",
              (plist?["MachServices"] as? [String: Bool]) == [HelperConstants.machServiceName: true],
              plist?["Program"] == nil, plist?["ProgramArguments"] == nil else {
            throw AppUpdateFailure(message: "This release has an invalid connection-service definition.")
        }
        let helper = url.appendingPathComponent("Contents/Resources/BifrostHelper")
        guard helper.resolvingSymlinksInPath().path.hasPrefix(url.resolvingSymlinksInPath().path + "/") else {
            throw AppUpdateFailure(message: "The connection service must be inside the app.")
        }
        try validateSignature(url, identifier: HelperConstants.mainAppIdentifier)
        try validateSignature(helper, identifier: "gr.klianos.bifrost.helper")
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

private enum DiskImage {
    static func attach(_ image: URL) throws -> URL {
        let output = try run(["attach", "-nobrowse", "-readonly", "-noautoopen", "-plist", "-mountrandom", "/tmp", image.path])
        guard let plist = try PropertyListSerialization.propertyList(from: output, format: nil) as? [String: Any],
              let mount = (plist["system-entities"] as? [[String: Any]])?
                  .compactMap({ $0["mount-point"] as? String }).first else {
            throw AppUpdateFailure(message: "Could not open the downloaded disk image.")
        }
        return URL(fileURLWithPath: mount)
    }

    static func detach(_ mountPoint: URL) {
        _ = try? run(["detach", mountPoint.path, "-force"])
    }

    private static func run(_ arguments: [String]) throws -> Data {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
        process.arguments = arguments
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        try process.run()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw AppUpdateFailure(message: "Could not open the downloaded disk image.")
        }
        return data
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
        case idle, checking, downloading, staging, ready(Int64), waiting, installing, finished
    }
    private(set) var phase: Phase = .idle
    private(set) var available: UpdateFeed.Release?
    private(set) var upToDate = false
    private(set) var readyIsVerified = false
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
    var currentBuild: Int64? { UnsignedRelease.buildNumber(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion")) }
    var detail: String {
        switch phase {
        case .idle:
            if let available { "Build \(available.build) is available. You have build \(currentBuild ?? 0)." }
            else if upToDate { "Bifrost is up to date (build \(currentBuild ?? 0))." }
            else { "Check for updates, or mount a downloaded Bifrost disk image and choose the app inside it." }
        case .checking: "Checking for updates…"
        case .downloading: "Downloading and verifying the update…"
        case .staging: "Checking and staging the downloaded app…"
        case .ready(let build) where readyIsVerified:
            "Build \(build) was verified against Bifrost's release key and is ready to install."
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
        readyIsVerified = false
        Task {
            do { try await stage(source: source, expectedBuild: nil) }
            catch { fail(error) }
        }
    }

    func checkForUpdates(userInitiated: Bool = true) async {
        guard phase == .idle else { return }
        phase = .checking
        upToDate = false
        defer { phase = .idle }
        do {
            var request = URLRequest(url: UpdateFeed.latestReleaseURL, timeoutInterval: 15)
            request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let status = (response as? HTTPURLResponse)?.statusCode, status == 200 || status == 404 else {
                throw AppUpdateFailure(message: "The update server returned an unexpected response.")
            }
            UserDefaults.standard.set(Date.now, forKey: "lastUpdateCheck")
            // 404 means nothing has been published yet.
            let release = status == 200 ? UpdateFeed.parseLatest(data) : nil
            if let release, release.build > (currentBuild ?? .max) { available = release }
            else { available = nil; upToDate = true }
        } catch {
            if userInitiated { errorMessage = "Could not check for updates: \(error.localizedDescription)" }
        }
    }

    /// At most once a day, and only when the user hasn't turned automatic checks off.
    func checkAutomaticallyIfDue() async {
        let defaults = UserDefaults.standard
        guard defaults.object(forKey: "automaticUpdateChecks") as? Bool ?? true else { return }
        if let last = defaults.object(forKey: "lastUpdateCheck") as? Date,
           Date.now.timeIntervalSince(last) < 24 * 3600 { return }
        await checkForUpdates(userInitiated: false)
    }

    /// Downloads the release image, authenticates it against the pinned key BEFORE
    /// the system parses the disk image, then feeds the mounted app to normal staging.
    func downloadAndStage() {
        guard phase == .idle, let release = available else { return }
        phase = .downloading
        errorMessage = nil
        readyIsVerified = false
        Task {
            var mountPoint: URL?
            var folder: URL?
            do {
                let temporary = FileManager.default.temporaryDirectory
                    .appendingPathComponent("bifrost-update-\(UUID().uuidString)")
                try FileManager.default.createDirectory(at: temporary, withIntermediateDirectories: false, attributes: [.posixPermissions: 0o700])
                folder = temporary
                let image = try await Self.download(UpdateFeed.assetURL(for: release, name: UpdateFeed.imageName),
                                                    limit: UpdateFeed.maximumImageBytes, into: temporary)
                let signature = try await Self.download(UpdateFeed.assetURL(for: release, name: UpdateFeed.signatureName),
                                                        limit: UpdateFeed.maximumSignatureBytes, into: temporary)
                let authentic = try await Task.detached {
                    UpdateFeed.isAuthentic(image: try Data(contentsOf: image), signature: try Data(contentsOf: signature))
                }.value
                guard authentic else {
                    throw AppUpdateFailure(message: "The downloaded update failed signature verification and was discarded.")
                }
                phase = .staging
                let mounted = try await Task.detached { try DiskImage.attach(image) }.value
                mountPoint = mounted
                try await stage(source: mounted.appendingPathComponent("Bifrost.app"), expectedBuild: release.build)
                readyIsVerified = true
            } catch { fail(error) }
            if let mountPoint { DiskImage.detach(mountPoint) }
            if let folder { try? FileManager.default.removeItem(at: folder) }
        }
    }

    private static func download(_ url: URL, limit: Int, into folder: URL) async throws -> URL {
        let (temporary, response) = try await URLSession.shared.download(from: url)
        let size = (try? temporary.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? .max
        guard (response as? HTTPURLResponse)?.statusCode == 200, size <= limit else {
            try? FileManager.default.removeItem(at: temporary)
            throw AppUpdateFailure(message: "The update could not be downloaded.")
        }
        let destination = folder.appendingPathComponent(url.lastPathComponent)
        try FileManager.default.moveItem(at: temporary, to: destination)
        return destination
    }

    private func stage(source: URL, expectedBuild: Int64?) async throws {
        let destination = Bundle.main.bundleURL.resolvingSymlinksInPath()
        guard FileManager.default.isWritableFile(atPath: destination.deletingLastPathComponent().path),
              FileManager.default.isWritableFile(atPath: destination.path),
              let currentBuild,
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
        if let expectedBuild, build != expectedBuild {
            throw AppUpdateFailure(message: "The downloaded app does not match the announced release.")
        }
        transaction = AppBundleReplacement(destination: destination, staged: staged, previous: directory.appendingPathComponent("Previous.app"))
        phase = .ready(build)
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
        readyIsVerified = false
        phase = .idle
    }
}
