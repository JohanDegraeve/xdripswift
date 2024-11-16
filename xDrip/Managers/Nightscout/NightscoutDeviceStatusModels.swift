//
//  NightscoutDeviceStatusModels.swift
//  xdrip
//
//  Created by Paul Plant on 30/10/24.
//  Copyright © 2024 Johan Degraeve. All rights reserved.
//
import Foundation
import SwiftUICore

// MARK: Internal DeviceStatus model

/// Struct to hold internal DeviceStatus
struct NightscoutDeviceStatus: Codable {
    var updatedDate: Date = .distantPast
    var lastCheckedDate: Date = .distantPast
    
    var didLoop: Bool = false
    var lastLoopDate: Date = .distantPast
    
    var createdAt: Date = .distantPast
    var device: String?
    var appVersion: String?
    var id: String = ""
    var mills: Int = 0
    var utcOffset: Int = 0
    
    var activeProfile: String?
    var baseBasalRate: Double?
    var bolusVolume: Double?
    var cob: Double?
    var currentTarget: Double?
    var duration: Int?
    var eventualBG: Double?
    var iob: Double?
    var isf: Double?
    var insulinReq: Double?
    var rate: Double?
    var reason: String?
    var sensitivityRatio: Double?
    var tdd: Double?
    var timestamp: Date?
    var error: String?
    // let units: Double?
    
    var pumpBatteryPercent: Int?
    var pumpClock: Date?
    var pumpID: String?
    var pumpIsBolusing: Bool?
    var pumpIsSuspended: Bool?
    var pumpStatus: String?
    var pumpStatusTimestamp: Date?
    var pumpManufacturer: String?
    var pumpModel: String?
    var pumpReservoir: Double?
    
    var uploaderBattery: Int?
    var uploaderIsCharging: Bool?
    
    // return true if data has been written after initialization
    func hasData() -> Bool {
        return updatedDate != .distantPast
    }
    
    // return the AID system name
    func systemName() -> String? {
        if let device {
            switch device {
            case let str where str.startsWith("loop://"):
                return "Loop"
            case let str where str.startsWith("openaps://"):
                return "AAPS"
            case "Trio":
                return "Trio"
            default:
                return nil
            }
        }
        
        return nil
    }
    
    // return the device name
    func deviceName() -> String? {
        if let device {
            let deviceName = device.components(separatedBy: "://")
            
            if deviceName.count > 1 {
                var deviceNameString = deviceName[1]
                
                if !deviceNameString.startsWith("iPhone") {
                    deviceNameString = deviceNameString.capitalized
                }
                
                return deviceNameString
            }
        }
        
        return nil
    }
    
    func reasonValuesArray() -> [String]? {
        if let reason {
            let array = reason.components(separatedBy: ", ")
            return array
        }
        else {
            return nil
        }
    }
    
    func uploaderBatteryImage() -> (batteryImage: Image, batteryColor: Color)? {
        if let uploaderBattery {
            switch uploaderBattery {
            case 0...10:
                return (Image(systemName: "battery.0percent"), Color(.systemRed))
            case 11...25:
                return (Image(systemName: "battery.25percent"), Color(.systemYellow))
            case 26...65:
                return (Image(systemName: "battery.50percent"), Color(.colorSecondary))
            case 66...90:
                return (Image(systemName: "battery.75percent"), Color(.colorSecondary))
            default:
                return (Image(systemName: "battery.100percent"), Color(.colorSecondary))
            }
        }
        
        return nil
    }
    
    func uploaderBatteryImageRVCStatusView() -> (batteryImageSystemName: String, batteryImageColor: UIColor)? {
        if let uploaderBattery, let uploaderIsCharging, !uploaderIsCharging {
            switch uploaderBattery {
            case 0...10:
                return ("battery.0percent", UIColor(.red))
            case 11...25:
                return ("battery.25percent", UIColor(.yellow))
            default:
                return nil
            }
        }
        
        return nil
    }
    
    func uploaderBatteryChargingImage() -> (chargingImage: Image, chargingColor: Color)? {
        if let uploaderIsCharging {
            if uploaderIsCharging {
                return (Image(systemName: "bolt"), Color(.systemGreen))
            } else {
                return nil //(Image(systemName: "bolt.slash"), Color(.colorTertiary))
            }
        }
        
        return nil
    }
}

// MARK: OpenAPS DeviceStatus model

