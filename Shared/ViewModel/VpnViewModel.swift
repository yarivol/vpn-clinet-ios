//
//  VpnViewModel.swift
//  pantherapp
//
//  Single shared, app-wide observable object backing every screen so the
//  connection/server/protection state stays consistent everywhere — mirrors
//  Android's ui/viewmodel/VpnViewModel.kt closely. Platform differences worth
//  knowing:
//  - No separate "check VPN permission, then launch a consent Intent" step
//    like Android's VpnService.prepare(): on iOS, NETunnelProviderManager's
//    saveToPreferences() (inside VpnManager.ensureManager()) triggers the
//    system's "Add VPN Configuration" consent sheet itself the first time,
//    and throws if the user declines — surfaced through the same error-event
//    path as any other connect failure, so there's no separate
//    vpnPermissionRequest event here.
//  - StateFlow → plain @Observable `var` properties. SharedFlow (one-shot
//    events: auth outcome, dashboard refresh feedback, VPN errors) →
//    EventEmitter<T> (see Shared/Support/EventEmitter.swift).
//

import Foundation
import Observation
import UIKit

enum AuthUiEvent {
    case loginSuccess
    case loginFailed
}

enum DashboardRefreshEvent {
    case success
    case failed
}

private let dashboardAutoRefreshIntervalSeconds: UInt64 = 60 * 60

// Every mutating method here does real async work (URLSession requests,
// Keychain calls via TokenStore) whose `await` can resume on a background
// executor - without @MainActor, state mutations after that resume point
// (subscription, servers, connectionState, etc., all read directly by
// SwiftUI views) wouldn't be guaranteed to happen on the main thread.
// @MainActor makes Swift insert the hop back automatically on every await,
// matching Apple's own guidance for @Observable view models doing async work.
@MainActor
@Observable
final class VpnViewModel {
    private let authRepository: AuthRepository
    private let cabinetRepository: CabinetRepository
    private let vpnManager: VpnManager

    // MARK: - Observable state

    private(set) var authState: AuthState
    private(set) var subscription: Subscription?
    private(set) var trafficStats: TrafficStats?
    private(set) var servers: [VpnServer] = []
    private(set) var isLoadingDashboard = false
    // serverId -> ping ms; a present key with nil value means "pinged, but
    // timed out/unreachable" (distinct from an absent key, "never pinged").
    private(set) var serverPings: [String: Int?] = [:]
    private(set) var isPinging = false
    private(set) var devices: [DeviceDto] = []
    private(set) var isLoadingDevices = false

    private var selectedServerId: String?
    var selectedServer: VpnServer? {
        servers.first { $0.id == selectedServerId } ?? servers.first
    }

    // Protection toggles have no real backend yet — plain local state, same
    // as Android's MockVpnRepository placeholder. Theme/style/language ARE
    // persisted (UserDefaults, see loadThemeMode/loadThemeStyle/loadLanguage
    // and the set* methods below) - these used to reset every launch, fixed
    // after real-device testing surfaced it.
    var protectionSettings = ProtectionSettings()
    var themeMode: ThemeMode
    var themeStyle: ThemeStyle
    var language: AppLanguage

    var connectionState: ConnectionState { vpnManager.connectionState }
    var currentDeviceHwid: String { cabinetRepository.currentDeviceHwid }

    // MARK: - One-shot events

    let authEvents = EventEmitter<AuthUiEvent>()
    let dashboardRefreshEvents = EventEmitter<DashboardRefreshEvent>()
    var vpnErrorEvents: AsyncStream<String> { vpnManager.errorEvents.stream }

    // nonisolated(unsafe): deinit isn't guaranteed to run on the main actor
    // even for a @MainActor class (deallocation can happen from whatever
    // thread drops the last reference), so deinit can't touch a normal
    // main-actor-isolated property. Safe here because Task.cancel() is
    // itself thread-safe/idempotent - this property is never mutated
    // concurrently with the cancel, only read-then-cancelled.
    nonisolated(unsafe) private var hourlyRefreshTask: Task<Void, Never>?

