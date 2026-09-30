import Foundation
@preconcurrency import SystemConfiguration

/// Installs profile-scoped split DNS through the SystemConfiguration dynamic store.
///
/// Entries live under `State:/Network/Service/<id>/DNS`, which configd merges into
/// the system resolver configuration. configd drops every key a client wrote when
/// that client's store session ends, so a helper crash cannot leave stale DNS rules.
enum ResolverManager {
    private static let servicePrefix = "gr.klianos.bifrost."
    private nonisolated(unsafe) static let store = SCDynamicStoreCreate(nil, "gr.klianos.bifrost.helper" as CFString, nil, nil)
    private static let lock = NSLock()

    /// Returns the installed store key, or nil when the profile defines no split DNS.
    static func install(profileID: String, servers: [String], domains: [String]) throws -> String? {
        guard !domains.isEmpty else { return nil }
        lock.lock()
        defer { lock.unlock() }
        guard let store else { throw HelperFailure.invalidDNS("the system configuration store is unavailable.") }

        let key = key(for: profileID)
        if let conflict = conflictingDomain(among: domains, excluding: key, in: store) {
            throw HelperFailure.resolverConflict(conflict)
        }

        let value: [String: Any] = [
            "ServerAddresses": servers,
            "SupplementalMatchDomains": domains
        ]
        guard SCDynamicStoreSetValue(store, key as CFString, value as CFDictionary) else {
            throw HelperFailure.invalidDNS("the resolver rules could not be written to the system configuration store.")
        }
        return key
    }

    static func remove(_ key: String?, ownedBy profileID: String) {
        guard let key, key == Self.key(for: profileID) else { return }
        lock.lock()
        defer { lock.unlock() }
        if let store { SCDynamicStoreRemoveValue(store, key as CFString) }
    }

    static func key(for profileID: String) -> String {
        "State:/Network/Service/\(servicePrefix)\(profileID)/DNS"
    }

    /// Another profile of this app already routes one of the requested domains.
    private static func conflictingDomain(among domains: [String], excluding ownKey: String, in store: SCDynamicStore) -> String? {
        let pattern = "State:/Network/Service/\(servicePrefix).*/DNS" as CFString
        guard let keys = SCDynamicStoreCopyKeyList(store, pattern) as? [String] else { return nil }
        let requested = Set(domains.map { $0.lowercased() })
        for other in keys where other != ownKey {
            guard let value = SCDynamicStoreCopyValue(store, other as CFString) as? [String: Any],
                  let existing = value["SupplementalMatchDomains"] as? [String] else { continue }
            if let overlap = existing.first(where: { requested.contains($0.lowercased()) }) { return overlap }
        }
        return nil
    }
}
