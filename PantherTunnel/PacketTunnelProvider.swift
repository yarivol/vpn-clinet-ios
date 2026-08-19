//
//  PacketTunnelProvider.swift
//  PantherTunnel (Network Extension target — not yet created in Xcode, see
//  the "SETUP NEEDED" note at the bottom of this file)
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
//  ⚠️ NAMING NOT YET VERIFIED — see the "GOMOBILE API NAMES" note below.
//

import NetworkExtension
import os.log

final class PacketTunnelProvider: NEPacketTunnelProvider {

    private var statsTimer: Timer?
    private var currentServerName: String?

    // MARK: - Lifecycle

    override func startTunnel(options: [String: NSObject]?, completionHandler: @escaping (Error?) -> Void) {
        guard let configJson = options?["config"] as? String, !configJson.isEmpty else {
            completionHandler(TunnelError.missingConfig)
            return
        }
        currentServerName = options?["serverName"] as? String

        ensureGeoAssets()

        let settings = Self.buildTunnelNetworkSettings()
        setTunnelNetworkSettings(settings) { [weak self] error in
            guard let self else { return }
            if let error {
                completionHandler(error)
                return
            }
            do {
                let fd = try Self.findTunFileDescriptor()
                try Self.startXrayCore(configJson: configJson, tunFd: fd)
                self.startStatsPolling()
                completionHandler(nil)
            } catch {
                completionHandler(error)
            }
        }
    }

    override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
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

    // MARK: - Xray-core (⚠️ NOT YET VERIFIED — see note below)

    // GOMOBILE API NAMES: this mirrors Android's exact calls —
    //   Libv2ray.initCoreEnv(assetPath, xudpBaseKey)
    //   Libv2ray.newCoreController(callbackHandler) -> CoreController
    //   controller.startLoop(configJson, tunFd)
    //   controller.stopLoop()
    //   controller.queryAllOutboundTrafficStats() -> String
    // gomobile's `bind -target=ios` generates an Obj-C/Swift interface from
    // the same Go package (github.com/2dust/AndroidLibXrayLite), so the
    // *shape* of this API will match — but gomobile's exact generated Swift
    // symbol names (e.g. "Libv2rayCoreController" vs "Libv2ray.CoreController")
    // depend on its ObjC-flattening convention and can only be confirmed once
    // Libv2ray.xcframework is actually built (see .github/workflows/build-ios-xray.yml)
    // and inspected in Xcode (Product > Generated Interface, or the umbrella
    // header). Fix the type/method names below against that before this compiles.
    private static var coreController: Libv2rayCoreController?

    private static func startXrayCore(configJson: String, tunFd: Int32) throws {
        Libv2ray.initCoreEnv(FileManager.default.temporaryDirectory.path, "")
        let handler = XrayCallbackHandler()
        let controller = Libv2ray.newCoreController(handler)
        try controller.startLoop(configJson, tunFd)
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
    // Libv2ray.initCoreEnv at that directory (see startXrayCore above).
    private func ensureGeoAssets() {
        let fileNames = ["geoip.dat", "geosite.dat", "geoip-only-cn-private.dat"]
        let targetDir = FileManager.default.temporaryDirectory
        for name in fileNames {
            let target = targetDir.appendingPathComponent(name)
            if FileManager.default.fileExists(atPath: target.path) { continue }
            guard let bundled = Bundle.main.url(forResource: name, withExtension: nil) else { continue }
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
        // TODO: surface uplink/downlink to the main app for a live traffic
        // display, once the UI phase adds one (Android shows this in its
        // persistent notification — iOS extensions can't post their own
        // arbitrary notifications the same way; likely needs an app-group
        // shared container the main app polls, or handleAppMessage).
    }

    private enum TunnelError: Error {
        case missingConfig
        case tunFileDescriptorNotFound
    }
}

private final class XrayCallbackHandler: NSObject, Libv2rayCoreCallbackHandlerProtocol {
    func startup() -> Int64 {
        os_log("Xray core startup")
        return 0
    }
    func shutdown() -> Int64 {
        os_log("Xray core shutdown")
        return 0
    }
    func onEmitStatus(_ code: Int64, _ message: String?) -> Int64 {
        os_log("onEmitStatus: %{public}d %{public}@", code, message ?? "")
        return 0
    }
}

// SETUP NEEDED (do this in Xcode on your Mac, I can't create Xcode targets
// from here):
// 1. File > New > Target > Network Extension > Packet Tunnel Provider, name
//    it "PantherTunnel". Xcode generates its own PacketTunnelProvider.swift +
//    Info.plist inside a new PantherTunnel/ folder — delete its generated
//    PacketTunnelProvider.swift and add this file to that target instead
//    (same folder location assumed above).
// 2. Add the "Network Extensions" capability (packet-tunnel-provider) to both
//    the main app target AND this extension target, plus "App Groups" on
//    both (needed later for main-app <-> extension data sharing) — requires
//    an Apple Developer Program account.
// 3. Add Libv2ray.xcframework (see .github/workflows/build-ios-xray.yml) to
//    this extension target's "Frameworks and Libraries".
// 4. Fix the Libv2ray* type/method names in this file against the actual
//    built framework's generated interface (Xcode: right-click the framework
//    > "Generated Interface", or check its umbrella .h).
