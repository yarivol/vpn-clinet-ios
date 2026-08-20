//
//  PacketTunnelProvider.swift
//  PantherTunnel (Network Extension target, wired up via project.yml — see
//  the "SETUP STATUS" note at the bottom of this file)
//
//  Owns the Xray-core engine lifecycle on iOS. Mirrors Android's
//  vpn/PantherVpnService.kt as closely as the platform allows — same TUN
//  addressing constants, same "tun" inbound contract, same stats-polling
//  approach. The big platform difference: Android's VpnService and VpnManager
//  run in the SAME process (in-process StateFlow); here the tunnel runs in a
//  separate Network Extension process, and VpnManager.swift (main app) talks
//  to it only through NETunnelProviderManager + this class's
//  handleAppMessage(_:completionHandler:) for anything beyond start/stop.
//
//  Symbol names below were confirmed against the actual built
//  Libv2ray.xcframework via a one-off swiftc -typecheck probe run in CI
//  (since removed) — not a guess. See the "GOMOBILE API NAMES" note below
//  for what was learned.
//

import Libv2ray
import NetworkExtension
import os.log

final class PacketTunnelProvider: NEPacketTunnelProvider {

    private var statsTimer: Timer?

    // MARK: - Lifecycle

    override func startTunnel(options: [String: NSObject]?, completionHandler: @escaping (Error?) -> Void) {
        AppLogger.log("startTunnel called", source: "tunnel")
        guard let configJson = options?["config"] as? String, !configJson.isEmpty else {
            AppLogger.log("startTunnel failed: missing config", source: "tunnel")
            completionHandler(TunnelError.missingConfig)
            return
        }
        ensureGeoAssets()

        let settings = Self.buildTunnelNetworkSettings()
        setTunnelNetworkSettings(settings) { [weak self] error in
            guard let self else { return }
            if let error {
                AppLogger.log("setTunnelNetworkSettings failed: \(error.localizedDescription)", source: "tunnel")
                completionHandler(error)
                return
            }
            do {
                let fd = try Self.findTunFileDescriptor()
                AppLogger.log("Found TUN fd \(fd)", source: "tunnel")
                try Self.startXrayCore(configJson: configJson, tunFd: fd)
                AppLogger.log("Xray core started", source: "tunnel")
                self.startStatsPolling()
                completionHandler(nil)
            } catch {
                AppLogger.log("startTunnel failed: \(error.localizedDescription)", source: "tunnel")
                completionHandler(error)
            }
        }
    }

