//
//  AuthState.swift
//  pantherapp
//
//  Mirrors Android's data/auth/AuthState.kt.
//

import Foundation

enum AuthState: Equatable {
    case loggedOut
    case authenticating
    case loggedIn(telegramId: Int64)
    case error(message: String)
}
