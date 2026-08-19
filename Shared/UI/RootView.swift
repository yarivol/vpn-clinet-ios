//
//  RootView.swift
//  pantherapp
//
//  Auth-gates between AuthRequiredView and the main tab UI — mirrors
//  Android's PantherNavGraph.kt's top-level branch on authState. Also
//  resolves and injects the active PantherColors palette (see
//  PantherColorsEnvironment.swift) from the ViewModel's themeMode/themeStyle
//  + the real @Environment(\.colorScheme), which is only reliable to read
//  from inside a View. Surfaces one-shot events (login outcome, VPN errors)
//  as a toast banner — mirrors MainActivity.kt's Toast.makeText(...) calls.
//

import SwiftUI

struct RootView: View {
    @Environment(VpnViewModel.self) private var viewModel
    @Environment(\.colorScheme) private var colorScheme

    @State private var toast: ToastMessage?

    var body: some View {
        Group {
            if case .loggedIn = viewModel.authState {
                MainTabView()
            } else {
                AuthRequiredView()
            }
        }
        .environment(\.pantherColors, resolvedColors)
        .environment(\.locale, resolvedLocale)
        .toastOverlay(message: $toast)
        .task { await handleAuthEvents() }
        .task { await handleDashboardRefreshEvents() }
        .task { await handleVpnErrorEvents() }
    }

    private var resolvedColors: PantherColors {
        .resolve(mode: viewModel.themeMode, style: viewModel.themeStyle, systemIsDark: colorScheme == .dark)
    }

    /// `.system` keeps whatever locale SwiftUI would already resolve
    /// (device language) by not overriding it at all; the two explicit
    /// options force a specific `Localizable.strings` table regardless of
    /// device settings — SwiftUI's supported mechanism for in-app language
    /// override, since Text/String(localized:) lookups consult the
    /// environment's locale.
    private var resolvedLocale: Locale {
        switch viewModel.language {
        case .system: return Locale.autoupdatingCurrent
        case .russian: return Locale(identifier: "ru")
        case .english: return Locale(identifier: "en")
        }
    }

    private func handleAuthEvents() async {
        for await event in viewModel.authEvents.stream {
            switch event {
            case .loginSuccess:
                toast = ToastMessage(text: String(localized: "toast_login_success", locale: resolvedLocale))
            case .loginFailed:
                toast = ToastMessage(text: String(localized: "toast_login_failed", locale: resolvedLocale), isError: true)
            }
        }
    }

    private func handleDashboardRefreshEvents() async {
        for await event in viewModel.dashboardRefreshEvents.stream {
            switch event {
            case .success:
                toast = ToastMessage(text: String(localized: "toast_subscription_refreshed", locale: resolvedLocale))
            case .failed:
                toast = ToastMessage(text: String(localized: "toast_subscription_refresh_failed", locale: resolvedLocale), isError: true)
            }
        }
    }

    /// `reasonKey` (from VpnManager.reportError) already IS a Localizable.strings
    /// key ("vpn_error_config_fetch_failed" etc.) — any unrecognized key falls
    /// back to a generic message rather than surfacing a raw untranslated key.
    private func handleVpnErrorEvents() async {
        let knownKeys: Set<String> = ["vpn_error_config_fetch_failed", "vpn_error_permission_denied", "vpn_error_tunnel_failed"]
        for await reasonKey in viewModel.vpnErrorEvents {
            let key = knownKeys.contains(reasonKey) ? reasonKey : "vpn_error_generic"
            toast = ToastMessage(text: String(localized: String.LocalizationValue(key), locale: resolvedLocale), isError: true)
        }
    }
}
