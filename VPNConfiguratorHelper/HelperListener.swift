import Foundation
import OSLog
import Security

private let listenerLogger = Logger(
    subsystem: "com.klianos.VPNConfigurator.helper",
    category: "XPCAuthorization"
)

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

        let requirementText = "anchor apple generic and certificate leaf[subject.OU] = \"\(HelperConstants.signingTeamIdentifier)\" and identifier \"\(HelperConstants.mainAppIdentifier)\""
        var requirement: SecRequirement?
        guard SecRequirementCreateWithString(requirementText as CFString, [], &requirement) == errSecSuccess,
              let requirement else { return false }
        return SecCodeCheckValidity(guestCode, [], requirement) == errSecSuccess
    }
}
