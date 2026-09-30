import Foundation

@MainActor
private final class MockHelper: VPNHelperClient {
    var launchedCredentials: [VPNCredentials] = []
    var isEnabled = true
    var statusReplies: [(@MainActor (Result<HelperVPNStatus, Error>) -> Void)] = []
    var stopReplies: [(@MainActor (Result<String, Error>) -> Void)] = []
    var startReplies: [(@MainActor (Result<String, Error>) -> Void)] = []
    func refreshStatus() {}
    func VPNStatus(profileID: VPNProfile.ID, completion: @escaping @MainActor (Result<HelperVPNStatus, Error>) -> Void) { statusReplies.append(completion) }
    func stopVPN(profileID: VPNProfile.ID, completion: @escaping @MainActor (Result<String, Error>) -> Void) { stopReplies.append(completion) }
    func startOpenFortiVPN(profileID: VPNProfile.ID, server: String, trustedCertificate: String, username: String, password: String, oneTimePassword: String, useSAML: Bool, dnsServers: [String], dnsDomains: [String], completion: @escaping @MainActor (Result<String, Error>) -> Void) { launchedCredentials.append(VPNCredentials(password: password, oneTimePassword: oneTimePassword)); startReplies.append(completion) }
    func startOpenVPN(profileID: VPNProfile.ID, configuration: String, username: String, password: String, dnsServers: [String], dnsDomains: [String], completion: @escaping @MainActor (Result<String, Error>) -> Void) { startReplies.append(completion) }
    func startOpenConnect(profileID: VPNProfile.ID, server: String, serverCertificatePin: String, username: String, password: String, oneTimePassword: String, dnsServers: [String], dnsDomains: [String], completion: @escaping @MainActor (Result<String, Error>) -> Void) { startReplies.append(completion) }

    func status(_ state: String, pid: Int32 = 0, interface: String = "") {
        statusReplies.removeFirst()(.success(HelperVPNStatus(state: state, processIdentifier: pid, interfaceName: interface, log: "")))
    }
}

private final class MockPasswordStore: VPNPasswordStore {
    var passwords: [VPNProfile.ID: String] = [:]
    func password(for profileID: VPNProfile.ID) throws -> String? { passwords[profileID] }
    func containsPassword(for profileID: VPNProfile.ID) throws -> Bool { passwords[profileID] != nil }
    func setPassword(_ password: String, for profileID: VPNProfile.ID) throws { passwords[profileID] = password }
    func removePassword(for profileID: VPNProfile.ID) throws { passwords[profileID] = nil }
}

@main
private struct ControllerRegressionTests {
    static func check(_ condition: @autoclosure () -> Bool, _ description: String) {
        guard condition() else { fatalError("FAIL: \(description)") }
        print("PASS: \(description)")
    }

