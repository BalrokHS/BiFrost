import Foundation

// Compiled with the helper service sources by script/test.sh. No root privileges,
// VPN gateway, /etc/resolver changes, or XPC registration are involved.
private func check(_ condition: @autoclosure () -> Bool, _ description: String) {
    guard condition() else { fatalError("FAIL: \(description)") }
    print("PASS: \(description)")
}

private func rejects(_ configuration: String) {
    do {
        _ = try OpenVPNConfiguration.sanitize(configuration)
        fatalError("Accepted unsafe/unsupported configuration: \(configuration)")
    } catch is OpenVPNConfigurationError { }
    catch { fatalError("Unexpected error: \(error)") }
}

private func parserTests() throws {
    for spelling in ["log", "--log", "\"log\"", "'log'", "l\\og"] {
        rejects("\(spelling) /tmp/should-not-be-created")
    }
    for directive in ["plugin /tmp/code", "--config /tmp/nested", "providers legacy", "engine dynamic", "setenv OPENSSL_CONF /tmp/code", "pkcs11-providers /tmp/code", "dev /tmp/device", "management /tmp/socket unix"] {
        rejects(directive)
    }
    for block in ["connection", "plugin", "config", "unknown"] {
        rejects("<\(block)>\n--log /tmp/code\n</\(block)>")
    }
    rejects("<ca>\ncertificate\n</key>")
    rejects("<ca>\ncertificate")
    rejects("remote \"unterminated")
    rejects("client\0\n")
    rejects(String(repeating: "#", count: 2_000_001))
    for directive in ["ca cert.pem", "--cert cert.pem", "key key.pem", "tls-auth ta.key 1", "pkcs12 identity.p12"] {
        rejects(directive)
    }
    check(true, "unsafe option spellings, inline blocks, external files and malformed input rejected")

    let safe = try OpenVPNConfiguration.sanitize("""
    --client
    dev tun
    remote vpn.example.com 1194 udp
    verify-x509-name "VPN server" name
    --auth-user-pass "/tmp/password file"
    <auth-user-pass>
    secret-username
    secret-password
    </auth-user-pass>
    <ca>
    -----BEGIN CERTIFICATE-----
    YWJj
    -----END CERTIFICATE-----
    </ca>
    """)
    check(!safe.contains("secret-") && !safe.contains("auth-user-pass"), "all imported credentials removed")
    check(safe.contains("<ca>") && safe.contains("YWJj"), "inline TLS material preserved")
    check(safe.contains("remote \"vpn.example.com\" \"1194\" \"udp\""), "remote metadata canonicalized")
    let roundTrip = try OpenVPNConfiguration.sanitize(safe)
    check(roundTrip == safe, "canonical configuration is stable across repeated validation")
    let tokens = try OpenVPNConfiguration.tokens(in: "verify-x509-name \"VPN server\" name # comment")
    check(tokens == ["verify-x509-name", "VPN server", "name"], "quoted arguments and comments parsed")
}

private func newSession(process: Process = Process()) -> VPNSession {
    VPNSession(profileID: UUID().uuidString, clientName: "Test", process: process,
               temporaryURLs: [], dnsServers: [], dnsDomains: [], connectedMarkers: ["Tunnel is up and running"])
}

