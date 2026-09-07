import Foundation

enum ConfigurationImportError: LocalizedError {
    case fileTooLarge
    case unreadable
    case unsupportedFormat
    case missingServer

    var errorDescription: String? {
        switch self {
        case .fileTooLarge: "The configuration is larger than 2 MB."
        case .unreadable: "The configuration is not readable text."
        case .unsupportedFormat: "This does not look like an OpenVPN or OpenFortiVPN configuration."
        case .missingServer: "No VPN server was found in the configuration."
        }
    }
}

enum ConfigurationImporter {
    static func profile(from url: URL) throws -> VPNProfile {
        let resourceValues = try url.resourceValues(forKeys: [.fileSizeKey])
        if let size = resourceValues.fileSize, size > 2_000_000 {
            throw ConfigurationImportError.fileTooLarge
        }

        guard let contents = try? String(contentsOf: url, encoding: .utf8) else {
            throw ConfigurationImportError.unreadable
        }

        let lines = meaningfulLines(in: contents)
        let fileExtension = url.pathExtension.lowercased()
        let looksLikeOpenVPN = fileExtension == "ovpn"
            || lines.contains { ["remote", "client"].contains(fields(in: $0).first ?? "") }
        let looksLikeFortiVPN = lines.contains { line in
            let key = line.split(separator: "=", maxSplits: 1).first?.trimmingCharacters(in: .whitespaces).lowercased()
            return key == "host" || key == "trusted-cert" || key == "saml-login"
        }

        if looksLikeOpenVPN {
            // Validate before creating any managed file. Parse metadata from the same
            // canonical syntax the helper will execute, but recover usernames separately.
            let safe = try OpenVPNConfiguration.sanitize(contents)
            var profile = try openVPNProfile(from: meaningfulLines(in: safe), contents: safe, url: url)
            profile.username = referencedOpenVPNUsername(from: lines, sourceURL: url) ?? ""
            return profile
        }
        if looksLikeFortiVPN {
            return try fortiVPNProfile(from: lines, url: url)
        }
        throw ConfigurationImportError.unsupportedFormat
    }

    private static func openVPNProfile(
        from lines: [String],
        contents: String,
        url: URL,
        id: UUID = UUID()
    ) throws -> VPNProfile {
        var server = ""
        var dnsServers: [String] = []
        var dnsDomains: [String] = []

        for line in lines {
            let fields = fields(in: line)
            guard let option = fields.first?.lowercased() else { continue }

            switch option {
            case "remote" where fields.count >= 2:
                server = fields[1] + (fields.count >= 3 ? ":\(fields[2])" : "")
            case "dhcp-option" where fields.count >= 3 && fields[1].uppercased() == "DNS":
                appendUnique(fields[2], to: &dnsServers)
            case "dhcp-option" where fields.count >= 3 && ["DOMAIN", "DOMAIN-SEARCH"].contains(fields[1].uppercased()):
                appendUnique(fields[2], to: &dnsDomains)
            default:
                break
            }
        }

        guard !server.isEmpty else { throw ConfigurationImportError.missingServer }
        let managedURL = try storeManagedOpenVPNConfiguration(contents, profileID: id)
        return VPNProfile(
            id: id,
            name: displayName(for: url),
            server: server,
            provider: .openVPN,
            authentication: .password,
            username: "",
            configurationPath: managedURL.path,
            dnsDomains: dnsDomains,
            dnsServers: dnsServers,
            accent: .pink
        )
    }

    static func migrateOpenVPNProfile(_ profile: VPNProfile) throws -> VPNProfile {
        guard profile.provider == .openVPN,
              let path = profile.configurationPath,
              !isManagedOpenVPNConfiguration(path) else { return profile }

        let url = URL(fileURLWithPath: path)
        guard let contents = try? String(contentsOf: url, encoding: .utf8) else {
            throw ConfigurationImportError.unreadable
        }
        let lines = meaningfulLines(in: contents)
        let imported = try openVPNProfile(
            from: lines,
            contents: contents,
            url: url,
            id: profile.id
        )

        var result = imported
        result.name = profile.name
        result.authentication = profile.authentication
        result.username = profile.username.isEmpty
            ? referencedOpenVPNUsername(from: lines, sourceURL: url) ?? ""
            : profile.username
        result.dnsDomains = profile.dnsDomains.isEmpty ? imported.dnsDomains : profile.dnsDomains
        result.dnsServers = profile.dnsServers.isEmpty ? imported.dnsServers : profile.dnsServers
        result.accent = profile.accent
        return result
    }

    static func removeManagedOpenVPNConfiguration(at path: String?) {
        guard let path, isManagedOpenVPNConfiguration(path) else { return }
        try? FileManager.default.removeItem(atPath: path)
    }

