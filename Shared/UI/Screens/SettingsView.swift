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

                NavigationLink(destination: LogsView()) {
                    SettingRow(labelKey: "settings_logs", value: "", showChevronOverride: true)
                }
                .buttonStyle(.plain)

                SettingRow(labelKey: "settings_about", value: String(format: String(localized: "settings_version_format", locale: locale), appVersion))

                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 4)
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $showLanguageDialog) {
            OptionPickerSheet(
                titleKey: "settings_choose_language",
                options: AppLanguage.allCases,
                label: { label(for: $0) },
                isSelected: { $0 == viewModel.language },
                onSelect: { viewModel.setLanguage($0) }
            )
        }
        .sheet(isPresented: $showStyleDialog) {
            OptionPickerSheet(
                titleKey: "settings_choose_style",
                options: ThemeStyle.allCases,
                label: { label(for: $0) },
                isSelected: { $0 == viewModel.themeStyle },
                onSelect: { viewModel.setThemeStyle($0) }
            )
        }
        .sheet(isPresented: $showThemeDialog) {
            OptionPickerSheet(
                titleKey: "settings_choose_theme",
                options: ThemeMode.allCases,
                label: { label(for: $0) },
                isSelected: { $0 == viewModel.themeMode },
                onSelect: { viewModel.setThemeMode($0) }
            )
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
    // For rows wrapped in an outer NavigationLink (e.g. Logs below): keep
    // onTap nil so PantherCard doesn't attach its own competing tap gesture
    // (same gesture-shadowing issue fixed elsewhere), but still show the
    // chevron affordance.
    var showChevronOverride: Bool = false

    @Environment(\.pantherColors) private var colors

    var body: some View {
        PantherCard(onTap: onTap) {
            HStack {
                Text(labelKey)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(colors.textPrimary)
                Spacer()
                if !value.isEmpty {
                    Text(value)
                        .font(.footnote)
                        .foregroundStyle(colors.textSecondary)
                }
                if onTap != nil || showChevronOverride {
                    Image(systemName: "chevron.right")
                        .font(.footnote)
                        .foregroundStyle(colors.textSecondary)
                }
            }
        }
    }
}
