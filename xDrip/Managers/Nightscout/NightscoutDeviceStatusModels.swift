//
//  NightscoutDeviceStatusModels.swift
//  xdrip
//
//  Created by Paul Plant on 30/10/24.
//  Copyright © 2024 Johan Degraeve. All rights reserved.
//
import Foundation

// MARK: Internal DeviceStatus model

/// Struct to hold internal DeviceStatus
struct NightscoutDeviceStatus: Codable {
    var updatedDate: Date = .distantPast
    var lastCheckedDate: Date = .distantPast
    
    var createdAt: Date = .distantPast
    var device: String?
    var id: String = ""
    var mills: Int = 0
    var utcOffset: Int = 0
    
    var cob: Int?
    var currentTarget: Int?
    var duration: Int?
    var eventualBG: Int?
    var iob: Double?
    var isf: Int?
    var insulinReq: Double?
    var rate: Double?
    var reason: String?
    var reservoir: Double?
    var sensitivityRatio: Double?
    var tdd: Double?
    var timestamp: Date?
    // let units: Double?
    
    var pumpBatteryPercent: Int?
    var pumpClock: Date?
    
    var pumpIsBolusing: Bool?
    var pumpStatus: String?
    var pumpIsSuspended: Bool?
    var pumpStatusTimestamp: String?
    
    var uploaderBattery: Int?
    
    // the canula age - not part of the nightscout Device Status, but we'll keep it here internally
    var CAGE: Double?
    
    // return true if data has been written after initialization
    func hasData() -> Bool {
        return updatedDate != .distantPast
    }
}

// MARK: Trio DeviceStatus model

/// Struct to parse Trio DeviceStatus downloaded from Nightscout
struct NightscoutDeviceStatusTrioResponse: Codable {
    struct OpenAPS: Codable {
        struct Enacted: Codable {
            let cob: Int?
            let cr: Double?
            let currentTarget: Int?
            let duration: Int?
            let eventualBG: Int?
            let iob: Double?
            let isf: Int?
            let insulinReq: Double?
            let rate: Double?
            let reason: String?
            let reservoir: Double?
            let sensitivityRatio: Double?
            let tdd: Double?
            let timestamp: String?
            let units: Double?
            
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
            }
        }
        
        let enacted: Enacted?
        
        private enum CodingKeys: String, CodingKey {
            case enacted
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
        
        let battery: Battery?
        let clock: String?
        let status: Status?
    }
    
    struct Uploader: Codable {
        let battery: Int?
    }
    
    let createdAt: String?
    let device: String?
    let id: String?
    let mills: Int?
    let openAPS: OpenAPS?
    let pump: Pump?
    let uploader: Uploader?
    let utcOffset: Int?
    
    private enum CodingKeys: String, CodingKey {
        case createdAt = "created_at"
        case device
        case id = "_id"
        case mills
        case openAPS = "openaps"
        case pump
        case uploader
        case utcOffset
    }
}

