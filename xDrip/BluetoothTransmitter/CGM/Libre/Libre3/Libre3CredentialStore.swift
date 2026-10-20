//
//  Libre3CredentialStore.swift
//  xdrip
//
//  Created by Paul Plant on 11/10/26.
//  Copyright © 2026 Johan Degraeve. All rights reserved.
//

import Foundation
import Security

/// Sensor-scoped recovery material. Never included in UserDefaults, diagnostics or backups.
struct Libre3PairingRecord: Codable, Equatable {
    var serial: String
    var receiverID: UInt32
    var blePIN: Data?
    var phase5Key: Data?
    var cryptoVersion: Int?
    var identityVersion: String?
    var identityLabel: String?
    var securityVersion: UInt16?
    var region: UInt16?
    var bleAddress: String?
    var peripheralID: String?
    var firmware: String
    var generation: UInt16
    var wearMinutes: Int
    var warmupMinutes: Int
    var startedAt: Date?
    var lastLifeCount: UInt16?
    var rejectedMinutes: Set<UInt16> = []
    var status: String = "Waiting for sensor"
    var nfcCompleted = false
    var authenticated = false
    var sensorEnded = false
}

final class Libre3CredentialStore {
    private let service: String
    init(service: String = (Bundle.main.bundleIdentifier ?? "xdrip") + ".libre3") { self.service = service }

    func appReceiverID() throws -> UInt32 {
        if let data = try read("receiver") {
            guard data.count == 4 else { throw Libre3ConnectionError.storage }
            return data.enumerated().reduce(UInt32(0)) { $0 | UInt32($1.element) << (8 * $1.offset) }
        }
        var value: UInt32 = 0
        guard SecRandomCopyBytes(kSecRandomDefault, MemoryLayout.size(ofValue: value), &value) == errSecSuccess else {
            throw Libre3ConnectionError.storage
        }
        try write(Libre3ReceiverID(value).littleEndianData, account: "receiver")
        return value
    }
    func load(serial: String) throws -> Libre3PairingRecord? {
        guard let data = try read("sensor." + serial) else { return nil }
        return try JSONDecoder().decode(Libre3PairingRecord.self, from: data)
    }
    func pending() throws -> Libre3PairingRecord? {
        guard let data = try read("pending"), let serial = String(data: data, encoding: .utf8) else { return nil }
        return try load(serial: serial)
    }
    func save(_ record: Libre3PairingRecord) throws {
        try write(JSONEncoder().encode(record), account: "sensor." + record.serial)
        try write(Data(record.serial.utf8), account: "pending")
    }
    func removeAll() throws {
        let result = SecItemDelete([kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service] as CFDictionary)
        guard result == errSecSuccess || result == errSecItemNotFound else { throw Libre3ConnectionError.storage }
    }
    private func query(_ account: String) -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service,
         kSecAttrAccount as String: account, kSecAttrSynchronizable as String: false]
    }
    func read(_ account: String) throws -> Data? {
        var q = query(account)
        q[kSecReturnData as String] = true
        q[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(q as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = result as? Data else { throw Libre3ConnectionError.storage }
        return data
    }
    func write(_ data: Data, account: String) throws {
        let attributes: [String: Any] = [kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly]
        let q = query(account)
        let result = SecItemUpdate(q as CFDictionary, attributes as CFDictionary)
        if result == errSecItemNotFound {
            guard SecItemAdd(q.merging(attributes) { _, new in new } as CFDictionary, nil) == errSecSuccess else {
                throw Libre3ConnectionError.storage
            }
        } else if result != errSecSuccess { throw Libre3ConnectionError.storage }
    }
}

enum Libre3ConnectionError: LocalizedError {
    case storage, disconnected, timeout, malformed, identity, notStarted, recovery, resources, credentialsRejected
    case alreadyStarted(receiverID: UInt32?)
    var errorDescription: String? {
        TextsLibre3.localized({ () -> String in
            switch self {
            case .storage: return "Sensor credentials could not be saved or read. Unlock the phone and retry."
            case .disconnected: return "The sensor disconnected. Retry the connection."
            case .timeout: return "The sensor did not respond. Retry the connection."
            case .malformed: return "The sensor returned an unsupported or invalid response."
            case .identity: return "This sensor is already active. Import it with its original account or Receiver ID."
            case .notStarted: return "This sensor has not been started. Choose “Start a new sensor”."
            case .alreadyStarted: return "This sensor has already been started. Choose “Connect using Receiver ID” if you have its ID, or “Import from original app”."
            case .recovery: return "Sensor authentication needs recovery. Scan again using the original Receiver ID."
            case .credentialsRejected: return "The sensor did not accept the available Libre 3 credentials. Check for a newer credential version in Advanced Settings before scanning again."
            case .resources: return "Libre 3 credentials are unavailable. Open Advanced Settings to download them before scanning."
            }
        }())
    }
}

extension Notification.Name {
    static let libre3StateChanged = Notification.Name("libre3StateChanged")
}

extension Libre3PairingRecord {
    /// A saved peripheral can outlive its device-only Keychain credentials after
    /// restore. Keep its UI available for NFC recovery without beginning BLE auth.
    static func unavailable(serial: String) -> Libre3PairingRecord {
        Libre3PairingRecord(serial: serial, receiverID: 0, firmware: "", generation: 0,
                            wearMinutes: 20160, warmupMinutes: 60)
    }
}
