//
//  DeviceIdStore.swift
//  pantherapp
//
//  Persistent per-install device identifier sent as Remnawave's `hwid` on
//  every subscription/config request — see CabinetRepository. Generated once
//  and kept for the app's lifetime so this device shows up as one stable
//  entry in Remnawave's HWID device list. Mirrors Android's
//  data/auth/DeviceIdStore.kt.
//

import Foundation

final class DeviceIdStore {
    private let keychain = KeychainStore(service: "com.panthervpn.pantherapp.device")
    private static let deviceIdKey = "device_id"

    lazy var deviceId: String = {
        if let existing = keychain.get(Self.deviceIdKey) {
            return existing
        }
        let generated = UUID().uuidString
        keychain.set(Self.deviceIdKey, value: generated)
        return generated
    }()
}
