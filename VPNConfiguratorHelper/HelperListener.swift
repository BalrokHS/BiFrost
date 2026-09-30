import Foundation
import OSLog
import Security

private let listenerLogger = Logger(
    subsystem: "com.klianos.VPNConfigurator.helper",
    category: "XPCAuthorization"
)

/// The code-signing requirements this helper is willing to accept from an XPC
/// client.
///
/// A build signed with the developer's certificate is pinned to the team
/// identifier, which is the strongest anchor macOS offers. An ad-hoc build —
/// what `script/package_unsigned_dmg.sh` produces for people without an Apple
/// Developer membership — carries no team, so it is pinned instead to the exact
/// code hashes of the app bundle that ships the running helper. launchd already
/// resolves this daemon's `BundleProgram` out of that same bundle, so anyone who
/// can substitute the app can substitute the root helper too: the pin concedes
/// no privilege the install location did not already carry. Accepting any client
/// that merely claims the bundle identifier would instead hand root to an
/// unsigned copy sitting anywhere on disk.
enum ClientRequirement {
    static func teamAnchored(
        team: String = HelperConstants.signingTeamIdentifier,
        identifier: String = HelperConstants.mainAppIdentifier
    ) -> String {
        "anchor apple generic and certificate leaf[subject.OU] = \"\(team)\" and identifier \"\(identifier)\""
    }

    /// `designatedRequirement` is the requirement read from the app bundle on
    /// disk; for ad-hoc code it is a disjunction of the code-directory hashes of
    /// every architecture slice, which is what pins the client to that exact
    /// build. Returns nil when it could not be read, so an unreadable bundle
    /// rejects the connection rather than widening the requirement.
    static func codeHashPinned(
        designatedRequirement: String,
        identifier: String = HelperConstants.mainAppIdentifier
    ) -> String? {
        guard !designatedRequirement.isEmpty else { return nil }
        return "identifier \"\(identifier)\" and (\(designatedRequirement))"
    }
}

/// Reads the signing state of the running helper and of the app bundle that
/// contains it.
enum HelperCodeIdentity {
    /// `kSecCodeSignatureAdhoc` from `<Security/SecCode.h>`, which the Security
    /// framework does not surface to Swift.
    private static let adHocSignatureFlag: UInt32 = 0x0002

    private static func signingInformation(_ code: SecStaticCode) -> [String: Any]? {
        var information: CFDictionary?
        let flags = SecCSFlags(rawValue: kSecCSSigningInformation)
        guard SecCodeCopySigningInformation(code, flags, &information) == errSecSuccess,
              let information = information as? [String: Any] else { return nil }
        return information
    }

    private static func selfSigningInformation() -> [String: Any]? {
        var code: SecCode?
        guard SecCodeCopySelf([], &code) == errSecSuccess, let code else { return nil }
        var staticCode: SecStaticCode?
        guard SecCodeCopyStaticCode(code, [], &staticCode) == errSecSuccess,
              let staticCode else { return nil }
        return signingInformation(staticCode)
    }

    private static func url(_ value: Any?) -> URL? {
        if let url = value as? URL { return url }
        if let url = value as? NSURL { return url as URL }
        return nil
    }

    /// True when the helper itself carries an ad-hoc signature, which is the only
    /// case in which the code-hash pin below is used.
    static func isSelfAdHoc() -> Bool {
        guard let information = selfSigningInformation(),
              let flags = information[kSecCodeInfoFlags as String] as? UInt32 else { return false }
        return flags & adHocSignatureFlag != 0
    }

    /// The `.app` bundle whose `Contents/Resources` holds this helper.
    static func hostApplicationURL() -> URL? {
        guard let information = selfSigningInformation(),
              let executable = url(information[kSecCodeInfoMainExecutable as String]) else { return nil }
        let bundle = executable
            .deletingLastPathComponent()  // Resources
            .deletingLastPathComponent()  // Contents
            .deletingLastPathComponent()  // <app>.app
        guard bundle.pathExtension == "app" else { return nil }
        return bundle
    }

    /// The designated requirement of the bundle at `bundleURL`. An ad-hoc bundle
    /// designates itself by code-directory hash, one per architecture slice, so
    /// this pins the client to the exact build installed alongside the helper.
    static func designatedRequirementText(ofBundleAt bundleURL: URL) -> String? {
        var staticCode: SecStaticCode?
        guard SecStaticCodeCreateWithPath(bundleURL as CFURL, [], &staticCode) == errSecSuccess,
              let staticCode else { return nil }
        var requirement: SecRequirement?
        guard SecCodeCopyDesignatedRequirement(staticCode, [], &requirement) == errSecSuccess,
              let requirement else { return nil }
        var text: CFString?
        guard SecRequirementCopyString(requirement, [], &text) == errSecSuccess,
              let text else { return nil }
        return text as String
    }
}

final class HelperListenerDelegate: NSObject, NSXPCListenerDelegate {
    private let service = HelperService()

    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection connection: NSXPCConnection) -> Bool {
        guard isAuthorized(connection) else {
            listenerLogger.error("Rejected an XPC client that failed the code-signing requirement.")
            return false
        }
        connection.exportedInterface = NSXPCInterface(with: HelperXPCProtocol.self)
        connection.exportedObject = service
        connection.resume()
        return true
    }

    private func isAuthorized(_ connection: NSXPCConnection) -> Bool {
        let attributes = [
            kSecGuestAttributePid as String: NSNumber(value: connection.processIdentifier)
        ] as CFDictionary

        var guestCode: SecCode?
        guard SecCodeCopyGuestWithAttributes(nil, attributes, [], &guestCode) == errSecSuccess,
              let guestCode else { return false }

        // An unsigned release trusts only its installed app, including when a
        // development-signed copy happens to be present on the same Mac.
        guard HelperCodeIdentity.isSelfAdHoc() else {
            return satisfies(guestCode, ClientRequirement.teamAnchored())
        }
        guard let applicationURL = HelperCodeIdentity.hostApplicationURL() else {
            listenerLogger.error("Could not locate the app bundle that ships this ad-hoc signed helper.")
            return false
        }
        guard let designated = HelperCodeIdentity.designatedRequirementText(ofBundleAt: applicationURL),
              let requirement = ClientRequirement.codeHashPinned(designatedRequirement: designated) else {
            listenerLogger.error("Could not read the designated requirement of the app bundle that ships this helper.")
            return false
        }
        guard satisfies(guestCode, requirement) else { return false }

        listenerLogger.info("Accepted an ad-hoc signed client pinned to the app bundle that ships this helper.")
        return true
    }

    private func satisfies(_ code: SecCode, _ requirementText: String) -> Bool {
        var requirement: SecRequirement?
        guard SecRequirementCreateWithString(requirementText as CFString, [], &requirement) == errSecSuccess,
              let requirement else { return false }
        return SecCodeCheckValidity(code, [], requirement) == errSecSuccess
    }
}