    override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        AppLogger.log("stopTunnel: \(reason)", source: "tunnel")
        statsTimer?.invalidate()
        statsTimer = nil
        Self.stopXrayCore()
        completionHandler()
    }

    override func handleAppMessage(_ messageData: Data, completionHandler: ((Data?) -> Void)?) {
        // Reserved for future use (e.g. live server switch without a full
        // reconnect) — not needed yet, Android doesn't have this either
        // (VpnViewModel.selectServer always does a full disconnect+connect).
        completionHandler?(nil)
    }

    // MARK: - TUN network settings

    // Matches Android's PantherVpnService constants exactly (TUN_MTU,
    // TUN_IPV4_ADDRESS/PREFIX, TUN_IPV6_ADDRESS/PREFIX, TUN_DNS_PRIMARY/SECONDARY) —
    // arbitrary private addressing, routes below send everything through the
    // tunnel regardless of the exact prefix chosen.
    private static func buildTunnelNetworkSettings() -> NEPacketTunnelNetworkSettings {
        let settings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: "10.10.14.1")

        let ipv4 = NEIPv4Settings(addresses: ["10.10.14.1"], subnetMasks: ["255.255.255.252"])
        ipv4.includedRoutes = [NEIPv4Route.default()]
        settings.ipv4Settings = ipv4

        let ipv6 = NEIPv6Settings(addresses: ["fdfe:dcba:9876::1"], networkPrefixLengths: [126])
        ipv6.includedRoutes = [NEIPv6Route.default()]
        settings.ipv6Settings = ipv6

        settings.dnsSettings = NEDNSSettings(servers: ["1.1.1.1", "1.0.0.1"])
        settings.mtu = 1500
        return settings
    }

    // The xray-core fork this app uses has a native `proxy/tun` module for
    // iOS, but NEPacketTunnelProvider only exposes packetFlow (an object API),
    // not a raw fd — Xray-core needs the actual utun socket fd. This is the
    // documented, standard technique (same one used by other open-source iOS
    // VPN clients built on utun): scan low file descriptors for the one that
    // identifies itself as a utun control socket via getsockopt. Ported
    // directly from xray-core's own proxy/tun/README.md iOS section.
    private static func findTunFileDescriptor() throws -> Int32 {
        var buffer = [CChar](repeating: 0, count: Int(IFNAMSIZ))
        for fd: Int32 in 0...1024 {
            var len = socklen_t(buffer.count)
            let result = getsockopt(fd, 2 /* SYSPROTO_CONTROL */, 2 /* UTUN_OPT_IFNAME */, &buffer, &len)
            if result == 0, String(cString: buffer).hasPrefix("utun") {
                return fd
            }
        }
        throw TunnelError.tunFileDescriptorNotFound
    }

    // MARK: - Xray-core

    // GOMOBILE API NAMES (confirmed via CI probe, see file header):
    //   gomobile's `gobind -lang=objc` emits loose C functions prefixed with
    //   the module name ("Libv2rayInitCoreEnv", "Libv2rayNewCoreController"),
    //   NOT members grouped under a "Libv2ray" namespace/enum the way
    //   Android's Kotlin binding reads (`Libv2ray.initCoreEnv(...)`) — that
    //   was the actual cause of the "cannot find type" build failure, not
    //   the type names themselves (which were already right):
    //     Libv2rayInitCoreEnv(assetPath, xudpBaseKey)
    //     Libv2rayNewCoreController(callbackHandler) -> Libv2rayCoreController?
    //     controller.startLoop(configJson, tunFd)
    //     controller.stopLoop()
    //     controller.queryAllOutboundTrafficStats() -> String
    //   Also: the ObjC header declares a callback *protocol* and a callback
    //   *class* with the identical name ("CoreCallbackHandler") — Swift
    //   disambiguates by importing the protocol as
    //   "Libv2rayCoreCallbackHandlerProtocol", which is what
    //   XrayCallbackHandler below conforms to.
    private static var coreController: Libv2rayCoreController?

    private static func startXrayCore(configJson: String, tunFd: Int32) throws {
        Libv2rayInitCoreEnv(FileManager.default.temporaryDirectory.path, "")
        let handler = XrayCallbackHandler()
        guard let controller = Libv2rayNewCoreController(handler) else {
            throw TunnelError.coreControllerCreationFailed
        }
        try controller.startLoop(configJson, tunFd: tunFd)
        coreController = controller
    }

    private static func stopXrayCore() {
        try? coreController?.stopLoop()
        coreController = nil
    }

    // MARK: - Geoip/geosite assets

    // Same lesson as Android: gomobile's Go-side asset-bundle fallback isn't
    // reliable, so this app copies geoip.dat/geosite.dat/geoip-only-cn-private.dat
    // out of the extension's own bundle resources to disk once, and points
    // Libv2rayInitCoreEnv at that directory (see startXrayCore above).
    private func ensureGeoAssets() {
        let fileNames = ["geoip.dat", "geosite.dat", "geoip-only-cn-private.dat"]
        let targetDir = FileManager.default.temporaryDirectory
        for name in fileNames {
            let target = targetDir.appendingPathComponent(name)
            if FileManager.default.fileExists(atPath: target.path) { continue }
            guard let bundled = Bundle.main.url(forResource: name, withExtension: nil) else {
                AppLogger.log("Geo asset missing from bundle: \(name)", source: "tunnel")
                continue
            }
            try? FileManager.default.copyItem(at: bundled, to: target)
        }
    }

    // MARK: - Stats polling

    // No push-status API (matches Android) — queryAllOutboundTrafficStats()
    // is polled instead; each read resets the underlying counters to 0, so
    // the raw per-tick values already ARE the bytes-per-interval figure.
    private func startStatsPolling() {
        statsTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            guard let stats = Self.coreController?.queryAllOutboundTrafficStats() else { return }
            self?.parseAndLogStats(stats)
        }
    }

    private func parseAndLogStats(_ stats: String) {
        var uplink: Int64 = 0
        var downlink: Int64 = 0
        for entry in stats.split(separator: ";") where !entry.isEmpty {
            let parts = entry.split(separator: ",")
            guard parts.count == 3, parts[0] == "proxy", let value = Int64(parts[2]) else { continue }
            if parts[1] == "uplink" { uplink += value }
            if parts[1] == "downlink" { downlink += value }
        }
        // Logged (not just silently dropped) now that AppLogger's App Group
        // store gives a cheap way to see it from the Logs screen - still no
        // dedicated live-traffic UI (Android shows this in its persistent
        // notification; iOS extensions can't post their own arbitrary
        // notifications the same way), that's a separate, bigger feature.
        if uplink > 0 || downlink > 0 {
            AppLogger.log("Traffic tick: ↑\(uplink)B ↓\(downlink)B", source: "tunnel")
        }
    }

    private enum TunnelError: Error {
        case missingConfig
        case tunFileDescriptorNotFound
        case coreControllerCreationFailed
    }
}

private final class XrayCallbackHandler: NSObject, Libv2rayCoreCallbackHandlerProtocol {
    // The protocol's ObjC methods are typed `long`, which bridges to Swift's
    // `Int` (not `Int64` - that's what `int64_t` bridges to, the type
    // CoreController's queryStats/measureDelay use instead). Protocol
    // conformance needs the exact bridged type, confirmed by CI.
    func startup() -> Int {
        os_log("Xray core startup")
        return 0
    }
    func shutdown() -> Int {
        os_log("Xray core shutdown")
        return 0
    }
    // ObjC selector is onEmitStatus:p1: - the protocol requires the external
    // label "p1" on the second parameter (confirmed by the same CI probe).
    func onEmitStatus(_ code: Int, p1 message: String?) -> Int {
        os_log("onEmitStatus: %{public}d %{public}@", code, message ?? "")
        return 0
    }
}

// SETUP STATUS: the PantherTunnel target, its Network Extension entitlement,
// and linking Libv2ray.xcframework are all now handled by project.yml (see
// its header comment) — `xcodegen generate` sets all of that up, no manual
// Xcode target creation needed any more. The Libv2ray* symbol names above
// are confirmed correct (see the file header + startXrayCore's comment).
//
// Still needs a real Mac + Apple Developer Program account to actually
// verify, though — this only proves the Swift compiles against the real
// framework, not that it works over the air:
// 1. App Groups ARE wired into project.yml now (main-app <-> extension
//    sharing, currently used for AppLogger's shared log buffer). A live
//    traffic-stats display would reuse the same App Group container.
// 2. Run on a real device (NetworkExtension doesn't fully function in the
//    Simulator) and confirm startLoop/stopLoop/the TUN fd scan actually
//    work end-to-end against a real Xray config.
