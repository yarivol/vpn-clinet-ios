//
//  SmallEnums.swift
//  pantherapp
//
//  Small state enums — mirror Android's data/model/ConnectionState.kt,
//  ThemeMode.kt, ThemeStyle.kt, AppLanguage.kt, ProtectionSettings.kt.
//

import Foundation

enum ConnectionState: Equatable {
    case disconnected
    case connecting
    case connected
}

enum ThemeMode: CaseIterable, Hashable {
    case dark
    case light
    case system
}

/// Color-scheme variant, independent of ThemeMode (dark/light) — see settings "Стиль".
enum ThemeStyle: CaseIterable, Hashable {
    case classic
    case original
}

enum AppLanguage: CaseIterable, Hashable {
    case system
    case russian
    case english

    var languageTag: String {
        switch self {
        case .system: return ""
        case .russian: return "ru"
        case .english: return "en"
        }
    }
}

enum ProtectionToggleType: Hashable {
    case killSwitch
    case adBlock
    case trackerBlock
}

struct ProtectionSettings {
    // Cosmetic-only for now (no real backend), same as Android — default off,
    // matching the "по умолчанию выключай эти пункты" fix applied on Android.
    var killSwitch: Bool = false
    var adBlock: Bool = false
    var trackerBlock: Bool = false

    func value(_ type: ProtectionToggleType) -> Bool {
        switch type {
        case .killSwitch: return killSwitch
        case .adBlock: return adBlock
        case .trackerBlock: return trackerBlock
        }
    }

    mutating func setValue(_ type: ProtectionToggleType, _ enabled: Bool) {
        switch type {
        case .killSwitch: killSwitch = enabled
        case .adBlock: adBlock = enabled
        case .trackerBlock: trackerBlock = enabled
        }
    }
}
