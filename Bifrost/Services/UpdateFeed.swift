import CryptoKit
import Foundation

/// Where releases live and how they are authenticated. Ad-hoc signed apps do not
/// identify their publisher, so every downloaded image must carry a detached
/// Ed25519 signature that verifies against the key pinned below.
enum UpdateFeed {
    static let repository = "BalrokHS/BiFrost"
    static let imageName = "Bifrost.dmg"
    static let signatureName = "Bifrost.dmg.sig"
    /// Public half of the key managed by script/release_signing.swift.
    static let pinnedPublicKey = "8mFDOOEp/RYPBwYAQ+ZWz6E8Gaq/2K4rKyK1yVxn7AM="
    static let maximumImageBytes = 300 * 1024 * 1024
    static let maximumSignatureBytes = 1024

    /// The app's marketing version (`0.2.0`) is the source of truth. The integer
    /// `build` that orders releases, and that names the helper registration, is
    /// derived from it, so a higher version is always a higher build.
    struct Release: Equatable, Sendable {
        let tag: String
        let version: String
        let build: Int64
    }

    /// `major.minor.patch` with each part below 1000 becomes
    /// `major * 1_000_000 + minor * 1_000 + patch`, so 0.2.0 is build 2000.
    static func build(forVersion version: String) -> Int64? {
        let parts = version.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 3 else { return nil }
        var numbers: [Int64] = []
        for part in parts {
            guard !part.isEmpty, part.count <= 3,
                  part.utf8.allSatisfy({ (48...57).contains($0) }),
                  part == "0" || part.first != "0",
                  let number = Int64(part) else { return nil }
            numbers.append(number)
        }
        let build = numbers[0] * 1_000_000 + numbers[1] * 1_000 + numbers[2]
        return build > 0 ? build : nil
    }

    static func version(forBuild build: Int64) -> String {
        "\(build / 1_000_000).\((build / 1_000) % 1_000).\(build % 1_000)"
    }

    static var latestReleaseURL: URL {
        URL(string: "https://api.github.com/repos/\(repository)/releases/latest")!
    }

    /// Built from the validated tag rather than trusting URLs inside the API response.
    static func assetURL(for release: Release, name: String) -> URL {
        URL(string: "https://github.com/\(repository)/releases/download/\(release.tag)/\(name)")!
    }

    static func release(tag: String) -> Release? {
        guard tag.hasPrefix("v") else { return nil }
        let version = String(tag.dropFirst())
        guard let build = build(forVersion: version) else { return nil }
        return Release(tag: tag, version: version, build: build)
    }

    /// Returns nil for drafts, prereleases and tags that are not `v<major>.<minor>.<patch>`.
    static func parseLatest(_ data: Data) -> Release? {
        struct Payload: Decodable {
            let tag_name: String
            let draft: Bool?
            let prerelease: Bool?
        }
        guard let payload = try? JSONDecoder().decode(Payload.self, from: data),
              payload.draft != true, payload.prerelease != true else { return nil }
        return release(tag: payload.tag_name)
    }

    static func isAuthentic(image: Data, signature: Data, publicKey: String = pinnedPublicKey) -> Bool {
        guard let keyBytes = Data(base64Encoded: publicKey),
              let key = try? Curve25519.Signing.PublicKey(rawRepresentation: keyBytes),
              let text = String(data: signature, encoding: .utf8),
              let raw = Data(base64Encoded: text.trimmingCharacters(in: .whitespacesAndNewlines)) else { return false }
        return key.isValidSignature(raw, for: image)
    }
}
