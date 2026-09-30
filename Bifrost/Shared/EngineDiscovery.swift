import Darwin
import Foundation

/// The external VPN clients this app manages. It launches these; it does not
/// implement any VPN protocol itself.
enum VPNEngine: String, CaseIterable, Codable, Sendable {
    case openFortiVPN = "openfortivpn"
    case openVPN = "openvpn"
    case openConnect = "openconnect"

    var displayName: String {
        switch self {
        case .openFortiVPN: "OpenFortiVPN"
        case .openVPN: "OpenVPN"
        case .openConnect: "OpenConnect"
        }
    }

    /// OpenConnect refuses to configure the interface without a vpnc-script.
    var needsVPNCScript: Bool { self == .openConnect }
}

/// Finds VPN clients the user installed themselves. Discovery answers "is it
/// here?" only. Whether the privileged helper may execute what we found is a
/// separate question, answered by `ApprovedEngineStore`.
enum EngineDiscovery {
    /// Searched in order, so a Homebrew build wins over an older system copy.
    static let searchDirectories = [
        "/opt/homebrew/sbin",
        "/opt/homebrew/bin",
        "/usr/local/sbin",
        "/usr/local/bin",
        "/opt/local/sbin",
        "/opt/local/bin",
        "/usr/sbin",
        "/usr/bin"
    ]

    static let vpncScriptCandidates = [
        "/opt/homebrew/etc/vpnc/vpnc-script",
        "/usr/local/etc/vpnc/vpnc-script",
        "/opt/local/etc/vpnc/vpnc-script",
        "/etc/vpnc/vpnc-script"
    ]

    static func candidates(for engine: VPNEngine) -> [String] {
        searchDirectories.map { "\($0)/\(engine.rawValue)" }
    }

    static func locate(_ engine: VPNEngine) -> String? {
        candidates(for: engine).first(where: isExecutableFile)
    }

    static func locateVPNCScript() -> String? {
        vpncScriptCandidates.first(where: isExecutableFile)
    }

    /// Follows symlinks, which is how Homebrew exposes `sbin/openvpn`, but still
    /// requires the destination to be a regular executable file.
    static func isExecutableFile(_ path: String) -> Bool {
        var info = stat()
        guard stat(path, &info) == 0, info.st_mode & S_IFMT == S_IFREG else { return false }
        return FileManager.default.isExecutableFile(atPath: path)
    }
}

/// One executable an administrator approved for root execution, pinned by the
/// SHA-256 of the executable itself and of every non-system library it loads.
/// The engine stays where its package manager put it; only these digests decide
/// whether the helper is still willing to run it.
struct ApprovedEngine: Codable, Sendable {
    let engine: VPNEngine
    let executablePath: String
    let vpncScriptPath: String?
    /// Absolute path to SHA-256 hex digest, including the executable itself.
    let files: [String: String]
    let approvedAt: Date
}

struct EngineApprovalRecord: Codable, Sendable {
    static let currentSchemaVersion = 1
    var schemaVersion = EngineApprovalRecord.currentSchemaVersion
    var engines: [String: ApprovedEngine] = [:]
}

enum EngineApproval {
    /// Written only by the privileged helper, and only as root.
    static let directory = URL(
        fileURLWithPath: "/Library/Application Support/Bifrost",
        isDirectory: true
    )
    static let recordURL = directory.appendingPathComponent("approved-engines.json")

    /// A predefined macOS right whose policy is "authenticate as an administrator".
    /// Defining a private right would need a second prompt to write the policy
    /// database, which defeats the point of asking once.
    static let right = "system.privilege.admin"

    /// Engines run from a prefix their package manager owns, so their TLS
    /// libraries must not resolve trust roots from that same prefix.
    static let systemCABundle = "/etc/ssl/cert.pem"
}

enum EngineApprovalState: String, Codable, Sendable {
    /// Approved, and every pinned digest still matches.
    case ready
    /// Found on disk, but no administrator has approved it for root execution.
    case notApproved
    /// Approved earlier, but the bytes changed. Expected after a package upgrade.
    case changed
    /// Not installed, or the helper could not be asked.
    case unavailable
}

struct EngineTrustError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}