private extension HelperService {
static func stateTests() {
    let helper = HelperService()
    let session = newSession()
    helper.append("Authenticate at 'https://example.com'\n", to: session)
    check(session.state == .waitingForAuthentication, "SAML authentication marker recognized")
    helper.append("Tunnel is up and running\n", to: session)
    check(session.state == .connected, "SAML tunnel becomes connected")
    helper.append("A later status message\n", to: session)
    check(session.state == .connected, "historical SAML marker cannot undo connected state")
    session.stopRequested = true
    session.state = .disconnecting
    helper.append("Tunnel is up and running\n", to: session)
    check(session.state == .disconnecting, "late output cannot undo disconnect request")
    helper.finish(session: session, exitStatus: 0)
    helper.append("Authenticate at 'https://example.com'\n", to: session)
    check(session.state == .disconnected, "exit and late output cannot revive a session")
    let failed = newSession()
    helper.append("AUTH_FAILED\nTunnel is up and running\n", to: failed)
    check(failed.state == .failed, "authentication failure wins over a stale success marker")
}

static func duplicateStartTests() throws {
    let helper = HelperService()
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/bin/sleep")
    process.arguments = ["30"]
    let session = newSession(process: process)
    try helper.queue.sync { try helper.launch(session) }
    defer {
        if process.isRunning { process.terminate() }
        process.waitUntilExit()
    }
    let replied = DispatchSemaphore(value: 0)
    helper.startOpenVPN(profileID: session.profileID, configuration: "client", username: "u", password: "p", dnsServers: [], dnsDomains: []) { success, message in
        check(!success && message.contains("already running"), "duplicate OpenVPN start rejected")
        replied.signal()
    }
    check(replied.wait(timeout: .now() + 3) == .success, "OpenVPN duplicate replies")
    helper.queue.sync { check(helper.sessions[session.profileID] === session && process.isRunning, "OpenVPN duplicate preserves original running session") }
    helper.startOpenConnect(profileID: session.profileID, server: "example.com", serverCertificatePin: "", username: "u", password: "p", oneTimePassword: "", dnsServers: [], dnsDomains: []) { success, message in
        check(!success && message.contains("already running"), "duplicate OpenConnect start rejected")
        replied.signal()
    }
    check(replied.wait(timeout: .now() + 3) == .success, "OpenConnect duplicate replies")
    helper.queue.sync { check(helper.sessions[session.profileID] === session, "OpenConnect duplicate preserves original session") }
    helper.stopVPN(profileID: session.profileID) { success, _ in
        check(success, "preserved session remains stoppable")
        replied.signal()
    }
    check(replied.wait(timeout: .now() + 3) == .success, "stop replies")
}

static func trustWorkDoesNotBlockSessionQueue() {
    let enteredTrust = DispatchSemaphore(value: 0)
    let releaseTrust = DispatchSemaphore(value: 0)
    let helper = HelperService { _ in
        enteredTrust.signal()
        releaseTrust.wait()
        throw EngineTrustError(message: "test rejection")
    }
    let profileID = UUID().uuidString
    let startReplied = DispatchSemaphore(value: 0)
    helper.startOpenVPN(
        profileID: profileID,
        configuration: "client\nremote vpn.example.com\n",
        username: "user",
        password: "password",
        dnsServers: [],
        dnsDomains: []
    ) { success, _ in
        check(!success, "blocked trust test eventually rejects its launch")
        startReplied.signal()
    }
    check(enteredTrust.wait(timeout: .now() + 2) == .success, "engine verification begins off the session queue")

    let statusReplied = DispatchSemaphore(value: 0)
    helper.VPNStatus(profileID: profileID) { state, _, _, _ in
        check(state == HelperSessionState.connecting.rawValue,
              "status remains responsive while engine verification is running")
        statusReplied.signal()
    }
    check(statusReplied.wait(timeout: .now() + 1) == .success,
          "engine verification does not block the session queue")
    releaseTrust.signal()
    check(startReplied.wait(timeout: .now() + 2) == .success, "engine verification completion replies")
}

static func idleRestartTests() {
    let activeTermination = DispatchSemaphore(value: 0)
    let activeHelper = HelperService(terminate: { activeTermination.signal() })
    let activeSession = newSession()
    activeHelper.queue.sync { activeHelper.sessions[activeSession.profileID] = activeSession }
    let activeReply = DispatchSemaphore(value: 0)
    activeHelper.restartWhenIdle { success, message in
        check(!success && message.contains("active VPN sessions"),
              "helper update is deferred while a VPN session is active")
        activeReply.signal()
    }
    check(activeReply.wait(timeout: .now() + 1) == .success, "active-session restart request replies")
    check(activeTermination.wait(timeout: .now() + .milliseconds(300)) == .timedOut,
          "active-session restart does not terminate the helper")
    activeHelper.queue.sync { activeHelper.finish(session: activeSession, exitStatus: 0) }
    check(activeTermination.wait(timeout: .now() + 1) == .success,
          "queued helper update restarts automatically after the active session finishes")

    let idleTermination = DispatchSemaphore(value: 0)
    let idleHelper = HelperService(terminate: { idleTermination.signal() })
    let idleReply = DispatchSemaphore(value: 0)
    idleHelper.restartWhenIdle { success, _ in
        check(success, "idle helper accepts an automatic update restart")
        idleReply.signal()
    }
    check(idleReply.wait(timeout: .now() + 1) == .success, "idle restart replies before termination")
    check(idleTermination.wait(timeout: .now() + 1) == .success,
          "idle helper terminates after acknowledging restart")
}

}

