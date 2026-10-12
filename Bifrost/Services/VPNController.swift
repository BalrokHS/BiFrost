import AppKit
import Foundation
import Observation

@MainActor
@Observable
final class VPNController {
    var profiles: [VPNProfile]
    var storageErrorMessage: String?
    var authenticationRequest: AuthenticationRequest?
    /// Set when a connection is requested before the connection service is
    /// enabled, so the window can ask the user to enable it.
    var serviceSetupRequired = false
    /// How long a code prompt waits before the attempt is abandoned.
    static let codeRequestTimeout: Duration = .seconds(120)
    var connectionLogs: [VPNProfile.ID: String] = [:]
    private var runtimeStates: [VPNProfile.ID: VPNRuntimeState] = [:]

    @ObservationIgnored
    private var transitionTasks: [VPNProfile.ID: Task<Void, Never>] = [:]
    @ObservationIgnored
    private let keychain: any VPNPasswordStore
    @ObservationIgnored
    private let helperManager: any VPNHelperClient
    @ObservationIgnored
    private var pendingCredentials: [VPNProfile.ID: VPNCredentials] = [:]
    @ObservationIgnored
    private var openedAuthenticationURLs: Set<VPNProfile.ID> = []
    @ObservationIgnored
    private var statusRequests: [VPNProfile.ID: UUID] = [:]
    @ObservationIgnored
    private var startingProfiles: Set<VPNProfile.ID> = []
    @ObservationIgnored
    private var keepAliveTasks: [VPNProfile.ID: Task<Void, Never>] = [:]
    @ObservationIgnored
    private var codeTimeouts: [VPNProfile.ID: Task<Void, Never>] = [:]
    @ObservationIgnored
    private var codesRequested: [VPNProfile.ID: Int] = [:]
    @ObservationIgnored
    private var ignoringCodePrompt: Set<VPNProfile.ID> = []
    /// Called when a server asks for a code, so the app can tell a user who is
    /// in another window.
    @ObservationIgnored
    var onCodeRequested: (@MainActor (String) -> Void)?

    init(
        helperManager: any VPNHelperClient,
        initialProfiles: [VPNProfile]? = nil,
        keychain: any VPNPasswordStore = KeychainStore()
    ) {
        self.helperManager = helperManager
        self.keychain = keychain
        if let initialProfiles {
            profiles = initialProfiles
        } else {
            do {
                let storedProfiles = try ProfileStore.load()
                let migration = Self.migrateLegacyProfiles(storedProfiles)
                profiles = migration.profiles
                if migration.didChange { try ProfileStore.save(migration.profiles) }
            } catch {
                profiles = []
                storageErrorMessage = "Your saved profiles could not be loaded: \(error.localizedDescription)"
            }
        }
        reconcileSessions()
    }

    /// The helper outlives the GUI. Persisted state is never evidence of a stopped tunnel.
    func reconcileSessions() {
        helperManager.refreshStatus()
        guard helperManager.isEnabled else { return }
        for profile in profiles where !startingProfiles.contains(profile.id) {
            if state(for: profile) == .disconnected {
                updateRuntime(profile.id) { $0.state = .connecting }
            }
            pollStatus(for: profile.id)
        }
    }

    func state(for profile: VPNProfile) -> ConnectionState {
        runtimeStates[profile.id]?.state ?? .disconnected
    }

    func interfaceName(for profile: VPNProfile) -> String? {
        runtimeStates[profile.id]?.interfaceName
    }

    /// When the tunnel last reached `.connected`, for the uptime readout.
    func connectedSince(for profile: VPNProfile) -> Date? {
        runtimeStates[profile.id]?.connectedSince
    }

    var connectedProfiles: [VPNProfile] {
        profiles.filter { state(for: $0) == .connected }
    }

    var busyProfiles: [VPNProfile] {
        profiles.filter { state(for: $0).isBusy }
    }

    var disconnectableProfiles: [VPNProfile] {
        profiles.filter { [.connected, .degraded, .connecting, .waitingForAuthentication].contains(state(for: $0)) }
    }

    func toggle(_ profile: VPNProfile) {
        switch state(for: profile) {
        case .connected, .degraded, .waitingForAuthentication:
            disconnect(profile.id)
        case .disconnected, .failed:
            requestConnection(profile)
        case .connecting, .disconnecting:
            break
        }
    }

