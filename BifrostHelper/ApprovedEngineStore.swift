import Darwin
import Foundation

/// The privileged helper's record of which VPN executables an administrator
/// approved for root execution, and what their bytes looked like at that moment.
///
/// The engines themselves stay where their package manager installed them, which
/// on macOS is a prefix the logged-in user can write to. That is a deliberate
/// trade: approval pins the executable and its whole library graph by SHA-256 and
/// re-measures before every launch, so a binary that is silently replaced stops
/// working instead of running as root. It cannot stop an attacker who already has
/// code execution as the user and races the window between measurement and exec —
/// macOS has no `fexecve`, so closing that window would require executing a copy
/// the user cannot write to.
enum ApprovedEngineStore {
    static func approve(
        _ engine: VPNEngine,
        executablePath: String,
        vpncScriptPath: String?
    ) throws -> ApprovedEngine {
        let executable = try normalizedExecutable(executablePath)
        var files = try ExecutableTrust.imageDigests(of: executable)
        guard files[executable] != nil else {
            throw EngineTrustError(message: "\(executable) is a system path this helper does not manage.")
        }

        var script: String?
        if engine.needsVPNCScript {
            guard let vpncScriptPath, !vpncScriptPath.isEmpty else {
                throw EngineTrustError(
                    message: "OpenConnect also needs a vpnc-script to configure routes and DNS. Install one with `brew install vpnc-script`, then approve OpenConnect again."
                )
            }
            let normalized = try normalizedExecutable(vpncScriptPath)
            files[normalized] = try ExecutableTrust.sha256(ofFileAt: normalized)
            script = normalized
        }

        let approved = ApprovedEngine(
            engine: engine,
            executablePath: executable,
            vpncScriptPath: script,
            files: files,
            approvedAt: Date()
        )
        var record = try loadRecord()
        record.engines[engine.rawValue] = approved
        try writeRecord(record)
        return approved
    }

    static func revoke(_ engine: VPNEngine) throws {
        var record = try loadRecord()
        guard record.engines.removeValue(forKey: engine.rawValue) != nil else {
            throw EngineTrustError(message: "\(engine.displayName) was not approved.")
        }
        try writeRecord(record)
    }

    /// Called on every connection attempt. Throws unless the approved engine is
    /// still byte-for-byte what the administrator approved.
    static func resolve(_ engine: VPNEngine) throws -> ApprovedEngine {
        let record = try loadRecord()
        guard let approved = record.engines[engine.rawValue] else {
            throw EngineTrustError(
                message: "\(engine.displayName) has not been approved to run with administrator privileges. Open Settings › VPN engines and approve the installed copy."
            )
        }
        try verify(approved)
        return approved
    }

    /// Non-throwing status for the Settings list, so the UI can distinguish
    /// "never approved" from "approved but changed".
    static func state(for engine: VPNEngine, executablePath: String) -> (state: EngineApprovalState, detail: String) {
        let record: EngineApprovalRecord
        do {
            record = try loadRecord()
        } catch {
            return (.unavailable, error.localizedDescription)
        }
        guard let approved = record.engines[engine.rawValue] else {
            return (.notApproved, "Approval is required before this engine can run with administrator privileges.")
        }
        let normalized = URL(fileURLWithPath: executablePath).standardizedFileURL.path
        guard approved.executablePath == normalized else {
            return (.changed, "You approved \(approved.executablePath), but \(normalized) is what the app now finds.")
        }
        do {
            try verify(approved)
            return (.ready, "Approved \(approved.approvedAt.formatted(date: .abbreviated, time: .shortened)). \(approved.files.count) pinned file\(approved.files.count == 1 ? "" : "s").")
        } catch {
            return (.changed, error.localizedDescription)
        }
    }

