//
//  KeychainStore.swift
//  pantherapp
//
//  Thin wrapper over the Keychain Services API — the iOS equivalent of
//  Android's EncryptedSharedPreferences (TokenStore.kt, DeviceIdStore.kt both
//  use one of these on Android; here they share this one Keychain helper).
//  Values are namespaced by `service` so TokenStore and DeviceIdStore don't
//  collide even though both use simple string keys.
//

import Foundation
import Security

struct KeychainStore {
    let service: String

    func get(_ key: String) -> String? {
        var query = baseQuery(key)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    func set(_ key: String, value: String) {
        let data = Data(value.utf8)
        var query = baseQuery(key)
        if SecItemCopyMatching(query as CFDictionary, nil) == errSecSuccess {
            SecItemUpdate(query as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        } else {
            query[kSecValueData as String] = data
            SecItemAdd(query as CFDictionary, nil)
        }
    }

    func delete(_ key: String) {
        SecItemDelete(baseQuery(key) as CFDictionary)
    }

    func deleteAll() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
        ]
        SecItemDelete(query as CFDictionary)
    }

    private func baseQuery(_ key: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
        ]
    }
}
