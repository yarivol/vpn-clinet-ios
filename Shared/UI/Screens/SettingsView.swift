//
//  SettingsView.swift
//  pantherapp
//
//  Mirrors Android's ui/screens/settings/SettingsScreen.kt — language, style,
//  theme, about. No battery-optimization row: iOS has no per-app equivalent
//  of Android's "exempt from battery optimization" setting (Low Power Mode
//  is user/system-wide, not something an app can request exemption from),
//  so that row is simply dropped rather than faked.
//

import SwiftUI

struct SettingsView: View {
    @Environment(VpnViewModel.self) private var viewModel
    @Environment(\.pantherColors) private var colors
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale

    @State private var showLanguageDialog = false
    @State private var showStyleDialog = false
    @State private var showThemeDialog = false

    var body: some View {
        GradientBackground {
            VStack(alignment: .leading, spacing: 16) {
                header
                Text("settings_title")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(colors.textPrimary)

                SettingRow(labelKey: "settings_language", value: languageLabel) { showLanguageDialog = true }
                SettingRow(labelKey: "settings_style", value: styleLabel) { showStyleDialog = true }
                SettingRow(labelKey: "settings_theme", value: themeLabel) { showThemeDialog = true }
                SettingRow(labelKey: "settings_about", value: String(format: String(localized: "settings_version_format", locale: locale), appVersion))

                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 4)
        }
        .navigationBarHidden(true)
        .confirmationDialog("settings_choose_language", isPresented: $showLanguageDialog, titleVisibility: .visible) {
            ForEach(AppLanguage.allCases, id: \.self) { option in
                Button(label(for: option)) { viewModel.setLanguage(option) }
            }
        }
        .confirmationDialog("settings_choose_style", isPresented: $showStyleDialog, titleVisibility: .visible) {
            ForEach(ThemeStyle.allCases, id: \.self) { option in
                Button(label(for: option)) { viewModel.setThemeStyle(option) }
            }
        }
        .confirmationDialog("settings_choose_theme", isPresented: $showThemeDialog, titleVisibility: .visible) {
            ForEach(ThemeMode.allCases, id: \.self) { option in
                Button(label(for: option)) { viewModel.setThemeMode(option) }
            }
        }
    }

    private var header: some View {
        HStack {
            IconTile(systemImage: "chevron.left", size: 52, cornerRadius: 16, containerColor: colors.cardFill, contentColor: colors.textPrimary) {
                dismiss()
            }
            .accessibilityLabel(Text("action_back"))
            .accessibilityAddTraits(.isButton)
            Spacer()
        }
        .padding(.top, 4)
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    private var languageLabel: String { label(for: viewModel.language) }
    private var styleLabel: String { label(for: viewModel.themeStyle) }
    private var themeLabel: String { label(for: viewModel.themeMode) }

    private func label(for language: AppLanguage) -> String {
        let key: String
        switch language {
        case .system: key = "lang_system"
        case .russian: key = "lang_russian"
        case .english: key = "lang_english"
        }
        return String(localized: String.LocalizationValue(key), locale: locale)
    }

    private func label(for style: ThemeStyle) -> String {
        let key = style == .classic ? "style_classic" : "style_original"
        return String(localized: String.LocalizationValue(key), locale: locale)
    }

    private func label(for mode: ThemeMode) -> String {
        let key: String
        switch mode {
        case .dark: key = "theme_dark"
        case .light: key = "theme_light"
        case .system: key = "theme_system"
        }
        return String(localized: String.LocalizationValue(key), locale: locale)
    }
}

private struct SettingRow: View {
    let labelKey: LocalizedStringKey
    let value: String
    var onTap: (() -> Void)?

    @Environment(\.pantherColors) private var colors

    var body: some View {
        PantherCard(onTap: onTap) {
            HStack {
                Text(labelKey)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(colors.textPrimary)
                Spacer()
                Text(value)
                    .font(.footnote)
                    .foregroundStyle(colors.textSecondary)
                if onTap != nil {
                    Image(systemName: "chevron.right")
                        .font(.footnote)
                        .foregroundStyle(colors.textSecondary)
                }
            }
        }
    }
}
