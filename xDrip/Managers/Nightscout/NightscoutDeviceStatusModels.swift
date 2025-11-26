//
//  NightscoutDeviceStatusModels.swift
//  xdrip
//
//  Created by Paul Plant on 30/10/24.
//  Copyright © 2024 Johan Degraeve. All rights reserved.
//
import Foundation
import SwiftUI

// MARK: - Internal NightscoutDeviceStatus

/// Struct to hold internal DeviceStatus
/// Initialize from a NightscoutDeviceStatusResponse
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

// MARK: Internal NightscoutDeviceStatus initializer

extension NightscoutDeviceStatus {
    /// Initialize from a unified NightscoutDeviceStatusResponse
    init(from unified: NightscoutDeviceStatusResponse) {
        self.init()
        
        // Parse createdAt
        if let createdAtStr = unified.createdAt {
            self.createdAt = ISO8601DateFormatter.withFractionalSeconds.date(from: createdAtStr)
                ?? ISO8601DateFormatter().date(from: createdAtStr)
                ?? .distantPast
        }
        
        self.device = unified.device
        self.id = unified.id ?? ""
        self.mills = unified.mills ?? 0
        self.utcOffset = unified.utcOffset ?? 0
        
        // Uploader battery: always from uploader.battery (int, percent)
        self.uploaderBatteryPercent = unified.uploader?.battery ?? unified.uploaderBattery
        self.uploaderIsCharging = unified.isCharging ?? unified.uploader?.isCharging

        // OpenAPS fields
        var lastLoopDates: [Date] = []
        var cobCandidates: [(value: Double, timestamp: Date?)] = []
        var iobCandidates: [(value: Double, timestamp: Date?)] = []

        if let openAPS = unified.openAPS {
            self.appVersion = openAPS.version
            let enacted = openAPS.enacted
            let suggested = openAPS.suggested
            let useSuggested = suggested != nil && (enacted == nil || (suggested?.timestamp ?? "") > (enacted?.timestamp ?? ""))
            let selectedAPS = useSuggested ? suggested : enacted
            if let aps = selectedAPS {
                self.currentTarget = aps.currentTarget
                self.duration = aps.duration
                self.eventualBG = aps.eventualBG
                self.isf = aps.isf ?? aps.variableSens
                self.insulinReq = aps.insulinReq
                self.rate = aps.rate
                self.reason = aps.reason
                self.sensitivityRatio = aps.sensitivityRatio
                self.tdd = aps.tdd
                let apsTimestampDate: Date? = aps.timestamp.flatMap { ISO8601DateFormatter.withFractionalSeconds.date(from: $0) ?? ISO8601DateFormatter().date(from: $0) }
                self.timestamp = apsTimestampDate
                if let apsTimestampDate = apsTimestampDate { lastLoopDates.append(apsTimestampDate) }
                if let cobValue = aps.cob { cobCandidates.append((cobValue, apsTimestampDate)) }
                if let iobValue = aps.iob { iobCandidates.append((iobValue, apsTimestampDate)) }
            }
            // Also consider enacted/suggested timestamps for lastLoopDate
            if let enactedTimestampString = enacted?.timestamp {
                let enactedTimestampDate = ISO8601DateFormatter.withFractionalSeconds.date(from: enactedTimestampString) ?? ISO8601DateFormatter().date(from: enactedTimestampString)
                if let enactedTimestampDate = enactedTimestampDate { lastLoopDates.append(enactedTimestampDate) }
                if let cobValue = enacted?.cob { cobCandidates.append((cobValue, enactedTimestampDate)) }
                if let iobValue = enacted?.iob { iobCandidates.append((iobValue, enactedTimestampDate)) }
            }
            if let suggestedTimestampString = suggested?.timestamp {
                let suggestedTimestampDate = ISO8601DateFormatter.withFractionalSeconds.date(from: suggestedTimestampString) ?? ISO8601DateFormatter().date(from: suggestedTimestampString)
                if let suggestedTimestampDate = suggestedTimestampDate { lastLoopDates.append(suggestedTimestampDate) }
                if let cobValue = suggested?.cob { cobCandidates.append((cobValue, suggestedTimestampDate)) }
                if let iobValue = suggested?.iob { iobCandidates.append((iobValue, suggestedTimestampDate)) }
            }
        }

        if let loop = unified.loop {
            self.appVersion = loop.version ?? appVersion
            self.error = loop.failureReason
            self.insulinReq = loop.recommendedBolus ?? insulinReq
            self.eventualBG = loop.predicted?.values?.last ?? eventualBG
            if let cobValue = loop.cob?.cob {
                let cobTimestampDate = loop.cob?.timestamp.flatMap { ISO8601DateFormatter.withFractionalSeconds.date(from: $0) ?? ISO8601DateFormatter().date(from: $0) }
                cobCandidates.append((cobValue, cobTimestampDate))
            }
            if let iobValue = loop.iob?.iob {
                let iobTimestampDate = loop.iob?.timestamp.flatMap { ISO8601DateFormatter.withFractionalSeconds.date(from: $0) ?? ISO8601DateFormatter().date(from: $0) }
                iobCandidates.append((iobValue, iobTimestampDate))
            }
            if let enacted = loop.enacted {
                self.bolusVolume = enacted.bolusVolume
                self.duration = enacted.duration ?? duration
                self.rate = enacted.rate ?? rate
                if let enactedTimestampString = enacted.timestamp {
                    let enactedTimestampDate = ISO8601DateFormatter.withFractionalSeconds.date(from: enactedTimestampString) ?? ISO8601DateFormatter().date(from: enactedTimestampString)
                    if let enactedTimestampDate = enactedTimestampDate { lastLoopDates.append(enactedTimestampDate) }
                }
            }
            if let loopTimestampString = loop.timestamp {
                let loopTimestampDate = ISO8601DateFormatter.withFractionalSeconds.date(from: loopTimestampString) ?? ISO8601DateFormatter().date(from: loopTimestampString)
                if let loopTimestampDate = loopTimestampDate { lastLoopDates.append(loopTimestampDate) }
            }
        }
        
        struct AutomaticDoseRecommendation: Codable {
            struct TempBasalAdjustment: Codable {
                let duration: Int?
                let rate: Double?
            }

            let bolusVolume: Double?
            let timestamp: String?
            let tempBasalAdjustment: TempBasalAdjustment?
        }

        // --- Robust, endpoint-accurate COB/IOB parsing for all system types ---
        // OpenAPS/AAPS/iAPS/Trio: use openAPS.suggested.cob/iob, then openAPS.enacted.cob/iob
        // Loop: use loop.cob.cob, loop.iob.iob
        // Fallback: most recent candidate

        var cobValue: Double?
        var iobValue: Double?

        // OpenAPS/AAPS/iAPS/Trio: use .cob/.iob properties (mapped from COB/IOB in JSON)
        if let openAPS = unified.openAPS {
            if let cob = openAPS.suggested?.cob { cobValue = cob }
            else if let cob = openAPS.enacted?.cob { cobValue = cob }
            if let iob = openAPS.suggested?.iob { iobValue = iob }
            else if let iob = openAPS.enacted?.iob { iobValue = iob }
        }

        // Loop
        if let loop = unified.loop {
            if let cob = loop.cob?.cob { cobValue = cob }
            if let iob = loop.iob?.iob { iobValue = iob }
        }

        // Fallback: most recent candidate (for future-proofing, e.g. Trio/iAPS variants)
        func mostRecentValue<T>(_ candidates: [(value: T, timestamp: Date?)]) -> T? {
            return candidates.sorted(by: { ($0.timestamp ?? .distantPast) > ($1.timestamp ?? .distantPast) }).first?.value
        }
        
        if cobValue == nil { cobValue = mostRecentValue(cobCandidates) }
        if iobValue == nil { iobValue = mostRecentValue(iobCandidates) }

        self.cob = cobValue
        self.iob = iobValue

        // Set lastLoopDate to the most recent valid date found
        if let mostRecent = lastLoopDates.max(), mostRecent > .distantPast {
            self.lastLoopDate = mostRecent
        }

        // Override fields
        if let override = unified.override {
            self.overrideActive = override.active
            self.overrideName = override.name
            self.overrideMaxValue = override.currentCorrectionRange?.maxValue
            self.overrideMinValue = override.currentCorrectionRange?.minValue
            self.overrideMultiplier = override.multiplier
        }

        // Pump fields
        if let pump = unified.pump {
            self.pumpManufacturer = pump.manufacturer ?? pumpManufacturer
            self.pumpModel = pump.model ?? pumpModel
            // Pump battery: always from pump.battery.percent (never from uploader.battery)
            self.pumpBatteryPercent = pump.battery?.percent ?? pumpBatteryPercent
            if let clock = pump.clock {
                self.pumpClock = ISO8601DateFormatter.withFractionalSeconds.date(from: clock) ?? ISO8601DateFormatter().date(from: clock)
            }
            self.pumpID = pump.pumpID ?? pumpID
            self.pumpIsBolusing = pump.bolusing ?? pump.status?.bolusing ?? pumpIsBolusing
            self.pumpIsSuspended = pump.suspended ?? pump.status?.suspended ?? pumpIsSuspended
            self.pumpStatus = pump.reservoir_display_override ?? pump.status?.status ?? pumpStatus
            if let ts = pump.status?.timestamp {
                self.pumpStatusTimestamp = ISO8601DateFormatter.withFractionalSeconds.date(from: ts) ?? ISO8601DateFormatter().date(from: ts)
            }
            // For Omnipod/Dash, if reservoir value being returned is nil,
            // set to omniPodReservoirFlagNumber so that the UI will display "50+"
            if pumpManufacturer?.lowercased() == "insulet" || pumpModel?.lowercased() == "dash" {
                self.pumpReservoir = pump.reservoir ?? ConstantsNightscout.omniPodReservoirFlagNumber
            } else {
                self.pumpReservoir = pump.reservoir ?? pumpReservoir
            }
            self.activeProfile = pump.extended?.activeProfile ?? activeProfile
            self.baseBasalRate = pump.extended?.baseBasalRate ?? baseBasalRate
            self.appVersion = pump.extended?.version ?? appVersion
        }
    }
}