/// Struct to parse OpenAPS DeviceStatus downloaded from Nightscout
struct NightscoutDeviceStatusOpenAPSResponse: Codable {
    struct OpenAPS: Codable {
        struct Suggested: Codable {
            let cob: Double?
            let cr: Double?
            let currentTarget: Double?
            let duration: Int?
            let eventualBG: Double?
            let iob: Double?
            let isf: Double?
            let insulinReq: Double?
            let rate: Double?
            let reason: String?
            let reservoir: Double?
            let sensitivityRatio: Double?
            let tdd: Double?
            let timestamp: String?
            let units: Double?
            let variableSens: Double?
            
            private enum CodingKeys: String, CodingKey {
                case cob = "COB"
                case cr = "CR"
                case currentTarget = "current_target"
                case duration
                case eventualBG
                case iob = "IOB"
                case isf = "ISF"
                case insulinReq
                case rate
                case reason
                case reservoir
                case sensitivityRatio
                case tdd = "TDD"
                case timestamp
                case units
                case variableSens = "variable_sens"
            }
        }
        
        let enacted: Suggested?
        let suggested: Suggested?
        let version: String?
        
        private enum CodingKeys: String, CodingKey {
            case enacted, suggested, version
        }
    }
    
    struct Pump: Codable {
        struct Battery: Codable {
            let percent: Int?
        }
        
        struct Status: Codable {
            let bolusing: Bool?
            let status: String?
            let suspended: Bool?
            let timestamp: String?
        }
        
        struct Extended: Codable {
            let version: String?
            let activeProfile: String?
            let baseBasalRate: Double?
            
            private enum CodingKeys: String, CodingKey {
                case version = "Version"
                case activeProfile = "ActiveProfile"
                case baseBasalRate = "BaseBasalRate"
            }
        }
        
        let battery: Battery?
        let reservoir: Double?
        let clock: String?
        let status: Status?
        let extended: Extended?
    }
    
    struct Uploader: Codable {
        let battery: Int?
    }
    
    let createdAt: String?
    let device: String?
    let id: String?
    let isCharging: Bool?
    let mills: Int?
    let openAPS: OpenAPS?
    let pump: Pump?
    let uploader: Uploader?
    let uploaderBattery: Int?
    let utcOffset: Int?
    
    private enum CodingKeys: String, CodingKey {
        case createdAt = "created_at"
        case device
        case id = "_id"
        case isCharging
        case mills
        case openAPS = "openaps"
        case pump
        case uploader
        case uploaderBattery
        case utcOffset
    }
}

// MARK: Loop DeviceStatus model

/// Struct to parse OpenAPS DeviceStatus downloaded from Nightscout
struct NightscoutDeviceStatusLoopResponse: Codable {
    struct Loop: Codable {
        struct AutomaticDoseRecommendation: Codable {
            let bolusVolume: Double?
            let timestamp: String?
        }
        
        struct COB: Codable {
            let cob: Double?
            let timestamp: String?
        }
        
        struct Enacted: Codable {
            let bolusVolume: Double?
            let duration: Int?
            let rate: Double?
            let received: Bool?
            let timestamp: String?
        }
        
        struct IOB: Codable {
            let iob: Double?
            let timestamp: String?
        }
        
        struct Predicted: Codable {
          let startDate: String?
          let values: [Double]?
        }
        
        let automaticDoseRecommendation: AutomaticDoseRecommendation?
        let cob: COB?
        let enacted: Enacted?
        let failureReason: String?
        let iob: IOB?
        let name: String?
        let predicted: Predicted?
        let recommendedBolus: Double?
        let timestamp: String?
        let version: String?
    }
    
    struct Override: Codable {
        let active: Bool?
        let timestamp: String?
    }
    
    struct Pump: Codable {
        let bolusing: Bool?
        let clock: String?
        let manufacturer: String?
        let model: String?
        let pumpID: String?
        let reservoir: Double?
        let reservoir_display_override: String?
        let secondsFromGMT: Int?
        let suspended: Bool?
    }
    
    struct Uploader: Codable {
        let battery: Int?
        let name: String?
        let timestamp: String?
    }
    
    let createdAt: String?
    let device: String?
    let id: String?
    let loop: Loop?
    let mills: Int?
    let override: Override?
    let pump: Pump?
    let uploader: Uploader?
    let utcOffset: Int?
    
    private enum CodingKeys: String, CodingKey {
        case createdAt = "created_at"
        case device
        case id = "_id"
        case loop
        case mills
        case override
        case pump
        case uploader
        case utcOffset
    }
}