private func trustTests() throws {
    // A positive path check must work; a gate that rejects everything is not a test.
    try ExecutableTrust.requireRootOwned("/usr/bin/true")
    check(true, "root-owned system path passes ownership and ACL checks")
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let candidate = directory.appendingPathComponent("engine")
    try Data("not an executable".utf8).write(to: candidate)
    do { try ExecutableTrust.requireRootOwned(candidate.path); fatalError("Accepted user-controlled path") }
    catch is ExecutableTrustError { check(true, "user-controlled path rejected where root ownership is required") }
    func words(_ values: [UInt32]) -> Data {
        Data(values.flatMap { value in (0..<4).map { UInt8(truncatingIfNeeded: value >> ($0 * 8)) } })
    }
    var commands = Data()
    for library in ["/opt/homebrew/opt/openssl@3/lib/libssl.3.dylib", "/opt/homebrew/opt/openssl@3/lib/libcrypto.3.dylib"] {
        let name = Data(library.utf8) + Data([0])
        let size = (24 + name.count + 7) / 8 * 8
        commands += words([0xc, UInt32(size), 24, 0, 0, 0]) + name
        commands += Data(repeating: 0, count: size - 24 - name.count)
    }
    let binary = words([0xfeedfacf, 0x0100000c, 0, 2, 2, UInt32(commands.count), 0, 0]) + commands
    let dependencies = try ExecutableTrust.dependencies(in: binary)
    check(dependencies.contains(where: { $0.contains("libssl") }) && dependencies.contains(where: { $0.contains("libcrypto") }), "Mach-O parser finds previously omitted OpenSSL dependencies")
    for invalid in [Data(), Data(repeating: 0, count: 32), binary.prefix(35)] {
        do { _ = try ExecutableTrust.dependencies(in: Data(invalid)); fatalError("Accepted malformed binary") }
        catch is ExecutableTrustError { }
    }
    check(true, "malformed Mach-O input rejected")
}

private func orphanedArtifactCleanupTests() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let runtime = root.appendingPathComponent("runtime", isDirectory: true)
    let resolvers = root.appendingPathComponent("resolver", isDirectory: true)
    try FileManager.default.createDirectory(at: runtime, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: resolvers, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }

    let profileID = UUID().uuidString
    let runtimeFile = runtime.appendingPathComponent("\(profileID)-\(UUID().uuidString).auth")
    let unrelatedRuntimeFile = runtime.appendingPathComponent("keep-me.auth")
    try Data("secret".utf8).write(to: runtimeFile)
    try Data("safe".utf8).write(to: unrelatedRuntimeFile)

    let resolverFile = resolvers.appendingPathComponent("internal.example")
    let unrelatedResolverFile = resolvers.appendingPathComponent("other.example")
    try "# VPN Configurator profile: \(profileID)\nnameserver 10.0.0.1\n".write(
        to: resolverFile, atomically: true, encoding: .utf8
    )
    try "nameserver 192.0.2.1\n".write(to: unrelatedResolverFile, atomically: true, encoding: .utf8)

    let result = OrphanedArtifactCleanup.run(runtimeDirectory: runtime, resolverDirectory: resolvers)
    check(result.runtimeFiles == 1 && !FileManager.default.fileExists(atPath: runtimeFile.path),
          "helper startup removes owned orphaned runtime files")
    check(result.resolverFiles == 1 && !FileManager.default.fileExists(atPath: resolverFile.path),
          "helper startup removes owned orphaned resolver files")
    check(FileManager.default.fileExists(atPath: unrelatedRuntimeFile.path)
          && FileManager.default.fileExists(atPath: unrelatedResolverFile.path),
          "helper startup preserves unrelated files")
}

private func discoveryTests() {
    // Homebrew's prefixes must win over an older system copy of the same name.
    let candidates = EngineDiscovery.candidates(for: .openVPN)
    check(candidates.first == "/opt/homebrew/sbin/openvpn", "Homebrew prefix is searched first")
    check(candidates.allSatisfy { $0.hasSuffix("/openvpn") }, "every candidate names the requested engine")
    check(EngineDiscovery.isExecutableFile("/usr/bin/true"), "an executable regular file is discoverable")
    check(!EngineDiscovery.isExecutableFile("/usr/bin"), "a directory is not discoverable as an engine")
    check(!EngineDiscovery.isExecutableFile("/etc/hosts"), "a non-executable file is not discoverable as an engine")
}

