//
//  BackupModels.swift
//  xdrip
//
//  Created by Paul Plant on 13/7/26.
//  Copyright © 2026 Johan Degraeve. All rights reserved.
//

import Foundation

// Defines the archive contract shared by backup creation, inspection and restore.

// MARK: - Backup Options

enum BackupMergeMode: String, Codable, CaseIterable, Identifiable, Sendable {
    case keepCurrent
    case fillGaps
    case replaceRange
    case ignore

    var id: String { rawValue }
}

enum BackupAccountCategory: String, CaseIterable, Hashable, Identifiable, Sendable {
    case nightscout
    case dexcomShare
    case libreLinkUp
    case medtrumEasyView
    case m5Stack

    var id: String { rawValue }

    var title: String {
        switch self {
        case .nightscout: "Nightscout"
        case .dexcomShare: "Dexcom Share"
        case .libreLinkUp: "LibreLinkUp"
        case .medtrumEasyView: "Medtrum EasyView"
        case .m5Stack: "M5Stack Connections"
        }
    }

    var keys: Set<String> {
        switch self {
        case .nightscout:
            [
                UserDefaults.Key.nightscoutUrl.rawValue,
                UserDefaults.Key.nightscoutAPIKey.rawValue,
                UserDefaults.Key.nightscoutToken.rawValue,
                UserDefaults.Key.nightscoutPort.rawValue,
            ]
        case .dexcomShare:
            [
                UserDefaults.Key.dexcomShareAccountName.rawValue,
                UserDefaults.Key.dexcomSharePassword.rawValue,
                UserDefaults.Key.dexcomShareUploadSerialNumber.rawValue,
                UserDefaults.Key.useUSDexcomShareurl.rawValue,
                UserDefaults.Key.dexcomShareRegion.rawValue,
            ]
        case .libreLinkUp:
            [
                UserDefaults.Key.libreLinkUpEmail.rawValue,
                UserDefaults.Key.libreLinkUpPassword.rawValue,
                UserDefaults.Key.libreLinkUpRegion.rawValue,
            ]
        case .medtrumEasyView:
            [
                UserDefaults.Key.medtrumEasyViewEmail.rawValue,
                UserDefaults.Key.medtrumEasyViewPassword.rawValue,
                UserDefaults.Key.medtrumEasyViewSelectedPatientUid.rawValue,
            ]
        case .m5Stack:
            [
                UserDefaults.Key.m5StackBlePassword.rawValue,
                UserDefaults.Key.m5StackWiFiName1.rawValue,
                UserDefaults.Key.m5StackWiFiName2.rawValue,
                UserDefaults.Key.m5StackWiFiName3.rawValue,
                UserDefaults.Key.m5StackWiFiPassword1.rawValue,
                UserDefaults.Key.m5StackWiFiPassword2.rawValue,
                UserDefaults.Key.m5StackWiFiPassword3.rawValue,
            ]
        }
    }

    // A category is offered for restore only when the backup contains its identifying connection value.
    var availabilityKeys: Set<String> {
        switch self {
        case .nightscout:
            [UserDefaults.Key.nightscoutUrl.rawValue]
        case .dexcomShare:
            [UserDefaults.Key.dexcomShareAccountName.rawValue]
        case .libreLinkUp:
            [UserDefaults.Key.libreLinkUpEmail.rawValue]
        case .medtrumEasyView:
            [UserDefaults.Key.medtrumEasyViewEmail.rawValue]
        case .m5Stack:
            [
                UserDefaults.Key.m5StackBlePassword.rawValue,
                UserDefaults.Key.m5StackWiFiName1.rawValue,
                UserDefaults.Key.m5StackWiFiName2.rawValue,
                UserDefaults.Key.m5StackWiFiName3.rawValue,
            ]
        }
    }

    static var allKeys: Set<String> {
        allCases.reduce(into: []) { $0.formUnion($1.keys) }
    }
}

struct BackupOptions: Sendable {
    var includesSettings = true
    var includesAccounts = false
    var includesBgReadings = true
    var includesTreatments = true
    var passphrase: String?
}

// MARK: - Archive Metadata

struct BackupManifest: Codable, Sendable {
    // Increment this when the archive contract changes incompatibly.
    static let currentFormatVersion = 1

    let format: String
    let formatVersion: Int
    let createdAt: Date
    let appVersion: String
    let appBuild: String
    let bgReadingCount: Int
    let treatmentCount: Int
    let firstBgReadingDate: Date?
    let lastBgReadingDate: Date?
    let firstTreatmentDate: Date?
    let includesSettings: Bool
    let includesAccounts: Bool
    let isPasswordProtected: Bool
}

