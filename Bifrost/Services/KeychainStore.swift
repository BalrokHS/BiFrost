import Foundation
import Security

enum KeychainError: LocalizedError {
    case unexpectedStatus(OSStatus)
    case invalidPasswordData

    var errorDescription: String? {
        switch self {
        case .unexpectedStatus(let status):
            let message = SecCopyErrorMessageString(status, nil) as String? ?? "Unknown Keychain error"
            return "Keychain error: \(message) (\(status))"
        case .invalidPasswordData:
            return "The saved password could not be decoded."
        }
    }
}

protocol VPNPasswordStore {
    func password(for profileID: VPNProfile.ID) throws -> String?
    func containsPassword(for profileID: VPNProfile.ID) throws -> Bool
    func setPassword(_ password: String, for profileID: VPNProfile.ID) throws
    func removePassword(for profileID: VPNProfile.ID) throws
}

struct KeychainStore: VPNPasswordStore, Sendable {
    private let service = "gr.klianos.bifrost.credentials"

    func password(for profileID: VPNProfile.ID) throws -> String? {
        var query = baseQuery(profileID: profileID)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else { throw KeychainError.unexpectedStatus(status) }
        guard let data = result as? Data, let password = String(data: data, encoding: .utf8) else {
            throw KeychainError.invalidPasswordData
        }
        return password
    }

    func containsPassword(for profileID: VPNProfile.ID) throws -> Bool {
        try password(for: profileID) != nil
    }

    func setPassword(_ password: String, for profileID: VPNProfile.ID) throws {
        let data = Data(password.utf8)
        let query = baseQuery(profileID: profileID)
        let attributes: [String: Any] = [kSecValueData as String: data]
        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)

        if updateStatus == errSecItemNotFound {
            var newItem = query
            newItem[kSecValueData as String] = data
            newItem[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            let addStatus = SecItemAdd(newItem as CFDictionary, nil)
            guard addStatus == errSecSuccess else { throw KeychainError.unexpectedStatus(addStatus) }
        } else if updateStatus != errSecSuccess {
            throw KeychainError.unexpectedStatus(updateStatus)
        }
    }

    func removePassword(for profileID: VPNProfile.ID) throws {
        let status = SecItemDelete(baseQuery(profileID: profileID) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unexpectedStatus(status)
        }
    }

    private func baseQuery(profileID: VPNProfile.ID) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: profileID.uuidString
        ]
    }
}
