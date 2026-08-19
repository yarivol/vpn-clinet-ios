//
//  CabinetModels.swift
//  pantherapp
//
//  Wire models for /me, /traffic/history, /devices — mirrors Android's
//  data/remote/dto/CabinetDtos.kt exactly (same backend, same JSON shape).
//  Relies on APIClient's JSONDecoder.keyDecodingStrategy = .convertFromSnakeCase
//  for the snake_case → camelCase mapping, so no manual CodingKeys are needed.
//

import Foundation

struct SubscriptionDto: Decodable {
    let status: String
    let planCode: String?
    let expiresAt: String?
    let daysLeft: Int
    let deviceLimit: Int
}

struct CabinetMeResponse: Decodable {
    let userId: Int64
    let telegramId: Int64
    let username: String?
    let firstName: String?
    let subscription: SubscriptionDto?
    let deviceLimit: Int
    let currentDevices: Int
    let subLink: String?
    let connectUrl: String?
    let trafficUsed: Int64?
    let trafficLimit: Int64?
}

struct TrafficHistoryEntryDto: Decodable {
    let date: String
    let bytes: Int64
}

struct TrafficHistoryResponse: Decodable {
    let history: [TrafficHistoryEntryDto]
}

struct DeviceDto: Decodable {
    let hwid: String?
    let platform: String?
    let osVersion: String?
    let deviceModel: String?
    let updatedAt: String?
    let createdAt: String?
}

struct DevicesResponse: Decodable {
    let devices: [DeviceDto]
}

struct DeviceRemoveRequest: Encodable {
    let hwid: String
}
