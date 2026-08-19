//
//  VpnServer.swift
//  pantherapp
//
//  Domain model — mirrors Android's data/model/VpnServer.kt.
//

import Foundation

struct VpnServer: Identifiable, Equatable {
    let id: String
    let name: String
    let countryCode: String
    let isOnline: Bool
    /// Real proxy endpoint, for ping measurement — nil for the "device not
    /// supported" placeholder entries, which aren't pingable.
    let host: String?
    let port: Int?
    /// This server's own standalone, ready-to-run Xray-core config (one array
    /// element from Remnawave's response — see CabinetRepository.parseServers).
    /// Handed to the VPN engine as-is to actually tunnel through this server.
    /// Nil only for the "device not supported" placeholder entries.
    let rawConfig: String?

    init(
        id: String,
        name: String,
        countryCode: String,
        isOnline: Bool,
        host: String? = nil,
        port: Int? = nil,
        rawConfig: String? = nil
    ) {
        self.id = id
        self.name = name
        self.countryCode = countryCode
        self.isOnline = isOnline
        self.host = host
        self.port = port
        self.rawConfig = rawConfig
    }
}