    private static func storeManagedOpenVPNConfiguration(
        _ contents: String,
        profileID: UUID
    ) throws -> URL {
        let directory = try managedOpenVPNDirectory(create: true)
        let destination = directory.appending(path: "\(profileID.uuidString).ovpn")
        let sanitized = try OpenVPNConfiguration.sanitize(contents)
        try Data(sanitized.utf8).write(
            to: destination,
            options: [.atomic, .completeFileProtection]
        )
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o600],
            ofItemAtPath: destination.path
        )
        return destination
    }

    private static func referencedOpenVPNUsername(
        from lines: [String],
        sourceURL: URL
    ) -> String? {
        guard let directive = lines.first(where: {
            fields(in: $0).first?.lowercased() == "auth-user-pass" && fields(in: $0).count >= 2
        }) else { return nil }

        let rawPath = fields(in: directive)[1]
            .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
        let sourceDirectory = sourceURL.deletingLastPathComponent().resolvingSymlinksInPath()
        let credentialURL = URL(fileURLWithPath: rawPath, relativeTo: sourceDirectory)
            .standardizedFileURL
            .resolvingSymlinksInPath()
        guard credentialURL.path.hasPrefix(sourceDirectory.path + "/"),
              let handle = try? FileHandle(forReadingFrom: credentialURL) else { return nil }
        defer { try? handle.close() }

        var bytes: [UInt8] = []
        while bytes.count < 256,
              let data = try? handle.read(upToCount: 1),
              let byte = data.first,
              byte != 10, byte != 13 {
            bytes.append(byte)
        }
        guard let username = String(bytes: bytes, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              !username.isEmpty,
              !username.contains("\0") else { return nil }
        return username
    }

    private static func isManagedOpenVPNConfiguration(_ path: String) -> Bool {
        guard let directory = try? managedOpenVPNDirectory(create: false) else { return false }
        let standardizedPath = URL(fileURLWithPath: path).standardizedFileURL.path
        return standardizedPath.hasPrefix(directory.standardizedFileURL.path + "/")
    }

    private static func managedOpenVPNDirectory(create: Bool) throws -> URL {
        let applicationSupport = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: create
        )
        let directory = applicationSupport
            .appending(path: "VPN Configurator", directoryHint: .isDirectory)
            .appending(path: "OpenVPN", directoryHint: .isDirectory)
        if create {
            try FileManager.default.createDirectory(
                at: directory,
                withIntermediateDirectories: true,
                attributes: [.posixPermissions: 0o700]
            )
        }
        return directory
    }

    private static func fortiVPNProfile(from lines: [String], url: URL) throws -> VPNProfile {
        var values: [String: String] = [:]
        for line in lines {
            let pair = line.split(separator: "=", maxSplits: 1).map {
                String($0).trimmingCharacters(in: .whitespacesAndNewlines)
            }
            guard pair.count == 2 else { continue }
            let key = pair[0].lowercased()

            // Passwords and one-time codes are deliberately never imported.
            guard !["password", "passwd", "otp"].contains(key) else { continue }
            values[key] = pair[1]
        }

        guard let host = values["host"], !host.isEmpty else {
            throw ConfigurationImportError.missingServer
        }

        let server = host + (values["port"].map { ":\($0)" } ?? "")
        // The openfortivpn config value is a callback port (normally 8020), so the
        // presence of the option enables SAML; it is not a Boolean setting.
        let usesSAML = values["saml-login"] != nil
        let usesOTP = values["otp-prompt"] != nil || booleanValue(values["use-otp"])

        return VPNProfile(
            name: displayName(for: url),
            server: server,
            provider: .openFortiVPN,
            authentication: usesSAML ? .saml : (usesOTP ? .passwordAndOTP : .password),
            username: values["username"] ?? "",
            serverCertificatePin: values["trusted-cert"],
            accent: .blue
        )
    }

    private static func meaningfulLines(in contents: String) -> [String] {
        contents.components(separatedBy: .newlines).compactMap { rawLine in
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty, !line.hasPrefix("#"), !line.hasPrefix(";") else { return nil }
            return line
        }
    }

    private static func fields(in line: String) -> [String] {
        var fields = (try? OpenVPNConfiguration.tokens(in: line)) ?? []
        if let first = fields.first, first.hasPrefix("--") { fields[0] = String(first.dropFirst(2)) }
        return fields
    }

    private static func displayName(for url: URL) -> String {
        url.deletingPathExtension().lastPathComponent
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "_", with: " ")
            .capitalized
    }

    private static func booleanValue(_ value: String?) -> Bool {
        guard let value else { return false }
        return ["1", "true", "yes", "on"].contains(value.lowercased())
    }

    private static func appendUnique(_ value: String, to values: inout [String]) {
        if !values.contains(value) { values.append(value) }
    }
}
