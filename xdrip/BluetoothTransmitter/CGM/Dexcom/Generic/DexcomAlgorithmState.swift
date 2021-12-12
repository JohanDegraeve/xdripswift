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
    
    public var description: String {
        
        switch self {
            
        case .None: return "None"
        case .SessionStopped: return "Session Stopped"
        case .SensorWarmup: return "Sensor Warmup"
        case .excessNoise: return "excess Noise"
        case .FirstofTwoBGsNeeded: return "First of Two BGs Needed"
        case .SecondofTwoBGsNeeded: return "Second of Two BGs Needed"
        case .okay: return "In Calibration/Okay"
        case .needsCalibration: return "needs Calibration"
        case .CalibrationError1: return "Calibration Error 1"
        case .CalibrationError2: return "Calibration Error "
        case .CalibrationLinearityFitFailure: return "Calibration LinearityFitFailure"
        case .SensorFailedDuetoCountsAberration: return "Sensor Failed Due to Counts Aberration"
        case .SensorFailedDuetoResidualAberration: return "Sensor Failed Due to Residual Aberration"
        case .OutOfCalibrationDueToOutlier: return "Out Of Calibration Due To Outlier"
        case .OutlierCalibrationRequest: return "Outlier Calibration Request"
        case .SessionExpired: return "Session Expired"
        case .SessionFailedDueToUnrecoverableError: return "Session Failed Due To Unrecoverable Error"
        case .SessionFailedDueToTransmitterError: return "Session Failed Due To Transmitter Error"
        case .TemporarySensorIssue: return "Temporary Sensor Issue"
        case .SensorFailedDueToProgressiveSensorDecline: return "Sensor Failed Due To Progressive Sensor Decline"
        case .SensorFailedDueToHighCountsAberration: return "Sensor Failed Due To High Counts Aberration"
        case .SensorFailedDueToLowCountsAberration: return "Sensor Failed Due To Low Counts Aberration"
        case .SensorFailedDueToRestart: return "Sensor Failed Due To Restart"

        }
        
    }
    
}
