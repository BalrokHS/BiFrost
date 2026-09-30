import Foundation

struct OpenVPNConfigurationError: LocalizedError {
    let reason: String
    var errorDescription: String? { "The OpenVPN profile was rejected: \(reason)" }
}

/// A deliberately restricted import format. Never forward unparsed directives to root.
/// Both the GUI importer and the privileged helper compile this file.
enum OpenVPNConfiguration {
    private static let inlineTypes: Set<String> = [
        "ca", "cert", "key", "tls-auth", "tls-crypt", "tls-crypt-v2", "extra-certs"
    ]
    private static let arities: [String: ClosedRange<Int>] = [
        "client": 0...0, "tls-client": 0...0, "dev": 1...1, "dev-type": 1...1,
        "proto": 1...1, "remote": 1...3, "remote-random": 0...0,
        "nobind": 0...0, "resolv-retry": 1...1, "connect-retry": 1...2,
        "connect-retry-max": 1...1, "connect-timeout": 1...1,
        "persist-key": 0...0, "persist-tun": 0...0,
        "remote-cert-tls": 1...1, "verify-x509-name": 1...2,
        "auth": 1...1, "cipher": 1...1, "data-ciphers": 1...1,
        "data-ciphers-fallback": 1...1, "tls-version-min": 1...2,
        "tls-version-max": 1...1, "tls-cipher": 1...1, "tls-ciphersuites": 1...1,
        "key-direction": 1...1, "reneg-sec": 1...2,
        "ping": 1...1, "ping-restart": 1...1, "ping-exit": 1...1,
        "keepalive": 2...2, "explicit-exit-notify": 0...1,
        "tun-mtu": 1...1, "mssfix": 0...2, "sndbuf": 1...1, "rcvbuf": 1...1,
        "verb": 1...1, "mute": 1...1, "auth-nocache": 0...0,
        "auth-retry": 1...1, "route": 1...4, "route-ipv6": 1...3,
        "route-gateway": 1...1, "route-metric": 1...1,
        "route-nopull": 0...0, "route-delay": 0...2,
        "redirect-gateway": 0...7, "dhcp-option": 2...2,
        "pull": 0...0, "pull-filter": 2...2,
        "compress": 0...1, "comp-lzo": 0...1, "allow-compression": 1...1
    ]

    static func sanitize(_ configuration: String) throws -> String {
        guard configuration.utf8.count <= 2_000_000, !configuration.contains("\0") else {
            throw OpenVPNConfigurationError(reason: "the file exceeds 2 MB or contains a null byte.")
        }
        var output: [String] = []
        var block: String?
        for (offset, line) in configuration.components(separatedBy: .newlines).enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            func reject(_ reason: String) -> OpenVPNConfigurationError {
                OpenVPNConfigurationError(reason: "line \(offset + 1): \(reason)")
            }
            if let current = block {
                if trimmed == "</\(current)>" {
                    if current != "auth-user-pass" { output.append(trimmed) }
                    block = nil
                } else {
                    guard !trimmed.contains("<"), !trimmed.contains(">") else {
                        throw reject("nested or mismatched inline blocks are not supported.")
                    }
                    if current != "auth-user-pass" { output.append(line) }
                }
                continue
            }
            if trimmed.isEmpty || trimmed.hasPrefix("#") || trimmed.hasPrefix(";") { continue }
            if trimmed.hasPrefix("<"), trimmed.hasSuffix(">") {
                let type = String(trimmed.dropFirst().dropLast())
                guard inlineTypes.contains(type) || type == "auth-user-pass" else {
                    throw reject("inline block '\(type)' is not supported.")
                }
                block = type
                if type != "auth-user-pass" { output.append(trimmed) }
                continue
            }
            let fields = try tokens(in: trimmed)
            guard let first = fields.first else { continue }
            let key = first.hasPrefix("--") ? String(first.dropFirst(2)) : first
            let arguments = Array(fields.dropFirst())
            // Credentials always come from the app; never preserve imported values or paths.
            if key == "auth-user-pass" { continue }
            if inlineTypes.contains(key) || ["pkcs12", "crl-verify", "dh"].contains(key) {
                throw reject("external '\(key)' files are not supported. Export a profile with embedded certificates and keys.")
            }
            guard let arity = arities[key], arity.contains(arguments.count) else {
                throw reject("option '\(key)' is unsupported or has an invalid argument count.")
            }
            if key == "dev", !["tun", "tap"].contains(arguments[0]) {
                throw reject("dev must be tun or tap; device paths are not allowed.")
            }
            if key == "dhcp-option", !["DNS", "DOMAIN", "DOMAIN-SEARCH"].contains(arguments[0]) {
                throw reject("only DNS, DOMAIN and DOMAIN-SEARCH dhcp-option values are supported.")
            }
            output.append(([key] + arguments.map(quoted)).joined(separator: " "))
        }
        guard block == nil else { throw OpenVPNConfigurationError(reason: "an inline block is incomplete.") }
        return output.joined(separator: "\n") + "\n"
    }

    /// Parse quoting once, then emit a canonical spelling. No line continuation or
    /// embedded control characters are accepted, including in quoted arguments.
    static func tokens(in line: String) throws -> [String] {
        var result: [String] = []
        var token = ""
        var quote: Character?
        var escaped = false
        var started = false
        for character in line {
            guard character == "\t" || !character.unicodeScalars.contains(where: CharacterSet.controlCharacters.contains) else {
                throw OpenVPNConfigurationError(reason: "control characters are not supported.")
            }
            if escaped { token.append(character); escaped = false; continue }
            if character == "\\", quote != "'" { escaped = true; started = true; continue }
            if let current = quote {
                if character == current { quote = nil } else { token.append(character) }
            } else if character == "\"" || character == "'" {
                quote = character
                started = true
            } else if character.isWhitespace {
                if started { result.append(token); token = ""; started = false }
            } else if !started && (character == "#" || character == ";") {
                break
            } else {
                token.append(character)
                started = true
            }
        }
        guard quote == nil, !escaped else {
            throw OpenVPNConfigurationError(reason: "an argument has incomplete quoting or escaping.")
        }
        if started { result.append(token) }
        return result
    }

    private static func quoted(_ value: String) -> String {
        "\"" + value.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"") + "\""
    }
}
