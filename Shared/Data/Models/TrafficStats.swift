//
//  TrafficStats.swift
//  pantherapp
//
//  Domain models — mirrors Android's data/model/TrafficStats.kt.
//

import Foundation

/// One day's traffic total, as returned by /traffic/history.
struct TrafficHistoryPoint {
    let date: String
    let bytes: Int64
}

/// Remnawave only reports combined traffic per user (no download/upload split),
/// so this is a single total rather than a two-sided shape.
struct TrafficStats {
    let usedBytes: Int64
    let limitBytes: Int64?
    let history: [TrafficHistoryPoint]
}