    init(
        authRepository: AuthRepository,
        cabinetRepository: CabinetRepository,
        vpnManager: VpnManager = .shared
    ) {
        self.authRepository = authRepository
        self.cabinetRepository = cabinetRepository
        self.vpnManager = vpnManager

        if let telegramId = authRepository.telegramId, authRepository.accessToken != nil {
            authState = .loggedIn(telegramId: telegramId)
        } else {
            authState = .loggedOut
        }

        // Falls back to light/original (unless the phone itself is in dark
        // mode) only on first launch, when nothing's been saved yet -
        // otherwise restores whatever the user last picked in Settings.
        // Mirrors the same fix applied on Android.
        // NOTE: this ViewModel is constructed before any SwiftUI view has
        // rendered, so UITraitCollection.current may not yet reflect the
        // real system appearance on every iOS version — once the App/root
        // View exists (UI phase), consider re-deriving this from
        // @Environment(\.colorScheme) there instead, which is guaranteed
        // accurate, and calling setThemeMode/setThemeStyle from a
        // .task { } / .onAppear on first launch if still unset.
        let systemIsDark = UITraitCollection.current.userInterfaceStyle == .dark
        themeMode = Self.loadThemeMode(systemIsDark: systemIsDark)
        themeStyle = Self.loadThemeStyle(systemIsDark: systemIsDark)
        language = Self.loadLanguage()

        APIClient.shared.tokenProvider = { [authRepository] in authRepository.currentAccessToken() }

        if case .loggedIn = authState {
            Task { await loadDashboard() }
        }
        startHourlyAutoRefresh()
    }

    deinit {
        hourlyRefreshTask?.cancel()
    }

    // MARK: - Auth

    func handleMagicLinkToken(_ token: String) async {
        authState = .authenticating
        do {
            try await authRepository.loginWithMagicLink(token: token)
            authState = .loggedIn(telegramId: authRepository.telegramId ?? -1)
            AppLogger.log("Login succeeded (magic link)")
            authEvents.emit(.loginSuccess)
            await loadDashboard()
        } catch {
            authState = .error(message: error.localizedDescription)
            AppLogger.log("Login failed (magic link): \(error.localizedDescription)")
            authEvents.emit(.loginFailed)
        }
    }

    func handleSubscriptionLink(_ link: String) async {
        authState = .authenticating
        do {
            try await authRepository.loginWithSubscriptionLink(link: link)
            authState = .loggedIn(telegramId: authRepository.telegramId ?? -1)
            AppLogger.log("Login succeeded (subscription link)")
            authEvents.emit(.loginSuccess)
            await loadDashboard()
        } catch {
            authState = .error(message: error.localizedDescription)
            AppLogger.log("Login failed (subscription link): \(error.localizedDescription)")
            authEvents.emit(.loginFailed)
        }
    }

    func logout() async {
        // Must run before authRepository.logout() clears the access token —
        // the /devices/remove call needs it. Best-effort: CabinetRepository
        // swallows failures internally so a Remnawave hiccup never blocks
        // logging out locally.
        await cabinetRepository.removeCurrentDevice()
        authRepository.logout()
        authState = .loggedOut
        subscription = nil
        trafficStats = nil
        servers = []
        AppLogger.log("Logged out")
    }

    // MARK: - Dashboard

    /// Re-fetches subscription/traffic/servers from the cabinet API. Safe to
    /// call anytime. `showFeedback` emits a one-shot success/failure event
    /// via `dashboardRefreshEvents` — only for an explicit user-tapped
    /// refresh, not the initial/silent loads (app open, hourly auto-refresh),
    /// where that would just be noise.
    func loadDashboard(showFeedback: Bool = false) async {
        isLoadingDashboard = true
        defer { isLoadingDashboard = false }

        if let me = await cabinetRepository.fetchMe() {
            subscription = cabinetRepository.toSubscription(me)
            trafficStats = await cabinetRepository.fetchTrafficStats(me)
        }

        // nil means the fetch failed — keep whatever server list we already
        // have rather than clearing it to empty (a dropped connection
        // shouldn't make an already-loaded server list disappear).
        if let fetched = await cabinetRepository.fetchServers() {
            servers = fetched
            if showFeedback { dashboardRefreshEvents.emit(.success) }
        } else if showFeedback {
            dashboardRefreshEvents.emit(.failed)
        }

        if selectedServerId == nil {
            // Default to Germany rather than the config's first entry — see
            // Android's identical comment for why (broken/non-standard-port
            // "Авто" defaults aside, this just picks a sane starting point).
            selectedServerId = servers.first { $0.isOnline && $0.name.contains("Германия") }?.id
                ?? servers.first { $0.isOnline }?.id
                ?? servers.first?.id
        }
    }

    // MARK: - Ping / optimal server

    /// Pings every server with a known host/port in parallel (TCP connect
    /// time — see ServerPinger) and merges the results into `serverPings`.
    func pingAllServers() async {
        guard !isPinging else { return }
        isPinging = true
        defer { isPinging = false }
        _ = await measureAllPings()
    }

    /// "Auto-select": measures every real server and picks the fastest
    /// reachable one, then selects it.
    func selectOptimalServer() async {
        guard !isPinging else { return }
        isPinging = true
        let results = await measureAllPings()
        isPinging = false
        let fastest = results.compactMap { key, value in value.map { (key, $0) } }
            .min { $0.1 < $1.1 }?.0
        if let fastest {
            await selectServer(fastest)
        }
    }

