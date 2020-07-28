//
//  SensorState.swift
//  LibreMonitor
//
//  Created by Uwe Petersen on 31.07.16.
//  Copyright © 2016 Uwe Petersen. All rights reserved.
//

import Foundation

/// State of the freestyle libre sensor
///
/// - notYetStarted: 0x01 sensor not yet started
/// - starting:      0x02 sensor is in the starting phase
/// - ready:         0x03 sensor is ready, i.e. in normal operation mode
/// - expired:       0x04 sensor is expired, status after 14 days, less than 14,5 days
/// - shutdown:      0x05 sensor stops operation after 15d after start
/// - failure:       0x06 sensor has an error
/// - unknown:       any other state
public enum LibreSensorState {
    case notYetStarted
    case starting
    case ready
    case expired
    case shutdown
    case failure
    case unknown
    
    init(){
        self = .unknown
    }
    init(stateByte: UInt8) {
        switch stateByte {
        case 01:
            self = .notYetStarted
        case 02:
            self = .starting
        case 03:
            self = .ready
        case 04:
            self = .expired
        case 05:
            self = .shutdown
        case 06:
            self = .failure
        default:
            self = .unknown
        }
    }
    
    var description: String {
        switch self {
        case .notYetStarted:
            return "Sensor not yet startet"
        case .starting:
            return "Sensor in starting phase"
        case .ready:
            return "Sensor is ready"
        case .expired:
            return "Sensor is expired"
        case .shutdown:
            return "Sensor is shut down"
        case .failure:
            return "Sensor has failure"
        default:
            return "Unknown sensor state"
        }
    }
    
    var translatedDescription: String {
        switch self {
        case .notYetStarted:
            return TextsLibreStates.notYetStarted
        case .starting:
            return TextsLibreStates.starting
        case .ready:
            return TextsLibreStates.ready
        case .expired:
            return TextsLibreStates.expired
        case .shutdown:
            return TextsLibreStates.shutdown
        case .failure:
            return TextsLibreStates.failure
        default:
            return TextsLibreStates.unknown
        }
    }
}
