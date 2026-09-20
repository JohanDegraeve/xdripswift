import Foundation
import CoreBluetooth

/// Per-device preferences. Missing settings deliberately retain the compatible multi-channel mode.
struct GenericHeartbeatSettings: Codable, Equatable {
    enum Mode: String, Codable, CaseIterable {
        case all, automatic

        // Keep the persisted automatic value so existing Single selections survive the UI rename.
        // Old manual selections become Single; unknown values retain the compatible All default.
        init(from decoder: Decoder) throws {
            let value = try decoder.singleValueContainer().decode(String.self)
            self = value == "selected" ? .automatic : (Self(rawValue: value) ?? .all)
        }
        var title: String { heartbeatText("mode." + rawValue) }
        // Support exports use stable English labels, independent of language and persisted raw values.
        var logDescription: String { self == .all ? "All" : "Single" }
        var explanation: String { heartbeatText("footer." + rawValue) + "\n\n" + heartbeatText("simpleFooter") }
    }

    var mode: Mode = .all

    private static func key(_ address: String) -> String { "genericHeartbeat." + address.uppercased() }

    static func load(_ address: String, defaults: UserDefaults = .standard) -> Self {
        // Older testing fields are ignored; only the subscription choice is retained.
        guard let data = defaults.data(forKey: key(address)),
              let settings = try? JSONDecoder().decode(Self.self, from: data) else { return Self() }
        return settings
    }

    func save(_ address: String, defaults: UserDefaults = .standard) {
        // Persist only the choice, not the current connection's discovered or subscribed channels.
        defaults.set(try? JSONEncoder().encode(self), forKey: Self.key(address))
    }

    static func remove(_ address: String, defaults: UserDefaults = .standard) {
        // Removing a device also resets its choice if the same Bluetooth address is added again.
        defaults.removeObject(forKey: key(address))
    }
}

/// Candidate metadata used to select subscriptions on the Bluetooth queue.
struct GenericHeartbeatChannel: Equatable {
    let service: String
    let characteristic: String
    let properties: CBCharacteristicProperties
    var id: String { service + "/" + characteristic }
    var eligible: Bool {
        // Battery responses are metadata, not a source of heartbeat notifications.
        !(service == "180F" && characteristic == "2A19") &&
        (!properties.intersection([.notify, .indicate]).isEmpty)
    }

    static func ordered(_ channels: [Self]) -> [Self] {
        // Prefer standard measurement channels, then notify over indicate-only channels.
        // UUID ordering breaks ties so asynchronous service discovery cannot change the choice.
        let measurements = ["2A18", "2AA7", "2A37"]
        // UUID pairs must identify one channel unambiguously. Never guess between duplicates.
        let counts = Dictionary(grouping: channels, by: \.id)
        return channels.filter { $0.eligible && counts[$0.id]?.count == 1 }.sorted {
            func rank(_ channel: Self) -> Int {
                if measurements.contains(channel.characteristic) { return 0 }
                return channel.properties.contains(.notify) ? 1 : 2
            }
            return rank($0) == rank($1) ? $0.id < $1.id : rank($0) < rank($1)
        }
    }
}

/// Shared localization for generic heartbeat controls.
func heartbeatText(_ key: String) -> String {
    NSLocalizedString("heartbeat." + key, tableName: "BluetoothPeripheralView", comment: "")
}

/// Bounded subscription bookkeeping, independent of Core Bluetooth objects for regression tests.
struct GenericHeartbeatSubscriptions {
    private(set) var attempted = Set<String>()
    private(set) var pending = Set<String>()
    private(set) var subscribed = Set<String>()

    mutating func next(_ candidates: [String], mode: GenericHeartbeatSettings.Mode) -> [String] {
        // A pending or successful single subscription must never grow into multiple channels.
        guard mode == .all || (pending.isEmpty && subscribed.isEmpty) else { return [] }
        let remaining = candidates.filter { !attempted.contains($0) }
        let selected = mode == .all ? remaining : Array(remaining.prefix(1))
        // Mark requests before returning them to the caller so repeated selection cannot duplicate them.
        attempted.formUnion(selected)
        pending.formUnion(selected)
        return selected
    }

    @discardableResult
    mutating func complete(_ id: String, success: Bool) -> Bool {
        // Duplicate, unsolicited and old-session confirmations do not advance fallback.
        guard pending.remove(id) != nil else { return false }
        if success { subscribed.insert(id) }
        return true
    }

    /// Notification state can change without a pending request. Track it without starting fallback.
    mutating func observe(_ id: String, isNotifying: Bool) {
        if isNotifying { subscribed.insert(id) } else { subscribed.remove(id) }
    }

    var outcome: String {
        if !subscribed.isEmpty { return "subscribed" }
        if !pending.isEmpty { return "pending" }
        return attempted.isEmpty ? "unavailable" : "failed"
    }
}

enum ConstantsHeartBeat {
    
    /// minimum time between two heartbeats
    static let minimumTimeBetweenTwoHeartBeats = TimeInterval(30)
    
    /// how many seconds should pass since the previous Libre 3 BLE heartbeat until we show it as disconnected (i.e. having missed a heartbeat)
    static let secondsUntilHeartBeatDisconnectWarningLibre3: Double = 70
    
    /// how many seconds should pass since the previous Dexcom G7 heartbeat until we show it as disconnected (i.e. having missed a heartbeat)
    static let secondsUntilHeartBeatDisconnectWarningDexcomG7: Double = 60 * 5.5
    
    /// how many seconds should pass since the previous OmniPod heartbeat until we show it as disconnected (i.e. having missed a heartbeat)
    static let secondsUntilHeartBeatDisconnectWarningOmniPod: Double = 60 * 5.5
    
}
