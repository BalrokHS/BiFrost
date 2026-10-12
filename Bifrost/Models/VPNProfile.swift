import SwiftUI

struct VPNProfile: Identifiable, Hashable, Codable, Sendable {
    let id: UUID
    var name: String
    var server: String
    var provider: VPNProvider
    var authentication: AuthenticationMethod
    var username: String
    var configurationPath: String?
    var serverCertificatePin: String?
    var dnsDomains: [String]
    var dnsServers: [String]
    var accent: ProfileAccent
    var icon: ProfileIcon

    init(
        id: UUID = UUID(),
        name: String,
        server: String,
        provider: VPNProvider,
        authentication: AuthenticationMethod,
        username: String = "",
        configurationPath: String? = nil,
        serverCertificatePin: String? = nil,
        dnsDomains: [String] = [],
        dnsServers: [String] = [],
        accent: ProfileAccent = .blue,
        icon: ProfileIcon = .avatar
    ) {
        self.id = id
        self.name = name
        self.server = server
        self.provider = provider
        self.authentication = authentication
        self.username = username
        self.configurationPath = configurationPath
        self.serverCertificatePin = serverCertificatePin
        self.dnsDomains = dnsDomains
        self.dnsServers = dnsServers
        self.accent = accent
        self.icon = icon
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, server, provider, authentication, username, configurationPath
        case serverCertificatePin, dnsDomains, dnsServers, accent, icon
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try container.decode(String.self, forKey: .name)
        server = try container.decode(String.self, forKey: .server)
        provider = try container.decode(VPNProvider.self, forKey: .provider)
        authentication = try container.decode(AuthenticationMethod.self, forKey: .authentication)
        username = try container.decodeIfPresent(String.self, forKey: .username) ?? ""
        configurationPath = try container.decodeIfPresent(String.self, forKey: .configurationPath)
        serverCertificatePin = try container.decodeIfPresent(String.self, forKey: .serverCertificatePin)
        dnsDomains = try container.decodeIfPresent([String].self, forKey: .dnsDomains) ?? []
        dnsServers = try container.decodeIfPresent([String].self, forKey: .dnsServers) ?? []
        accent = try container.decodeIfPresent(ProfileAccent.self, forKey: .accent) ?? .blue
        icon = try container.decodeIfPresent(ProfileIcon.self, forKey: .icon) ?? .avatar
    }
}

enum VPNProvider: String, CaseIterable, Codable, Sendable {
    case openFortiVPN = "OpenFortiVPN"
    case openConnect = "OpenConnect"
    case openVPN = "OpenVPN"

    var symbol: String {
        switch self {
        case .openFortiVPN: "building.columns.fill"
        case .openConnect: "point.3.connected.trianglepath.dotted"
        case .openVPN: "lock.shield.fill"
        }
    }
}

enum AuthenticationMethod: String, CaseIterable, Codable, Sendable {
    case password = "Password"
    case passwordAndOTP = "Password + OTP"
    case saml = "SAML browser login"
}

enum ConnectionState: String, Codable, Sendable {
    case disconnected = "Disconnected"
    case waitingForAuthentication = "Waiting for authentication"
    case connecting = "Connecting"
    case connected = "Connected"
    case disconnecting = "Disconnecting"
    case degraded = "Degraded"
    case failed = "Failed"

    var isBusy: Bool {
        self == .connecting || self == .disconnecting || self == .waitingForAuthentication
    }

    var isDisconnectable: Bool {
        self == .connected || self == .degraded || self == .waitingForAuthentication
    }

    var color: Color {
        switch self {
        case .connected: .green
        case .connecting, .disconnecting, .waitingForAuthentication: .orange
        case .degraded: .yellow
        case .failed: .red
        case .disconnected: .secondary
        }
    }
}

enum ProfileAccent: String, CaseIterable, Codable, Sendable {
    case blue, purple, teal, orange, pink

    var color: Color {
        switch self {
        case .blue: .blue
        case .purple: .purple
        case .teal: .teal
        case .orange: .orange
        case .pink: .pink
        }
    }
}

/// What identifies a profile in the list. With no choice made, Bifrost draws an
/// avatar from the profile name. An imported picture lives in `ProfileIconStore`.
enum ProfileIcon: Hashable, Codable, Sendable {
    case avatar
    case symbol(String)
    case image

    /// The symbols offered in the editor. A stored name outside this list is
    /// ignored, so a hand-edited file cannot name an arbitrary symbol.
    static let symbols = [
        "lock.shield", "shield", "network", "globe", "building.2", "briefcase", "house",
        "server.rack", "cloud", "key", "bolt", "laptopcomputer", "person.2",
        "antenna.radiowaves.left.and.right"
    ]

    private static let symbolPrefix = "symbol:"

    init(from decoder: Decoder) throws {
        let value = try decoder.singleValueContainer().decode(String.self)
        if value == "image" {
            self = .image
        } else if value.hasPrefix(Self.symbolPrefix),
                  Self.symbols.contains(String(value.dropFirst(Self.symbolPrefix.count))) {
            self = .symbol(String(value.dropFirst(Self.symbolPrefix.count)))
        } else {
            self = .avatar
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .avatar: try container.encode("avatar")
        case .image: try container.encode("image")
        case .symbol(let name): try container.encode(Self.symbolPrefix + name)
        }
    }
}
