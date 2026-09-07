import Foundation

enum HelperConstants {
    static let machServiceName = "com.klianos.VPNConfigurator.helper"
    static let launchDaemonPlistName = "com.klianos.VPNConfigurator.helper.plist"
    static let mainAppIdentifier = "com.klianos.VPNConfigurator"
    static let signingTeamIdentifier = "68SX8JZQFD"
    static let executionHelperVersion = "VPN Configurator Helper 0.6.2"
    static let restartDeferredMessage = "The helper update is queued until active VPN sessions disconnect."
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

    /// Exits after replying when no VPN launch or session is active. Because
    /// launchd resolves BundleProgram from the registered app, the next XPC
    /// request starts the helper embedded in the current app bundle.
    func restartWhenIdle(reply: @escaping @Sendable (Bool, String) -> Void)

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
