import Darwin
import Foundation
import OSLog

private let cleanupLogger = Logger(
    subsystem: "com.klianos.VPNConfigurator.helper",
    category: "ArtifactCleanup"
)

enum OrphanedArtifactCleanup {
    static let runtimeDirectory = URL(fileURLWithPath: "/var/run/vpnconfigurator", isDirectory: true)
    static let resolverDirectory = URL(fileURLWithPath: "/etc/resolver", isDirectory: true)
    static let resolverMarker = "# VPN Configurator profile: "

    @discardableResult
    static func run(
        runtimeDirectory: URL = runtimeDirectory,
        resolverDirectory: URL = resolverDirectory
    ) -> (runtimeFiles: Int, resolverFiles: Int) {
        let runtimeFiles = removeFiles(in: runtimeDirectory, matching: isRuntimeArtifact)
        let resolverFiles = removeFiles(in: resolverDirectory, matching: isOwnedResolver)
        return (runtimeFiles, resolverFiles)
    }

    private static func removeFiles(in directory: URL, matching predicate: (URL) -> Bool) -> Int {
        guard let urls = try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else { return 0 }

        var removed = 0
        for url in urls where isRegularFileWithoutFollowingLinks(url) && predicate(url) {
            do {
                try FileManager.default.removeItem(at: url)
                removed += 1
            } catch {
                cleanupLogger.error("Could not remove orphaned artifact \(url.path, privacy: .public): \(error.localizedDescription, privacy: .public)")
            }
        }
        return removed
    }

    private static func isRuntimeArtifact(_ url: URL) -> Bool {
        let name = url.lastPathComponent
        guard name.count > 73 else { return false }
        let firstEnd = name.index(name.startIndex, offsetBy: 36)
        guard name[firstEnd] == "-" else { return false }
        let secondStart = name.index(after: firstEnd)
        let secondEnd = name.index(secondStart, offsetBy: 36)
        guard UUID(uuidString: String(name[..<firstEnd])) != nil,
              UUID(uuidString: String(name[secondStart..<secondEnd])) != nil else { return false }
        return [".conf", ".ovpn", ".auth", ".vpnc.sh"].contains(String(name[secondEnd...]))
    }

    private static func isOwnedResolver(_ url: URL) -> Bool {
        guard let values = try? url.resourceValues(forKeys: [.fileSizeKey]),
              let size = values.fileSize, size <= 4_096,
              let contents = try? String(contentsOf: url, encoding: .utf8),
              let firstLine = contents.split(separator: "\n", maxSplits: 1).first,
              firstLine.hasPrefix(resolverMarker) else { return false }
        return UUID(uuidString: String(firstLine.dropFirst(resolverMarker.count))) != nil
    }

    private static func isRegularFileWithoutFollowingLinks(_ url: URL) -> Bool {
        var info = stat()
        return lstat(url.path, &info) == 0 && info.st_mode & S_IFMT == S_IFREG
    }
}
