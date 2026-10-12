import AppKit
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

/// Pictures imported as profile icons. Each is normalised to a small square PNG
/// next to the profile data, so the original file can move or disappear.
enum ProfileIconStore {
    static let pixelSize = 128
    nonisolated(unsafe) private static let cache = NSCache<NSUUID, NSImage>()

    static func load(_ id: UUID) -> NSImage? {
        if let cached = cache.object(forKey: id as NSUUID) { return cached }
        guard let url = try? fileURL(for: id, createDirectory: false),
              let image = NSImage(contentsOf: url) else { return nil }
        cache.setObject(image, forKey: id as NSUUID)
        return image
    }

    static func save(_ image: NSImage, for id: UUID) throws {
        guard let data = normalizedPNG(from: image) else { throw CocoaError(.fileWriteUnknown) }
        let url = try fileURL(for: id, createDirectory: true)
        try data.write(to: url, options: [.atomic, .completeFileProtection])
        cache.removeObject(forKey: id as NSUUID)
    }

    static func remove(for id: UUID) {
        cache.removeObject(forKey: id as NSUUID)
        if let url = try? fileURL(for: id, createDirectory: false) {
            try? FileManager.default.removeItem(at: url)
        }
    }

    /// Centre-crops to a square and scales to `pixelSize`.
    static func normalizedPNG(from image: NSImage) -> Data? {
        guard let source = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
        let side = min(source.width, source.height)
        let crop = CGRect(
            x: (source.width - side) / 2,
            y: (source.height - side) / 2,
            width: side,
            height: side
        )
        guard let square = source.cropping(to: crop),
              let context = CGContext(
                data: nil,
                width: pixelSize,
                height: pixelSize,
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: CGColorSpace(name: CGColorSpace.sRGB)!,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              ) else { return nil }
        context.interpolationQuality = .high
        context.draw(square, in: CGRect(x: 0, y: 0, width: pixelSize, height: pixelSize))
        guard let scaled = context.makeImage() else { return nil }
        return NSBitmapImageRep(cgImage: scaled).representation(using: .png, properties: [:])
    }

    private static func fileURL(for id: UUID, createDirectory: Bool) throws -> URL {
        let support = try FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: false
        )
        let directory = support
            .appending(path: "Bifrost", directoryHint: .isDirectory)
            .appending(path: "Icons", directoryHint: .isDirectory)
        if createDirectory {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        return directory.appending(path: "\(id.uuidString).png")
    }
}
