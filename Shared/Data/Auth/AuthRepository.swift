//
//  AuthRepository.swift
//  pantherapp
//
//  Redeems the one-time magic-link token minted by the bot's "📱 Открыть в
//  приложении" button against the same /auth/magic-link endpoint the web
//  cabinet uses. Also supports pasting an existing subscription link directly
//  — for users who installed the app straight from the store instead of going
//  through the bot. Mirrors Android's data/auth/AuthRepository.kt.
//

import Foundation

final class AuthRepository {
    private let api: APIClient
    private let tokenStore: TokenStore

    init(api: APIClient, tokenStore: TokenStore) {
        self.api = api
        self.tokenStore = tokenStore
    }

    var accessToken: String? { tokenStore.accessToken }
    var telegramId: Int64? { tokenStore.telegramId }

    func loginWithMagicLink(token: String) async throws {
        let session = try await api.exchangeMagicLink(token: token)
        tokenStore.save(accessToken: session.accessToken, telegramId: session.telegramId)
    }

    func loginWithSubscriptionLink(link: String) async throws {
        let session = try await api.exchangeSubscriptionLink(link: link)
        tokenStore.save(accessToken: session.accessToken, telegramId: session.telegramId)
    }

    func logout() {
        tokenStore.clear()
    }

    func currentAccessToken() -> String? {
        tokenStore.accessToken
    }
}
