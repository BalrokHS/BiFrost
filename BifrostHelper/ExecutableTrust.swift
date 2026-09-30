import CryptoKit
import Darwin
import Foundation

struct ExecutableTrustError: LocalizedError {
    let reason: String
    var errorDescription: String? { reason }
}

/// Two different jobs live here.
///
/// `requireRootOwned` is an absolute check, used for files this helper must be
/// able to trust unconditionally — its own approval record. Nothing a normal
/// user can rewrite may pass it.
///
/// `imageDigests` is the measurement used for the VPN engines themselves. Those
/// deliberately stay where their package manager installed them, inside a
/// user-writable prefix, so ownership cannot be the test. Instead we record what
/// the administrator approved and re-measure it before every launch.
enum ExecutableTrust {
    static func requireRootOwned(_ path: String, remainingLinks: Int = 32) throws {
        guard remainingLinks > 0, path.hasPrefix("/") else {
            throw ExecutableTrustError(reason: "\(path) is not a supported absolute path.")
        }
        let components = URL(fileURLWithPath: path).standardizedFileURL.pathComponents
        var current = ""
        for (index, component) in components.enumerated() {
            current = component == "/" ? "/" : (current as NSString).appendingPathComponent(component)
            guard let security = filesec_init() else {
                throw ExecutableTrustError(reason: "file security could not be allocated.")
            }
            defer { filesec_free(security) }
            var info = stat()
            guard lstatx_np(current, &info, security) == 0, info.st_uid == 0 else {
                throw ExecutableTrustError(reason: "\(current) is missing or is not owned by root.")
            }
            if info.st_mode & S_IFMT == S_IFLNK {
                let target = try FileManager.default.destinationOfSymbolicLink(atPath: current)
                let parent = (current as NSString).deletingLastPathComponent
                let absolute = target.hasPrefix("/") ? target : (parent as NSString).appendingPathComponent(target)
                // Validate the target before following any further path components.
                try requireRootOwned(absolute, remainingLinks: remainingLinks - 1)
                let suffix = components.dropFirst(index + 1).joined(separator: "/")
                if !suffix.isEmpty {
                    try requireRootOwned((absolute as NSString).appendingPathComponent(suffix), remainingLinks: remainingLinks - 1)
                }
                return
            }
            guard info.st_mode & 0o022 == 0 else {
                throw ExecutableTrustError(reason: "\(current) is writable by a non-root group or other users.")
            }
            // POSIX mode bits do not account for ACL write grants. Fail closed on
            // extended ACLs until a more granular ACL policy is supported.
            var optionalACL: acl_t?
            errno = 0
            let aclResult = filesec_get_property(security, FILESEC_ACL, &optionalACL)
            // Unlike acl_get_file, successful lstatx_np above distinguishes a missing
            // ACL property (ENOENT) from failure to inspect the file itself.
            if aclResult == -1 && errno == ENOENT { continue }
            guard aclResult == 0, let acl = optionalACL else {
                throw ExecutableTrustError(reason: "the ACL for \(current) could not be checked.")
            }
            defer { acl_free(UnsafeMutableRawPointer(acl)) }
            var entry: acl_entry_t?
            errno = 0
            let result = acl_get_entry(acl, Int32(ACL_FIRST_ENTRY.rawValue), &entry)
            guard result == -1, errno == EINVAL else {
                throw ExecutableTrustError(reason: "\(current) has an unsupported extended ACL.")
            }
        }
    }

    /// SHA-256 of an executable and of every non-system library reachable from it,
    /// keyed by absolute path. Measuring the whole graph matters because replacing
    /// a dependency is as good as replacing the executable: `openvpn` loading a
    /// hostile `libcrypto` still runs that code as root.
    static func imageDigests(of path: String) throws -> [String: String] {
        var digests: [String: String] = [:]
        try collect(path, into: &digests)
        return digests
    }

    private static func collect(_ path: String, into digests: inout [String: String]) throws {
        let canonical = URL(fileURLWithPath: path).standardizedFileURL.path
        guard digests[canonical] == nil else { return }
        // Apple's own libraries are protected by SIP and often exist only inside
        // the dyld shared cache, so there is no file to hash and no need to.
        guard !isSystemImage(canonical) else { return }
        guard digests.count < 256 else {
            throw ExecutableTrustError(reason: "\(path) loads more libraries than this helper will verify.")
        }
        let data: Data
        do {
            data = try Data(contentsOf: URL(fileURLWithPath: canonical), options: .uncached)
        } catch {
            throw ExecutableTrustError(reason: "\(canonical) could not be read: \(error.localizedDescription)")
        }
        digests[canonical] = sha256(data)
        for dependency in try dependencies(in: data) {
            guard dependency.hasPrefix("/") else {
                throw ExecutableTrustError(
                    reason: "\(canonical) loads \(dependency) through a relative or @rpath reference, which cannot be pinned."
                )
            }
            try collect(dependency, into: &digests)
        }
    }

