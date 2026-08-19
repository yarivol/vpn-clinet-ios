//
//  Subscription.swift
//  pantherapp
//
//  Domain model — mirrors Android's data/model/Subscription.kt.
//

import Foundation

struct Subscription {
    let isActive: Bool
    let planCode: String?
    let expiresOnRaw: String?
    let daysLeft: Int
    let deviceLimit: Int
    let currentDevices: Int
    let subLink: String?
    let displayName: String?
}
