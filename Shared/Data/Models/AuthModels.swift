//
//  AuthModels.swift
//  pantherapp
//
//  Wire models for /auth/magic-link and /auth/subscription-link — mirrors
//  Android's data/remote/dto/AuthDtos.kt exactly (same backend, same JSON shape).
//

import Foundation

struct MagicLinkRequest: Encodable {
    let token: String
}

struct SubscriptionLinkRequest: Encodable {
    let link: String
}

struct AuthSessionResponse: Decodable {
    let accessToken: String
    let userId: Int64
    let telegramId: Int64
}