    func requestConnection(_ profile: VPNProfile) {
        guard profiles.contains(where: { $0.id == profile.id }) else { return }
        let currentState = state(for: profile)
        guard currentState == .disconnected || currentState == .failed else { return }
        helperManager.refreshStatus()
        guard helperManager.isEnabled else {
            serviceSetupRequired = true
            return
        }
        do {
            if profile.provider == .openVPN, profile.configurationPath == nil {
                throw VPNConnectionError.missingOpenVPNConfiguration
            }
            // A tunnel failure does not invalidate the password saved in Keychain.
            // OpenFortiVPN asks for a code itself, after its first attempt, so it
            // is connected like a password profile.
            let promptsFor = profile.authentication == .passwordAndOTP && profile.provider == .openFortiVPN
                ? AuthenticationMethod.password
                : profile.authentication
            switch promptsFor {
            case .saml:
                connect(profile.id)
            case .password:
                let hasStoredPassword = try keychain.containsPassword(for: profile.id)
                if hasStoredPassword {
                    connect(profile.id)
                } else {
                    authenticationRequest = AuthenticationRequest(
                        profileID: profile.id,
                        profileName: profile.name,
                        method: profile.authentication,
                        usesStoredPassword: false
                    )
                }
            case .passwordAndOTP:
                // Other clients take the code with the password, so ask up front.
                // Defaulting to the stored password when none exists hid the
                // password field while still requiring one, leaving the first
                // connection of an OTP profile with no way to authenticate.
                let hasStoredPassword = try keychain.containsPassword(for: profile.id)
                authenticationRequest = AuthenticationRequest(
                    profileID: profile.id,
                    profileName: profile.name,
                    method: profile.authentication,
                    usesStoredPassword: hasStoredPassword,
                    collectsCode: true
                )
            }
        } catch {
            storageErrorMessage = error.localizedDescription
        }
    }

    func submitAuthentication(
        password: String,
        oneTimePassword: String,
        rememberPassword: Bool,
        useStoredPassword: Bool
    ) throws {
        guard let request = authenticationRequest else { return }

        let trimmedPassword = password.trimmingCharacters(in: .whitespacesAndNewlines)
        let connectionPassword: String
        if useStoredPassword {
            guard let storedPassword = try keychain.password(for: request.profileID) else {
                throw AuthenticationValidationError.missingPassword
            }
            connectionPassword = storedPassword
        } else {
            guard !trimmedPassword.isEmpty else { throw AuthenticationValidationError.missingPassword }
            connectionPassword = password
            if rememberPassword {
                try keychain.setPassword(password, for: request.profileID)
            }
        }

        if request.collectsCode,
           oneTimePassword.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw AuthenticationValidationError.missingOTP
        }

        pendingCredentials[request.profileID] = VPNCredentials(
            password: connectionPassword,
            oneTimePassword: oneTimePassword.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        authenticationRequest = nil
        connect(request.profileID)
    }

    func cancelAuthentication() {
        let request = authenticationRequest
        authenticationRequest = nil
        // A code prompt belongs to a connection that is already running.
        if let request, request.serverRequestedCode {
            codeTimeouts.removeValue(forKey: request.profileID)?.cancel()
            disconnect(request.profileID)
        }
    }

    /// Sends the code the server asked for to the running connection.
    func submitOneTimePassword(_ code: String) throws {
        guard let request = authenticationRequest, request.serverRequestedCode else { return }
        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw AuthenticationValidationError.missingOTP }