/*
 
 struct NightscoutDeviceStatusResponse: Codable {
 struct Openap: Codable {
 struct Enacted: Codable {
 struct Insulin: Codable {
 let bolus: Double?
 let scheduledBasal: Double?
 let tDD: Double?
 let tempBasal: Double?
 
 private enum CodingKeys: String, CodingKey {
 case bolus
 case scheduledBasal = "scheduled_basal"
 case tDD = "TDD"
 case tempBasal = "temp_basal"
 }
 }
 
 struct PredBG: Codable {
 let cOB: [Int]?
 let iOB: [Int]?
 let uAM: [Int]?
 let zT: [Int]?
 
 private enum CodingKeys: String, CodingKey {
 case cOB = "COB"
 case iOB = "IOB"
 case uAM = "UAM"
 case zT = "ZT"
 }
 }
 
 let bg: Int?
 let cOB: Int?
 let currentTarget: Int?
 let deliverAt: String?
 let duration: Int?
 let eventualBG: Int?
 let expectedDelta: Double?
 let iOB: Double?
 let iSF: Int?
 let insulin: Insulin?
 let insulinForManualBolus: Double?
 let insulinReq: Double?
 let manualBolusErrorString: Int?
 let minDelta: Double?
 let minGuardBG: Int?
 let predBGs: PredBG?
 let rate: Double?
 let reason: String?
 let recieved: Bool?
 let reservoir: Double?
 let sensitivityRatio: Double?
 let tDD: Double?
 let temp: String?
 let threshold: Int?
 let timestamp: String?
 let units: Double?
 
 private enum CodingKeys: String, CodingKey {
 case bg
 case cOB = "COB"
 case currentTarget = "current_target"
 case deliverAt
 case duration
 case eventualBG
 case expectedDelta
 case iOB = "IOB"
 case iSF = "ISF"
 case insulin
 case insulinForManualBolus
 case insulinReq
 case manualBolusErrorString
 case minDelta
 case minGuardBG
 case predBGs
 case rate
 case reason
 case recieved
 case reservoir
 case sensitivityRatio
 case tDD = "TDD"
 case temp
 case threshold
 case timestamp
 case units
 }
 }
 
 struct Iob: Codable {
 struct IobWithZeroTemp: Codable {
 let activity: Double?
 let basaliob: Double?
 let bolusinsulin: Double?
 let bolusiob: Double?
 let iob: Double?
 let netbasalinsulin: Double?
 let time: String?
 }
 
 struct LastTemp: Codable {
 let date: Int?
 let duration: Double?
 let rate: Double?
 let startedAt: String?
 let timestamp: String?
 
 private enum CodingKeys: String, CodingKey {
 case date
 case duration
 case rate
 case startedAt = "started_at"
 case timestamp
 }
 }
 
 let activity: Double?
 let basaliob: Double?
 let bolusinsulin: Double?
 let bolusiob: Double?
 let iob: Double?
 let iobWithZeroTemp: IobWithZeroTemp?
 let lastBolusTime: Int?
 let lastTemp: LastTemp?
 let netbasalinsulin: Double?
 let time: String?
 }
 
 struct Suggested: Codable {
 struct Insulin: Codable {
 let bolus: Double?
 let scheduledBasal: Double?
 let tDD: Double?
 let tempBasal: Double?
 
 private enum CodingKeys: String, CodingKey {
 case bolus
 case scheduledBasal = "scheduled_basal"
 case tDD = "TDD"
 case tempBasal = "temp_basal"
 }
 }
 
 struct PredBG: Codable {
 let cOB: [Int]?
 let iOB: [Int]?
 let uAM: [Int]?
 let zT: [Int]?
 
 private enum CodingKeys: String, CodingKey {
 case cOB = "COB"
 case iOB = "IOB"
 case uAM = "UAM"
 case zT = "ZT"
 }
 }
 
 let bg: Int?
 let cOB: Int?
 let currentTarget: Int?
 let deliverAt: String?
 let duration: Int?
 let eventualBG: Int?
 let expectedDelta: Double?
 let iOB: Double?
 let iSF: Int?
 let insulin: Insulin?
 let insulinForManualBolus: Double?
 let insulinReq: Double?
 let manualBolusErrorString: Int?
 let minDelta: Double?
 let minGuardBG: Int?
 let predBGs: PredBG?
 let rate: Double?
 let reason: String?
 let reservoir: Double?
 let sensitivityRatio: Double?
 let tDD: Double?
 let temp: String?
 let threshold: Int?
 let timestamp: String?
 let units: Double?
 
 private enum CodingKeys: String, CodingKey {
 case bg
 case cOB = "COB"
 case currentTarget = "current_target"
 case deliverAt
 case duration
 case eventualBG
 case expectedDelta
 case iOB = "IOB"
 case iSF = "ISF"
 case insulin
 case insulinForManualBolus
 case insulinReq
 case manualBolusErrorString
 case minDelta
 case minGuardBG
 case predBGs
 case rate
 case reason
 case reservoir
 case sensitivityRatio
 case tDD = "TDD"
 case temp
 case threshold
 case timestamp
 case units
 }
 }
 
 let enacted: Enacted?
 let iob: Iob?
 let suggested: Suggested?
 let version: String?
 }
 
 struct Pump: Codable {
 struct Battery: Codable {
 let display: Bool?
 let percent: Int?
 let string: String?
 }
 
 struct Status: Codable {
 let bolusing: Bool?
 let status: String?
 let suspended: Bool?
 let timestamp: String?
 }
 
 let battery: Battery?
 let clock: String?
 let reservoir: Double?
 let status: Status?
 }
 
 struct Uploader: Codable {
 let battery: Int?
 }
 
 let createdAt: String?
 let device: String?
 let id: String?
 let mills: Int?
 let openaps: Openap?
 let pump: Pump?
 let uploader: Uploader?
 let utcOffset: Int?
 
 private enum CodingKeys: String, CodingKey {
 case createdAt = "created_at"
 case device
 case id = "_id"
 case mills
 case openaps
 case pump
 case uploader
 case utcOffset
 }
 }
 
 */
