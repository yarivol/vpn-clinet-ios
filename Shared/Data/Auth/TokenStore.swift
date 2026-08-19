//
//  TokenStore.swift
//  pantherapp
//
//  Keychain-backed storage for the cabinet JWT — survives app restarts, not
//  readable by other apps. Mirrors Android's data/auth/TokenStore.kt.
//

import Foundation

@Observable
final class TokenStore {
    private let keychain = KeychainStore(service: "com.panthervpn.pantherapp.auth")
    private static let accessTokenKey = "access_token"
    private static let telegramIdKey = "telegram_id"

    private(set) var accessToken: String?

    var telegramId: Int64? {
        keychain.get(Self.telegramIdKey).flatMap { Int64($0) }
    }

    init() {
        accessToken = keychain.get(Self.accessTokenKey)
    }

    func save(accessToken: String, telegramId: Int64) {
        keychain.set(Self.accessTokenKey, value: accessToken)
        keychain.set(Self.telegramIdKey, value: String(telegramId))
        self.accessToken = accessToken
    }

    func clear() {
        keychain.deleteAll()
        accessToken = nil
    }
}