        let id = request.profileID
        codeTimeouts.removeValue(forKey: id)?.cancel()
        authenticationRequest = nil
        ignoringCodePrompt.insert(id)
        helperManager.submitOneTimePassword(profileID: id, oneTimePassword: trimmed) { [weak self] result in
            guard let self else { return }
            switch result {
            case .success:
                self.pollStatus(for: id)
            case .failure(let error):
                // Let the user try again while the prompt is still open.
                self.ignoringCodePrompt.remove(id)
                var retry = request
                retry.errorMessage = error.localizedDescription
                self.authenticationRequest = retry
                self.startCodeTimeout(for: id)
            }
        }
    }

    private func presentCodeRequest(for id: VPNProfile.ID) {
        guard !ignoringCodePrompt.contains(id), let profile = profiles.first(where: { $0.id == id }),
              authenticationRequest?.profileID != id || authenticationRequest?.serverRequestedCode != true
        else { return }
        let attempts = codesRequested[id, default: 0]
        codesRequested[id] = attempts + 1
        authenticationRequest = AuthenticationRequest(
            profileID: id,
            profileName: profile.name,
            method: .passwordAndOTP,
            usesStoredPassword: true,
            serverRequestedCode: true,
            deadline: Date().addingTimeInterval(Double(Self.codeRequestTimeout.components.seconds)),
            isRetry: attempts > 0
        )
        startCodeTimeout(for: id)
        onCodeRequested?(profile.name)
    }

    private func startCodeTimeout(for id: VPNProfile.ID) {
        codeTimeouts[id]?.cancel()
        codeTimeouts[id] = Task { [weak self] in
            try? await Task.sleep(for: Self.codeRequestTimeout)
            guard !Task.isCancelled, let self,
                  self.authenticationRequest?.profileID == id,
                  self.authenticationRequest?.serverRequestedCode == true else { return }
            self.authenticationRequest = nil
            self.connectionLogs[id, default: ""].append("\nNo code was entered in time, so the connection was cancelled.\n")
            self.disconnect(id)
        }
    }

    func hasSavedPassword(for profileID: VPNProfile.ID) throws -> Bool {
        try keychain.containsPassword(for: profileID)
    }

    func savedPassword(for profileID: VPNProfile.ID) throws -> String? {
        try keychain.password(for: profileID)
    }

    func removeSavedPassword(for profileID: VPNProfile.ID) throws {
        try keychain.removePassword(for: profileID)
    }

    func connect(_ id: VPNProfile.ID) {
        guard let profile = profiles.first(where: { $0.id == id }),
              !startingProfiles.contains(id) else { return }
        transitionTasks[id]?.cancel()
        statusRequests[id] = nil
        startingProfiles.insert(id)
        do {
            let supplied = pendingCredentials.removeValue(forKey: id)
            let password = profile.authentication == .saml
                ? ""
                : try supplied?.password ?? keychain.password(for: id) ?? ""
            let oneTimePassword = supplied?.oneTimePassword ?? ""

            updateRuntime(id) {
                $0.state = .connecting
                $0.interfaceName = nil
            }
            openedAuthenticationURLs.remove(id)
            connectionLogs[id] = "Requesting privileged \(profile.provider.rawValue) launch…\n"

            let completion: @MainActor (Result<String, Error>) -> Void = { [weak self] result in
                guard let self else { return }
                self.startingProfiles.remove(id)
                switch result {
                case .success:
                    // Disconnect all may have been requested while start was in flight.
                    if self.runtimeStates[id]?.state == .disconnecting {
                        self.disconnect(id)
                    } else {
                        self.pollStatus(for: id)
                    }
                case .failure(let error):
                    self.storageErrorMessage = error.localizedDescription
                    self.pollStatus(for: id)
                }
            }

            switch profile.provider {
            case .openFortiVPN:
                helperManager.startOpenFortiVPN(
                    profileID: id,
                    server: profile.server,
                    trustedCertificate: profile.serverCertificatePin ?? "",
                    username: profile.username,
                    password: password,
                    oneTimePassword: oneTimePassword,
                    useSAML: profile.authentication == .saml,
                    dnsServers: profile.dnsServers,
                    dnsDomains: profile.dnsDomains,
                    completion: completion
                )
            case .openConnect:
                helperManager.startOpenConnect(
                    profileID: id,
                    server: profile.server,
                    serverCertificatePin: profile.serverCertificatePin ?? "",
                    username: profile.username,
                    password: password,
                    oneTimePassword: oneTimePassword,
                    dnsServers: profile.dnsServers,
                    dnsDomains: profile.dnsDomains,
                    completion: completion
                )
            case .openVPN:
                guard let path = profile.configurationPath else {
                    throw VPNConnectionError.missingOpenVPNConfiguration
                }
                let configuration = try String(
                    contentsOf: URL(fileURLWithPath: path),
                    encoding: .utf8
                )
                helperManager.startOpenVPN(
                    profileID: id,
                    configuration: configuration,
                    username: profile.username,
                    password: password,
                    dnsServers: profile.dnsServers,
                    dnsDomains: profile.dnsDomains,
                    completion: completion
                )
            }
        } catch {
            fail(id, error: error)
        }
    }

    func disconnect(_ id: VPNProfile.ID) {
        transitionTasks[id]?.cancel()
        statusRequests[id] = nil
        updateRuntime(id) { $0.state = .disconnecting }
        guard !startingProfiles.contains(id) else { return }

        helperManager.stopVPN(profileID: id) { [weak self] result in
            guard let self else { return }
            switch result {
            case .success:
                self.pollStatus(for: id)
            case .failure(let error):
                self.storageErrorMessage = error.localizedDescription
                self.pollStatus(for: id)
            }
        }
    }

    func disconnectAll() {
        for profile in disconnectableProfiles {
            disconnect(profile.id)
        }
    }

    func add(_ profile: VPNProfile) {
        profiles.append(profile)
        persistProfiles()
    }

    func replace(_ profile: VPNProfile) {
        guard let index = profiles.firstIndex(where: { $0.id == profile.id }) else { return }
        profiles[index] = profile
        persistProfiles()
    }

    func delete(_ id: VPNProfile.ID) {
        guard let profile = profiles.first(where: { $0.id == id }) else { return }
        let state = state(for: profile)
        guard state == .disconnected || state == .failed else { return }
        ConfigurationImporter.removeManagedOpenVPNConfiguration(at: profile.configurationPath)
        transitionTasks.removeValue(forKey: id)?.cancel()
        statusRequests[id] = nil
        runtimeStates[id] = nil
        profiles.removeAll { $0.id == id }
        try? keychain.removePassword(for: id)
        ProfileIconStore.remove(for: id)
        connectionLogs[id] = nil
        persistProfiles()
    }

    func importConfiguration(at url: URL) throws {
        let profile = try ConfigurationImporter.profile(from: url)
        add(profile)
    }

    private func updateRuntime(_ id: VPNProfile.ID, change: (inout VPNRuntimeState) -> Void) {
        guard profiles.contains(where: { $0.id == id }) else { return }
        var runtime = runtimeStates[id] ?? VPNRuntimeState()
        change(&runtime)
        // Stamped centrally so every path into `.connected` gets an uptime,
        // and every path out of it drops the stale one.
        if runtime.state == .connected {
            runtime.connectedSince = runtime.connectedSince ?? Date()
        } else {
            runtime.connectedSince = nil
        }
        runtimeStates[id] = runtime
        syncKeepAlive(for: id, state: runtime.state)
    }

    /// Pings the profile's keep-alive host while connected. The ping is bound to
    /// the tunnel interface, so it counts as tunnel traffic whatever the routes.
    private func syncKeepAlive(for id: VPNProfile.ID, state: ConnectionState) {
        guard state == .connected else {
            keepAliveTasks.removeValue(forKey: id)?.cancel()
            return
        }
        guard keepAliveTasks[id] == nil else { return }
        keepAliveTasks[id] = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: VPNKeepAlive.interval)
                guard !Task.isCancelled, let self else { return }
                let host = self.profiles.first { $0.id == id }?.keepAliveHost
                let interface = self.runtimeStates[id]?.interfaceName
                guard let host, let interface, VPNKeepAlive.isValid(host: host) else { continue }
                await VPNKeepAlive.ping(host: host, interface: interface)
            }
        }
    }

    private func pollStatus(for id: VPNProfile.ID) {
        let requestID = UUID()
        statusRequests[id] = requestID
        helperManager.VPNStatus(profileID: id) { [weak self] result in
            guard let self, self.statusRequests[id] == requestID,
                  self.profiles.contains(where: { $0.id == id }) else { return }
            self.statusRequests[id] = nil
            switch result {
            case .success(let status):
                self.connectionLogs[id] = status.log
                self.updateRuntime(id) { runtime in
                    runtime.interfaceName = status.interfaceName.isEmpty ? nil : status.interfaceName
                    runtime.state = switch HelperSessionState(rawValue: status.state) {
                    case .connecting: .connecting
                    case .waitingForAuthentication, .waitingForOneTimePassword: .waitingForAuthentication
                    case .connected: .connected
                    case .disconnecting: .disconnecting
                    case .failed: status.processIdentifier == 0 ? .failed : .degraded
                    case .disconnected: .disconnected
                    case nil: status.processIdentifier == 0 ? .disconnected : .degraded
                    }
                }

                if status.state == HelperSessionState.waitingForOneTimePassword.rawValue,
                   status.processIdentifier != 0 {
                    self.presentCodeRequest(for: id)
                } else {
                    self.ignoringCodePrompt.remove(id)
                    if status.state != HelperSessionState.connecting.rawValue {
                        self.dismissCodeRequest(for: id)
                    }
                }

                if status.state == HelperSessionState.waitingForAuthentication.rawValue,
                   status.processIdentifier != 0 {
                    self.openSAMLAuthenticationIfNeeded(profileID: id, log: status.log)
                }

                let transitionalStates: Set<HelperSessionState> = [
                    .connecting, .waitingForAuthentication, .waitingForOneTimePassword, .disconnecting
                ]
                if status.processIdentifier != 0
                    || HelperSessionState(rawValue: status.state).map(transitionalStates.contains) == true {
                    self.scheduleStatusPoll(for: id)
                }
            case .failure(let error):
                // An unavailable status service cannot prove the root process stopped.
                self.updateRuntime(id) { $0.state = .degraded }
                self.connectionLogs[id] = "Connection status unavailable: \(error.localizedDescription)"
                self.scheduleStatusPoll(for: id, delay: .seconds(3))
            }
        }
    }

    private func scheduleStatusPoll(for id: VPNProfile.ID, delay: Duration = .milliseconds(700)) {
        transitionTasks[id]?.cancel()
        transitionTasks[id] = Task { [weak self] in
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled else { return }
            self?.pollStatus(for: id)
        }
    }

    /// The connection moved on without the code (finished, failed or stopped).
    private func dismissCodeRequest(for id: VPNProfile.ID) {
        codeTimeouts.removeValue(forKey: id)?.cancel()
        codesRequested[id] = nil
        if authenticationRequest?.profileID == id, authenticationRequest?.serverRequestedCode == true {
            authenticationRequest = nil
        }
    }

    private func fail(_ id: VPNProfile.ID, error: Error) {
        startingProfiles.remove(id)
        statusRequests[id] = nil
        transitionTasks[id]?.cancel()
        updateRuntime(id) {
            $0.state = .failed
            $0.interfaceName = nil
        }
        let message = error.localizedDescription
        connectionLogs[id, default: ""].append("\nError: \(message)\n")
        storageErrorMessage = message
    }

    private func openSAMLAuthenticationIfNeeded(profileID: VPNProfile.ID, log: String) {
        guard !openedAuthenticationURLs.contains(profileID),
              let expression = try? NSRegularExpression(pattern: #"Authenticate at '([^']+)'"#),
              let match = expression.firstMatch(in: log, range: NSRange(log.startIndex..., in: log)),
              let range = Range(match.range(at: 1), in: log),
              let url = URL(string: String(log[range])),
              url.scheme == "https" else { return }
        openedAuthenticationURLs.insert(profileID)
        NSWorkspace.shared.open(url)
    }

    private func persistProfiles() {
        do {
            try ProfileStore.save(profiles)
        } catch {
            storageErrorMessage = "Profiles could not be saved: \(error.localizedDescription)"
        }
    }

    private static func migrateLegacyProfiles(
        _ profiles: [VPNProfile]
    ) -> (profiles: [VPNProfile], didChange: Bool) {
        var didChange = false
        let migrated = profiles.map { profile -> VPNProfile in
            if profile.provider == .openVPN,
               let migrated = try? ConfigurationImporter.migrateOpenVPNProfile(profile),
               migrated.configurationPath != profile.configurationPath {
                didChange = true
                return migrated
            }

            guard profile.provider == .openFortiVPN,
                  let path = profile.configurationPath else { return profile }

            guard let imported = try? ConfigurationImporter.profile(
                from: URL(fileURLWithPath: path)
            ), imported.provider == .openFortiVPN else {
                return profile
            }

            var result = profile
            result.server = imported.server
            if result.username.isEmpty { result.username = imported.username }
            if result.serverCertificatePin == nil {
                result.serverCertificatePin = imported.serverCertificatePin
            }
            result.configurationPath = nil
            didChange = true
            return result
        }
        return (migrated, didChange)
    }
}

