import Foundation

enum ProfileStore {
    private static let fileName = "profiles.json"

    static func load() throws -> [VPNProfile] {
        let legacyDirectory = try migrateLegacyDirectory()
        let url = try storeURL(createDirectory: false)
        guard FileManager.default.fileExists(atPath: url.path) else { return [] }

        let data = try Data(contentsOf: url)
        var profiles = try JSONDecoder().decode([VPNProfile].self, from: data)
        if let legacyDirectory {
            // Managed OpenVPN files moved with the directory; point profiles at the new location.
            let newDirectory = url.deletingLastPathComponent().path
            for index in profiles.indices {
                if let path = profiles[index].configurationPath, path.hasPrefix(legacyDirectory.path + "/") {
                    profiles[index].configurationPath = newDirectory + path.dropFirst(legacyDirectory.path.count)
                }
            }
            try save(profiles)
        }
        return profiles
    }

    /// Before the rename to Bifrost, data lived in "VPN Configurator". Moves it once and
    /// returns the old location if a move happened.
    private static func migrateLegacyDirectory() throws -> URL? {
        let files = FileManager.default
        let applicationSupport = try files.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
        let legacy = applicationSupport.appending(path: "VPN Configurator", directoryHint: .isDirectory)
        let current = applicationSupport.appending(path: "Bifrost", directoryHint: .isDirectory)
        guard files.fileExists(atPath: legacy.path), !files.fileExists(atPath: current.path) else { return nil }
        try files.moveItem(at: legacy, to: current)
        return legacy
    }

    static func save(_ profiles: [VPNProfile]) throws {
        let url = try storeURL(createDirectory: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(profiles).write(to: url, options: [.atomic, .completeFileProtection])
    }

    private static func storeURL(createDirectory: Bool) throws -> URL {
        let applicationSupport = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: createDirectory
        )
        let directory = applicationSupport.appending(path: "Bifrost", directoryHint: .isDirectory)

        if createDirectory {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }

        return directory.appending(path: fileName)
    }
}