struct CreatedBackup: Sendable {
    let url: URL
    let manifest: BackupManifest
}

struct BackupPayload: Codable, Sendable {
    let manifest: BackupManifest
    let settings: [String: BackupPropertyListValue]?
    let accounts: [String: BackupPropertyListValue]?
    let alertTypes: [BackupAlertType]
    let bgReadings: [BackupBgReading]
    let treatments: [BackupTreatment]
}

// MARK: - Settings and Alerts

struct BackupAlertType: Codable, Sendable {
    let enabled: Bool
    let name: String
    let overrideMute: Bool
    let snooze: Bool
    let snoozePeriod: Int16
    let soundName: String?
    let vibrate: Bool
    let entries: [BackupAlertEntry]
}

struct BackupAlertEntry: Codable, Sendable {
    let alertKind: Int16
    let isDisabled: Bool
    let start: Int16
    let triggerValue: Int16
    let value: Int16
}

struct BackupPropertyListValue: Codable, Sendable {
    let data: Data

    init(_ value: Any) throws {
        data = try PropertyListSerialization.data(
            fromPropertyList: value,
            format: .binary,
            options: 0
        )
    }

    func decoded() throws -> Any {
        try PropertyListSerialization.propertyList(from: data, options: [], format: nil)
    }
}

struct BackupEncryptedData: Codable, Sendable {
    let salt: Data
    let iv: Data
    let ciphertextAndTag: Data
    let iterations: Int
}

// MARK: - Core Data Records

struct BackupBgReading: Codable, Sendable {
    let id: String
    let timeStamp: Date
    let a: Double
    let adjustedValue: Double?
    let ageAdjustedRawValue: Double
    let backfilledAt: Date?
    let b: Double
    let c: Double
    let calculatedValue: Double
    let calculatedValueSlope: Double
    let calibrationFlag: Bool
    let deviceName: String?
    // finalValue is retained for validation because Core Data derives it from the stored value fields.
    let finalValue: Double
    let hideSlope: Bool
    let isSuppressedByFiveMinuteCadence: Bool
    let ra: Double
    let rawData: Double
    let rb: Double
    let rc: Double
    let smoothedValue: Double?
}

struct BackupTreatment: Codable, Sendable {
    let date: Date
    let enteredBy: String?
    let id: String
    let nightscoutEventType: String?
    let notes: String?
    let treatmentDeleted: Bool
    let treatmentType: Int16
    let uploaded: Bool
    let value: Double
    let valueSecondary: Double
}

struct BackupInspection: Sendable {
    let payload: BackupPayload
}

// MARK: - Restore Result

enum BackupAccountRestoreStatus: Equatable, Sendable {
    case restored
    case notRestored
    case unavailable
}

struct BackupRestoreResult: Sendable {
    let bgReadingsAdded: Int
    let bgReadingsSkipped: Int
    let firstBgReadingAppliedAt: Date?
    let treatmentsAdded: Int
    let treatmentsSkipped: Int
    let settingsRestored: Int
    let accountsRestored: Int
    let accountStatuses: [BackupAccountCategory: BackupAccountRestoreStatus]
}

// MARK: - Errors

enum BackupError: LocalizedError {
    case invalidFile
    case unsupportedVersion(Int)
    case incorrectPassphrase
    case missingPassphrase
    case finalValueMismatch(String)

    var errorDescription: String? {
        switch self {
        case .invalidFile:
            Texts_SettingsView.backupErrorInvalidFile
        case let .unsupportedVersion(version):
            Texts_SettingsView.backupErrorUnsupportedVersion(version)
        case .incorrectPassphrase:
            Texts_SettingsView.backupErrorIncorrectPassword
        case .missingPassphrase:
            Texts_SettingsView.backupErrorMissingPassword
        case let .finalValueMismatch(id):
            Texts_SettingsView.backupErrorFinalValueMismatch(id)
        }
    }

    /// Returns a support-safe error without including record identifiers or archive contents.
    var traceDescription: String {
        switch self {
        case .invalidFile: "invalid backup file"
        case let .unsupportedVersion(version): "unsupported backup format version \(version)"
        case .incorrectPassphrase: "incorrect password or damaged encrypted backup"
        case .missingPassphrase: "missing backup password"
        case .finalValueMismatch: "BG reading final value validation failed"
        }
    }
}
