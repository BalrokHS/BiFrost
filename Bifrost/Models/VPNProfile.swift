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
        accent: ProfileAccent = .blue
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
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, server, provider, authentication, username, configurationPath
        case serverCertificatePin, dnsDomains, dnsServers, accent
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
