//
//  SensorHealthModels.swift
//  xdrip
//
//  Created by Paul Plant on 2/8/26.
//  Copyright © 2026 Johan Degraeve. All rights reserved.
//

import Foundation
import UserNotifications

/// Presentation urgency for one sensor-health episode.
enum SensorHealthSeverity: Int, Codable, Comparable {
    case caution = 0
    case actionRequired = 1
    case terminal = 2

    static func < (lhs: SensorHealthSeverity, rhs: SensorHealthSeverity) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

/// Groups related manufacturer and calculated conditions into one episode type.
enum SensorHealthIssueKind: String, Codable {
    case persistentNoise
    case flatline
    case temporaryTransmitterIssue
    case terminalFailure

    var priority: Int {
        switch self {
        case .temporaryTransmitterIssue:
            return 0
        case .persistentNoise:
            return 1
        case .flatline:
            return 2
        case .terminalFailure:
            return 3
        }
    }
}

/// Identifies the component that reported the condition.
enum SensorHealthSource: String, Codable {
    case calculatedNoise
    case dexcom
    case libre
}

/// Identifies the detail screen opened from the Home banner.
enum SensorHealthDestination: String, Codable {
    case sensorManagement
    case bluetoothPeripheral
}

/// Preserves the exact decoded or calculated reason for user guidance.
enum SensorHealthReason: String, Codable {
    case persistentNoise
    case flatline
    case dexcomExcessNoise
    case dexcomTemporarySensorIssue
    case dexcomQuestionMarks
    case dexcomSensorFailure
    case dexcomTransmitterFailure
    case libreSensorFailure
    case dexcomTransmitterBatteryFailure
}

/// A persisted sensor-health episode shared by Home and notification handling.
struct SensorHealthIssue: Codable, Equatable, Identifiable {
    let id: String
    let kind: SensorHealthIssueKind
    let severity: SensorHealthSeverity
    let source: SensorHealthSource
    let reason: SensorHealthReason
    let firstSeen: Date
    let sensorSessionID: String
    let destination: SensorHealthDestination

    var title: String {
        switch reason {
        case .persistentNoise:
            return Texts_HomeView.sensorHealthPersistentNoiseTitle
        case .flatline:
            return Texts_HomeView.sensorHealthFlatlineTitle
        case .dexcomExcessNoise, .dexcomTemporarySensorIssue, .dexcomQuestionMarks:
            return Texts_HomeView.sensorHealthTemporaryIssueTitle
        case .dexcomSensorFailure, .libreSensorFailure:
            return Texts_HomeView.sensorHealthSensorFailedTitle
        case .dexcomTransmitterFailure, .dexcomTransmitterBatteryFailure:
            return Texts_HomeView.sensorHealthTransmitterFailedTitle
        }
    }

    var guidance: String {
        switch reason {
        case .persistentNoise:
            return Texts_HomeView.sensorHealthPersistentNoiseGuidance
        case .flatline:
            return Texts_HomeView.sensorHealthFlatlineGuidance
        case .dexcomExcessNoise, .dexcomTemporarySensorIssue, .dexcomQuestionMarks:
            return Texts_HomeView.sensorHealthTemporaryIssueGuidance
        case .dexcomSensorFailure, .libreSensorFailure:
            return Texts_HomeView.sensorHealthSensorFailedGuidance
        case .dexcomTransmitterFailure, .dexcomTransmitterBatteryFailure:
            return Texts_HomeView.sensorHealthTransmitterFailedGuidance
        }
    }
}

/// Typed boundary between transmitter decoding and sensor-health presentation.
enum CGMSensorHealthEvent: Equatable {
    case recovered(source: SensorHealthSource)
    case temporary(source: SensorHealthSource, reason: SensorHealthReason)
    case terminal(source: SensorHealthSource, reason: SensorHealthReason)
}

/// Values used to build one isolated sensor-health test presentation.
struct SensorHealthTestIssueValues {
    let kind: SensorHealthIssueKind
    let severity: SensorHealthSeverity
    let source: SensorHealthSource
    let reason: SensorHealthReason
    let destination: SensorHealthDestination
}

/// Synthetic sensor-health presentations available from the hidden Home test menu.
enum SensorHealthTestKind: CaseIterable {
    case persistentNoise
    case flatline
    case temporarySensorIssue
    case sensorFailure
    case transmitterFailure

    var issueValues: SensorHealthTestIssueValues {
        switch self {
        case .persistentNoise:
            return SensorHealthTestIssueValues(
                kind: .persistentNoise,
                severity: .actionRequired,
                source: .calculatedNoise,
                reason: .persistentNoise,
                destination: .sensorManagement
            )
        case .flatline:
            return SensorHealthTestIssueValues(
                kind: .flatline,
                severity: .actionRequired,
                source: .calculatedNoise,
                reason: .flatline,
                destination: .sensorManagement
            )
        case .temporarySensorIssue:
            return SensorHealthTestIssueValues(
                kind: .temporaryTransmitterIssue,
                severity: .caution,
                source: .dexcom,
                reason: .dexcomTemporarySensorIssue,
                destination: .bluetoothPeripheral
            )
        case .sensorFailure:
            return SensorHealthTestIssueValues(
                kind: .terminalFailure,
                severity: .terminal,
                source: .dexcom,
                reason: .dexcomSensorFailure,
                destination: .bluetoothPeripheral
            )
        case .transmitterFailure:
            return SensorHealthTestIssueValues(
                kind: .terminalFailure,
                severity: .terminal,
                source: .dexcom,
                reason: .dexcomTransmitterFailure,
                destination: .bluetoothPeripheral
            )
        }
    }

    var testMenuTitle: String {
        switch self {
        case .persistentNoise:
            return Texts_HomeView.sensorHealthTestPersistentNoise
        case .flatline:
            return Texts_HomeView.sensorHealthTestFlatline
        case .temporarySensorIssue:
            return Texts_HomeView.sensorHealthTestTemporaryIssue
        case .sensorFailure:
            return Texts_HomeView.sensorHealthTestSensorFailure
        case .transmitterFailure:
            return Texts_HomeView.sensorHealthTestTransmitterFailure
        }
    }
}

/// Notification operations used by the episode manager and its tests.
protocol SensorHealthNotificationScheduling: AnyObject {
    func add(_ request: UNNotificationRequest, withCompletionHandler completionHandler: (@Sendable (Error?) -> Void)?)
    func removeDeliveredNotifications(withIdentifiers identifiers: [String])
    func removePendingNotificationRequests(withIdentifiers identifiers: [String])
}

extension UNUserNotificationCenter: SensorHealthNotificationScheduling {}

/// The narrow alarm-system entry point for a confirmed terminal failure.
///
/// Other sensor-health episodes must not use this protocol. They have no alarm cycle, repeat
/// schedule or snooze state and remain owned by `SensorHealthIssueManager`.
protocol SensorHealthOneOffAlarmRaising: AnyObject {
    func raiseOneOffSensorFailureAlarm(_ issue: SensorHealthIssue)
}
