import Darwin
import Foundation

enum SecureRuntimeFiles {
    static func make(profileID: String, suffix: String, data: Data) throws -> URL {
        let directoryURL = URL(fileURLWithPath: "/var/run/bifrost", isDirectory: true)
        try FileManager.default.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        let url = directoryURL.appendingPathComponent("\(profileID)-\(UUID().uuidString).\(suffix)")
        try write(data, to: url)
        return url
    }

    static func makeOpenConnectScript(profileID: String, engine: ApprovedEngine) throws -> URL {
        guard let vpncScript = engine.vpncScriptPath else {
            throw HelperFailure.untrustedExecutable("OpenConnect was approved without a vpnc-script.")
        }
        let script = """
        #!/bin/sh
        unset INTERNAL_IP4_DNS INTERNAL_IP6_DNS CISCO_DEF_DOMAIN CISCO_SPLIT_DNS
        exec /bin/sh -c '. "$1"' bifrost-vpnc '\(vpncScript)'
        """
        let url = try make(profileID: profileID, suffix: "vpnc.sh", data: Data(script.utf8))
        guard chmod(url.path, 0o700) == 0 else {
            try? FileManager.default.removeItem(at: url)
            throw HelperFailure.launchFailed(String(cString: strerror(errno)))
        }
        return url
    }

    static func remove(_ urls: [URL]) {
        for url in urls { try? FileManager.default.removeItem(at: url) }
    }

    static func openFortiVPNConfiguration(
        host: String,
        port: Int,
        trustedCertificate: String,
        username: String,
        password: String,
        oneTimePassword: String
    ) -> String {
        var configuration = "host = \(host)\nport = \(port)\n"
        if !trustedCertificate.isEmpty { configuration += "trusted-cert = \(trustedCertificate)\n" }
        if !username.isEmpty { configuration += "username = \(username)\n" }
        if !password.isEmpty { configuration += "password = \(password)\n" }
        if !oneTimePassword.isEmpty {
            configuration += "otp = \(oneTimePassword)\n"
            // Explicit OTP input must disable FortiToken push or the code is ignored.
            configuration += "no-ftm-push = 1\n"
        }
        return configuration
    }

    static func makeOpenFortiVPNConfiguration(
        profileID: String,
        host: String,
        port: Int,
        trustedCertificate: String,
        username: String,
        password: String,
        oneTimePassword: String
    ) throws -> URL {
        let configuration = openFortiVPNConfiguration(
            host: host,
            port: port,
            trustedCertificate: trustedCertificate,
            username: username,
            password: password,
            oneTimePassword: oneTimePassword
        )
        return try make(profileID: profileID, suffix: "conf", data: Data(configuration.utf8))
    }

    static func write(
        _ data: Data,
        to url: URL,
        permissions: mode_t = S_IRUSR | S_IWUSR
    ) throws {
        let descriptor = Darwin.open(url.path, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW, permissions)
        guard descriptor >= 0 else {
            throw HelperFailure.launchFailed(String(cString: strerror(errno)))
        }
        defer { Darwin.close(descriptor) }

        try data.withUnsafeBytes { rawBuffer in
            guard let baseAddress = rawBuffer.baseAddress else { return }
            var written = 0
            while written < rawBuffer.count {
                let result = Darwin.write(descriptor, baseAddress.advanced(by: written), rawBuffer.count - written)
                guard result > 0 else {
                    throw HelperFailure.launchFailed(String(cString: strerror(errno)))
                }
                written += result
            }
        }
    }
}