// MARK: - External downloaded NightscoutDeviceStatusResponse

/// Robust, tolerant unified model for decoding Nightscout devicestatus endpoint (AAPS, Trio, Loop, iAPS, OpenAPS etc)
struct NightscoutDeviceStatusResponse: Codable {
    struct Suggested: Codable {
        let carbohydratesOnBoard: Double?
        let carbohydrateRatio: Double?
        let currentTarget: Double?
        let duration: Int?
        let eventualBloodGlucose: Double?
        let insulinOnBoard: Double?
        let insulinSensitivityFactor: Double?
        let insulinRequired: Double?
        let rate: Double?
        let reason: String?
        let received: Bool?
        let recieved: Bool? // Was the action received (iAPS typo)
        let reservoir: Double?
        let sensitivityRatio: Double?
        let totalDailyDose: Double?
        let timestamp: String?
        let units: Double?
        let variableSensitivity: Double?

        private enum CodingKeys: String, CodingKey {
            case carbohydratesOnBoard = "COB"
            case carbohydrateRatio
            case currentTarget
            case duration
            case eventualBloodGlucose = "eventualBG"
            case insulinOnBoard = "IOB"
            case insulinSensitivityFactor
            case insulinRequired = "insulinReq"
            case rate
            case reason
            case received
            case recieved // iAPS typo
            case reservoir
            case sensitivityRatio
            case totalDailyDose = "TDD"
            case timestamp
            case units
            case variableSensitivity
        }
    }
    
