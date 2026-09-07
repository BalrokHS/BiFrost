import Foundation
import Observation
import Security
import ServiceManagement

struct HelperEngineApproval: Sendable {
    let state: EngineApprovalState
    let detail: String
}

struct HelperVPNStatus: Sendable {
    let state: String
    let processIdentifier: Int32
    let interfaceName: String
    let log: String
}

/// Keeps an `AuthorizationRef` alive for exactly as long as the helper needs to
/// restore its external form, then destroys it. Holding one for the app's
/// lifetime would leave an administrator credential live far longer than the
/// single request that earned it.
private final class AdministratorAuthorization: @unchecked Sendable {
    let externalForm: Data
    private var reference: AuthorizationRef?

    init(reference: AuthorizationRef, externalForm: Data) {
        self.reference = reference
        self.externalForm = externalForm
    }

    func release() {
        guard let reference else { return }
        self.reference = nil
        AuthorizationFree(reference, [])
    }

    deinit { release() }
}

private struct HelperClientError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

private final class XPCResultBridge<Value: Sendable>: @unchecked Sendable {
    let deliver: @Sendable (Result<Value, Error>) -> Void

    init(deliver: @escaping @Sendable (Result<Value, Error>) -> Void) {
        self.deliver = deliver
    }

    func handle(error: Error) {
        deliver(.failure(error))
    }

    func fail(with message: String) {
        deliver(.failure(HelperClientError(message: message)))
    }

}

private final class RegistrationResultBridge: @unchecked Sendable {
    let deliver: @Sendable (Result<Void, Error>) -> Void

    init(deliver: @escaping @Sendable (Result<Void, Error>) -> Void) {
        self.deliver = deliver
    }

    func handle(error: Error?) {
        deliver(error.map(Result.failure) ?? .success(()))
    }
}

/// The controller depends on a transport contract so lifecycle behavior can be
/// tested without registering a daemon or changing the machine's network.
@MainActor
protocol VPNHelperClient: AnyObject {
    var isEnabled: Bool { get }
    func refreshStatus()
    func startOpenFortiVPN(
        profileID: VPNProfile.ID,
        server: String,
        trustedCertificate: String,
        username: String,
        password: String,
        oneTimePassword: String,
        useSAML: Bool,
        dnsServers: [String],
        dnsDomains: [String],
        completion: @escaping @MainActor (Result<String, Error>) -> Void
    )

    func startOpenVPN(
        profileID: VPNProfile.ID,
        configuration: String,
        username: String,
        password: String,
        dnsServers: [String],
        dnsDomains: [String],
        completion: @escaping @MainActor (Result<String, Error>) -> Void
    )

    func startOpenConnect(
        profileID: VPNProfile.ID,
        server: String,
        serverCertificatePin: String,
        username: String,
        password: String,
        oneTimePassword: String,
        dnsServers: [String],
        dnsDomains: [String],
        completion: @escaping @MainActor (Result<String, Error>) -> Void
    )

    func stopVPN(
        profileID: VPNProfile.ID,
        completion: @escaping @MainActor (Result<String, Error>) -> Void
    )

    func VPNStatus(
        profileID: VPNProfile.ID,
        completion: @escaping @MainActor (Result<HelperVPNStatus, Error>) -> Void
    )
}

@MainActor
@Observable
final class PrivilegedHelperManager: VPNHelperClient {
    var status: SMAppService.Status = .notRegistered
    var helperVersion: String?
    var errorMessage: String?
    var isCheckingHealth = false
    var isChangingRegistration = false
    var isUpdatingHelper = false

    @ObservationIgnored
    private var operationConnections: [UUID: NSXPCConnection] = [:]
    @ObservationIgnored
    private var helperUpdateWaiters: [(@MainActor (Result<Void, Error>) -> Void)] = []

    init() {
        refreshStatus()
        if isEnabled { checkHealth() }
    }

    var statusTitle: String {
        switch status {
        case .notRegistered: "Not installed"
        case .enabled: "Enabled"
        case .requiresApproval: "Awaiting approval"
        case .notFound: "Not available in this build"
        @unknown default: "Unknown"
        }
    }

    var isEnabled: Bool { status == .enabled }