    private func measureAllPings() async -> [String: Int?] {
        let targets = servers.filter { $0.host != nil && $0.port != nil }
        let results = await withTaskGroup(of: (String, Int?).self) { group -> [String: Int?] in
            for server in targets {
                group.addTask {
                    let ms = await ServerPinger.ping(host: server.host!, port: server.port!)
                    return (server.id, ms)
                }
            }
            var collected: [String: Int?] = [:]
            for await (id, ms) in group {
                collected.updateValue(ms, forKey: id)
            }
            return collected
        }
        for (id, ms) in results {
            serverPings.updateValue(ms, forKey: id)
        }
        return results
    }

    // Keeps subscription/server data reasonably fresh without the user
    // having to remember to pull-to-refresh — silent (no toast), same as the
    // initial load.
    private func startHourlyAutoRefresh() {
        hourlyRefreshTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: dashboardAutoRefreshIntervalSeconds * 1_000_000_000)
                guard let self, !Task.isCancelled else { return }
                if case .loggedIn = self.authState {
                    await self.loadDashboard()
                }
            }
        }
    }

    // MARK: - Devices

    func loadDevices() async {
        isLoadingDevices = true
        devices = await cabinetRepository.fetchDevices()
        isLoadingDevices = false
    }

    func removeDevice(_ hwid: String) async {
        if await cabinetRepository.removeDevice(hwid) {
            devices.removeAll { $0.hwid == hwid }
        }
    }

    // MARK: - Connection

    func toggleConnection() async {
        switch connectionState {
        case .connected:
            vpnManager.disconnect()
        case .disconnected:
            await connectToSelectedServer()
        case .connecting:
            break
        }
    }

    // Fetches a fresh server list (never cached — picks up link rotation via
    // the bot's "Пересоздать адрес подписки" immediately) and connects using
    // whichever server is currently selected. Each server's own config
    // (VpnServer.rawConfig) is a fully standalone, ready-to-run Xray config —
    // there's no shared selector to switch on a running tunnel, so picking
    // the right one BEFORE connecting replaces the old post-connect
    // live-switch entirely.
    private func connectToSelectedServer() async {
        if let fetched = await cabinetRepository.fetchServers() {
            servers = fetched
        }
        let target = servers.first { $0.id == selectedServerId }
            ?? servers.first { $0.isOnline && $0.name.contains("Германия") }
            ?? servers.first { $0.isOnline }
            ?? servers.first

        guard let target, let config = target.rawConfig, !config.isEmpty else {
            AppLogger.log("Connect aborted: no usable config for selected server")
            vpnManager.reportError("vpn_error_config_fetch_failed")
            return
        }
        selectedServerId = target.id
        AppLogger.log("Connecting to \(target.name)")
        await vpnManager.connect(configJson: config, serverName: target.name)
    }

    func selectServer(_ serverId: String) async {
        selectedServerId = serverId
        // Picking a different server while already connected forces a full
        // reconnect (disconnect + fresh connect) rather than a live hot-swap
        // — simpler and more robust, and Xray-core has no live-switch
        // mechanism to begin with. Same behavior as Android.
        if connectionState == .connected {
            vpnManager.disconnect()
            await connectToSelectedServer()
        }
    }

    // MARK: - Settings

    func setProtectionToggle(_ type: ProtectionToggleType, enabled: Bool) {
        protectionSettings.setValue(type, enabled)
    }

    func setThemeMode(_ mode: ThemeMode) {
        themeMode = mode
        UserDefaults.standard.set(mode.rawValue, forKey: Self.themeModeKey)
    }

    func setThemeStyle(_ style: ThemeStyle) {
        themeStyle = style
        UserDefaults.standard.set(style.rawValue, forKey: Self.themeStyleKey)
    }

    func setLanguage(_ language: AppLanguage) {
        self.language = language
        UserDefaults.standard.set(language.rawValue, forKey: Self.languageKey)
        // Takes effect immediately, no relaunch needed — RootView derives
        // `.environment(\.locale, ...)` from this property, which is
        // SwiftUI's supported in-app language override mechanism.
    }

    private static let themeModeKey = "settings.themeMode"
    private static let themeStyleKey = "settings.themeStyle"
    private static let languageKey = "settings.language"

    private static func loadThemeMode(systemIsDark: Bool) -> ThemeMode {
        UserDefaults.standard.string(forKey: themeModeKey).flatMap(ThemeMode.init)
            ?? (systemIsDark ? .dark : .light)
    }

    private static func loadThemeStyle(systemIsDark: Bool) -> ThemeStyle {
        UserDefaults.standard.string(forKey: themeStyleKey).flatMap(ThemeStyle.init)
            ?? (systemIsDark ? .classic : .original)
    }

    private static func loadLanguage() -> AppLanguage {
        UserDefaults.standard.string(forKey: languageKey).flatMap(AppLanguage.init) ?? .system
    }
}
