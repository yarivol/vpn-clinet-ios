//
//  pantherappApp.swift
//  pantherapp
//
//  App entry point — constructs the dependency graph (mirrors Android's
//  VpnViewModel constructor defaults: APIClient/TokenStore/DeviceIdStore/
//  AuthRepository/CabinetRepository) and injects the single shared
//  VpnViewModel via .environment(), same "one ViewModel for the whole app"
//  shape as Android. Also handles the panthervpn://login?token=... deep link
//  from the bot's "Открыть приложение" button — mirrors MainActivity.kt's
//  handleIntent().
//

import SwiftUI

@main
struct pantherappApp: App {
    @State private var viewModel: VpnViewModel

    init() {
        let tokenStore = TokenStore()
        let deviceIdStore = DeviceIdStore()
        let authRepository = AuthRepository(api: APIClient.shared, tokenStore: tokenStore)

        let versionName = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let versionCode = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        let cabinetRepository = CabinetRepository(
            api: APIClient.shared,
            hwid: deviceIdStore.deviceId,
            platform: "ios",
            osVersion: UIDevice.current.systemVersion,
            deviceModel: Self.deviceModelIdentifier(),
            userAgent: "PantherApp/\(versionName)/ios/\(versionCode)"
        )

        _viewModel = State(initialValue: VpnViewModel(
            authRepository: authRepository,
            cabinetRepository: cabinetRepository
        ))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(viewModel)
                .onOpenURL { url in
                    guard url.scheme == "panthervpn", url.host == "login",
                          let token = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                            .queryItems?.first(where: { $0.name == "token" })?.value
                    else { return }
                    Task { await viewModel.handleMagicLinkToken(token) }
                }
        }
    }

    /// Raw hardware identifier (e.g. "iPhone15,2") rather than a
    /// marketing name ("iPhone 14 Pro") — good enough for the HWID device
    /// list to tell devices apart; mapping to marketing names is a
    /// nice-to-have, not needed for that purpose.
    private static func deviceModelIdentifier() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)
        return withUnsafePointer(to: &systemInfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) { ptr in
                String(cString: ptr)
            }
        }
    }
}