    static func isSystemImage(_ path: String) -> Bool {
        path.hasPrefix("/usr/lib/") || path.hasPrefix("/System/")
    }

    static func sha256(ofFileAt path: String) throws -> String {
        do {
            return sha256(try Data(contentsOf: URL(fileURLWithPath: path), options: .uncached))
        } catch {
            throw ExecutableTrustError(reason: "\(path) could not be read: \(error.localizedDescription)")
        }
    }

    static func sha256(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    /// Read Mach-O load commands without executing the candidate or requiring
    /// Xcode/otool on the recipient's Mac. Universal binaries are unioned across
    /// every slice: dyld picks one at launch, and pinning the dependencies of a
    /// slice we did not inspect is the whole point. Anything else fails closed.
    static func dependencies(in data: Data) throws -> [String] {
        // Mach-O headers are little-endian on every Mac this app supports, but a
        // universal wrapper is big-endian by definition, so its magic reads
        // byte-reversed here: 0xcafebabe on disk becomes 0xbebafeca.
        let magic = try word(data, 0)
        switch magic {
        case 0xfeedfacf:
            return try loadCommands(in: data, start: 0)
        case 0xbebafeca, 0xbfbafeca:
            return try universalDependencies(in: data, is64Bit: magic == 0xbfbafeca)
        default:
            throw malformed()
        }
    }

    private static func universalDependencies(in data: Data, is64Bit: Bool) throws -> [String] {
        let count = Int(try bigEndianWord(data, 4))
        let entrySize = is64Bit ? 32 : 20
        guard count > 0, count <= 32, 8 + count * entrySize <= data.count else { throw malformed() }
        var result: [String] = []
        for index in 0..<count {
            let entry = 8 + index * entrySize
            let start: Int
            let size: Int
            if is64Bit {
                // The upper half of a 64-bit offset larger than Int.max is not a
                // file this helper is going to hash anyway.
                guard try bigEndianWord(data, entry + 8) == 0, try bigEndianWord(data, entry + 16) == 0 else {
                    throw malformed()
                }
                start = Int(try bigEndianWord(data, entry + 12))
                size = Int(try bigEndianWord(data, entry + 20))
            } else {
                start = Int(try bigEndianWord(data, entry + 8))
                size = Int(try bigEndianWord(data, entry + 12))
            }
            guard size >= 32, start >= 8 + count * entrySize, data.count - start >= size else { throw malformed() }
            guard try word(data, start) == 0xfeedfacf else { throw malformed() }
            for name in try loadCommands(in: data.prefix(start + size), start: start) where !result.contains(name) {
                result.append(name)
            }
        }
        return result
    }

    /// One 64-bit little-endian Mach-O image beginning at `start`.
    private static func loadCommands(in data: Data, start: Int) throws -> [String] {
        guard data.count - start >= 32 else { throw malformed() }
        let count = Int(try word(data, start + 16))
        let size = Int(try word(data, start + 20))
        guard size <= data.count - start - 32, count <= size / 8 else { throw malformed() }
        let end = start + 32 + size
        var offset = start + 32
        var result: [String] = []
        for _ in 0..<count {
            guard offset <= end - 8 else { throw malformed() }
            let command = try word(data, offset)
            let commandSize = Int(try word(data, offset + 4))
            guard commandSize >= 8, commandSize <= end - offset else { throw malformed() }
            if [UInt32(0xc), 0x80000018, 0x8000001f, 0x80000023, 0x20].contains(command) {
                guard commandSize >= 24 else { throw malformed() }
                let nameOffset = Int(try word(data, offset + 8))
                guard nameOffset >= 24, nameOffset < commandSize else { throw malformed() }
                let base = data.startIndex
                let bytes = data[(base + offset + nameOffset)..<(base + offset + commandSize)]
                guard let terminator = bytes.firstIndex(of: 0),
                      let name = String(data: bytes[..<terminator], encoding: .utf8), !name.isEmpty else { throw malformed() }
                result.append(name)
            }
            offset += commandSize
        }
        guard offset == end else { throw malformed() }
        return result
    }

    private static func malformed() -> ExecutableTrustError {
        ExecutableTrustError(reason: "unsupported or malformed Mach-O image.")
    }

    private static func word(_ data: Data, _ offset: Int) throws -> UInt32 {
        guard offset >= 0, data.count >= 4, offset <= data.count - 4 else { throw malformed() }
        return (0..<4).reduce(UInt32(0)) { $0 | UInt32(data[data.startIndex + offset + $1]) << ($1 * 8) }
    }

    private static func bigEndianWord(_ data: Data, _ offset: Int) throws -> UInt32 {
        try word(data, offset).byteSwapped
    }
}
