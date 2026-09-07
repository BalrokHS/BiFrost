import Darwin
import Foundation

enum HelperInputValidator {
    static func openVPNConfiguration(_ configuration: String) throws -> String {
        try OpenVPNConfiguration.sanitize(configuration)
    }

    static func openConnectPin(_ value: String) throws -> String {
        let pin = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !pin.isEmpty else { return "" }
        guard pin.utf8.count <= 200,
              !pin.contains(where: { $0.isWhitespace || $0.isNewline || $0 == "\0" }),
              pin.hasPrefix("pin-sha256:") || pin.hasPrefix("sha256:") else {
            throw HelperFailure.invalidServerCertificatePin
        }
        return pin
    }

    static func gateway(_ value: String) throws -> (host: String, port: Int) {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              !trimmed.contains(where: { $0.isNewline || $0 == "\0" }),
              !trimmed.contains(where: { "/@?#".contains($0) }),
              let components = URLComponents(string: "https://\(trimmed)"),
              let host = components.host,
              !host.isEmpty else {
            throw HelperFailure.invalidGateway("enter a hostname or IP address, optionally followed by a port.")
        }

        guard isIPAddress(host) || isDNSDomain(host.lowercased()) else {
            throw HelperFailure.invalidGateway("\(host) is not a valid hostname or IP address.")
        }
        let port = components.port ?? 443
        guard (1...65_535).contains(port) else {
            throw HelperFailure.invalidGateway("the port must be between 1 and 65535.")
        }
        return (host, port)
    }

    static func trustedCertificate(_ value: String) throws -> String {
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalized.isEmpty else { return "" }
        guard normalized.utf8.count == 64,
              normalized.utf8.allSatisfy({ ($0 >= 48 && $0 <= 57) || ($0 >= 97 && $0 <= 102) }) else {
            throw HelperFailure.invalidTrustedCertificate
        }
        return normalized
    }

    static func secret(_ value: String) throws {
        if value.contains("\n") || value.contains("\r") || value.contains("\0") {
            throw HelperFailure.unsafeSecret
        }
    }

    static func dnsConfiguration(
        servers: [String],
        domains: [String]
    ) throws -> (servers: [String], domains: [String]) {
        let normalizedServers = Array(Set(servers.map {
            $0.trimmingCharacters(in: .whitespacesAndNewlines)
        }.filter { !$0.isEmpty })).sorted()
        let normalizedDomains = Array(Set(domains.map {
            $0.trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
                .trimmingCharacters(in: CharacterSet(charactersIn: "."))
        }.filter { !$0.isEmpty })).sorted()

        guard normalizedServers.isEmpty == normalizedDomains.isEmpty else {
            throw HelperFailure.invalidDNS("both DNS servers and DNS domains are required.")
        }
        guard normalizedServers.count <= 8, normalizedDomains.count <= 32 else {
            throw HelperFailure.invalidDNS("a profile supports at most 8 servers and 32 domains.")
        }
        for server in normalizedServers where !isIPAddress(server) {
            throw HelperFailure.invalidDNS("\(server) is not a valid IPv4 or IPv6 address.")
        }
        for domain in normalizedDomains where !isDNSDomain(domain) {
            throw HelperFailure.invalidDNS("\(domain) is not a valid ASCII DNS domain.")
        }
        return (normalizedServers, normalizedDomains)
    }

    private static func isIPAddress(_ value: String) -> Bool {
        var ipv4 = in_addr()
        if value.withCString({ inet_pton(AF_INET, $0, &ipv4) }) == 1 { return true }
        var ipv6 = in6_addr()
        return value.withCString({ inet_pton(AF_INET6, $0, &ipv6) }) == 1
    }

    private static func isDNSDomain(_ value: String) -> Bool {
        guard !value.isEmpty, value.utf8.count <= 253 else { return false }
        return value.split(separator: ".", omittingEmptySubsequences: false).allSatisfy { label in
            guard !label.isEmpty, label.utf8.count <= 63,
                  label.first != "-", label.last != "-" else { return false }
            return label.utf8.allSatisfy {
                ($0 >= 48 && $0 <= 57) || ($0 >= 97 && $0 <= 122) || $0 == 45
            }
        }
    }
}
