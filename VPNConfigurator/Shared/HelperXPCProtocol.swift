import Foundation

enum HelperConstants {
    static let machServiceName = "com.klianos.VPNConfigurator.helper"
    static var launchDaemonPlistName: String {
        Bundle.main.object(forInfoDictionaryKey: "BifrostHelperDaemonPlist") as? String
            ?? "com.klianos.VPNConfigurator.helper.plist"
    }
    static let mainAppIdentifier = "com.klianos.VPNConfigurator"
    static let signingTeamIdentifier = "68SX8JZQFD"
    static let executionHelperVersion = "VPN Configurator Helper 0.7.0"
}

/// The wire contract is independent of the product's display/build versions.
/// Unknown protocols fail closed; a missing feature blocks only that feature.
struct HelperHandshake: Codable, Equatable, Sendable {
    static let protocolVersion = 1
    static let updatePreparation = "update-preparation-v1"
    static let fortiRealm = "forti-realm"
    let version: String
    let protocolVersion: Int
    let capabilities: Set<String>

    static let current = HelperHandshake(
        version: HelperConstants.executionHelperVersion,
        protocolVersion: protocolVersion,
        capabilities: [updatePreparation, fortiRealm]
    )

    var isCompatible: Bool { protocolVersion == Self.protocolVersion }

    var encoded: String {
        guard let data = try? JSONEncoder().encode(self) else { return "{}" }
        return String(decoding: data, as: UTF8.self)
    }

    static func decode(_ value: String) -> HelperHandshake? {
        if let handshake = try? JSONDecoder().decode(Self.self, from: Data(value.utf8)) {
            return handshake
        }
        // Explicit migration support for shipped helpers, never inferred from
        // an arbitrary future version string. They cannot prepare an app update.
        switch value {
        case "VPN Configurator Helper 0.6.2":
            return HelperHandshake(version: value, protocolVersion: 1, capabilities: [])
        case "VPN Configurator Helper 0.6.3":
            return HelperHandshake(version: value, protocolVersion: 1, capabilities: [fortiRealm])
        default:
            return nil
        }
    }
}

enum HelperSessionState: String, Codable, Sendable {
    case connecting
    case waitingForAuthentication
    case connected
    case disconnecting
    case failed
    case disconnected
}

@objc protocol HelperXPCProtocol {
    func ping(reply: @escaping @Sendable (String) -> Void)

    /// A short renewable lease blocks new connections while the app waits for
    /// sessions and pending launches to finish. Only the app unregisters the service.
    func prepareForUpdate(_ preparing: Bool, reply: @escaping @Sendable (String) -> Void)

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
    )

    func startOpenVPN(
        profileID: String,
        configuration: String,
        username: String,
        password: String,
        dnsServers: [String],
        dnsDomains: [String],
        reply: @escaping @Sendable (Bool, String) -> Void
    )

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
    )

    func stopVPN(
        profileID: String,
        reply: @escaping @Sendable (Bool, String) -> Void
    )

    func VPNStatus(
        profileID: String,
        reply: @escaping @Sendable (String, Int32, String, String) -> Void
    )

    /// Reports whether the helper would run `executablePath` for `engine`, as an
    /// `EngineApprovalState` raw value plus a human-readable detail line.
    func engineApprovalState(
        engine: String,
        executablePath: String,
        reply: @escaping @Sendable (String, String) -> Void
    )

    /// Records `executablePath` and its library graph as approved for root
    /// execution. `authorization` is an `AuthorizationExternalForm` the app
    /// obtained by prompting the user; the helper re-checks it before writing.
    /// `vpncScriptPath` is empty for engines that do not need one.
    func approveEngine(
        engine: String,
        executablePath: String,
        vpncScriptPath: String,
        authorization: Data,
        reply: @escaping @Sendable (Bool, String) -> Void
    )

    func revokeEngine(
        engine: String,
        authorization: Data,
        reply: @escaping @Sendable (Bool, String) -> Void
    )
}
