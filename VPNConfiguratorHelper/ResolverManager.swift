import Foundation

enum ResolverManager {
    static func install(profileID: String, servers: [String], domains: [String]) throws -> [URL] {
        guard !domains.isEmpty else { return [] }
        let directoryURL = URL(fileURLWithPath: "/etc/resolver", isDirectory: true)
        try FileManager.default.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o755]
        )

        let marker = marker(for: profileID)
        var installed: [URL] = []
        do {
            for domain in domains {
                let url = directoryURL.appendingPathComponent(domain, isDirectory: false)
                if FileManager.default.fileExists(atPath: url.path) {
                    let existing = try String(contentsOf: url, encoding: .utf8)
                    guard existing.hasPrefix(marker) else {
                        throw HelperFailure.resolverConflict(domain)
                    }
                    try FileManager.default.removeItem(at: url)
                }

                var contents = marker + "domain \(domain)\n"
                for server in servers { contents += "nameserver \(server)\n" }
                try SecureRuntimeFiles.write(Data(contents.utf8), to: url, permissions: 0o644)
                installed.append(url)
            }
            return installed
        } catch {
            remove(installed, ownedBy: profileID)
            throw error
        }
    }

    static func remove(_ urls: [URL], ownedBy profileID: String) {
        let expectedMarker = marker(for: profileID)
        for url in urls {
            guard let existing = try? String(contentsOf: url, encoding: .utf8),
                  existing.hasPrefix(expectedMarker) else { continue }
            try? FileManager.default.removeItem(at: url)
        }
    }

    private static func marker(for profileID: String) -> String {
        "# VPN Configurator profile: \(profileID)\n"
    }
}