    var statusDetail: String {
        switch status {
        case .notRegistered:
            "The privileged connection service has not been registered."
        case .enabled:
            if isUpdatingHelper {
                "The helper is restarting to use the version embedded in this app."
            } else {
                helperVersion.map { "The helper is responding (\($0))." }
                    ?? "The helper is registered. Run a health check to verify XPC."
            }
        case .requiresApproval:
            "An administrator must approve Bifrost in Login Items & Extensions."
        case .notFound:
            "macOS could not validate the bundled launch daemon. Try registration to see the precise Service Management error."
        @unknown default:
            "macOS returned an unknown helper status."
        }
    }

    func refreshStatus() {
        status = service.status
        if status != .enabled { helperVersion = nil }
    }

    func register() {
        guard !isChangingRegistration else { return }
        isChangingRegistration = true
        defer { isChangingRegistration = false }
        do {
            try service.register()
            refreshStatus()
        } catch {
            refreshStatus()

            // Service Management can report "Operation not permitted" after it has
            // successfully recorded a launch daemon that still needs administrator
            // approval. The status is authoritative in that case, so guide the user
            // to System Settings instead of presenting a misleading failure alert.
            if status == .requiresApproval {
                errorMessage = nil
                openApprovalSettings()
                return
            }

            errorMessage = detailedMessage(for: error)
        }
    }

    func unregister() {
        guard !isChangingRegistration else { return }
        isChangingRegistration = true

        let bridge = RegistrationResultBridge { [weak self] result in
            Task { @MainActor in
                guard let self else { return }
                self.isChangingRegistration = false
                self.helperVersion = nil
                self.refreshStatus()
                if case .failure(let error) = result {
                    self.errorMessage = self.detailedMessage(for: error)
                }
            }
        }
        service.unregister(completionHandler: bridge.handle(error:))
    }

