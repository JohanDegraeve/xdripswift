//
//  DexcomG6CalibrationResponseType.swift
//  xDrip
//
//  Created by Dmitry on 29.12.2020.
//  Copyright © 2020 Faifly. All rights reserved.
//

import Foundation

enum DexcomCalibrationResponseType: UInt8 {
    case okay = 0x00
    case codeOne = 0x01
    case secondCalibrationNeeded = 0x06
    case rejected = 0x08
    case sensorStopped = 0x0B
    case duplicate = 0x0D
    case notReady = 0x0E
    case unableToDecode = 0xFF
    
    var description: String {
        
        switch self {
            
        case .okay:
            return "okay"
            
        case .codeOne:
            return "codeOne"
            
        case .secondCalibrationNeeded:
            return "secondCalibrationNeeded"
            
        case .rejected:
            return "rejected"
            
        case .sensorStopped:
            return "sensorStopped"
            
        case .duplicate:
            return "duplicate"
            
        case .notReady:
            return "notReady"
            
        case .unableToDecode:
            return "unableToDecode"
            
        }
        
    }
}

extension DexcomCalibrationResponseType {
    static let validCollection: [DexcomCalibrationResponseType] = [
        .okay, .secondCalibrationNeeded, .duplicate
    ]
}
