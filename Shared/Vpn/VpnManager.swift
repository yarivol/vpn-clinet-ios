//
//  VpnManager.swift
//  pantherapp
//
//  Main-app-side bridge to the Network Extension tunnel — mirrors Android's
//  vpn/VpnManager.kt. Unlike Android (where VpnManager and the VpnService run
//  in the same process and share state directly via StateFlow), iOS runs the
//  actual tunnel in a separate Network Extension process (PacketTunnelProvider,
//  see PantherTunnel/PacketTunnelProvider.swift, the "PantherTunnel" extension
//  target). This class only talks to it through NEVPNManager/NETunnelProviderManager
//  — start/stop, and NEVPNStatusDidChange notifications for connection state.
//
//  Requires the "PantherTunnel" Network Extension target (Packet Tunnel
//  Provider) to exist with a matching bundle id
//  ("<main-app-bundle-id>.PantherTunnel") — set up declaratively in
//  project.yml (see its header comment) via `xcodegen generate`, confirmed
//  building in CI. Still needs a real device + Apple Developer Program
//  account to actually exercise at runtime (see PacketTunnelProvider's
//  "SETUP STATUS" note).
//

import Foundation
import NetworkExtension
import Observation

// Same reasoning as VpnViewModel: connect()/ensureManager() do async
// NETunnelProviderManager work whose await can resume off the main thread,
// and connectionState/errorEvents are read directly by SwiftUI. @MainActor
// guarantees every mutation (including from the @objc NEVPNStatusDidChange
// notification handler, which Swift hops to the main actor for
// automatically on an @objc method of a @MainActor class) lands on the
// main thread.
@MainActor
@Observable
final class VpnManager {
    static let shared = VpnManager()

    private(set) var connectionState: ConnectionState = .disconnected

    // Not @Observable-tracked on purpose — this is a one-shot toast-like
    // event (mirrors Android's VpnManager.errorEvents: SharedFlow<String>),
    // not persistent state a view should re-render from.
    let errorEvents = EventEmitter<String>()

    // Bundle identifier of the Packet Tunnel Provider extension target —
    // update this to match whatever the extension's actual bundle id ends up
    // being once created in Xcode (defaults to "<app-bundle-id>.PantherTunnel").
    private let tunnelBundleId = "com.panthervpn.pantherapp.PantherTunnel"

    private var manager: NETunnelProviderManager?

    private init() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(statusDidChange(_:)),
            name: .NEVPNStatusDidChange,
            object: nil
        )
        Task { await loadManager() }
    }

    private func loadManager() async {
        let managers = (try? await NETunnelProviderManager.loadAllFromPreferences()) ?? []
        manager = managers.first
        syncStateFromManager()
    }

    @objc private func statusDidChange(_ notification: Notification) {
        guard let connection = notification.object as? NEVPNConnection else { return }
        let newState = Self.mapStatus(connection.status)
        if newState != connectionState {
            AppLogger.log("NEVPNStatusDidChange: \(connection.status) -> \(newState)")
        }
        connectionState = newState
    }

    private func syncStateFromManager() {
        guard let status = manager?.connection.status else { return }
        connectionState = Self.mapStatus(status)
    }

    private static func mapStatus(_ status: NEVPNStatus) -> ConnectionState {
        switch status {
        case .connected: return .connected
        case .connecting, .reasserting: return .connecting
        case .disconnected, .invalid, .disconnecting: return .disconnected
        @unknown default: return .disconnected
        }
    }

    func reportError(_ reasonKey: String) {
        AppLogger.log("VPN error: \(reasonKey)")
        connectionState = .disconnected
        errorEvents.emit(reasonKey)
    }

    /// configJson is one server's own standalone config — see VpnServer.rawConfig
    /// / CabinetRepository.parseServers. There's no live server-switch API with
    /// Xray-core, so picking a different server while already connected is
    /// always a full disconnect+connect cycle — see the ViewModel's selectServer.
    /// `serverName` isn't currently sent to the extension (it doesn't do
    /// anything with a server name yet) — kept as a parameter here since the
    /// call sites already have it and the system VPN settings entry's
    /// localizedDescription is a natural, low-effort place to surface it if
    /// that's ever wanted, without needing to plumb it through the extension.
    func connect(configJson: String, serverName: String?) async {
        connectionState = .connecting
        do {
            let tunnelManager = try await ensureManager()
            let options: [String: NSObject] = [
                "config": NSString(string: insertTunInbound(configJson)),
            ]
            try tunnelManager.connection.startVPNTunnel(options: options)
            AppLogger.log("startVPNTunnel called successfully")
        } catch {
            AppLogger.log("startVPNTunnel threw: \(error.localizedDescription)")
            // .permissionDenied specifically means iOS refused to activate the
            // VPN configuration because this build isn't properly entitled
            // (confirmed live: sideloaded builds signed with a free/personal
            // Apple ID hit exactly this, every time, not intermittently) -
            // "try again" is actively misleading for that case, so it gets
            // its own, more accurate message instead of the generic one.
            if let nevpnError = error as? NEVPNError, nevpnError.code == .permissionDenied {
                reportError("vpn_error_permission_denied")
            } else {
                reportError("vpn_error_tunnel_failed")
            }
        }
    }

    func disconnect() {
        AppLogger.log("Disconnect requested")
        manager?.connection.stopVPNTunnel()
    }

    /// Creates the NETunnelProviderManager configuration on first use (mirrors
    /// Android's VpnService.prepare() consent flow — on iOS, saving this
    /// configuration is what triggers the system's "Add VPN Configuration"
    /// consent prompt the first time).
    private func ensureManager() async throws -> NETunnelProviderManager {
        if let manager, manager.isEnabled { return manager }

        let tunnelManager = manager ?? NETunnelProviderManager()
        let proto = NETunnelProviderProtocol()
        proto.providerBundleIdentifier = tunnelBundleId
        proto.serverAddress = "PantherVPN"
        tunnelManager.protocolConfiguration = proto
        tunnelManager.localizedDescription = "PantherVPN"
        tunnelManager.isEnabled = true
        try await tunnelManager.saveToPreferences()
        AppLogger.log("VPN configuration saved to preferences")
        try await tunnelManager.loadFromPreferences()
        manager = tunnelManager
        return tunnelManager
    }

    // The TUN fd reaches Xray-core as an explicit parameter to
    // CoreController.startLoop(_:tunFd:) (confirmed against the real built
    // framework — see PacketTunnelProvider.startXrayCore), not via an env
    // var. The core still only attaches that fd when the config carries a
    // matching {"protocol": "tun"} inbound, though — Remnawave's per-server
    // config only ships "socks"/"http" local inbounds (meant for proxy-mode
    // clients like Happ), so this app appends its own tun inbound before
    // handing the config to the core. Existing inbounds are left alone.
    // Identical logic to Android's VpnManager.insertTunInbound.
    private func insertTunInbound(_ raw: String) -> String {
        guard let data = raw.data(using: .utf8),
              var root = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return raw }

        var inbounds = root["inbounds"] as? [[String: Any]] ?? []
        inbounds.append([
            "port": 0,
            "protocol": "tun",
            "settings": [
                "name": "xray-tun0",
                "mtu": 1500,
            ],
        ])
        root["inbounds"] = inbounds

        guard let newData = try? JSONSerialization.data(withJSONObject: root),
              let newRaw = String(data: newData, encoding: .utf8)
        else { return raw }
        return newRaw
    }
}