    func openApprovalSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }

    func checkHealth() {
        guard !isCheckingHealth else { return }
        isCheckingHealth = true
        helperVersion = nil
        verifyExecutionHelper { [weak self] result in
            guard let self else { return }
            isCheckingHealth = false
            switch result {
            case .success:
                errorMessage = nil
            case .failure(let error):
                errorMessage = error.localizedDescription
            }
        }
    }

    func startOpenFortiVPN(
        profileID: VPNProfile.ID,
        server: String,
        trustedCertificate: String,
        username: String,
        password: String,
        oneTimePassword: String,
        useSAML: Bool,
        dnsServers: [String],
        dnsDomains: [String],
        completion: @escaping @MainActor (Result<String, Error>) -> Void
    ) {
        verifyExecutionHelper { [weak self] result in
            guard let self else { return }
            switch result {
            case .success:
                self.sendStartOpenFortiVPN(
                    profileID: profileID,
                    server: server,
                    trustedCertificate: trustedCertificate,
                    username: username,
                    password: password,
                    oneTimePassword: oneTimePassword,
                    useSAML: useSAML,
                    dnsServers: dnsServers,
                    dnsDomains: dnsDomains,
                    completion: completion
                )
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    private func sendStartOpenFortiVPN(
        profileID: VPNProfile.ID,
        server: String,
        trustedCertificate: String,
        username: String,
        password: String,
        oneTimePassword: String,
        useSAML: Bool,
        dnsServers: [String],
        dnsDomains: [String],
        completion: @escaping @MainActor (Result<String, Error>) -> Void
    ) {
        performOperation(completion: completion) { proxy, reply in
            proxy.startOpenFortiVPN(
                profileID: profileID.uuidString,
                server: server,
                trustedCertificate: trustedCertificate,
                username: username,
                password: password,
                oneTimePassword: oneTimePassword,
                useSAML: useSAML,
                dnsServers: dnsServers,
                dnsDomains: dnsDomains
            ) { success, message in
                reply(success ? .success(message) : .failure(HelperClientError(message: message)))
            }
        }
    }

    func startOpenVPN(
        profileID: VPNProfile.ID,
        configuration: String,
        username: String,
        password: String,
        dnsServers: [String],
        dnsDomains: [String],
        completion: @escaping @MainActor (Result<String, Error>) -> Void
    ) {
        verifyExecutionHelper { [weak self] result in
            guard let self else { return }
            guard case .success = result else {
                if case .failure(let error) = result { completion(.failure(error)) }
                return
            }
            self.performOperation(completion: completion) { proxy, reply in
                proxy.startOpenVPN(
                    profileID: profileID.uuidString,
                    configuration: configuration,
                    username: username,
                    password: password,
                    dnsServers: dnsServers,
                    dnsDomains: dnsDomains
                ) { success, message in
                    reply(success ? .success(message) : .failure(HelperClientError(message: message)))
                }
            }
        }
    }

    func startOpenConnect(
        profileID: VPNProfile.ID,
        server: String,
        serverCertificatePin: String,
        username: String,
        password: String,
        oneTimePassword: String,
        dnsServers: [String],
        dnsDomains: [String],
        completion: @escaping @MainActor (Result<String, Error>) -> Void
    ) {
        verifyExecutionHelper { [weak self] result in
            guard let self else { return }
            guard case .success = result else {
                if case .failure(let error) = result { completion(.failure(error)) }
                return
            }
            self.performOperation(completion: completion) { proxy, reply in
                proxy.startOpenConnect(
                    profileID: profileID.uuidString,
                    server: server,
                    serverCertificatePin: serverCertificatePin,
                    username: username,
                    password: password,
                    oneTimePassword: oneTimePassword,
                    dnsServers: dnsServers,
                    dnsDomains: dnsDomains
                ) { success, message in
                    reply(success ? .success(message) : .failure(HelperClientError(message: message)))
                }
            }
        }
    }

    private func verifyExecutionHelper(
        completion: @escaping @MainActor (Result<Void, Error>) -> Void
    ) {
        performOperation(completion: { [weak self] (result: Result<String, Error>) in
            guard let self else { return }
            switch result {
            case .success(let version):
                self.helperVersion = version
                guard version == HelperConstants.executionHelperVersion else {
                    guard Self.supportsAutomaticRestart(version) else {
                        completion(.failure(self.updateFailure(
                            installedVersion: version,
                            reason: "this helper predates the safe restart protocol."
                        )))
                        return
                    }
                    self.refreshExecutionHelper(completion: completion)
                    return
                }
                completion(.success(()))
            case .failure(let error):
                completion(.failure(error))
            }
        }, request: { proxy, reply in
            proxy.ping { version in reply(.success(version)) }
        })
    }

    private func refreshExecutionHelper(
        completion: @escaping @MainActor (Result<Void, Error>) -> Void
    ) {
        helperUpdateWaiters.append(completion)
        guard !isUpdatingHelper else { return }
        isUpdatingHelper = true

        performOperation(timeout: .seconds(3), completion: { [weak self] (result: Result<String, Error>) in
            guard let self else { return }
            switch result {
            case .success:
                self.waitForCurrentExecutionHelper(attemptsRemaining: 12)
            case .failure(let error):
                if error.localizedDescription == HelperConstants.restartDeferredMessage {
                    self.finishHelperUpdate(.failure(error))
                } else {
                    // The reply and connection invalidation can race when the
                    // helper exits, so look for the new process before failing.
                    self.waitForCurrentExecutionHelper(attemptsRemaining: 12)
                }
            }
        }, request: { proxy, reply in
            proxy.restartWhenIdle { success, message in
                reply(success ? .success(message) : .failure(HelperClientError(message: message)))
            }
        })
    }

    private func waitForCurrentExecutionHelper(attemptsRemaining: Int) {
        performOperation(timeout: .seconds(2), completion: { [weak self] (result: Result<String, Error>) in
            guard let self else { return }
            if case .success(let version) = result,
               version == HelperConstants.executionHelperVersion {
                self.helperVersion = version
                self.finishHelperUpdate(.success(()))
                return
            }

            guard attemptsRemaining > 1 else {
                let reason: String
                switch result {
                case .success(let version):
                    reason = "launchd continued to run \(version)."
                case .failure(let error):
                    reason = error.localizedDescription
                }
                self.finishHelperUpdate(.failure(self.updateFailure(
                    installedVersion: self.helperVersion ?? "an older helper",
                    reason: reason
                )))
                return
            }

            Task { @MainActor [weak self] in
                try? await Task.sleep(for: .milliseconds(250))
                self?.waitForCurrentExecutionHelper(attemptsRemaining: attemptsRemaining - 1)
            }
        }, request: { proxy, reply in
            proxy.ping { reply(.success($0)) }
        })
    }

    private func finishHelperUpdate(_ result: Result<Void, Error>) {
        isUpdatingHelper = false
        let waiters = helperUpdateWaiters
        helperUpdateWaiters.removeAll()
        for waiter in waiters { waiter(result) }
    }

    private func updateFailure(installedVersion: String, reason: String) -> HelperClientError {
        HelperClientError(message: """
        The running service is \(installedVersion), but \(HelperConstants.executionHelperVersion) is required. Automatic refresh failed: \(reason)

        As a fallback, unregister it in Settings, wait for Not installed, then register it again. This fallback is expected once when upgrading from a helper that predates automatic refresh.
        """)
    }

    nonisolated static func supportsAutomaticRestart(_ version: String) -> Bool {
        guard let token = version.split(separator: " ").last else { return false }
        let components = token.split(separator: ".").compactMap { Int($0) }
        guard components.count == 3 else { return false }
        return components.lexicographicallyPrecedes([0, 6, 2]) == false
    }

    func stopVPN(
        profileID: VPNProfile.ID,
        completion: @escaping @MainActor (Result<String, Error>) -> Void
    ) {
        performOperation(completion: completion) { proxy, reply in
            proxy.stopVPN(profileID: profileID.uuidString) { success, message in
                reply(success ? .success(message) : .failure(HelperClientError(message: message)))
            }
        }
    }

    func VPNStatus(
        profileID: VPNProfile.ID,
        completion: @escaping @MainActor (Result<HelperVPNStatus, Error>) -> Void
    ) {
        performOperation(completion: completion) { proxy, reply in
            proxy.VPNStatus(profileID: profileID.uuidString) { state, pid, interfaceName, log in
                reply(.success(HelperVPNStatus(
                    state: state,
                    processIdentifier: pid,
                    interfaceName: interfaceName,
                    log: log
                )))
            }
        }
    }

    func engineApprovalState(
        engine: VPNEngine,
        executablePath: String,
        completion: @escaping @MainActor (HelperEngineApproval) -> Void
    ) {
        performOperation(completion: { (result: Result<HelperEngineApproval, Error>) in
            switch result {
            case .success(let approval):
                completion(approval)
            case .failure(let error):
                completion(HelperEngineApproval(state: .unavailable, detail: error.localizedDescription))
            }
        }, request: { proxy, reply in
            proxy.engineApprovalState(engine: engine.rawValue, executablePath: executablePath) { state, detail in
                reply(.success(HelperEngineApproval(
                    state: EngineApprovalState(rawValue: state) ?? .unavailable,
                    detail: detail
                )))
            }
        })
    }

    func approveEngine(
        engine: VPNEngine,
        executablePath: String,
        vpncScriptPath: String?,
        completion: @escaping @MainActor (Result<String, Error>) -> Void
    ) {
        let granted: AdministratorAuthorization
        do {
            granted = try makeAdministratorAuthorization(
                prompt: "Bifrost needs your approval to run \(engine.displayName) at \(executablePath) with administrator privileges."
            )
        } catch {
            completion(.failure(error))
            return
        }
        let authorization = granted.externalForm
        performOperation(completion: { (result: Result<String, Error>) in
            granted.release()
            completion(result)
        }) { proxy, reply in
            proxy.approveEngine(
                engine: engine.rawValue,
                executablePath: executablePath,
                vpncScriptPath: vpncScriptPath ?? "",
                authorization: authorization
            ) { success, message in
                reply(success ? .success(message) : .failure(HelperClientError(message: message)))
            }
        }
    }

    func revokeEngine(
        engine: VPNEngine,
        completion: @escaping @MainActor (Result<String, Error>) -> Void
    ) {
        let granted: AdministratorAuthorization
        do {
            granted = try makeAdministratorAuthorization(
                prompt: "Bifrost needs your approval to withdraw \(engine.displayName)'s permission to run with administrator privileges."
            )
        } catch {
            completion(.failure(error))
            return
        }
        let authorization = granted.externalForm
        performOperation(completion: { (result: Result<String, Error>) in
            granted.release()
            completion(result)
        }) { proxy, reply in
            proxy.revokeEngine(engine: engine.rawValue, authorization: authorization) { success, message in
                reply(success ? .success(message) : .failure(HelperClientError(message: message)))
            }
        }
    }

    /// Prompts for administrator credentials here, in the app, so the sheet is
    /// attached to a visible user action, then hands the resulting credential to
    /// the helper as an `AuthorizationExternalForm`. The helper cannot prompt: a
    /// launch daemon has no window server session.
    ///
    /// The external form is a handle into `authd`, not a self-contained
    /// credential, so the reference it came from has to stay alive until the
    /// helper has restored it. Freeing it first makes the helper's
    /// `AuthorizationCreateFromExternalForm` fail with `errAuthorizationInvalidRef`.
    private func makeAdministratorAuthorization(prompt: String) throws -> AdministratorAuthorization {
        var reference: AuthorizationRef?
        guard AuthorizationCreate(nil, nil, [], &reference) == errAuthorizationSuccess,
              let reference else {
            throw HelperClientError(message: "macOS could not start an authorization session.")
        }

        // Every C string below must outlive the AuthorizationCopyRights call, so
        // each one gets its own withCString scope rather than an implicit
        // String-to-pointer conversion that dangles as soon as it is made.
        let status = EngineApproval.right.withCString { rightName in
            kAuthorizationEnvironmentPrompt.withCString { promptName in
                prompt.withCString { promptText -> OSStatus in
                    var item = AuthorizationItem(name: rightName, valueLength: 0, value: nil, flags: 0)
                    var promptItem = AuthorizationItem(
                        name: promptName,
                        valueLength: strlen(promptText),
                        value: UnsafeMutableRawPointer(mutating: promptText),
                        flags: 0
                    )
                    return withUnsafeMutablePointer(to: &item) { itemPointer in
                        withUnsafeMutablePointer(to: &promptItem) { promptPointer in
                            var rights = AuthorizationRights(count: 1, items: itemPointer)
                            var environment = AuthorizationEnvironment(count: 1, items: promptPointer)
                            return AuthorizationCopyRights(
                                reference,
                                &rights,
                                &environment,
                                [.extendRights, .interactionAllowed],
                                nil
                            )
                        }
                    }
                }
            }
        }
        guard status == errAuthorizationSuccess else {
            AuthorizationFree(reference, [])
            throw HelperClientError(
                message: status == errAuthorizationCanceled
                    ? "Administrator approval was cancelled."
                    : "Administrator approval failed (status \(status))."
            )
        }

        var form = AuthorizationExternalForm()
        guard AuthorizationMakeExternalForm(reference, &form) == errAuthorizationSuccess else {
            AuthorizationFree(reference, [])
            throw HelperClientError(message: "The administrator approval could not be handed to the helper.")
        }
        return AdministratorAuthorization(
            reference: reference,
            externalForm: withUnsafeBytes(of: &form) { Data($0) }
        )
    }

    private var service: SMAppService {
        SMAppService.daemon(plistName: HelperConstants.launchDaemonPlistName)
    }

    private func performOperation<Value: Sendable>(
        timeout: Duration = .seconds(20),
        completion: @escaping @MainActor (Result<Value, Error>) -> Void,
        request: (HelperXPCProtocol, @escaping @Sendable (Result<Value, Error>) -> Void) -> Void
    ) {
        guard status == .enabled else {
            completion(.failure(HelperClientError(message: "The privileged helper is not enabled.")))
            return
        }

        let operationID = UUID()
        let connection = NSXPCConnection(
            machServiceName: HelperConstants.machServiceName,
            options: .privileged
        )
        connection.remoteObjectInterface = NSXPCInterface(with: HelperXPCProtocol.self)
        operationConnections[operationID] = connection

        let bridge = XPCResultBridge<Value> { [weak self] result in
            Task { @MainActor in
                guard let self,
                      let connection = self.operationConnections.removeValue(forKey: operationID) else { return }
                connection.interruptionHandler = nil
                connection.invalidationHandler = nil
                connection.invalidate()
                completion(result)
            }
        }

        connection.interruptionHandler = {
            bridge.fail(with: "The privileged helper connection was interrupted.")
        }
        connection.invalidationHandler = {
            bridge.fail(with: "The privileged helper connection became invalid.")
        }
        connection.resume()

        guard let proxy = connection.remoteObjectProxyWithErrorHandler(bridge.handle(error:)) as? HelperXPCProtocol else {
            bridge.fail(with: "The privileged helper proxy could not be created.")
            return
        }
        request(proxy, bridge.deliver)
        // XPC can stay connected without ever delivering a reply. The bridge discards
        // late/duplicate completions through operationConnections.removeValue.
        Task { @MainActor in
            try? await Task.sleep(for: timeout)
            guard self.operationConnections[operationID] != nil else { return }
            bridge.fail(with: "The privileged helper did not reply before the operation timed out.")
        }
    }

    private func detailedMessage(for error: Error) -> String {
        let error = error as NSError
        var parts = [error.localizedDescription, "\(error.domain) (\(error.code))"]
        if let reason = error.localizedFailureReason {
            parts.append(reason)
        }
        if let suggestion = error.localizedRecoverySuggestion {
            parts.append(suggestion)
        }
        return parts.joined(separator: "\n\n")
    }
}