    static func updateReplacementTests() throws {
        let files = FileManager.default
        let root = files.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try files.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? files.removeItem(at: root) }
        let original = root.appendingPathComponent("Bifrost.app")
        let incoming = root.appendingPathComponent("Incoming.app")
        let backup = root.appendingPathComponent("Previous.app")
        try Data("old".utf8).write(to: original)
        let replacement = AppBundleReplacement(destination: original, staged: incoming, previous: backup)
        do { try replacement.install(); fatalError("Missing staged app was installed") }
        catch { }
        let restored = try String(contentsOf: original, encoding: .utf8)
        check(restored == "old", "failed app replacement restores the previous app")
        try Data("new".utf8).write(to: incoming)
        try replacement.install()
        let installed = try String(contentsOf: original, encoding: .utf8)
        let old = try String(contentsOf: backup, encoding: .utf8)
        check(installed == "new" && old == "old", "app replacement preserves a rollback copy")
        try replacement.rollback()
        let rolledBack = try String(contentsOf: original, encoding: .utf8)
        check(rolledBack == "old", "failed relaunch can roll back the app replacement")
        check(UnsignedRelease.buildNumber("123") == 123 && UnsignedRelease.buildNumber("0") == nil
              && UnsignedRelease.buildNumber("1.2") == nil && UnsignedRelease.buildNumber("-1") == nil,
              "unsigned release build numbers have unambiguous ordering")
    }

    @MainActor
    static func main() throws {
        let future = HelperHandshake(version: "future display version", protocolVersion: 1, capabilities: [HelperHandshake.fortiRealm])
        check(HelperHandshake.decode(future.encoded)?.isCompatible == true,
              "compatible helpers do not need identical display versions")
        let incompatible = HelperHandshake(version: "future", protocolVersion: 2, capabilities: [])
        check(HelperHandshake.decode(incompatible.encoded)?.isCompatible == false,
              "unknown helper protocols fail closed")
        check(HelperHandshake.decode("VPN Configurator Helper 99.0.0") == nil,
              "arbitrary legacy version strings do not imply capabilities")
        check(HelperHandshake.decode("VPN Configurator Helper 0.6.2")?.capabilities.contains(HelperHandshake.fortiRealm) == false,
              "legacy helpers cannot receive unsupported realm operations")
        check(HelperHandshake.decode("VPN Configurator Helper 0.6.3")?.capabilities.contains(HelperHandshake.updatePreparation) == false,
              "legacy helpers cannot receive update-preparation requests")
        check(HelperHandshake.decode(HelperHandshake.current.encoded) == HelperHandshake.current,
              "current handshake preserves protocol and capabilities")
        try updateReplacementTests()
        if let path = ProcessInfo.processInfo.environment["BIFROST_TEST_RELEASE"] {
            let release = URL(fileURLWithPath: path)
            let build = try UnsignedRelease.validate(release, newerThan: 1)
            check(build > 1, "packaged unsigned release passes real signature and metadata validation")
            do {
                _ = try UnsignedRelease.validate(release, newerThan: build)
                fatalError("Accepted a non-increasing update")
            } catch is AppUpdateFailure { }
            let copy = FileManager.default.temporaryDirectory.appendingPathComponent("Bifrost-tamper-\(UUID().uuidString).app")
            try FileManager.default.copyItem(at: release, to: copy)
            defer { try? FileManager.default.removeItem(at: copy) }
            let binary = copy.appendingPathComponent("Contents/Resources/VPNConfiguratorHelper")
            let handle = try FileHandle(forWritingTo: binary)
            try handle.seekToEnd()
            try handle.write(contentsOf: Data("tampered".utf8))
            try handle.close()
            do {
                _ = try UnsignedRelease.validate(copy, newerThan: 1)
                fatalError("Accepted a tampered helper")
            } catch is AppUpdateFailure { }
            check(true, "damaged releases and non-increasing updates are refused")
        }

        let helper = MockHelper()
        let profile = VPNProfile(name: "Fixture", server: "example.com", provider: .openFortiVPN, authentication: .saml)
        let encodedProfile = String(decoding: try JSONEncoder().encode(profile), as: UTF8.self)
        check(!encodedProfile.contains("\"state\"") && !encodedProfile.contains("interfaceName"),
              "persisted profiles contain configuration only")
        guard var legacyObject = try JSONSerialization.jsonObject(
            with: Data(encodedProfile.utf8)
        ) as? [String: Any] else { fatalError("Encoded profile was not a JSON object") }
        legacyObject["state"] = "Connected"
        legacyObject["interfaceName"] = "utun9"
        let legacyProfile = try JSONDecoder().decode(
            VPNProfile.self,
            from: JSONSerialization.data(withJSONObject: legacyObject)
        )
        check(legacyProfile == profile, "profiles saved with legacy runtime fields still decode")
        let controller = VPNController(helperManager: helper, initialProfiles: [profile])
        check(controller.state(for: profile) == .connecting && helper.statusReplies.count == 1, "startup reconciles with helper before allowing connections")
        helper.status("connected", pid: 123, interface: "utun4")
        check(controller.state(for: profile) == .connected && controller.interfaceName(for: profile) == "utun4", "startup restores surviving tunnel state and interface")

        controller.reconcileSessions()
        helper.status("futureHelperState", pid: 123)
        check(controller.state(for: profile) == .degraded, "unknown helper state with a live process fails closed")

        controller.reconcileSessions()
        helper.statusReplies.removeFirst()(.failure(NSError(domain: "test", code: 1)))
        check(controller.state(for: profile) == .degraded, "status transport failure preserves uncertainty")
        controller.delete(profile.id)
        check(controller.profiles.count == 1, "unknown running state cannot be deleted")
        controller.disconnect(profile.id)
        helper.stopReplies.removeFirst()(.failure(NSError(domain: "test", code: 2)))
        check(controller.state(for: profile) != .disconnected, "failed stop does not claim disconnection")
        helper.status("connected", pid: 123)
        check(controller.state(for: profile) == .connected, "failed stop reconciles actual running state")

        controller.reconcileSessions()
        let stale = helper.statusReplies.removeFirst()
        controller.disconnect(profile.id)
        stale(.success(HelperVPNStatus(state: "connected", processIdentifier: 123, interfaceName: "utun4", log: "")))
        check(controller.state(for: profile) == .disconnecting, "old status reply cannot undo disconnect")
        helper.stopReplies.removeFirst()(.success("stopped"))
        helper.status("disconnected")
        check(controller.state(for: profile) == .disconnected, "confirmed stopped process becomes disconnected")

        controller.connect(profile.id)
        controller.connect(profile.id)
        check(helper.startReplies.count == 1, "overlapping GUI starts are suppressed")
        controller.disconnectAll()
        check(helper.stopReplies.isEmpty && controller.state(for: profile) == .disconnecting, "disconnect during launch waits for start reply")
        helper.startReplies.removeFirst()(.success("started"))
        check(helper.stopReplies.count == 1, "pending disconnect is delivered after launch")
        helper.stopReplies.removeFirst()(.success("stopped"))
        helper.status("disconnected")

        for method in [AuthenticationMethod.password, .passwordAndOTP] {
            let reconnectHelper = MockHelper()
            let savedProfile = VPNProfile(
                name: "Reconnect fixture", server: "vpn.example.com", provider: .openFortiVPN,
                authentication: method, username: "saved-user", serverCertificatePin: "saved-pin",
                dnsDomains: ["internal.example.com"], dnsServers: ["10.0.0.53"]
            )
            let passwordStore = MockPasswordStore()
            passwordStore.passwords[savedProfile.id] = "saved-password"
            let reconnectController = VPNController(
                helperManager: reconnectHelper, initialProfiles: [savedProfile], keychain: passwordStore
            )
            reconnectHelper.status("connected", pid: 456, interface: "utun5")
            reconnectController.reconcileSessions()
            reconnectHelper.status("failed")
            check(reconnectController.state(for: savedProfile) == .failed, "\(method): dropped tunnel becomes failed")
            check(reconnectController.profiles == [savedProfile], "\(method): connection failure preserves all profile settings")
            check(passwordStore.passwords[savedProfile.id] == "saved-password", "\(method): connection failure preserves saved password")

            reconnectController.requestConnection(savedProfile)
            if method == .passwordAndOTP {
                check(reconnectController.authenticationRequest?.usesStoredPassword == true,
                      "OTP reconnect uses saved password and requests a fresh code")
                check(reconnectHelper.startReplies.isEmpty, "OTP reconnect waits for a fresh code")
                do {
                    try reconnectController.submitAuthentication(password: "", oneTimePassword: "", rememberPassword: false, useStoredPassword: true)
                    fatalError("Accepted missing OTP")
                } catch AuthenticationValidationError.missingOTP {
                    check(reconnectHelper.startReplies.isEmpty, "missing OTP does not launch a tunnel")
                }
                try reconnectController.submitAuthentication(password: "", oneTimePassword: "123456", rememberPassword: false, useStoredPassword: true)
            } else {
                check(reconnectController.authenticationRequest == nil, "password reconnect does not ask for the saved password again")
            }
            check(reconnectHelper.launchedCredentials.last?.password == "saved-password",
                  "\(method): reconnect passes saved password to helper")
            check(reconnectHelper.launchedCredentials.last?.oneTimePassword == (method == .passwordAndOTP ? "123456" : ""),
                  "\(method): reconnect passes only the current OTP")
            reconnectHelper.startReplies.removeFirst()(.success("started"))
            reconnectHelper.status("connected", pid: 789)
            check(reconnectController.state(for: savedProfile) == .connected, "\(method): reconnect completes")

            reconnectController.reconcileSessions()
            reconnectHelper.status("failed")
            try reconnectController.removeSavedPassword(for: savedProfile.id)
            reconnectController.requestConnection(savedProfile)
            check(reconnectController.authenticationRequest?.usesStoredPassword == false,
                  "\(method): explicitly forgotten password is requested again")
            check(reconnectHelper.startReplies.isEmpty, "\(method): missing password waits for authentication")
        }

        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let source = directory.appendingPathComponent("fixture.ovpn")
        try "client\nremote vpn.example.com\nca external.pem\n".write(to: source, atomically: true, encoding: .utf8)
        do {
            _ = try ConfigurationImporter.profile(from: source)
            fatalError("Accepted unsupported external TLS material")
        } catch let error as OpenVPNConfigurationError {
            check(error.reason.contains("embedded"), "import rejects external TLS files immediately with actionable error")
        }
        try "test-user\nsecret-password\n".write(to: directory.appendingPathComponent("credentials file"), atomically: true, encoding: .utf8)
        try "--client\nremote vpn.example.com 1194\n--auth-user-pass \"credentials file\"\n".write(to: source, atomically: true, encoding: .utf8)
        let imported = try ConfigurationImporter.profile(from: source)
        defer { ConfigurationImporter.removeManagedOpenVPNConfiguration(at: imported.configurationPath) }
        check(imported.server == "vpn.example.com:1194" && imported.username == "test-user", "import parses canonical endpoint and quoted credential filename")
        let stored = try String(contentsOfFile: imported.configurationPath!, encoding: .utf8)
        check(!stored.contains("credentials file") && !stored.contains("secret-password"), "managed import contains no credential reference or password")
        let fortiSource = source.deletingLastPathComponent().appendingPathComponent("realm.conf")
        try "host = 193.41.150.166\nport = 443\nrealm = UniSystems\nsaml-login = 8020\n".write(to: fortiSource, atomically: true, encoding: .utf8)
        let fortiProfile = try ConfigurationImporter.profile(from: fortiSource)
        check(fortiProfile.server == "193.41.150.166:443/UniSystems" && fortiProfile.authentication == .saml,
              "Forti imports preserve authentication realm and SAML")
        let restoredForti = try JSONDecoder().decode(VPNProfile.self, from: JSONEncoder().encode(fortiProfile))
        check(restoredForti.server == fortiProfile.server, "Forti realm survives profile persistence")
        print("All controller and importer regression tests passed.")
    }
}
