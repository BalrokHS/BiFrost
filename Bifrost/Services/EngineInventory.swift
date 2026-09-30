import Foundation
import Observation

struct EngineReport: Identifiable, Sendable {
    let engine: VPNEngine
    let executablePath: String?
    let vpncScriptPath: String?
    let version: String?
    let state: EngineApprovalState
    let detail: String

    var id: String { engine.rawValue }
    var isInstalled: Bool { executablePath != nil }
    var canApprove: Bool {
        guard isInstalled, state == .notApproved || state == .changed else { return false }
        return !engine.needsVPNCScript || vpncScriptPath != nil
    }

    var statusTitle: String {
        switch state {
        case .ready: "Ready"
        case .notApproved: "Approval required"
        case .changed: "Changed since approval"
        case .unavailable: isInstalled ? "Unknown" : "Not installed"
        }
    }
}

/// Finds the VPN clients the user installed and asks the helper whether it would
/// run them. Discovery and version probing happen here, in the unprivileged app,
/// because reporting a version means executing the candidate — something the root
/// helper must never do for a binary nobody has approved.
@MainActor
@Observable
final class EngineInventory {
    private(set) var reports: [EngineReport] = []
    private(set) var isRefreshing = false
    private(set) var busyEngine: VPNEngine?
    var errorMessage: String?
    var successMessage: String?

    @ObservationIgnored
    private let helper: PrivilegedHelperManager

    init(helper: PrivilegedHelperManager) {
        self.helper = helper
    }

    func refresh() {
        guard !isRefreshing else { return }
        isRefreshing = true
        Task {
            let discovered = await Self.discover()
            var results: [EngineReport] = []
            for item in discovered {
                guard let executablePath = item.executablePath else {
                    results.append(EngineReport(
                        engine: item.engine,
                        executablePath: nil,
                        vpncScriptPath: item.vpncScriptPath,
                        version: nil,
                        state: .unavailable,
                        detail: "Not found in \(EngineDiscovery.searchDirectories.prefix(2).joined(separator: ", ")) or the other supported locations."
                    ))
                    continue
                }
                let approval = await approvalState(engine: item.engine, executablePath: executablePath)
                // OpenConnect cannot configure routes or DNS without a vpnc-script,
                // and Homebrew ships it as a separate formula, so a missing one is
                // worth saying here rather than only when approval fails.
                let missingScript = item.engine.needsVPNCScript && item.vpncScriptPath == nil
                results.append(EngineReport(
                    engine: item.engine,
                    executablePath: executablePath,
                    vpncScriptPath: item.vpncScriptPath,
                    version: item.version,
                    state: approval.state,
                    detail: missingScript
                        ? "No vpnc-script found. Install one with `brew install vpnc-script`, then refresh."
                        : approval.detail
                ))
            }
            reports = results
            isRefreshing = false
        }
    }

    func approve(_ engine: VPNEngine) {
        guard busyEngine == nil,
              let report = reports.first(where: { $0.engine == engine }),
              let executablePath = report.executablePath else { return }
        busyEngine = engine
        helper.approveEngine(
            engine: engine,
            executablePath: executablePath,
            vpncScriptPath: report.vpncScriptPath
        ) { [weak self] result in
            self?.finish(result)
        }
    }

    func revoke(_ engine: VPNEngine) {
        guard busyEngine == nil else { return }
        busyEngine = engine
        helper.revokeEngine(engine: engine) { [weak self] result in
            self?.finish(result)
        }
    }

    private func finish(_ result: Result<String, Error>) {
        busyEngine = nil
        switch result {
        case .success(let message): successMessage = message
        case .failure(let error): errorMessage = error.localizedDescription
        }
        refresh()
    }

    private func approvalState(
        engine: VPNEngine,
        executablePath: String
    ) async -> HelperEngineApproval {
        guard helper.isEnabled else {
            return HelperEngineApproval(
                state: .unavailable,
                detail: "Register the privileged connection service before approving engines."
            )
        }
        return await withCheckedContinuation { continuation in
            helper.engineApprovalState(engine: engine, executablePath: executablePath) { approval in
                continuation.resume(returning: approval)
            }
        }
    }

    private struct Discovered: Sendable {
        let engine: VPNEngine
        let executablePath: String?
        let vpncScriptPath: String?
        let version: String?
    }

    private nonisolated static func discover() async -> [Discovered] {
        await Task.detached(priority: .userInitiated) {
            let vpncScript = EngineDiscovery.locateVPNCScript()
            return VPNEngine.allCases.map { engine in
                let path = EngineDiscovery.locate(engine)
                return Discovered(
                    engine: engine,
                    executablePath: path,
                    vpncScriptPath: engine.needsVPNCScript ? vpncScript : nil,
                    version: path.flatMap(probeVersion)
                )
            }
        }.value
    }

    /// Runs `--version` as the logged-in user, never as root. Some engines report
    /// their version on stderr and exit non-zero, so any first line counts.
    private nonisolated static func probeVersion(at path: String) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = ["--version"]
        process.environment = ["PATH": "/usr/bin:/bin", "LANG": "C"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        process.standardInput = FileHandle.nullDevice
        do { try process.run() } catch { return nil }

        // A version probe must not be able to hang Settings.
        let watchdog = DispatchWorkItem { process.terminate() }
        DispatchQueue.global().asyncAfter(deadline: .now() + 5, execute: watchdog)
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        watchdog.cancel()

        return String(decoding: data, as: UTF8.self)
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .first { !$0.isEmpty }
            .map { String($0.prefix(120)) }
    }
}
