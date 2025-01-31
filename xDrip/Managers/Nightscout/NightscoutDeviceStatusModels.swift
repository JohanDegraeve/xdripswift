//
//  NightscoutDeviceStatusModels.swift
//  xdrip
//
//  Created by Paul Plant on 30/10/24.
//  Copyright © 2024 Johan Degraeve. All rights reserved.
//
import Foundation
import SwiftUI

// MARK: Internal DeviceStatus model

/// Struct to hold internal DeviceStatus
struct NightscoutDeviceStatus: Codable {
    var updatedDate: Date = .distantPast
    var lastCheckedDate: Date = .distantPast
    
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
    
    var overrideActive: Bool?
    var overrideName: String?
    var overrideMaxValue: Double?
    var overrideMinValue: Double?
    var overrideMultiplier: Double?
    
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
    
    var uploaderBatteryPercent: Int?
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
            case "iAPS":
                return "iAPS"
            default:
                return nil
            }
        }
        
        return nil
    }
    
    // return the AID system icon
    func systemIcon() -> Image? {
        if let device {
            switch device {
            case let str where str.startsWith("loop://"):
                return Image("LoopIcon")
            case let str where str.startsWith("openaps://"):
                return Image("AAPSIcon")
            case "Trio":
                return Image("TrioIcon")
            case "iAPS":
                return Image("iAPSIcon")
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
            return deviceName.count > 1 ? deviceName[1].capitalizedSentence : nil
        }
        
        return nil
    }
    
    // should the response for this device type use the Suggested attribute as though it was Enacted (i.e. AAPS)
    func useSuggestedAsEnacted() -> Bool {
        switch device {
        case "Trio", "iAPS":
            return false
        default:
            return true
        }
    }
    
    func reasonValuesArray() -> [String]? {
        if var reason {
            // replace the html character references with real symbols
            reason = reason.replacingOccurrences(of: "&lt;", with: "<")
            reason = reason.replacingOccurrences(of: "&gt;", with: ">")
            reason = reason.replacingOccurrences(of: "&le;", with: "<=")
            reason = reason.replacingOccurrences(of: "&ge;", with: ">=")
            
            return reason.components(separatedBy: ", ")
            
        } else {
            return nil
        }
    }
    
    // as the minimum deployment target is iOS16.2, we need to provide a nice option for people running it
    // even if nearly all users will be running iOS18
    func batteryImage(percent: Int?) -> (image: Image, color: Color)? {
        if let percent {
            switch percent {
            case 0...10:
                if #available(iOS 17.0, *) {
                    return (Image(systemName: "battery.0percent"), Color(.systemRed))
                } else {
                    return (Image(systemName: "minus.plus.batteryblock.slash"), Color(.systemRed))
                }
            case 11...25:
                if #available(iOS 17.0, *) {
                    return (Image(systemName: "battery.25percent"), Color(.systemYellow))
                } else {
                    return (Image(systemName: "minus.plus.batteryblock"), Color(.systemYellow))
                }
            case 26...65:
                if #available(iOS 17.0, *) {
                    return (Image(systemName: "battery.50percent"), Color(.colorSecondary))
                } else {
                    return (Image(systemName: "minus.plus.batteryblock"), Color(.colorSecondary))
                }
            case 66...90:
                if #available(iOS 17.0, *) {
                    return (Image(systemName: "battery.75percent"), Color(.colorSecondary))
                } else {
                    return (Image(systemName: "minus.plus.batteryblock.fill"), Color(.colorSecondary))
                }
            default:
                if #available(iOS 17.0, *) {
                    return (Image(systemName: "battery.100percent"), Color(.colorSecondary))
                } else {
                    return (Image(systemName: "minus.plus.batteryblock.fill"), Color(.colorSecondary))
                }
            }
        }
        
        return nil
    }
    
    func uploaderBatteryImageRVCStatusView() -> (batteryImageSystemName: String, batteryImageColor: UIColor)? {
        if let uploaderBatteryPercent, let uploaderIsCharging, !uploaderIsCharging {
            switch uploaderBatteryPercent {
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
    
    func uploaderBatteryChargingImage() -> (image: Image, color: Color)? {
        if let uploaderIsCharging {
            if uploaderIsCharging {
                return (Image(systemName: "bolt"), Color(.systemGreen))
            } else {
                return nil
            }
        }
        
        return nil
    }
    
    func deviceStatusColor() -> Color {
        if lastLoopDate > .now.addingTimeInterval(-ConstantsHomeView.loopShowWarningAfterMinutes) {
            return .green
        } else if lastLoopDate > .now.addingTimeInterval(-ConstantsHomeView.loopShowNoDataAfterMinutes) {
            return .green
        } else if createdAt > .now.addingTimeInterval(-ConstantsHomeView.loopShowNoDataAfterMinutes) {
            return .yellow
        } else {
            return .red
        }
    }
    
    func deviceStatusBannerBackgroundColor() -> Color {
        if lastLoopDate > .now.addingTimeInterval(-ConstantsHomeView.loopShowWarningAfterMinutes) {
            return Color(red: 0, green: 1, blue: 0).opacity(ConstantsHomeView.AIDStatusBannerBackgroundOpacity)
        } else if lastLoopDate > .now.addingTimeInterval(-ConstantsHomeView.loopShowNoDataAfterMinutes) {
            return Color(red: 0, green: 1, blue: 0).opacity(ConstantsHomeView.AIDStatusBannerBackgroundOpacity)
        } else if createdAt > .now.addingTimeInterval(-ConstantsHomeView.loopShowNoDataAfterMinutes) {
            return Color(red: 1, green: 1, blue: 0).opacity(ConstantsHomeView.AIDStatusBannerBackgroundOpacity)
        } else {
            return Color(red: 1, green: 0, blue: 0).opacity(ConstantsHomeView.AIDStatusBannerBackgroundOpacity)
        }
    }
    
    func deviceStatusUIColor() -> UIColor {
        if lastLoopDate > .now.addingTimeInterval(-ConstantsHomeView.loopShowWarningAfterMinutes) {
            return .systemGreen
        } else if lastLoopDate > .now.addingTimeInterval(-ConstantsHomeView.loopShowNoDataAfterMinutes) {
            return .systemGreen
        } else if createdAt > .now.addingTimeInterval(-ConstantsHomeView.loopShowNoDataAfterMinutes) {
            return .systemYellow
        } else {
            return .systemRed
        }
    }
    
    func deviceStatusTitle() -> String {
        if lastLoopDate > .now.addingTimeInterval(-ConstantsHomeView.loopShowWarningAfterMinutes) {
            return "Looping"
        } else if lastLoopDate > .now.addingTimeInterval(-ConstantsHomeView.loopShowNoDataAfterMinutes) {
            return "Looping"
        } else if createdAt > .now.addingTimeInterval(-ConstantsHomeView.loopShowNoDataAfterMinutes) {
            return "Not looping"
        } else {
            return "Error/No data"
        }
    }
    
    func deviceStatusIconImage() -> Image {
        if lastLoopDate > .now.addingTimeInterval(-ConstantsHomeView.loopShowWarningAfterMinutes) {
            return Image(systemName: "checkmark.circle.fill")
        } else if lastLoopDate > .now.addingTimeInterval(-ConstantsHomeView.loopShowNoDataAfterMinutes) {
            return Image(systemName: "checkmark.circle")
        } else if createdAt > .now.addingTimeInterval(-ConstantsHomeView.loopShowNoDataAfterMinutes) {
            return Image(systemName: "questionmark.circle")
        } else {
            return Image(systemName: "exclamationmark.circle")
        }
    }
    
    func deviceStatusIconUIImage() -> UIImage {
        if lastLoopDate > .now.addingTimeInterval(-ConstantsHomeView.loopShowWarningAfterMinutes) {
            return UIImage(systemName: "checkmark.circle.fill") ?? UIImage()
        } else if lastLoopDate > .now.addingTimeInterval(-ConstantsHomeView.loopShowNoDataAfterMinutes) {
            return UIImage(systemName: "checkmark.circle") ?? UIImage()
        } else if createdAt > .now.addingTimeInterval(-ConstantsHomeView.loopShowNoDataAfterMinutes) {
            return UIImage(systemName: "questionmark.circle") ?? UIImage()
        } else {
            return UIImage(systemName: "exclamationmark.circle") ?? UIImage()
        }
    }
    
    func pumpReservoirColor() -> Color? {
        if let pumpReservoir {
            if pumpReservoir < ConstantsHomeView.pumpReservoirUrgent {
                return .red
            } else if pumpReservoir < ConstantsHomeView.pumpReservoirWarning {
                return .yellow
            }
        }
        
        return nil
    }
    
    func pumpReservoirUIColor() -> UIColor? {
        if let pumpReservoir {
            if pumpReservoir < ConstantsHomeView.pumpReservoirUrgent {
                return UIColor.systemRed
            } else if pumpReservoir < ConstantsHomeView.pumpReservoirWarning {
                return UIColor.systemYellow
            }
        }
        
        return nil
    }
    
    func pumpBatteryPercentColor() -> Color? {
        if let pumpBatteryPercent {
            if pumpBatteryPercent < ConstantsHomeView.pumpBatteryPercentUrgent {
                return .red
            } else if pumpBatteryPercent < ConstantsHomeView.pumpBatteryPercentWarning {
                return .yellow
            }
        }
        
        return nil
    }
    
    func pumpBatteryPercentUIColor() -> UIColor? {
        if let pumpBatteryPercent {
            if pumpBatteryPercent < ConstantsHomeView.pumpBatteryPercentUrgent {
                return UIColor.systemRed
            } else if pumpBatteryPercent < ConstantsHomeView.pumpBatteryPercentWarning {
                return UIColor.systemYellow
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
            let received: Bool?
            let recieved: Bool? // spelt incorrectly in iAPS
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
                case received
                case recieved // spelt incorrectly in iAPS
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
        let isCharging: Bool?
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
        struct CurrentCorrectionRange: Codable {
            let maxValue: Double?
            let minValue: Double?
        }
        
        let active: Bool?
        let currentCorrectionRange: CurrentCorrectionRange?
        let name: String?
        let multiplier: Double?
    }
    
    struct Pump: Codable {
        struct Battery: Codable {
            let percent: Int?
        }
        
        let battery: Battery?
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