enum AuthenticationValidationError: LocalizedError {
    case missingPassword
    case missingOTP

    var errorDescription: String? {
        switch self {
        case .missingPassword: "Enter a password or use the password saved in Keychain."
        case .missingOTP: "Enter the current one-time password."
        }
    }
}

private enum VPNConnectionError: LocalizedError {
    case missingOpenVPNConfiguration

    var errorDescription: String? {
        "OpenVPN needs an imported configuration file for this profile."
    }
}

private struct VPNRuntimeState: Sendable {
    var state = ConnectionState.disconnected
    var interfaceName: String?
    var connectedSince: Date?
}


/// Sends one ping through a tunnel so a gateway that drops idle sessions sees traffic.
enum VPNKeepAlive {
    static let interval: Duration = .seconds(60)

    /// An address or host name. Empty is valid and means no keep-alive.
    static func isValid(host: String) -> Bool {
        let trimmed = host.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return true }
        return trimmed.range(of: #"^[A-Za-z0-9][A-Za-z0-9.:-]{0,252}$"#, options: .regularExpression) != nil
    }

    static func ping(host: String, interface: String) async {
        guard interface.range(of: #"^[a-z]+[0-9]+$"#, options: .regularExpression) != nil else { return }
        await withCheckedContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/sbin/ping")
            process.arguments = ["-c", "1", "-t", "3", "-b", interface, host.trimmingCharacters(in: .whitespacesAndNewlines)]
            process.standardOutput = FileHandle.nullDevice
            process.standardError = FileHandle.nullDevice
            process.terminationHandler = { _ in continuation.resume() }
            do { try process.run() } catch { continuation.resume() }
        }
    }
}
