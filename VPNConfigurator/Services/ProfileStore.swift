import Foundation

enum ProfileStore {
    private static let fileName = "profiles.json"

    static func load() throws -> [VPNProfile] {
        let url = try storeURL(createDirectory: false)
        guard FileManager.default.fileExists(atPath: url.path) else { return [] }

        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode([VPNProfile].self, from: data)
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
        let directory = applicationSupport.appending(path: "VPN Configurator", directoryHint: .isDirectory)

        if createDirectory {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }

        return directory.appending(path: fileName)
    }
}
