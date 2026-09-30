#!/usr/bin/env swift
// Manages the Ed25519 key that signs Bifrost update images. The private key lives
// in the login Keychain or, for CI, the BIFROST_SIGNING_KEY environment variable
// (never in the repository); the app pins the public key.
//
//   swift script/release_signing.swift generate          create the key, print the public key
//   swift script/release_signing.swift public            print the public key
//   swift script/release_signing.swift sign <file>       write <file>.sig
//   swift script/release_signing.swift export-private    print the private key for a backup
//
// Losing the private key means installed copies can never verify another update.
import CryptoKit
import Foundation
import Security

let service = "gr.klianos.bifrost.update-signing"
let account = "ed25519-private-key"

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data("error: \(message)\n".utf8))
    exit(1)
}

func loadKey() -> Curve25519.Signing.PrivateKey {
    // CI supplies the key from a secret instead of the Keychain.
    if let encoded = ProcessInfo.processInfo.environment["BIFROST_SIGNING_KEY"], !encoded.isEmpty {
        guard let data = Data(base64Encoded: encoded.trimmingCharacters(in: .whitespacesAndNewlines)),
              let key = try? Curve25519.Signing.PrivateKey(rawRepresentation: data) else {
            fail("BIFROST_SIGNING_KEY is not a valid base64 Ed25519 private key")
        }
        return key
    }
    let query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: service,
        kSecAttrAccount as String: account,
        kSecReturnData as String: true,
    ]
    var item: CFTypeRef?
    let status = SecItemCopyMatching(query as CFDictionary, &item)
    guard status == errSecSuccess, let data = item as? Data,
          let key = try? Curve25519.Signing.PrivateKey(rawRepresentation: data) else {
        fail("no signing key in the login Keychain (status \(status)). Run `generate` first.")
    }
    return key
}

let arguments = CommandLine.arguments.dropFirst()
switch arguments.first {
case "generate":
    let key = Curve25519.Signing.PrivateKey()
    let attributes: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: service,
        kSecAttrAccount as String: account,
        kSecAttrLabel as String: "Bifrost update signing key",
        kSecValueData as String: key.rawRepresentation,
    ]
    let status = SecItemAdd(attributes as CFDictionary, nil)
    guard status == errSecSuccess else {
        fail(status == errSecDuplicateItem
            ? "a signing key already exists. Refusing to overwrite it."
            : "could not store the key (status \(status))")
    }
    print(key.publicKey.rawRepresentation.base64EncodedString())
case "public":
    print(loadKey().publicKey.rawRepresentation.base64EncodedString())
case "sign":
    guard arguments.count == 2, let path = arguments.dropFirst().first,
          let data = FileManager.default.contents(atPath: path) else { fail("usage: sign <file>") }
    guard let signature = try? loadKey().signature(for: data) else { fail("signing failed") }
    let output = path + ".sig"
    try Data((signature.base64EncodedString() + "\n").utf8).write(to: URL(fileURLWithPath: output))
    print(output)
case "export-private":
    print(loadKey().rawRepresentation.base64EncodedString())
default:
    fail("usage: release_signing.swift generate | public | sign <file> | export-private")
}
