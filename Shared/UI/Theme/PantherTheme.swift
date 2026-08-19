//
//  PantherTheme.swift
//  pantherapp
//
//  One full set of brand colors — mirrors Android's ui/theme/Color.kt exactly
//  (same hex values, same four palettes: Dark/Light × Classic/Original).
//  Compose uses a CompositionLocal (LocalPantherColors) that swaps per theme;
//  here VpnViewModel.colors resolves the active palette from
//  themeMode/themeStyle, and views read it via @Environment(VpnViewModel.self).
//

import SwiftUI

struct PantherColors {
    let gradientTop: Color
    let gradientMid: Color
    let gradientBottom: Color
    let accent: Color
    let accentMuted: Color
    let glow: Color
    let cardFill: Color
    let cardStroke: Color
    let iconTileFill: Color
    let iconTint: Color
    let textPrimary: Color
    let textSecondary: Color
    let bottomBarFill: Color
    let bottomBarBorder: Color
    let statusGood: Color
    let statusMedium: Color
    let statusPoor: Color
    let surface: Color

    static let dark = PantherColors(
        gradientTop: Color(hex: 0x4A1E8A),
        gradientMid: Color(hex: 0x1E0E38),
        gradientBottom: Color(hex: 0x120722),
        accent: Color(hex: 0xA855F7),
        accentMuted: Color(hex: 0x8B5CF6),
        glow: Color(hex: 0xC084FC),
        cardFill: Color.white.opacity(0.06),
        cardStroke: Color.white.opacity(0.08),
        iconTileFill: Color(hex: 0x7C3AED).opacity(0.25),
        iconTint: Color(hex: 0xC4B5FD),
        textPrimary: .white,
        textSecondary: Color(hex: 0xA794C9),
        bottomBarFill: Color(hex: 0x150A26).opacity(0.95),
        bottomBarBorder: Color.white.opacity(0.06),
        statusGood: Color(hex: 0x34D399),
        statusMedium: Color(hex: 0xFBBF24),
        statusPoor: Color(hex: 0xF87171),
        surface: Color(hex: 0x1A0F30)
    )

    static let light = PantherColors(
        gradientTop: Color(hex: 0xEFE7FE),
        gradientMid: Color(hex: 0xF8F5FE),
        gradientBottom: .white,
        accent: Color(hex: 0x7C3AED),
        accentMuted: Color(hex: 0x9333EA),
        glow: Color(hex: 0xD8B4FE),
        cardFill: Color(hex: 0x120722).opacity(0.045),
        cardStroke: Color(hex: 0x120722).opacity(0.09),
        iconTileFill: Color(hex: 0x7C3AED).opacity(0.12),
        iconTint: Color(hex: 0x7C3AED),
        textPrimary: Color(hex: 0x1B1024),
        textSecondary: Color(hex: 0x6B6280),
        bottomBarFill: Color.white.opacity(0.95),
        bottomBarBorder: Color(hex: 0x120722).opacity(0.08),
        statusGood: Color(hex: 0x059669),
        statusMedium: Color(hex: 0xD97706),
        statusPoor: Color(hex: 0xDC2626),
        surface: .white
    )

    // "Original" style — matches the web dashboard's exact palette
    // (panthervpn.store/dashboard): diagonal near-black gradient, solid
    // dark-purple card fill rather than a translucent white overlay.
    static let originalDark = PantherColors(
        gradientTop: Color(hex: 0x0A0815),
        gradientMid: Color(hex: 0x120D22),
        gradientBottom: Color(hex: 0x050505),
        accent: Color(hex: 0xA855F7),
        accentMuted: Color(hex: 0x8B5CF6),
        glow: Color(hex: 0xC084FC),
        cardFill: Color(hex: 0x120D1F),
        cardStroke: Color(hex: 0xA855F7).opacity(0.2),
        iconTileFill: Color(hex: 0xA855F7).opacity(0.1),
        iconTint: Color(hex: 0xD8B4FE),
        textPrimary: .white,
        textSecondary: Color(hex: 0xC4B5FD).opacity(0.7),
        bottomBarFill: Color(hex: 0x0A0815).opacity(0.95),
        bottomBarBorder: Color(hex: 0xA855F7).opacity(0.12),
        statusGood: Color(hex: 0x34D399),
        statusMedium: Color(hex: 0xFBBF24),
        statusPoor: Color(hex: 0xF87171),
        surface: Color(hex: 0x120D1F)
    )

    static let originalLight = PantherColors(
        gradientTop: Color(hex: 0xF3ECFE),
        gradientMid: Color(hex: 0xFAF7FE),
        gradientBottom: .white,
        accent: Color(hex: 0xA855F7),
        accentMuted: Color(hex: 0x9333EA),
        glow: Color(hex: 0xD8B4FE),
        cardFill: Color(hex: 0xA855F7).opacity(0.06),
        cardStroke: Color(hex: 0xA855F7).opacity(0.18),
        iconTileFill: Color(hex: 0xA855F7).opacity(0.12),
        iconTint: Color(hex: 0xA855F7),
        textPrimary: Color(hex: 0x1B1024),
        textSecondary: Color(hex: 0x6B6280),
        bottomBarFill: Color.white.opacity(0.95),
        bottomBarBorder: Color(hex: 0xA855F7).opacity(0.12),
        statusGood: Color(hex: 0x059669),
        statusMedium: Color(hex: 0xD97706),
        statusPoor: Color(hex: 0xDC2626),
        surface: .white
    )

    static func resolve(mode: ThemeMode, style: ThemeStyle, systemIsDark: Bool) -> PantherColors {
        let isDark = mode == .dark || (mode == .system && systemIsDark)
        switch (isDark, style) {
        case (true, .classic): return .dark
        case (false, .classic): return .light
        case (true, .original): return .originalDark
        case (false, .original): return .originalLight
        }
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}
