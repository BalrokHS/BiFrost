import Foundation
import Security

// Compiled with the helper service sources by script/test.sh. No root privileges,
// VPN gateway, DNS changes, or XPC registration are involved.
private final class TestClock: @unchecked Sendable {
    private let lock = NSLock()
    private var time: TimeInterval = 100
    var value: TimeInterval { lock.withLock { time } }
    func advance(_ delta: TimeInterval) { lock.withLock { time += delta } }
}

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
    let preparation = DispatchSemaphore(value: 0)
    helper.prepareForUpdate(true) { state in
        check(state == "busy", "pending engine validation prevents app replacement")
        preparation.signal()
    }
    check(preparation.wait(timeout: .now() + 1) == .success, "pending-launch preparation replies")
    releaseTrust.signal()
    check(startReplied.wait(timeout: .now() + 2) == .success, "engine verification completion replies")
}

static func updatePreparationTests() {
    let clock = TestClock()
    let helper = HelperService(resolveEngine: { _ in
        throw HelperFailure.untrustedExecutable("test resolver reached")
    }, now: { clock.value })
    let session = newSession()
    helper.queue.sync { helper.sessions[session.profileID] = session }
    func prepare(_ preparing: Bool, expected: String) {
        let reply = DispatchSemaphore(value: 0)
        helper.prepareForUpdate(preparing) { state in
            check(state == expected, "update preparation reports \(expected)")
            reply.signal()
        }
        check(reply.wait(timeout: .now() + 1) == .success, "update preparation replies")
    }
    func start(expect message: String) {
        let reply = DispatchSemaphore(value: 0)
        helper.startOpenVPN(profileID: UUID().uuidString, configuration: "client", username: "u", password: "p", dnsServers: [], dnsDomains: []) { success, detail in
            check(!success && detail.contains(message), "update lease controls new launches: \(message)")
            reply.signal()
        }
        check(reply.wait(timeout: .now() + 1) == .success, "launch gate replies")
    }
    prepare(true, expected: "busy")
    start(expect: "waiting for VPN sessions")
    helper.queue.sync {
        check(!session.didFinish, "preparation preserves the active session")
        helper.finish(session: session, exitStatus: 0)
    }
    prepare(true, expected: "ready")
    start(expect: "waiting for VPN sessions")
    prepare(false, expected: "cancelled")
    start(expect: "test resolver reached")
    prepare(true, expected: "ready")
    clock.advance(16)
    start(expect: "test resolver reached")
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
    try "# Bifrost profile: \(profileID)\nnameserver 10.0.0.1\n".write(
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

private func clientRequirementTests() {
    check(
        ClientRequirement.teamAnchored(team: "TEAMID", identifier: "com.example.app")
            == "anchor apple generic and certificate leaf[subject.OU] = \"TEAMID\" and identifier \"com.example.app\"",
        "a signed client is pinned to the developer team and bundle identifier"
    )
    // An unreadable bundle must pin nothing, so the connection is refused rather
    // than falling back to a requirement any same-identifier app would satisfy.
    check(
        ClientRequirement.codeHashPinned(designatedRequirement: "", identifier: "com.example.app") == nil,
        "an unreadable app bundle pins nothing and is therefore refused"
    )
    let pinned = ClientRequirement.codeHashPinned(
        designatedRequirement: "cdhash H\"aa\" or cdhash H\"bb\"",
        identifier: "com.example.app"
    )
    check(
        pinned == "identifier \"com.example.app\" and (cdhash H\"aa\" or cdhash H\"bb\")",
        "an ad-hoc client is pinned to every architecture slice of the app bundle shipping the helper"
    )
    // The whole ad-hoc path collapses to a rejection if this text does not
    // compile, so the exact syntax is worth asserting.
    var requirement: SecRequirement?
    check(
        ClientRequirement.codeHashPinned(
            designatedRequirement: "cdhash H\"b089788d0bc67433e071dd2b74a59229cd183e09\""
        ).map { SecRequirementCreateWithString($0 as CFString, [], &requirement) } == errSecSuccess,
        "the code-hash pin compiles as a real code-signing requirement"
    )
    check(
        HelperCodeIdentity.designatedRequirementText(ofBundleAt: URL(fileURLWithPath: "/nonexistent.app")) == nil,
        "a missing app bundle yields no requirement"
    )
}

discoveryTests()
try approvalTests()
authorizationTests()
clientRequirementTests()
openFortiVPNConfigurationTests()
try parserTests()
HelperService.stateTests()
try HelperService.duplicateStartTests()
HelperService.trustWorkDoesNotBlockSessionQueue()
HelperService.updatePreparationTests()
try trustTests()
try orphanedArtifactCleanupTests()

// Forti gateways carry an optional realm without relaxing other engines' validation.
do {
    let gateway = try HelperInputValidator.openFortiVPNGateway("193.41.150.166:443/UniSystems")
    check(gateway.host == "193.41.150.166" && gateway.port == 443 && gateway.realm == "UniSystems", "Forti gateway separates endpoint and case-sensitive realm")
    let plain = try HelperInputValidator.openFortiVPNGateway("vpn.example.com")
    check(plain.port == 443 && plain.realm == nil, "Forti gateways without realms keep existing defaults")
    let encoded = try HelperInputValidator.openFortiVPNGateway("vpn.example.com:8443/Uni%53ystems")
    check(encoded.port == 8443 && encoded.realm == "UniSystems", "Forti realm percent escapes are decoded")
    for invalid in ["", "vpn.example.com/", "vpn.example.com/a/b", "vpn.example.com/a?b", "vpn.example.com/%00", "vpn.example.com/%0A", "vpn.example.com/%2F", "vpn.example.com:99999/realm"] {
        do {
            _ = try HelperInputValidator.openFortiVPNGateway(invalid)
            fatalError("Accepted invalid Forti gateway: \(invalid)")
        } catch is HelperFailure { }
    }
    do {
        _ = try HelperInputValidator.gateway("vpn.example.com/UniSystems")
        fatalError("Generic gateway accepted a realm")
    } catch is HelperFailure { }
    check(true, "invalid realms rejected and generic gateway validation stays strict")
} catch { fatalError("Forti gateway regression: \(error)") }

print("All helper regression tests passed.")