    static func verify(_ approved: ApprovedEngine) throws {
        var current = try ExecutableTrust.imageDigests(of: approved.executablePath)
        if let script = approved.vpncScriptPath {
            current[script] = try ExecutableTrust.sha256(ofFileAt: script)
        }
        guard current != approved.files else { return }

        // Report what actually moved. An added path matters as much as a changed
        // digest: a new dependency is unpinned code the administrator never saw.
        let changed = approved.files.keys.filter { current[$0] != nil && current[$0] != approved.files[$0] }.sorted()
        let removed = approved.files.keys.filter { current[$0] == nil }.sorted()
        let added = current.keys.filter { approved.files[$0] == nil }.sorted()
        var reasons: [String] = []
        if !changed.isEmpty { reasons.append("changed: \(changed.joined(separator: ", "))") }
        if !added.isEmpty { reasons.append("newly loaded: \(added.joined(separator: ", "))") }
        if !removed.isEmpty { reasons.append("no longer present: \(removed.joined(separator: ", "))") }
        throw EngineTrustError(
            message: "\(approved.engine.displayName) is not what you approved (\(reasons.joined(separator: "; "))). This is expected after a package upgrade — approve it again in Settings. If you did not upgrade anything, do not approve it."
        )
    }

    static func loadRecord() throws -> EngineApprovalRecord {
        guard FileManager.default.fileExists(atPath: EngineApproval.recordURL.path) else {
            return EngineApprovalRecord()
        }
        // The record decides what runs as root, so unlike the engines it pins, it
        // must live somewhere no non-root user can rewrite.
        try ExecutableTrust.requireRootOwned(EngineApproval.recordURL.path)
        let values = try EngineApproval.recordURL.resourceValues(forKeys: [.fileSizeKey])
        guard (values.fileSize ?? Int.max) <= 1_000_000 else {
            throw EngineTrustError(message: "The VPN engine approval record is too large.")
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let record = try decoder.decode(EngineApprovalRecord.self, from: Data(contentsOf: EngineApproval.recordURL))
        guard record.schemaVersion == EngineApprovalRecord.currentSchemaVersion else {
            throw EngineTrustError(message: "The VPN engine approval record uses an unsupported format. Approve your engines again.")
        }
        for (key, approved) in record.engines {
            guard key == approved.engine.rawValue, approved.files[approved.executablePath] != nil,
                  approved.files.count <= 256,
                  approved.files.keys.allSatisfy({ $0.hasPrefix("/") }),
                  approved.files.values.allSatisfy({ $0.count == 64 && $0.allSatisfy { $0.isHexDigit && $0.isASCII } }),
                  approved.vpncScriptPath.map({ approved.files[$0] != nil }) ?? true else {
                throw EngineTrustError(message: "The approval for \(key) is inconsistent. Approve your engines again.")
            }
        }
        return record
    }

    private static func writeRecord(_ record: EngineApprovalRecord) throws {
        let manager = FileManager.default
        if !manager.fileExists(atPath: EngineApproval.directory.path) {
            try manager.createDirectory(
                at: EngineApproval.directory,
                withIntermediateDirectories: true,
                attributes: [.posixPermissions: 0o755]
            )
        }
        try ExecutableTrust.requireRootOwned(EngineApproval.directory.path)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(record)

        let temporary = EngineApproval.directory
            .appendingPathComponent(".approved-engines-\(UUID().uuidString).json")
        try data.write(to: temporary, options: .atomic)
        guard chmod(temporary.path, 0o644) == 0, rename(temporary.path, EngineApproval.recordURL.path) == 0 else {
            let reason = String(cString: strerror(errno))
            try? manager.removeItem(at: temporary)
            throw EngineTrustError(message: "The VPN engine approval record could not be written: \(reason)")
        }
    }

    private static func normalizedExecutable(_ path: String) throws -> String {
        let normalized = URL(fileURLWithPath: path).standardizedFileURL.path
        guard path.hasPrefix("/"), normalized == path else {
            throw EngineTrustError(message: "\(path) must be an absolute, normalized path.")
        }
        guard EngineDiscovery.isExecutableFile(normalized) else {
            throw EngineTrustError(message: "\(normalized) is not an executable file.")
        }
        return normalized
    }
}
