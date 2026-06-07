//
//  DexcomAlgorithmState.swift
//  xdrip
//
//  Created by Johan Degraeve on 12/11/2021.
//  Copyright © 2021 Johan Degraeve. All rights reserved.
//

import Foundation

enum DexcomAlgorithmState: UInt8, CustomStringConvertible {
    
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
        case .CalibrationError2: return "Calibration error "
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
        case .expired: return "Expired"
        case .sensorFailed: return "Sensor failed"
        }
        
    }
    
}
