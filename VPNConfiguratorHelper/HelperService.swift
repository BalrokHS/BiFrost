import Foundation
import OSLog
import Security
import Darwin

private let logger = Logger(
    subsystem: "com.klianos.VPNConfigurator.helper",
    category: "VPNLifecycle"
)

enum HelperFailure: LocalizedError {
    case invalidProfileID
    case invalidGateway(String)
    case invalidTrustedCertificate
    case invalidServerCertificatePin
    case missingCredentials
    case unsafeSecret
    case invalidDNS(String)
    case resolverConflict(String)
    case untrustedExecutable(String)
    case notAuthorized(String)
    case alreadyRunning
    case notRunning
    case launchFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidProfileID:
            "The VPN profile identifier is invalid."
        case .invalidGateway(let reason):
            "The VPN server was rejected: \(reason)"
        case .invalidTrustedCertificate:
            "The trusted certificate must be a 64-character SHA-256 hexadecimal digest."
        case .invalidServerCertificatePin:
            "The OpenConnect server certificate pin is invalid."
        case .missingCredentials:
            "Both a username and password are required for this VPN profile."
        case .unsafeSecret:
            "A credential contains a newline or null byte and cannot be passed safely."
        case .invalidDNS(let reason):
            "The profile DNS configuration was rejected: \(reason)"
        case .resolverConflict(let domain):
            "The DNS domain \(domain) already has a resolver that is not owned by this VPN profile."
        case .untrustedExecutable(let reason):
            "An installed VPN artifact is not trusted: \(reason)"
        case .notAuthorized(let reason):
            "Administrator approval was not granted: \(reason)"
        case .alreadyRunning:
            "This VPN profile is already running."
        case .notRunning:
            "This VPN profile is not running."
        case .launchFailed(let reason):
            "The VPN client could not start: \(reason)"
        }
    }
}

private struct ProcessSpecification: Sendable {
    let clientName: String
    let executablePath: String
    let arguments: [String]
    let temporaryURLs: [URL]
    let dnsServers: [String]
    let dnsDomains: [String]
    let connectedMarkers: [String]
    var standardInput: Data? = nil
    var launchLog: String? = nil
}

private final class ReplyBox<Value>: @unchecked Sendable {
    let call: (Value) -> Void
    init(_ call: @escaping (Value) -> Void) { self.call = call }
}

final class HelperService: NSObject, HelperXPCProtocol, @unchecked Sendable {
    let queue = DispatchQueue(label: "com.klianos.VPNConfigurator.helper.sessions")
    private let trustQueue = DispatchQueue(label: "com.klianos.VPNConfigurator.helper.trust", qos: .userInitiated)
    private let resolveEngine: @Sendable (VPNEngine) throws -> ApprovedEngine
    private let terminate: @Sendable () -> Void
    var sessions: [String: VPNSession] = [:]
    private var pendingStarts: Set<String> = []
    private var restartRequested = false
    private var terminationScheduled = false

    init(
        resolveEngine: @escaping @Sendable (VPNEngine) throws -> ApprovedEngine = ApprovedEngineStore.resolve,
        terminate: @escaping @Sendable () -> Void = { _exit(EXIT_SUCCESS) }
    ) {
        self.resolveEngine = resolveEngine
        self.terminate = terminate
        super.init()
    }

    func ping(reply: @escaping @Sendable (String) -> Void) {
        reply(HelperConstants.executionHelperVersion)
    }

    func restartWhenIdle(reply: @escaping @Sendable (Bool, String) -> Void) {
        let replyBox = ReplyBox<(Bool, String)> { reply($0.0, $0.1) }
        queue.async { [self] in
            restartRequested = true
            let hasActiveSession = sessions.values.contains { !$0.didFinish }
            guard pendingStarts.isEmpty, !hasActiveSession else {
                replyBox.call((false, HelperConstants.restartDeferredMessage))
                return
            }
            replyBox.call((true, "The helper is restarting from the current app bundle."))
            scheduleTerminationIfIdle()
        }
    }

