//
//  DexcomAlgorithmState.swift
//  xdrip
//
//  Created by Johan Degraeve on 12/11/2021.
//  Copyright © 2021 Johan Degraeve. All rights reserved.
//

import Foundation

enum DexcomSensorStatusIndicatorColor {
    case green
    case yellow
    case orange
    case red
}

enum DexcomAlgorithmState: UInt8, CustomStringConvertible, CaseIterable {
    case None = 0x00
    case SessionStopped = 0x01
    case SensorWarmup = 0x02
    case excessNoise = 0x03
    case FirstofTwoBGsNeeded = 0x04
    case SecondofTwoBGsNeeded = 0x05
    case okay = 0x06
    case needsCalibration = 0x07
    case CalibrationError1 = 0x08
    case CalibrationError2 = 0x09
    case CalibrationLinearityFitFailure = 0x0A
    case SensorFailedDuetoCountsAberration = 0x0B
    case SensorFailedDuetoResidualAberration = 0x0C
    case OutOfCalibrationDueToOutlier = 0x0D
    case OutlierCalibrationRequest = 0x0E
    case SessionExpired = 0x0F
    case SessionFailedDueToUnrecoverableError = 0x10
    case SessionFailedDueToTransmitterError = 0x11
    case TemporarySensorIssue = 0x12
    case SensorFailedDueToProgressiveSensorDecline = 0x13
    case SensorFailedDueToHighCountsAberration = 0x14
    case SensorFailedDueToLowCountsAberration = 0x15
    case SensorFailedDueToRestart = 0x16
    case questionMarks = 0x18
    // xDrip+ documents `0x1B` as SensorFailed8. G7 can return it in a status `0x80` frame while
    // retaining the final glucose sample. The user-facing text deliberately omits the internal
    // number because it does not help someone understand what action is required.
    // Reference: https://github.com/NightscoutFoundation/xDrip/blob/master/app/src/main/java/com/eveningoutpost/dexdrip/g5model/CalibrationState.java
    case SensorFailed8 = 0x1B
    case expired = 0x24
    case sensorFailed = 0x25

    public var description: String {
        switch self {
        case .None: return "None"
        case .SessionStopped: return "Session stopped"
        case .SensorWarmup: return "Sensor warmup"
        case .excessNoise: return "excess noise"
        case .FirstofTwoBGsNeeded: return "First of two BG readings needed"
        case .SecondofTwoBGsNeeded: return "Second of two BG readings needed"
        case .okay: return "OK / Calibrated"
        case .needsCalibration: return "needs calibration"
        case .CalibrationError1: return "Calibration error 1"
        case .CalibrationError2: return "Calibration error 2"
        case .CalibrationLinearityFitFailure: return "Calibration LinearityFitFailure"
        case .SensorFailedDuetoCountsAberration: return "Sensor failed due to counts aberration"
        case .SensorFailedDuetoResidualAberration: return "Sensor failed due to residual aberration"
        case .OutOfCalibrationDueToOutlier: return "Out of calibration due to outlier"
        case .OutlierCalibrationRequest: return "Outlier calibration request"
        case .SessionExpired: return "Session expired"
        case .SessionFailedDueToUnrecoverableError: return "Session failed due to unrecoverable error"
        case .SessionFailedDueToTransmitterError: return "Session failed due to transmitter error"
        case .TemporarySensorIssue: return "Temporary sensor issue"
        case .SensorFailedDueToProgressiveSensorDecline: return "Sensor failed due to progressive sensor decline"
        case .SensorFailedDueToHighCountsAberration: return "Sensor failed due to high counts aberration"
        case .SensorFailedDueToLowCountsAberration: return "Sensor failed due to low counts aberration"
        case .SensorFailedDueToRestart: return "Sensor failed due to restart"
        case .questionMarks: return "???"
        case .SensorFailed8: return "Sensor failed"
        case .expired: return "Expired"
        case .sensorFailed: return "Sensor failed"
        }
    }

    var indicatorColor: DexcomSensorStatusIndicatorColor {
        switch self {
        case .okay, .needsCalibration:
            return .green
        case .SensorWarmup, .FirstofTwoBGsNeeded, .SecondofTwoBGsNeeded:
            return .yellow
        case .excessNoise, .OutOfCalibrationDueToOutlier, .OutlierCalibrationRequest, .TemporarySensorIssue, .questionMarks:
            return .orange
        default:
            return .red
        }
    }

    static func indicatorColor(forDescription description: String) -> DexcomSensorStatusIndicatorColor? {
        allCases.first { $0.description == description }?.indicatorColor
    }

    /// Converts the transmitter's algorithm state into the shared sensor-health model.
    ///
    /// Temporary states keep one ongoing warning episode that can later recover. Terminal states
    /// drive the failure alert and root banner. Normal operational states return `recovered`, which
    /// closes an earlier temporary episode without inventing a separate G7-only health lifecycle.
    /// This mapping is deliberately independent of authentication. A valid authenticated glucose
    /// response can still report a failed physical sensor.
    var sensorHealthEvent: CGMSensorHealthEvent {
        switch self {
        case .excessNoise:
            return .temporary(source: .dexcom, reason: .dexcomExcessNoise)
        case .TemporarySensorIssue:
            return .temporary(source: .dexcom, reason: .dexcomTemporarySensorIssue)
        case .questionMarks:
            return .temporary(source: .dexcom, reason: .dexcomQuestionMarks)
        case .SessionFailedDueToTransmitterError:
            return .terminal(source: .dexcom, reason: .dexcomTransmitterFailure)
        case .SensorFailedDuetoCountsAberration,
             .SensorFailedDuetoResidualAberration,
             .SessionFailedDueToUnrecoverableError,
             .SensorFailedDueToProgressiveSensorDecline,
             .SensorFailedDueToHighCountsAberration,
             .SensorFailedDueToLowCountsAberration,
             .SensorFailedDueToRestart,
             .SensorFailed8,
             .sensorFailed:
            return .terminal(source: .dexcom, reason: .dexcomSensorFailure)
        default:
            return .recovered(source: .dexcom)
        }
    }
}
