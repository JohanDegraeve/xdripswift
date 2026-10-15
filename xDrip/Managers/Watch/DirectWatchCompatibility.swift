//
//  DirectWatchCompatibility.swift
//  xDrip
//
//  Created by Paul Plant on 13/10/26.
//  Copyright © 2026 Johan Degraeve. All rights reserved.
//

import Foundation

/// Keeps saved data and queued messages usable when the phone and Watch update separately.
/// The old names are confined here. New code and newly written files use Direct to Watch.
enum DirectWatchCompatibility {
    private static let legacyPrefix = "g6Watch"
    private static let currentPrefix = "directWatch"

    // CoreBluetooth uses this identifier to restore a pending connection after an update.
    // Changing it with the class name would discard the system's restoration state.
    static let centralRestorationIdentifier = "xdrip.g6.watch"
    static let missedReadingNotificationIDs = ["directWatch.missed", "g6Watch.missed"]

    static func normalized(_ payload: [String: Any]) -> [String: Any] {
        var result = payload
        for (key, value) in payload where key.hasPrefix(legacyPrefix) {
            let current = currentPrefix + String(key.dropFirst(legacyPrefix.count))
            if result[current] == nil { result[current] = value }
        }
        return result
    }

    static func outgoing(_ payload: [String: Any]) -> [String: Any] {
        var result = normalized(payload)
        for (key, value) in payload where key.hasPrefix(currentPrefix) {
            result[legacyPrefix + String(key.dropFirst(currentPrefix.count))] = value
        }
        return result
    }

    static func migrateSettings(in defaults: UserDefaults = .standard) {
        let migrationKey = "directWatch.legacySettingsMigrated"
        guard !defaults.bool(forKey: migrationKey) else { return }
        for (key, value) in defaults.dictionaryRepresentation() where key.hasPrefix(legacyPrefix + ".") {
            let current = currentPrefix + String(key.dropFirst(legacyPrefix.count))
            if defaults.object(forKey: current) == nil { defaults.set(value, forKey: current) }
        }
        defaults.set(true, forKey: migrationKey)
    }

    static func collectorStoreURL(in directory: URL) -> URL {
        migratedFileURL(in: directory, currentName: "DirectWatchCollector.json", legacyName: "G6WatchCollector.json")
    }

    static func logURL(in directory: URL) -> URL {
        migratedFileURL(in: directory, currentName: "Direct-to-Watch.log", legacyName: "G6-Watch.log")
    }

    private static func migratedFileURL(in directory: URL, currentName: String, legacyName: String) -> URL {
        let current = directory.appendingPathComponent(currentName)
        let legacy = directory.appendingPathComponent(legacyName)
        guard !FileManager.default.fileExists(atPath: current.path), FileManager.default.fileExists(atPath: legacy.path) else { return current }
        do {
            try FileManager.default.copyItem(at: legacy, to: current)
            return current
        } catch {
            // Keep using the existing file if migration fails. Never start an empty store
            // just because a rename failed while readings were waiting to sync.
            return legacy
        }
    }
}
