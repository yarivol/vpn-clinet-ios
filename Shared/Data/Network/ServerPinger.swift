//
//  ServerPinger.swift
//  pantherapp
//
//  "Ping" for a proxy server, the same way Happ and other VPN clients do it:
//  real ICMP ping needs raw sockets (not available to a normal app sandbox),
//  so this measures TCP connect time to the server's actual proxy port
//  instead — a fair proxy for reachability/latency, since that's the same
//  handshake the tunnel itself would have to do. Mirrors Android's
//  data/network/ServerPinger.kt.
//

import Foundation
import Network

enum ServerPinger {
    private static let timeoutSeconds: TimeInterval = 3

    /// Connect time in ms, or nil if unreachable/timed out/the port is out of
    /// range (a plain UInt16(port) traps on overflow - server-supplied data,
    /// so a malformed port should read as "can't ping", not crash the app).
    static func ping(host: String, port: Int) async -> Int? {
        guard let port16 = UInt16(exactly: port) else { return nil }
        return await withCheckedContinuation { continuation in
            let start = Date()
            let connection = NWConnection(
                host: NWEndpoint.Host(host),
                port: NWEndpoint.Port(integerLiteral: port16),
                using: .tcp
            )

            var resumed = false
            let resume: (Int?) -> Void = { result in
                guard !resumed else { return }
                resumed = true
                connection.cancel()
                continuation.resume(returning: result)
            }

            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    let elapsedMs = Int(Date().timeIntervalSince(start) * 1000)
                    resume(elapsedMs)
                case .failed, .cancelled:
                    resume(nil)
                default:
                    break
                }
            }

            connection.start(queue: .global(qos: .utility))
            DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + timeoutSeconds) {
                resume(nil)
            }
        }
    }
}
