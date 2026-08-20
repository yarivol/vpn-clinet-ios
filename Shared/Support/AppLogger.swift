//
//  AppLogger.swift
//  pantherapp
//
//  Lightweight in-memory + on-disk log buffer, surfaced via
//  Settings -> Logs (mirrors Android's in-app log viewer, requested after
//  real-device testing found no way to see what the app/tunnel were doing).
//
//  Shared between the main app and the PantherTunnel extension via an App
//  Group UserDefaults suite (see project.yml) - both processes append to the
//  same store under a "source" tag ("app"/"tunnel") so a single Logs screen
//  shows the whole picture. This file is compiled into BOTH targets (see
//  project.yml's PantherTunnel sources) rather than shared through a
//  framework, since it's small and has no other dependencies.
//
//  Deliberately a plain read-modify-write over UserDefaults, not a properly
//  synchronized cross-process append log - the two processes could each
//  clobber a near-simultaneous write from the other. Acceptable for a
//  debug/support log fed by discrete, infrequent events (connect, auth,
//  errors), not something worth a real IPC/file-locking design for.
//

import Foundation

enum AppLogger {
    struct Entry: Identifiable, Codable {
        let id: UUID
        let date: Date
        let source: String
        let message: String
    }

    private static let appGroupID = "group.com.panthervpn.pantherapp"
    private static let storageKey = "app_logs"
    private static let maxEntries = 300

    /// Falls back to the app's own sandboxed UserDefaults if the App Group
    /// isn't available (e.g. pantherapp-uitest, which carries no App Group
    /// entitlement since it has no tunnel to share logs with anyway) -
    /// UserDefaults(suiteName:) returns nil rather than crashing in that case.
    private static var defaults: UserDefaults {
        UserDefaults(suiteName: appGroupID) ?? .standard
    }

    static func log(_ message: String, source: String = "app") {
        var entries = allEntries()
        entries.append(Entry(id: UUID(), date: Date(), source: source, message: message))
        if entries.count > maxEntries {
            entries.removeFirst(entries.count - maxEntries)
        }
        guard let data = try? JSONEncoder().encode(entries) else { return }
        defaults.set(data, forKey: storageKey)
    }

    static func allEntries() -> [Entry] {
        guard let data = defaults.data(forKey: storageKey),
              let entries = try? JSONDecoder().decode([Entry].self, from: data)
        else { return [] }
        return entries
    }

    static func clear() {
        defaults.removeObject(forKey: storageKey)
    }

    static func exportText() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return allEntries()
            .map { "\(formatter.string(from: $0.date)) [\($0.source)] \($0.message)" }
            .joined(separator: "\n")
    }
}