    private func scheduleTerminationIfIdle() {
        let hasActiveSession = sessions.values.contains { !$0.didFinish }
        guard restartRequested, !terminationScheduled, pendingStarts.isEmpty, !hasActiveSession else { return }
        terminationScheduled = true
        let terminate = self.terminate
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + .milliseconds(200)) {
            terminate()
        }
    }

    func startOpenFortiVPN(
        profileID: String,
        server: String,
        trustedCertificate: String,
        username: String,
        password: String,
        oneTimePassword: String,
        useSAML: Bool,
        dnsServers: [String],
        dnsDomains: [String],
        reply: @escaping @Sendable (Bool, String) -> Void
    ) {
        let replyBox = ReplyBox<(Bool, String)> { reply($0.0, $0.1) }
        withApprovedEngine(.openFortiVPN, profileID: profileID, replyBox: replyBox) { [self] engine in
            var temporaryURLs: [URL] = []
            do {
                let gateway = try HelperInputValidator.gateway(server)
                let trustedCertificate = try HelperInputValidator.trustedCertificate(trustedCertificate)
                try HelperInputValidator.secret(username)
                try HelperInputValidator.secret(password)
                try HelperInputValidator.secret(oneTimePassword)
                let dnsConfiguration = try HelperInputValidator.dnsConfiguration(
                    servers: dnsServers,
                    domains: dnsDomains
                )

                let temporaryURL = try SecureRuntimeFiles.makeOpenFortiVPNConfiguration(
                    profileID: profileID,
                    host: gateway.host,
                    port: gateway.port,
                    trustedCertificate: trustedCertificate,
                    username: username,
                    password: password,
                    oneTimePassword: oneTimePassword
                )
                temporaryURLs.append(temporaryURL)

                var arguments = [
                    "-c", temporaryURL.path,
                    "--set-routes=1",
                    "--no-dns",
                    "--pppd-use-peerdns=0"
                ]
                if useSAML { arguments.append("--saml-login") }
                try launch(ProcessSpecification(
                    clientName: "OpenFortiVPN",
                    executablePath: engine.executablePath,
                    arguments: arguments,
                    temporaryURLs: temporaryURLs,
                    dnsServers: dnsConfiguration.servers,
                    dnsDomains: dnsConfiguration.domains,
                    connectedMarkers: ["Tunnel is up and running"]
                ), profileID: profileID)
                return "OpenFortiVPN started."
            } catch {
                SecureRuntimeFiles.remove(temporaryURLs)
                throw error
            }
        }
    }

    func startOpenVPN(
        profileID: String,
        configuration: String,
        username: String,
        password: String,
        dnsServers: [String],
        dnsDomains: [String],
        reply: @escaping @Sendable (Bool, String) -> Void
    ) {
        let replyBox = ReplyBox<(Bool, String)> { reply($0.0, $0.1) }
        withApprovedEngine(.openVPN, profileID: profileID, replyBox: replyBox) { [self] engine in
            var temporaryURLs: [URL] = []
            do {
                try HelperInputValidator.secret(username)
                try HelperInputValidator.secret(password)
                guard !username.isEmpty, !password.isEmpty else {
                    throw HelperFailure.missingCredentials
                }
                let safeConfiguration = try HelperInputValidator.openVPNConfiguration(configuration)
                let dnsConfiguration = try HelperInputValidator.dnsConfiguration(servers: dnsServers, domains: dnsDomains)

                let configURL = try SecureRuntimeFiles.make(
                    profileID: profileID,
                    suffix: "ovpn",
                    data: Data(safeConfiguration.utf8)
                )
                temporaryURLs.append(configURL)
                let authURL = try SecureRuntimeFiles.make(
                    profileID: profileID,
                    suffix: "auth",
                    data: Data("\(username)\n\(password)\n".utf8)
                )
                temporaryURLs.append(authURL)
                try launch(ProcessSpecification(
                    clientName: "OpenVPN",
                    executablePath: engine.executablePath,
                    arguments: [
                        "--config", configURL.path,
                        "--auth-user-pass", authURL.path,
                        "--auth-nocache",
                        "--script-security", "1"
                    ],
                    temporaryURLs: temporaryURLs,
                    dnsServers: dnsConfiguration.servers,
                    dnsDomains: dnsConfiguration.domains,
                    connectedMarkers: ["Initialization Sequence Completed"],
                    launchLog: "Supplied the Authentication section username and password using OpenVPN's two-line auth-user-pass file format.\n"
                ), profileID: profileID)
                return "OpenVPN started."
            } catch {
                SecureRuntimeFiles.remove(temporaryURLs)
                throw error
            }
        }
    }

    func startOpenConnect(
        profileID: String,
        server: String,
        serverCertificatePin: String,
        username: String,
        password: String,
        oneTimePassword: String,
        dnsServers: [String],
        dnsDomains: [String],
        reply: @escaping @Sendable (Bool, String) -> Void
    ) {
        let replyBox = ReplyBox<(Bool, String)> { reply($0.0, $0.1) }
        withApprovedEngine(.openConnect, profileID: profileID, replyBox: replyBox) { [self] engine in
            var temporaryURLs: [URL] = []
            do {
                let gateway = try HelperInputValidator.gateway(server)
                let pin = try HelperInputValidator.openConnectPin(serverCertificatePin)
                try HelperInputValidator.secret(username)
                try HelperInputValidator.secret(password)
                try HelperInputValidator.secret(oneTimePassword)
                let dnsConfiguration = try HelperInputValidator.dnsConfiguration(servers: dnsServers, domains: dnsDomains)
                let wrapperURL = try SecureRuntimeFiles.makeOpenConnectScript(profileID: profileID, engine: engine)
                temporaryURLs.append(wrapperURL)
                var arguments = [
                    "https://\(gateway.host):\(gateway.port)",
                    "--user", username,
                    "--useragent", "AnyConnect-compatible OpenConnect VPN Agent",
                    "--passwd-on-stdin",
                    "--non-inter",
                    "--no-system-trust",
                    "--cafile", EngineApproval.systemCABundle,
                    "--script", wrapperURL.path
                ]
                if !pin.isEmpty { arguments += ["--servercert", pin] }
                let submittedPassword = password + oneTimePassword
                try launch(ProcessSpecification(
                    clientName: "OpenConnect",
                    executablePath: engine.executablePath,
                    arguments: arguments,
                    temporaryURLs: temporaryURLs,
                    dnsServers: dnsConfiguration.servers,
                    dnsDomains: dnsConfiguration.domains,
                    connectedMarkers: ["CSTP connected", "ESP session established", "Connected as"],
                    standardInput: Data("\(submittedPassword)\n".utf8)
                ), profileID: profileID)
                return "OpenConnect started."
            } catch {
                SecureRuntimeFiles.remove(temporaryURLs)
                throw error
            }
        }
    }

    func stopVPN(profileID: String, reply: @escaping @Sendable (Bool, String) -> Void) {
        let replyBox = ReplyBox<(Bool, String)> { reply($0.0, $0.1) }
        queue.async { [self] in
            guard let session = sessions[profileID], session.process.isRunning else {
                replyBox.call((false, HelperFailure.notRunning.localizedDescription))
                return
            }

            session.stopRequested = true
            session.state = .disconnecting
            append("Stopping \(session.clientName)…\n", to: session)
            session.process.terminate()
            logger.info("Stopping profile \(profileID, privacy: .public)")
            replyBox.call((true, "Disconnect requested."))

            queue.asyncAfter(deadline: .now() + 8) { [weak session] in
                guard let session, session.process.isRunning else { return }
                kill(session.process.processIdentifier, SIGKILL)
            }
        }
    }

    func VPNStatus(
        profileID: String,
        reply: @escaping @Sendable (String, Int32, String, String) -> Void
    ) {
        let replyBox = ReplyBox<(String, Int32, String, String)> {
            reply($0.0, $0.1, $0.2, $0.3)
        }
        queue.async { [self] in
            if pendingStarts.contains(profileID) {
                replyBox.call((HelperSessionState.connecting.rawValue, 0, "", "Verifying the approved VPN engine…\n"))
                return
            }
            guard let session = sessions[profileID] else {
                replyBox.call((HelperSessionState.disconnected.rawValue, 0, "", ""))
                return
            }
            let pid = session.process.isRunning ? session.process.processIdentifier : 0
            replyBox.call((session.state.rawValue, pid, session.interfaceName, session.log))
        }
    }

    func engineApprovalState(
        engine: String,
        executablePath: String,
        reply: @escaping @Sendable (String, String) -> Void
    ) {
        let replyBox = ReplyBox<(String, String)> { reply($0.0, $0.1) }
        trustQueue.async {
            guard let engine = VPNEngine(rawValue: engine) else {
                replyBox.call((EngineApprovalState.unavailable.rawValue, "\(engine) is not a supported VPN engine."))
                return
            }
            let result = ApprovedEngineStore.state(for: engine, executablePath: executablePath)
            replyBox.call((result.state.rawValue, result.detail))
        }
    }

    func approveEngine(
        engine: String,
        executablePath: String,
        vpncScriptPath: String,
        authorization: Data,
        reply: @escaping @Sendable (Bool, String) -> Void
    ) {
        let replyBox = ReplyBox<(Bool, String)> { reply($0.0, $0.1) }
        trustQueue.async {
            do {
                guard let engine = VPNEngine(rawValue: engine) else {
                    throw HelperFailure.untrustedExecutable("\(engine) is not a supported VPN engine.")
                }
                try Self.requireAdministrator(authorization)
                let approved = try ApprovedEngineStore.approve(
                    engine,
                    executablePath: executablePath,
                    vpncScriptPath: vpncScriptPath.isEmpty ? nil : vpncScriptPath
                )
                logger.info("Approved \(approved.engine.rawValue, privacy: .public) at \(approved.executablePath, privacy: .public) with \(approved.files.count) pinned files")
                replyBox.call((true, "\(approved.engine.displayName) is approved. \(approved.files.count) file\(approved.files.count == 1 ? "" : "s") are pinned and rechecked before every connection."))
            } catch {
                logger.error("Approval rejected: \(error.localizedDescription, privacy: .public)")
                replyBox.call((false, error.localizedDescription))
            }
        }
    }

    func revokeEngine(
        engine: String,
        authorization: Data,
        reply: @escaping @Sendable (Bool, String) -> Void
    ) {
        let replyBox = ReplyBox<(Bool, String)> { reply($0.0, $0.1) }
        trustQueue.async {
            do {
                guard let engine = VPNEngine(rawValue: engine) else {
                    throw HelperFailure.untrustedExecutable("\(engine) is not a supported VPN engine.")
                }
                try Self.requireAdministrator(authorization)
                try ApprovedEngineStore.revoke(engine)
                replyBox.call((true, "\(engine.displayName) is no longer approved."))
            } catch {
                replyBox.call((false, error.localizedDescription))
            }
        }
    }

    /// The XPC peer is already code-signature checked, but approving an executable
    /// for root execution is a privilege grant, so it also needs a live human
    /// administrator. The app prompts and forwards the resulting credential; this
    /// side re-checks it without `.interactionAllowed`, because a launch daemon has
    /// no session in which to present UI.
    static func requireAdministrator(_ externalForm: Data) throws {
        guard externalForm.count == MemoryLayout<AuthorizationExternalForm>.size else {
            throw HelperFailure.notAuthorized("the authorization token is malformed.")
        }
        var form = AuthorizationExternalForm()
        withUnsafeMutableBytes(of: &form) { _ = externalForm.copyBytes(to: $0) }

        var reference: AuthorizationRef?
        guard AuthorizationCreateFromExternalForm(&form, &reference) == errAuthorizationSuccess,
              let reference else {
            throw HelperFailure.notAuthorized("the authorization token could not be restored.")
        }
        defer { AuthorizationFree(reference, []) }

        let status = EngineApproval.right.withCString { name -> OSStatus in
            var item = AuthorizationItem(name: name, valueLength: 0, value: nil, flags: 0)
            return withUnsafeMutablePointer(to: &item) { pointer in
                var rights = AuthorizationRights(count: 1, items: pointer)
                return AuthorizationCopyRights(reference, &rights, nil, [.extendRights], nil)
            }
        }
        guard status == errAuthorizationSuccess else {
            throw HelperFailure.notAuthorized("macOS returned status \(status) for \(EngineApproval.right).")
        }
    }

    /// Engines run from the prefix their package manager owns, so their TLS
    /// libraries must not take configuration or trust roots from that prefix.
    /// No DYLD_* variable is passed, so the child loads exactly the libraries
    /// named in the Mach-O images that approval pinned.
    private var secureEnvironment: [String: String] {
        [
            "HOME": "/var/root",
            "LANG": "C",
            "PATH": "/usr/bin:/bin:/usr/sbin:/sbin",
            "OPENSSL_CONF": "/dev/null",
            "OPENSSL_MODULES": "/var/empty",
            "SSL_CERT_FILE": EngineApproval.systemCABundle,
            "SSL_CERT_DIR": "/var/empty",
            "GNUTLS_SYSTEM_PRIORITY_FILE": "/dev/null",
            "P11_KIT_NO_USER_CONFIG": "1"
        ]
    }

    /// Reserves the profile on the state queue, verifies its approved engine on a
    /// separate serial queue, then returns to the state queue for process launch.
    /// Status and stop requests therefore remain responsive while files are hashed.
    private func withApprovedEngine(
        _ engine: VPNEngine,
        profileID: String,
        replyBox: ReplyBox<(Bool, String)>,
        operation: @escaping @Sendable (ApprovedEngine) throws -> String
    ) {
        queue.async { [self] in
            do {
                try validateNewSession(profileID)
                pendingStarts.insert(profileID)
            } catch {
                replyBox.call((false, error.localizedDescription))
                return
            }

            trustQueue.async { [self] in
                let result = Result { try resolveEngine(engine) }
                queue.async { [self] in
                    pendingStarts.remove(profileID)
                    do {
                        replyBox.call((true, try operation(result.get())))
                    } catch {
                        logger.error("Start rejected for profile \(profileID, privacy: .public): \(error.localizedDescription, privacy: .public)")
                        replyBox.call((false, error.localizedDescription))
                    }
                    scheduleTerminationIfIdle()
                }
            }
        }
    }

    private func validateNewSession(_ profileID: String) throws {
        guard UUID(uuidString: profileID) != nil else { throw HelperFailure.invalidProfileID }
        guard !restartRequested else {
            throw HelperFailure.launchFailed("the helper is restarting to apply an update.")
        }
        if pendingStarts.contains(profileID) || sessions[profileID].map({ !$0.didFinish }) == true {
            throw HelperFailure.alreadyRunning
        }
    }

    private func launch(_ specification: ProcessSpecification, profileID: String) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: specification.executablePath)
        process.currentDirectoryURL = URL(fileURLWithPath: "/", isDirectory: true)
        process.arguments = specification.arguments
        process.environment = secureEnvironment

        let inputPipe = specification.standardInput.map { _ in Pipe() }
        process.standardInput = inputPipe ?? FileHandle.nullDevice
        let session = VPNSession(
            profileID: profileID,
            clientName: specification.clientName,
            process: process,
            temporaryURLs: specification.temporaryURLs,
            dnsServers: specification.dnsServers,
            dnsDomains: specification.dnsDomains,
            connectedMarkers: specification.connectedMarkers
        )
        try launch(session)

        if let input = specification.standardInput, let inputPipe {
            inputPipe.fileHandleForWriting.write(input)
            try? inputPipe.fileHandleForWriting.close()
        }
        if let launchLog = specification.launchLog {
            append(launchLog, to: session)
        }
    }

    func launch(_ session: VPNSession) throws {
        session.process.standardOutput = session.outputPipe
        session.process.standardError = session.errorPipe
        installReaders(for: session)
        session.process.terminationHandler = { [weak self, weak session] process in
            guard let self, let session else { return }
            self.queue.async { self.finish(session: session, exitStatus: process.terminationStatus) }
        }
        sessions[session.profileID] = session
        do {
            try session.process.run()
        } catch {
            session.outputPipe.fileHandleForReading.readabilityHandler = nil
            session.errorPipe.fileHandleForReading.readabilityHandler = nil
            if sessions[session.profileID] === session { sessions[session.profileID] = nil }
            throw error
        }
        append("Started \(session.clientName) (PID \(session.process.processIdentifier)).\n", to: session)
        logger.info("Started \(session.clientName, privacy: .public) profile \(session.profileID, privacy: .public), PID \(session.process.processIdentifier)")
    }

    private func installReaders(for session: VPNSession) {
        session.outputPipe.fileHandleForReading.readabilityHandler = { [weak self, weak session] handle in
            guard let self, let session else { return }
            let data = handle.availableData
            guard !data.isEmpty else {
                handle.readabilityHandler = nil
                return
            }
            let text = String(decoding: data, as: UTF8.self)
            self.queue.async { self.append(text, to: session) }
        }
        session.errorPipe.fileHandleForReading.readabilityHandler = { [weak self, weak session] handle in
            guard let self, let session else { return }
            let data = handle.availableData
            guard !data.isEmpty else {
                handle.readabilityHandler = nil
                return
            }
            let text = String(decoding: data, as: UTF8.self)
            self.queue.async { self.append(text, to: session) }
        }
    }

    func append(_ text: String, to session: VPNSession) {
        session.log.append(text)
        if session.log.utf8.count > 64 * 1_024 {
            session.log = String(session.log.suffix(48 * 1_024))
        }

        // Log history must never revive a stopped session or undo a connection.
        guard !session.didFinish, !session.stopRequested else { return }
        if !session.didProcessConnectedMarker, session.state == .connecting,
           session.log.localizedCaseInsensitiveContains("Authenticate at '") {
            session.state = .waitingForAuthentication
        }
        if session.log.localizedCaseInsensitiveContains("AUTH_FAILED"),
           !session.didDetectAuthenticationFailure {
            session.didDetectAuthenticationFailure = true
            session.state = .failed
            session.log.append(
                "The server rejected authentication or a server-side connection policy check. OpenVPN had already read and submitted the Authentication section credentials.\n"
            )
        }
        if session.log.localizedCaseInsensitiveContains("unauthorized connection mechanism"),
           !session.didDetectAuthenticationFailure {
            session.didDetectAuthenticationFailure = true
            session.state = .failed
            session.log.append(
                "The gateway rejected the AnyConnect client mechanism before authentication completed.\n"
            )
        }
        if session.connectedMarkers.contains(where: session.log.localizedCaseInsensitiveContains),
           !session.didProcessConnectedMarker, !session.didDetectAuthenticationFailure {
            session.didProcessConnectedMarker = true
            do {
                try activateResolvers(for: session)
                session.state = .connected
            } catch {
                session.state = .failed
                session.log.append("Split DNS could not be installed after the tunnel connected: \(error.localizedDescription)\n")
                session.process.terminate()
            }
        }
        if let range = session.log.range(
            of: #"(?:ppp|utun|tun)[0-9]+"#,
            options: [.regularExpression, .backwards]
        ) {
            session.interfaceName = String(session.log[range])
        }
    }

    private func activateResolvers(for session: VPNSession) throws {
        session.resolverURLs = try ResolverManager.install(
            profileID: session.profileID,
            servers: session.dnsServers,
            domains: session.dnsDomains
        )
        guard !session.dnsDomains.isEmpty else { return }
        session.log.append(
            "Installed configured split DNS for \(session.dnsDomains.joined(separator: ", ")) using \(session.dnsServers.joined(separator: ", ")).\n"
        )
    }

    func finish(session: VPNSession, exitStatus: Int32) {
        guard !session.didFinish else { return }
        session.didFinish = true
        session.outputPipe.fileHandleForReading.readabilityHandler = nil
        session.errorPipe.fileHandleForReading.readabilityHandler = nil
        for url in session.temporaryURLs { try? FileManager.default.removeItem(at: url) }
        ResolverManager.remove(session.resolverURLs, ownedBy: session.profileID)
        if session.stopRequested {
            session.state = .disconnected
        } else if session.state == .failed || !session.didProcessConnectedMarker || exitStatus != 0 {
            session.state = .failed
        } else {
            session.state = .disconnected
        }
        append("\(session.clientName) exited with status \(exitStatus).\n", to: session)
        logger.info("Profile \(session.profileID, privacy: .public) exited with status \(exitStatus)")
        scheduleTerminationIfIdle()
    }
}
