import CryptoKit
import Foundation

/// Where releases live and how they are authenticated. Ad-hoc signed apps do not
/// identify their publisher, so every downloaded image must carry a detached
/// Ed25519 signature that verifies against the key pinned below.
enum UpdateFeed {
    static let repository = "BalrokHS/BiFrost"
    static let imageName = "Bifrost-unsigned.dmg"
    static let signatureName = "Bifrost-unsigned.dmg.sig"
    /// Public half of the key managed by script/release_signing.swift.
    static let pinnedPublicKey = "8mFDOOEp/RYPBwYAQ+ZWz6E8Gaq/2K4rKyK1yVxn7AM="
    static let maximumImageBytes = 300 * 1024 * 1024
    static let maximumSignatureBytes = 1024

    struct Release: Equatable, Sendable {
        let tag: String
        let build: Int64
    }

    static var latestReleaseURL: URL {
        URL(string: "https://api.github.com/repos/\(repository)/releases/latest")!
    }

    /// Built from the validated tag rather than trusting URLs inside the API response.
    static func assetURL(for release: Release, name: String) -> URL {
        URL(string: "https://github.com/\(repository)/releases/download/\(release.tag)/\(name)")!
    }

    static func release(tag: String) -> Release? {
        guard tag.hasPrefix("build-"),
              let build = UnsignedRelease.buildNumber(String(tag.dropFirst("build-".count))) else { return nil }
        return Release(tag: tag, build: build)
    }

    /// Returns nil for drafts, prereleases and tags that are not `build-<number>`.
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
