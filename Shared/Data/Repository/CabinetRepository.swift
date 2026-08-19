//
//  CabinetRepository.swift
//  pantherapp
//
//  Real data source backed by the BotVPN cabinet API. Mirrors Android's
//  data/repository/CabinetRepository.kt — same endpoints, same server-list
//  parsing logic (kept in lockstep on purpose: this parsing was worked out and
//  verified live against real Remnawave responses during the Xray-core
//  migration, don't redesign it here without re-verifying against the same
//  server the Android app talks to).
//

import Foundation

final class CabinetRepository {
    private let api: APIClient
    private let hwid: String
    private let platform: String
    private let osVersion: String?
    // Real device model (e.g. "iPhone 15 Pro") and an app-identifying
    // User-Agent ("PantherApp/1.5/ios/...") — matches how Happ/Karing show up
    // in Remnawave's HWID device list (their real model + their own client
    // string), not swapped.
    private let deviceModel: String?
    private let userAgent: String?

    init(
        api: APIClient,
        hwid: String,
        platform: String = "ios",
        osVersion: String? = nil,
        deviceModel: String? = nil,
        userAgent: String? = nil
    ) {
        self.api = api
        self.hwid = hwid
        self.platform = platform
        self.osVersion = osVersion
        self.deviceModel = deviceModel
        self.userAgent = userAgent
    }

    /// This install's own hwid — used by the Devices screen to mark/protect "this device".
    var currentDeviceHwid: String { hwid }

    func fetchMe() async -> CabinetMeResponse? {
        try? await api.getCabinetMe()
    }

    func toSubscription(_ me: CabinetMeResponse) -> Subscription {
        let sub = me.subscription
        let displayName = me.username.map { "@\($0)" } ?? me.firstName
        return Subscription(
            isActive: sub?.status == "active",
            planCode: sub?.planCode,
            expiresOnRaw: sub?.expiresAt,
            daysLeft: sub?.daysLeft ?? 0,
            deviceLimit: me.deviceLimit,
            currentDevices: me.currentDevices,
            subLink: me.subLink ?? me.connectUrl,
            displayName: displayName
        )
    }

    func fetchTrafficStats(_ me: CabinetMeResponse) async -> TrafficStats {
        let history = (try? await api.getTrafficHistory().history) ?? []
        return TrafficStats(
            usedBytes: me.trafficUsed ?? 0,
            limitBytes: me.trafficLimit,
            history: history.map { TrafficHistoryPoint(date: $0.date, bytes: $0.bytes) }
        )
    }

    // The real, user-facing server list comes from Remnawave's Xray-core
    // subscription format: a JSON array where each element is a fully
    // standalone, ready-to-run Xray config for ONE server ("remarks" =
    // display name, "outbounds"[0] = the real proxy outbound, plus
    // "direct"/"block" helpers) — confirmed via live curl with a Happ-style
    // User-Agent + registered X-Hwid. There's no shared selector group to
    // pick a member from: each array element already IS one complete,
    // connectable config, kept verbatim in VpnServer.rawConfig and handed to
    // the VPN engine as-is when the user picks that server.
    //
    // nil means the fetch itself failed (network/server error) — distinct
    // from a successful fetch that happens to contain zero servers. Callers
    // should keep whatever server list they last had on nil, rather than
    // clearing it to empty.
    func fetchServers() async -> [VpnServer]? {
        guard let raw = try? await fetchRawConfig() else { return nil }
        return parseServers(from: raw)
    }

    private func parseServers(from data: Data) -> [VpnServer] {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return []
        }

        var servers: [VpnServer] = []
        for (index, element) in root.enumerated() {
            let name = (element["remarks"] as? String)?.trimmingCharacters(in: .whitespaces) ?? ""
            if name.isEmpty { continue }
            // The template's own "🌀 Авто-подбор..." entries carry multiple
            // proxy outbounds bundled behind Xray's own balancer/routing —
            // hidden entirely, since the app has its own real auto-select
            // (lowest-ping) which picks among the real named hosts.
            if name.range(of: "Авто", options: .caseInsensitive) != nil { continue }

            let outbounds = element["outbounds"] as? [[String: Any]] ?? []
            guard let proxyOutbound = outbounds.first(where: { ($0["tag"] as? String) == "proxy" }) ?? outbounds.first
            else { continue }

            // Remnawave's "device/app not supported" fallback uses a real
            // protocol type but a dummy 0.0.0.0 host — surface those as
            // offline, not as a pickable server. Host/port live at different
            // JSON paths per protocol: vless/vmess use settings.vnext[0],
            // trojan/shadowsocks use settings.servers[0], hysteria uses a
            // flat settings.address/settings.port (no nested array) —
            // confirmed live for all three shapes. Try the array shapes
            // first, then fall back to the flat fields.
            let proxySettings = proxyOutbound["settings"] as? [String: Any]
            let endpoint = (proxySettings?["vnext"] as? [[String: Any]])?.first
                ?? (proxySettings?["servers"] as? [[String: Any]])?.first
                ?? proxySettings
            let host = endpoint?["address"] as? String
            let port = (endpoint?["port"] as? NSNumber)?.intValue
            let isPlaceholder = host == nil || host == "0.0.0.0"

            let rawConfig = (try? JSONSerialization.data(withJSONObject: element))
                .flatMap { String(data: $0, encoding: .utf8) }

            servers.append(
                VpnServer(
                    id: "\(index)-\(name)",
                    name: name,
                    countryCode: "",
                    isOnline: !isPlaceholder,
                    host: isPlaceholder ? nil : host,
                    port: isPlaceholder ? nil : port,
                    rawConfig: rawConfig
                )
            )
        }
        return servers
    }

    private func fetchRawConfig() async throws -> Data {
        try await api.getVpnConfig(
            hwid: hwid, platform: platform, osVersion: osVersion,
            deviceModel: deviceModel, userAgent: userAgent
        )
    }

    // Called on logout so this device stops counting against the user's
    // Remnawave device limit and disappears from their HWID device list —
    // best-effort, a failed call here shouldn't block logging out locally.
    func removeCurrentDevice() async {
        _ = await removeDevice(hwid)
    }

    func fetchDevices() async -> [DeviceDto] {
        (try? await api.getDevices().devices) ?? []
    }

    @discardableResult
    func removeDevice(_ targetHwid: String) async -> Bool {
        do {
            try await api.removeDevice(hwid: targetHwid)
            return true
        } catch {
            return false
        }
    }
}
