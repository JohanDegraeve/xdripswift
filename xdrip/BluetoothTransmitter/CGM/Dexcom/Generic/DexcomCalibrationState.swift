//
//  DexcomG6CalibrationState.swift
//  xDrip
//
//  Created by Ivan Skoryk on 02.11.2020.
//  Copyright © 2020 Faifly. All rights reserved.
//
//  update for xDrip4iOS : renamed to DexcomCalibrationState

import Foundation

enum DexcomCalibrationState: UInt8 {
    case unknown = 0x00
    case stopped = 0x01
    case warmingUp = 0x02
    case excessNoise = 0x03
    case needsFirstCalibration = 0x04
    case needsSecondCalibration = 0x05
    case okay = 0x06
    case needsCalibration = 0x07
    case calibrationConfused = 0x08
    case calibrationConfused2 = 0x09
    case needsDifferentCalibration = 0x0a
    case sensorFailed = 0x0b
    case sensorFailed2 = 0x0c
    case unusualCalibration = 0x0d
    case insufficientCalibration = 0x0e
    case ended = 0x0f
    case sensorFailed3 = 0x10
    case transmitterProblem = 0x11
    case errors = 0x12
    case sensorFailed4 = 0x13
    case sensorFailed5 = 0x14
    case sensorFailed6 = 0x15
    case sensorFailedStart = 0x16
}

extension DexcomCalibrationState {
    static let stoppedCollection: [DexcomCalibrationState] = [
        .stopped, .ended, .sensorFailed, .sensorFailed2,
        .sensorFailed3, .sensorFailed4, .sensorFailed5,
        .sensorFailed6, .sensorFailedStart
    ]
}

extension DexcomCalibrationState: CustomStringConvertible {
    
    public var description: String {
        
        switch self {
            
        case .unknown:
            return "unknown"
        case .stopped:
            return "stopped"
        case .warmingUp:
            return "warmingUp"
        case .excessNoise:
            return "excessNoise"
        case .needsFirstCalibration:
            return "needsFirstCalibration"
        case .needsSecondCalibration:
            return "needsSecondCalibration"
        case .okay:
            return "okay"
        case .needsCalibration:
            return "needsCalibration"
        case .calibrationConfused:
            return "calibrationConfused"
        case .calibrationConfused2:
            return "calibrationConfused2"
        case .needsDifferentCalibration:
            return "needsDifferentCalibration"
        case .sensorFailed:
            return "sensorFailed"
        case .sensorFailed2:
            return "sensorFailed2"
        case .unusualCalibration:
            return "unusualCalibration"
        case .insufficientCalibration:
            return "insufficientCalibration"
        case .ended:
            return "ended"
        case .sensorFailed3:
            return "sensorFailed3"
        case .transmitterProblem:
            return "transmitterProblem"
        case .errors:
            return "errors"
        case .sensorFailed4:
            return "sensorFailed4"
        case .sensorFailed5:
            return "sensorFailed5"
        case .sensorFailed6:
            return "sensorFailed6"
        case .sensorFailedStart:
            return "sensorFailedStart"
            
        }
    }
}