private func approvalTests() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    // A real Mach-O whose dependencies all live in the dyld shared cache, so the
    // measured graph is exactly one file we control.
    let executable = directory.appendingPathComponent("engine")
    try FileManager.default.copyItem(at: URL(fileURLWithPath: "/usr/bin/true"), to: executable)
    let digests = try ExecutableTrust.imageDigests(of: executable.path)
    check(digests.count == 1 && digests[executable.path] != nil, "image measurement covers the executable and skips system libraries")

    let approved = ApprovedEngine(
        engine: .openVPN,
        executablePath: executable.path,
        vpncScriptPath: nil,
        files: digests,
        approvedAt: Date()
    )
    try ApprovedEngineStore.verify(approved)
    check(true, "an unchanged engine passes verification")

    // Appending after the load commands leaves the Mach-O parseable but changes
    // the bytes that would run as root.
    let handle = try FileHandle(forWritingTo: executable)
    try handle.seekToEnd()
    try handle.write(contentsOf: Data([0x41]))
    try handle.close()
    do {
        try ApprovedEngineStore.verify(approved)
        fatalError("Accepted an engine whose bytes changed after approval")
    } catch is EngineTrustError {
        check(true, "an engine modified after approval is rejected")
    }

    // A library the administrator never saw must fail even though every digest
    // that was recorded still matches.
    let unpinned = ApprovedEngine(
        engine: .openVPN,
        executablePath: executable.path,
        vpncScriptPath: nil,
        files: [:],
        approvedAt: Date()
    )
    do {
        try ApprovedEngineStore.verify(unpinned)
        fatalError("Accepted an engine with unpinned code")
    } catch is EngineTrustError {
        check(true, "an engine loading code that was never pinned is rejected")
    }

    // A record naming a file that no longer exists must not silently pass.
    var missing = digests
    missing[directory.appendingPathComponent("removed.dylib").path] = String(repeating: "b", count: 64)
    do {
        try ApprovedEngineStore.verify(ApprovedEngine(
            engine: .openVPN,
            executablePath: executable.path,
            vpncScriptPath: nil,
            files: missing,
            approvedAt: Date()
        ))
        fatalError("Accepted a record referring to a missing file")
    } catch is EngineTrustError {
        check(true, "a record referring to a file that disappeared is rejected")
    }

    do {
        _ = try ApprovedEngineStore.approve(.openVPN, executablePath: "relative/openvpn", vpncScriptPath: nil)
        fatalError("Accepted a relative executable path")
    } catch is EngineTrustError {
        check(true, "a relative or unnormalized executable path is rejected")
    }
    do {
        _ = try ApprovedEngineStore.approve(.openConnect, executablePath: "/usr/bin/true", vpncScriptPath: nil)
        fatalError("Approved OpenConnect without a vpnc-script")
    } catch is EngineTrustError {
        check(true, "OpenConnect cannot be approved without a vpnc-script")
    }
}

private func openFortiVPNConfigurationTests() {
    func configuration(otp: String) -> String {
        SecureRuntimeFiles.openFortiVPNConfiguration(
            host: "vpn.example.com",
            port: 443,
            trustedCertificate: "",
            username: "user",
            password: "secret",
            oneTimePassword: otp
        )
    }

    let withOTP = configuration(otp: "123456")
    check(withOTP.contains("otp = 123456\n"), "a supplied OTP reaches the OpenFortiVPN configuration")
    // Without this, a gateway offering FortiToken Mobile push authenticates by
    // push and never submits the code the user typed.
    check(withOTP.contains("no-ftm-push = 1\n"), "supplying an OTP disables FTM push so the code is actually used")

    let withoutOTP = configuration(otp: "")
    check(!withoutOTP.contains("otp = "), "no OTP line is written when none was supplied")
    check(!withoutOTP.contains("no-ftm-push"), "FTM push stays available when no OTP was supplied")
}

private func authorizationTests() {
    for token in [Data(), Data(repeating: 0, count: 8)] {
        do {
            try HelperService.requireAdministrator(token)
            fatalError("Accepted a malformed authorization token")
        } catch { }
    }
    check(true, "malformed administrator authorization tokens are rejected")
}

discoveryTests()
try approvalTests()
authorizationTests()
openFortiVPNConfigurationTests()
try parserTests()
HelperService.stateTests()
try HelperService.duplicateStartTests()
HelperService.trustWorkDoesNotBlockSessionQueue()
HelperService.idleRestartTests()
try trustTests()
try orphanedArtifactCleanupTests()
print("All helper regression tests passed.")