    let createdAt: String?
    let device: String?
    let id: String?
    let isCharging: Bool?
    let mills: Int?
    let openAPS: OpenAPS?
    let loop: Loop?
    let override: Override?
    let pump: Pump?
    let uploader: Uploader?
    let uploaderBattery: Int?
    let utcOffset: Int?

    struct OpenAPS: Codable {
        let enacted: APSuggestion?
        let suggested: APSuggestion?
        let version: String?

        struct APSuggestion: Codable {
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
            let recieved: Bool? // iAPS typo
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
                case recieved
                case reservoir
                case sensitivityRatio
                case tdd = "TDD"
                case timestamp
                case units
                case variableSens = "variable_sens"
            }
        }
    }

    struct Loop: Codable {
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

        struct AutomaticDoseRecommendation: Codable {
            struct TempBasalAdjustment: Codable {
                let duration: Int?
                let rate: Double?
            }

            let bolusVolume: Double?
            let timestamp: String?
            let tempBasalAdjustment: TempBasalAdjustment?
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
    }

    struct Override: Codable {
        let active: Bool?
        let currentCorrectionRange: CurrentCorrectionRange?
        let name: String?
        let multiplier: Double?
        struct CurrentCorrectionRange: Codable {
            let maxValue: Double?
            let minValue: Double?
        }
    }

    struct Pump: Codable {
        let battery: Battery?
        let bolusing: Bool?
        let clock: String?
        let manufacturer: String?
        let model: String?
        let pumpID: String?
        let reservoir: Double?
        let reservoir_display_override: String?
        let secondsFromGMT: Int?
        let status: Status?
        let suspended: Bool?
        let extended: Extended?
        struct Battery: Codable { let percent: Int? }
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
        }
    }

    struct Uploader: Codable {
        let battery: Int?
        let isCharging: Bool?
        let name: String?
        let timestamp: String?
    }

    private enum CodingKeys: String, CodingKey {
        case createdAt = "created_at"
        case device
        case id = "_id"
        case isCharging
        case mills
        case openAPS = "openaps"
        case loop
        case override
        case pump
        case uploader
        case uploaderBattery
        case utcOffset
    }
}

// MARK: - ISO8601DateFormatter with fractional seconds

extension ISO8601DateFormatter {
    static let withFractionalSeconds: ISO8601DateFormatter = {
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return dateFormatter
    }()
}
