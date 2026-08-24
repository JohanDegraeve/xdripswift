//
//  LoopManager.swift
//  xdrip
//
//  Created by Julian Groen on 05/04/2020.
//  Copyright © 2020 Johan Degraeve. All rights reserved.
//

import Foundation
import OSLog

struct XDripCGMMetadataEnvelope: Codable, Equatable {
    static let schemaVersion = 1
    static let appGroupKey = "xDrip4iOSCGMMetadata"

    let schemaVersion: Int
    let generatedAt: Double
    let producer: Producer?
    let source: Source?
    let sensor: SensorState?
    let latestData: LatestData?
    let transmitter: Transmitter?
    let calibration: CalibrationState?

    struct Producer: Codable, Equatable {
        let appName: String?
        let version: String?
    }

    struct Source: Codable, Equatable {
        let mode: String
        let kind: String?
        let expectedReadingIntervalSeconds: Double?
        let lastCommunicationAt: Double?
    }

    struct SensorState: Codable, Equatable {
        let sessionIdentifier: String?
        let state: String?
        let type: String?
        let model: String?
        let serialNumber: String?
        let startedAt: Double?
        let warmupEndsAt: Double?
        let expiresAt: Double?
        let graceEndsAt: Double?
    }

    struct LatestData: Codable, Equatable {
        let glucoseAt: Double?
        let qualityCode: String?
    }

    struct Transmitter: Codable, Equatable {
        let identifier: String?
        let model: String?
        let battery: Battery?
    }

    struct Battery: Codable, Equatable {
        let value: Double
        let representation: String
        let unit: String
        let observedAt: Double?
    }

    struct CalibrationState: Codable, Equatable {
        let state: String
        let lastCalibrationAt: Double?
    }
}

struct XDripCGMMetadataContext {
    let activeSensor: Sensor?
    let transmitter: CGMTransmitter?
    let sensorHealthIssue: SensorHealthIssue?
    let hasInitialCalibration: Bool?
    let lastCalibrationAt: Date?
    let dexcomAlgorithmState: DexcomAlgorithmState?
    let libreSensorState: LibreSensorState?
}

enum XDripCGMMetadataBuilder {
    static func build(
        context: XDripCGMMetadataContext,
        latestSharedGlucoseAt: Date?,
        lastCommunicationAt: Date?,
        sensorStateOverride: String? = nil,
        now: Date = Date()
    ) -> XDripCGMMetadataEnvelope {
        let defaults = UserDefaults.standard
        let appName = Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ??
            Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String
        let appVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        let transmitterType = context.transmitter?.cgmTransmitterType()
        let mode = defaults.isMaster ? "direct" : "follower"
        let sourceKind = defaults.isMaster ? directSourceKind(transmitterType) : followerSourceKind(defaults.followerDataSourceType)
        let expectedInterval = defaults.isMaster ? directExpectedInterval(transmitterType) : followerExpectedInterval(defaults.followerDataSourceType)
        let startDate = context.activeSensor?.startDate ?? defaults.activeSensorStartDate
        let model = defaults.activeSensorDescription ?? transmitterType?.detailedDescription()
        let maxAgeInDays = context.transmitter?.maxSensorAgeInDays() ?? defaults.activeSensorMaxSensorAgeInDays
        let warmupEnd = startDate.map { $0.addingTimeInterval(warmupDuration(transmitter: context.transmitter, defaults: defaults)) }

        let finalEnd = startDate.flatMap { start in
            maxAgeInDays.flatMap { $0 > 0 ? start.addingTimeInterval(.days($0)) : nil }
        }
        let usesDexcomGrace = transmitterType == .dexcomG7 && finalEnd != nil
        let normalExpiration = usesDexcomGrace ? finalEnd?.addingTimeInterval(-.hours(12)) : finalEnd
        let graceEnd = usesDexcomGrace ? finalEnd : nil
        let terminalFailure = context.sensorHealthIssue?.severity == .terminal

        let state: String? = {
            if terminalFailure { return "failed" }
            if let sensorStateOverride { return sensorStateOverride }
            if let dexcomState = context.dexcomAlgorithmState {
                switch dexcomState {
                case .SessionStopped: return "stopped"
                case .SensorWarmup: return "warmup"
                case .SessionExpired, .expired: return "expired"
                case .SensorFailedDuetoCountsAberration, .SensorFailedDuetoResidualAberration,
                     .SessionFailedDueToUnrecoverableError, .SessionFailedDueToTransmitterError,
                     .SensorFailedDueToProgressiveSensorDecline, .SensorFailedDueToHighCountsAberration,
                     .SensorFailedDueToLowCountsAberration, .SensorFailedDueToRestart, .sensorFailed:
                    return "failed"
                default: break
                }
            }
            if let libreState = context.libreSensorState {
                switch libreState {
                case .notYetStarted: return "not_started"
                case .starting: return "warmup"
                case .ready: break
                case .expired: return "expired"
                case .shutdown: return "stopped"
                case .failure: return "failed"
                case .unknown: break
                }
            }
            guard startDate != nil else { return context.transmitter == nil && !defaults.isMaster ? nil : "not_started" }
            if let warmupEnd, now < warmupEnd { return "warmup" }
            if let graceEnd, let normalExpiration, now >= normalExpiration, now < graceEnd { return "grace" }
            if let finalEnd, now >= finalEnd { return "expired" }
            return "active"
        }()

        let qualityCode: String? = {
            if let issue = context.sensorHealthIssue {
                switch issue.reason {
                case .persistentNoise: return "persistent_noise"
                case .flatline: return "flatline"
                case .dexcomExcessNoise: return "excess_noise"
                case .dexcomTemporarySensorIssue, .dexcomQuestionMarks: return "temporary_sensor_issue"
                case .dexcomSensorFailure, .libreSensorFailure, .dexcomTransmitterFailure, .dexcomTransmitterBatteryFailure:
                    return "sensor_error"
                }
            }
            switch context.dexcomAlgorithmState {
            case .excessNoise: return "excess_noise"
            case .TemporarySensorIssue, .questionMarks: return "temporary_sensor_issue"
            case .SensorFailedDuetoCountsAberration, .SensorFailedDuetoResidualAberration,
                 .SessionFailedDueToUnrecoverableError, .SessionFailedDueToTransmitterError,
                 .SensorFailedDueToProgressiveSensorDecline, .SensorFailedDueToHighCountsAberration,
                 .SensorFailedDueToLowCountsAberration, .SensorFailedDueToRestart, .sensorFailed:
                return "sensor_error"
            default: return latestSharedGlucoseAt == nil ? nil : "reliable"
            }
        }()

        let calibration: XDripCGMMetadataEnvelope.CalibrationState? = {
            guard defaults.isMaster, let transmitter = context.transmitter else { return nil }
            let requiresAppCalibration = !transmitter.isWebOOPEnabled() && !transmitter.overruleIsWebOOPEnabled()
            let state: String
            switch context.dexcomAlgorithmState {
            case .FirstofTwoBGsNeeded, .SecondofTwoBGsNeeded, .needsCalibration:
                state = "required"
            case .CalibrationError1, .CalibrationError2, .CalibrationLinearityFitFailure,
                 .OutOfCalibrationDueToOutlier, .OutlierCalibrationRequest:
                state = "error"
            default:
                if !requiresAppCalibration {
                    state = "not_required"
                } else if context.hasInitialCalibration == true {
                    state = "current"
                } else if let warmupEnd, now >= warmupEnd {
                    state = "required"
                } else {
                    return nil
                }
            }
            return .init(state: state, lastCalibrationAt: context.lastCalibrationAt?.timeIntervalSince1970)
        }()

        let battery: XDripCGMMetadataEnvelope.Battery? = {
            guard let batteryInfo = defaults.transmitterBatteryInfo else { return nil }
            switch batteryInfo {
            case let .percentage(percentage):
                return .init(value: Double(percentage), representation: "percentage", unit: "percent", observedAt: nil)
            case let .DexcomG5(_, voltageB, _, _, _):
                return .init(
                    value: Double(voltageB * 10),
                    representation: "voltage",
                    unit: "millivolts",
                    observedAt: defaults.timeStampOfLastBatteryReading?.timeIntervalSince1970
                )
            }
        }()

        let sensorType: String? = {
            switch transmitterType?.sensorType() {
            case .Dexcom: return "dexcom"
            case .Libre: return "libre"
            case .Medtrum: return "medtrum"
            case nil:
                let description = model?.lowercased() ?? ""
                if description.contains("guardian") { return "guardian" }
                if description.contains("dexcom") { return "dexcom" }
                if description.contains("libre") { return "libre" }
                if description.contains("medtrum") { return "medtrum" }
                return nil
            }
        }()

        let sessionIdentifier = context.activeSensor?.id ?? sessionIdentifier(
            serial: defaults.activeSensorSerialNumber,
            model: model,
            startDate: startDate
        )

        let sensorMetadata: XDripCGMMetadataEnvelope.SensorState? = {
            guard sessionIdentifier != nil || state != nil || sensorType != nil || model != nil ||
                defaults.activeSensorSerialNumber != nil || startDate != nil || warmupEnd != nil ||
                normalExpiration != nil || graceEnd != nil else { return nil }
            return .init(
                sessionIdentifier: sessionIdentifier,
                state: state,
                type: sensorType,
                model: model,
                serialNumber: defaults.activeSensorSerialNumber,
                startedAt: startDate?.timeIntervalSince1970,
                warmupEndsAt: warmupEnd?.timeIntervalSince1970,
                expiresAt: normalExpiration?.timeIntervalSince1970,
                graceEndsAt: graceEnd?.timeIntervalSince1970
            )
        }()
        let latestData: XDripCGMMetadataEnvelope.LatestData? = {
            guard latestSharedGlucoseAt != nil || qualityCode != nil else { return nil }
            return .init(glucoseAt: latestSharedGlucoseAt?.timeIntervalSince1970, qualityCode: qualityCode)
        }()
        let transmitterMetadata: XDripCGMMetadataEnvelope.Transmitter? = {
            let identifier = defaults.activeSensorTransmitterId
            let transmitterModel = transmitterType?.detailedDescription()
            guard identifier != nil || transmitterModel != nil || battery != nil else { return nil }
            return .init(identifier: identifier, model: transmitterModel, battery: battery)
        }()

        return XDripCGMMetadataEnvelope(
            schemaVersion: XDripCGMMetadataEnvelope.schemaVersion,
            generatedAt: now.timeIntervalSince1970,
            producer: .init(appName: appName, version: appVersion),
            source: .init(
                mode: mode,
                kind: sourceKind,
                expectedReadingIntervalSeconds: expectedInterval,
                lastCommunicationAt: lastCommunicationAt?.timeIntervalSince1970
            ),
            sensor: sensorMetadata,
            latestData: latestData,
            transmitter: transmitterMetadata,
            calibration: calibration
        )
    }

    private static func directSourceKind(_ type: CGMTransmitterType?) -> String? {
        switch type {
        case .dexcom:
            let identifier = UserDefaults.standard.activeSensorTransmitterId ?? ""
            if identifier.hasPrefix("4") { return "dexcom_g5" }
            if identifier.hasPrefix("5") || identifier.hasPrefix("C") { return "dexcom_one" }
            if identifier.hasPrefix("8") { return "dexcom_g6" }
            return "dexcom_g5_g6"
        case .dexcomG7:
            let identifier = UserDefaults.standard.activeSensorTransmitterId ?? ""
            if identifier.hasPrefix("DX01") { return "dexcom_stelo" }
            if identifier.hasPrefix("DX02") { return "dexcom_one_plus" }
            return "dexcom_g7"
        case .Libre2: return "libre_2"
        case .miaomiao: return "libre_miaomiao"
        case .Bubble: return "libre_bubble"
        case .medtrumTouchCareNano: return "medtrum_nano"
        case nil: return nil
        }
    }

    private static func followerSourceKind(_ type: FollowerDataSourceType) -> String {
        switch type {
        case .nightscout: return "nightscout"
        case .libreLinkUp: return "libre_link_up"
        case .libreLinkUpRussia: return "libre_link_up_russia"
        case .dexcomShare: return "dexcom_share"
        case .medtrumEasyView: return "medtrum_easyview"
        case .calendar: return "shared_calendar"
        case .careLink: return "carelink"
        }
    }

    private static func directExpectedInterval(_ type: CGMTransmitterType?) -> Double? {
        switch type {
        case .dexcom, .dexcomG7: return 300
        case .Libre2, .miaomiao, .Bubble, .medtrumTouchCareNano: return 60
        case nil: return nil
        }
    }

    private static func followerExpectedInterval(_ type: FollowerDataSourceType) -> Double {
        switch type {
        case .libreLinkUp, .libreLinkUpRussia, .medtrumEasyView: return 60
        case .nightscout, .dexcomShare, .calendar: return 300
        case .careLink: return 300
        }
    }

    private static func warmupDuration(transmitter: CGMTransmitter?, defaults: UserDefaults) -> TimeInterval {
        if !defaults.isMaster,
           defaults.followerDataSourceType == .libreLinkUp || defaults.followerDataSourceType == .libreLinkUpRussia {
            return .minutes(ConstantsLibreLinkUp.sensorWarmUpRequiredInMinutesForLibre)
        }
        switch transmitter?.cgmTransmitterType() {
        case .dexcomG7:
            return .minutes(ConstantsMaster.minimumSensorWarmUpRequiredInMinutesDexcomG7)
        case .dexcom:
            return .minutes(transmitter?.isAnubisG6() == true
                ? ConstantsMaster.minimumSensorWarmUpRequiredInMinutesDexcomG6Anubis
                : ConstantsMaster.minimumSensorWarmUpRequiredInMinutesDexcomG5G6)
        case .Libre2, .miaomiao, .Bubble, .medtrumTouchCareNano:
            return .minutes(ConstantsMaster.minimumSensorWarmUpRequiredInMinutes)
        case nil:
            let description = defaults.activeSensorDescription?.lowercased() ?? ""
            if description.contains("dexcom") { return .minutes(ConstantsMaster.minimumSensorWarmUpRequiredInMinutesDexcomG5G6) }
            return .minutes(ConstantsMaster.minimumSensorWarmUpRequiredInMinutes)
        }
    }

    private static func sessionIdentifier(serial: String?, model: String?, startDate: Date?) -> String? {
        guard serial != nil || model != nil || startDate != nil else { return nil }
        return [serial, model, startDate.map { String(Int($0.timeIntervalSince1970)) }]
            .compactMap { $0 }
            .joined(separator: "|")
    }
}

public class LoopManager: NSObject {

    // MARK: - private properties

    /// reference to coreDataManager
    private var coreDataManager:CoreDataManager

    /// a BgReadingsAccessor
    private var bgReadingsAccessor:BgReadingsAccessor

    /// Whether the active Dexcom G6 transmitter is an Anubis.
    private let activeSensorIsAnubisProvider: () -> Bool

    private let metadataContextProvider: () -> XDripCGMMetadataContext

    private var lastSuccessfulSourceCommunication: Date?

    private var explicitSensorState: String?

    // for trace,
    private let log = OSLog(subsystem: ConstantsLog.subSystem, category: ConstantsLog.categoryLoopManager)

    // MARK: - public properties

    /// latest glucose data values - to be used only if using loopDelay
    /// - first is the youngest
    ///
    /// actually there's redundancy in data. Readings are normally read from coredata here in this module, and stored in lastReadings - disadvantage is that BgReadings in coredata only contain readings per 5 minutes + the latest reading (which can be less than 5 minutes later than latest but one reading. But when using loopdelay, we omit the most recent values, and end up with an array of readings, 5 minutes apart from each other, as a result Loop would receive a reading only every 5 minutes. For that reason, this second array glucoseData is introduced (later in the project). This array has readings per minute. Ideally, glucoseData could be used no matter of loopDelay is used or not, but to avoid uncatched coding errors, I kept both
    public var glucoseData = [GlucoseData]()

    // MARK: - initializer

    init(
        coreDataManager: CoreDataManager,
        activeSensorIsAnubisProvider: @escaping () -> Bool,
        metadataContextProvider: @escaping () -> XDripCGMMetadataContext
    ) {

        // initialize non optional private properties
        self.coreDataManager = coreDataManager
        self.bgReadingsAccessor = BgReadingsAccessor(coreDataManager: coreDataManager)
        self.activeSensorIsAnubisProvider = activeSensorIsAnubisProvider
        self.metadataContextProvider = metadataContextProvider

        // call super.init
        super.init()

    }

    // MARK: - public functions

    /// share latest readings with Loop
    public func share() {

        // App Store releasers who cannot support the shared app group used by Loop/iAPS/Trio
        // should add this line to xDripConfigOverride.xcconfig:
        //
        // DISABLE_LOOP_SHARE = YES
        //
        // When enabled, the OS-AID Share row is hidden from Sharing and Services, the
        // stored Loop share setting is forced back to disabled, LoopManager is not started,
        // and this defensive runtime guard prevents Loop share writes from running.
        //
        // This does not affect OS-AID Follower behaviour.
        guard !Bundle.main.disableLoopShare else {
            UserDefaults.standard.loopShareType = .disabled
            return
        }

        // will return if loop share is disabled
        guard UserDefaults.standard.loopShareType != .disabled else { return }

        // Apply the active source policy before reading or writing the shared app group. Direct
        // Medtrum Nano is always blocked; EasyView retains its explicit consent requirement.
        guard Self.osAidSharingPermitted else {
            glucoseData.removeAll()
            clearBlockedSourceSharedData()
            return
        }

        // shared app group suite name to publish data
        let loopShareType = UserDefaults.standard.loopShareType
        let suiteName = loopShareType.sharedUserDefaultsSuiteName

        // make sure the enum didn't return an empty string
        guard suiteName != "" else { return }

        // create and unwrap sharedUserDefaults
        // this was previously done at the class level, but the scope must now be changed to allow us to change the target app group
        guard let sharedUserDefaults = UserDefaults(suiteName: suiteName) else {return}

        guard let timeStampLatestLoopSharedBgReading = UserDefaults.standard.timeStampLatestLoopSharedBgReading else {

            // if the last share data hasn't been set previously (could only happen on the first run) then just set it and return until next bg reading is processed. We won't normally ever get to here
            UserDefaults.standard.timeStampLatestLoopSharedBgReading = Date()

            publishMetadata(sharedUserDefaults: sharedUserDefaults, latestSharedGlucoseAt: nil)

            return

        }

        trace("    in share, sharing data with selected OS-AID target",log: log, category: ConstantsLog.categoryLoopManager, type: .debug, troubleshooting: .detailed(.integration(name: .osAid, activity: .started)))

        // get last readings with calculated value
        // reduce timeStampLatestLoopSharedBgReading with 30 minutes. Because maybe Loop wasn't running for a while and so missed one or more readings. By adding 30 minutes of readings, we fill up a gap of maximum 30 minutes in Loop
        let lastReadings = bgReadingsAccessor.getLatestBgReadings(limit: ConstantsShareWithLoop.maxReadingsToShareWithLoop, fromDate: timeStampLatestLoopSharedBgReading.addingTimeInterval(-TimeInterval(minutes: 30)), forSensor: nil, ignoreRawData: true, ignoreCalculatedValue: false)

        // calculate loopDelay, to avoid having to do it multiple times
        let loopDelay = LoopManager.loopDelay()

        // if needed, remove readings less than loopDelay minutes old from glucoseData
        if loopDelay > 0 {

            trace("    in share, loopDelay = %{public}@. Deleting %{public}@ minutes of readings from glucoseData.",log: log, category: ConstantsLog.categoryLoopManager, type: .debug, loopDelay.description)

            while glucoseData.count > 0 &&  glucoseData[0].timeStamp.addingTimeInterval(loopDelay) > Date() {

                glucoseData.remove(at: 0)

            }

            // if no readings anymore, then no need to continue
            if glucoseData.count == 0 {
                if loopShareType == .trio {
                    writeEmptyReadingsAndMetadata(sharedUserDefaults: sharedUserDefaults)
                }
                return
            }

        } else if lastReadings.count == 0 {
            // this is the case where loopdelay = 0 and lastReadings is empty
            if loopShareType == .trio {
                publishMetadata(
                    sharedUserDefaults: sharedUserDefaults,
                    latestSharedGlucoseAt: latestPreviouslySharedGlucoseAt()
                )
            }
            return
        }

        //  double check that lastReadings.first exists, because in some cases lastReadings is empty but still lastReadings.count != nil
        guard lastReadings.first != nil else {return}

        // convert to json Dexcom Share format
        var dictionary = [Dictionary<String, Any>]()

        if loopDelay > 0 {

            for reading in glucoseData {

                var representation = reading.dictionaryRepresentationForLoopShare

                // Adding "from" field to be able to use multiple BG sources with the same shared group in FreeAPS X
                representation["from"] = "xDrip"
                dictionary.append(representation)
            }

        } else {

            for reading in lastReadings {

                // OS-AID targets should receive adjusted values, or calculated values if no adjustment exists.
                // Smoothed/final values are only shared when the user explicitly enables the warned override.
                let date = "/Date(" + Int64(floor(reading.timeStamp.toMillisecondsAsDouble() / 1000) * 1000).description + ")/"
                var representation: [String : Any] = [
                    "Trend" : reading.slopeOrdinal(),
                    "ST" : date,
                    "DT" : date,
                    "Value" : round(reading.loopShareValue),
                    "direction" : reading.slopeName
                ]

                // Adding "from" field to be able to use multiple BG sources with the same shared group in FreeAPS X
                representation["from"] = "xDrip"
                dictionary.append(representation)
            }

        }

        // now, if needed, increase the timestamp for each reading
        if loopDelay > 0 {

            // create new dictionary that will have the readings with timestamp increased
            var newDictionary = [Dictionary<String, Any>]()

            // iterate through dictionary
            for reading in dictionary {

                var readingTimeStamp: Date?
                if let rawGlucoseStartDate = reading["DT"] as? String {
                    do {

                        readingTimeStamp = try self.parseTimestamp(rawGlucoseStartDate)

                    } catch  {

                    }
                }

                if let readingTimeStamp = readingTimeStamp, let slopeOrdinal = reading["Trend"] as? Int, let value = reading["Value"] as? Double {

                    // create new date : original date + loopDelay
                    let newReadingTimeStamp = readingTimeStamp.addingTimeInterval(loopDelay)

                    // ignore the reading if newReadingTimeStamp > now
                    if newReadingTimeStamp < Date() {

                        // this is for the json representation
                        let dateAsString = "/Date(" + Int64(floor(newReadingTimeStamp.toMillisecondsAsDouble() / 1000) * 1000).description + ")/"

                        // create new reading and append to new dictionary
                        let newReading: [String : Any] = [
                            "Trend" : slopeOrdinal,
                            "ST" : dateAsString,
                            "DT" : dateAsString,
                            "Value" : value,
                            "direction" : slopeOrdinal,
                            "from" : "xDrip"
                        ]

                        newDictionary.append(newReading)

                    }

                }

            }

            dictionary = newDictionary

        }

        // If there are no readings to share, clear the shared container to avoid stale entries
        if dictionary.isEmpty {
            if loopShareType == .trio {
                writeEmptyReadingsAndMetadata(sharedUserDefaults: sharedUserDefaults)
            } else {
                sharedUserDefaults.removeObject(forKey: "latestReadings")
                UserDefaults.standard.readingsStoredInSharedUserDefaultsAsDictionary = nil
            }
            return
        }

        // Every existing OS-AID consumer expects this key to contain a top-level
        // array. Rich Trio metadata is published independently after this write.
        guard let data = try? Self.encodeLegacyReadings(dictionary) else {
            return
        }

        // add a trace at debug level to record the data we're going to write to the shared container
        if let debugJSON = String(data: data, encoding: .utf8) {
            trace("    in share, latestReadings JSON = %{public}@", log: log, category: ConstantsLog.categoryLoopManager, type: .debug, debugJSON)
        } else {
            trace("    in share, latestReadings JSON = (unavailable UTF8). count = %{public}@", log: log, category: ConstantsLog.categoryLoopManager, type: .debug, dictionary.count.description)
        }

        // write readings to shared user defaults
        sharedUserDefaults.set(data, forKey: "latestReadings")
        trace("    in share, stored readings for selected OS-AID target", log: log, category: ConstantsLog.categoryLoopManager, type: .debug, troubleshooting: .detailed(.integration(name: .osAid, activity: .succeeded(itemCount: dictionary.count))))

        if loopShareType == .trio {
            publishMetadata(
                sharedUserDefaults: sharedUserDefaults,
                latestSharedGlucoseAt: sharedGlucoseDate(from: dictionary.first)
            )
        }

        // mirror exactly what we wrote so local deletions are reflected immediately
        UserDefaults.standard.readingsStoredInSharedUserDefaultsAsDictionary = dictionary

        // initially set timeStampLatestLoopSharedBgReading to timestamp of first reading - may get another value later, in case loopdelay > 0
        // add 5 seconds to last Readings timestamp, because due to the way timestamp for libre readings is calculated, it may happen that the same reading shifts 1 or 2 seconds in next reading cycle
        if let first = lastReadings.first {
            UserDefaults.standard.timeStampLatestLoopSharedBgReading = first.timeStamp.addingTimeInterval(5.0)
        }

        // in case loopdelay is used, then update UserDefaults.standard.timeStampLatestLoopSharedBgReading with value of timestamp of first element in the dictionary
        if let element = dictionary.first, loopDelay > 0 {

            if let elementDateAsString = element["DT"] as? String {

                do {
                    if let readingTimeStamp = try self.parseTimestamp(elementDateAsString) {
                        UserDefaults.standard.timeStampLatestLoopSharedBgReading = readingTimeStamp
                    }
                } catch  {
                    // timeStampLatestLoopSharedBgReading keeps initially set value
                }

            }

        }

    }

    /// Clear all glucose data previously shared with Loop / OS-AID from the shared app group container.
    /// Call this when BG readings are deleted to ensure stale values do not remain in the shared container.
    public func clearSharedLoopReadings() {
        let suiteName = UserDefaults.standard.loopShareType.sharedUserDefaultsSuiteName
        guard suiteName != "" else { return }

        if let sharedUserDefaults = UserDefaults(suiteName: suiteName) {
            sharedUserDefaults.removeObject(forKey: "latestReadings")
            sharedUserDefaults.removeObject(forKey: XDripCGMMetadataEnvelope.appGroupKey)
        }

        UserDefaults.standard.readingsStoredInSharedUserDefaultsAsDictionary = nil
    }

    /// Publishes the current rich CGM snapshot without changing the legacy reading array.
    /// Call this for source/status/battery updates that may arrive without glucose.
    public func shareMetadata(
        lastCommunicationAt: Date? = nil,
        clearReadings: Bool = false,
        sensorState: String? = nil,
        clearSensorState: Bool = false
    ) {
        guard !Bundle.main.disableLoopShare,
              UserDefaults.standard.loopShareType == .trio
        else { return }

        if let lastCommunicationAt {
            lastSuccessfulSourceCommunication = lastCommunicationAt
        }
        if clearSensorState {
            explicitSensorState = nil
        } else if let sensorState {
            explicitSensorState = sensorState
        }

        guard Self.osAidSharingPermitted else {
            glucoseData.removeAll()
            clearBlockedSourceSharedData()
            return
        }

        guard let sharedUserDefaults = UserDefaults(suiteName: UserDefaults.standard.loopShareType.sharedUserDefaultsSuiteName) else {
            return
        }

        if clearReadings {
            writeLegacyReadings([], sharedUserDefaults: sharedUserDefaults)
        }
        publishMetadata(
            sharedUserDefaults: sharedUserDefaults,
            latestSharedGlucoseAt: clearReadings ? nil : latestPreviouslySharedGlucoseAt()
        )
    }

    /// calculate loop delay to use dependent on the time of the day, based on UserDefaults loopDelaySchedule and loopDelayValueInMinutes
    ///
    /// finds element in loopDelaySchedule with value > actual minutes and uses previous element in loopDelayValueInMinutes as value to use as loopDelay
    public static func loopDelay() -> TimeInterval {

        // loopDelaySchedule is array of ints, giving minutes starting at 00:00 as of which new value for loopDelay should be used
        // if nil then user didn't set yet any value
        guard let loopDelaySchedule = UserDefaults.standard.loopDelaySchedule else {return TimeInterval(0)}

        // split in array of Int
        let loopDelayScheduleArray = loopDelaySchedule.splitToInt()

        // array size should be > 0
        guard loopDelaySchedule.count > 0 else {return TimeInterval(0)}

        // loopDelayValueInMinutes is array of ints, giving values to be applied as loopdelay, for matching minutes values in loopDelaySchedule
        guard let loopDelayValueInMinutes = UserDefaults.standard.loopDelayValueInMinutes else {return TimeInterval(0)}

        // splity in array of int
        let loopDelayValueInMinutesArray = loopDelayValueInMinutes.splitToInt()

        // array size should be > 0, and size should be equal to size of loopDelayScheduleArray
        guard loopDelayValueInMinutesArray.count > 0, loopDelayScheduleArray.count == loopDelayValueInMinutesArray.count else {return TimeInterval(0)}

        // minutes since midnight
        let minutes = Int16(Date().minutesSinceMidNightLocalTime())

        // index in loopDelaySchedule and loopDelayValueInMinutes, start with first value
        var indexInLoopDelayScheduleArray = 0

        // loop through Ints in loopDelayScheduleArray, until value > current minutes
        for (index, schedule) in loopDelayScheduleArray.enumerated() {

            if schedule > minutes {
                break
            }

            if index < loopDelayScheduleArray.count - 1 {
                if loopDelayScheduleArray[index + 1] > minutes {
                    break
                }
            } else {
                indexInLoopDelayScheduleArray = index
                break
            }
            indexInLoopDelayScheduleArray = indexInLoopDelayScheduleArray + 1
        }

        return TimeInterval(minutes: Double(loopDelayValueInMinutesArray[indexInLoopDelayScheduleArray]))

    }

    /// Encodes the long-standing app-group contract used by Loop, iAPS, and Trio.
    /// Keeping this pure makes it possible to guard the top-level array shape in tests.
    static func encodeLegacyReadings(_ readings: [[String: Any]]) throws -> Data {
        try JSONSerialization.data(withJSONObject: readings)
    }

    // MARK: - private functions

    private func publishMetadata(sharedUserDefaults: UserDefaults, latestSharedGlucoseAt: Date?) {
        let defaults = UserDefaults.standard
        let communicationAt = defaults.isMaster
            ? lastSuccessfulSourceCommunication ?? latestSharedGlucoseAt
            : lastSuccessfulSourceCommunication ?? defaults.timeStampOfLastFollowerConnection
        let envelope = XDripCGMMetadataBuilder.build(
            context: metadataContextProvider(),
            latestSharedGlucoseAt: latestSharedGlucoseAt,
            lastCommunicationAt: communicationAt,
            sensorStateOverride: explicitSensorState
        )
        guard let data = try? JSONEncoder().encode(envelope) else { return }
        sharedUserDefaults.set(data, forKey: XDripCGMMetadataEnvelope.appGroupKey)
    }

    private func writeEmptyReadingsAndMetadata(sharedUserDefaults: UserDefaults) {
        writeLegacyReadings([], sharedUserDefaults: sharedUserDefaults)
        publishMetadata(sharedUserDefaults: sharedUserDefaults, latestSharedGlucoseAt: nil)
    }

    private func writeLegacyReadings(_ readings: [[String: Any]], sharedUserDefaults: UserDefaults) {
        guard let data = try? JSONSerialization.data(withJSONObject: readings) else { return }
        sharedUserDefaults.set(data, forKey: "latestReadings")
        UserDefaults.standard.readingsStoredInSharedUserDefaultsAsDictionary = readings
    }

    /// Removes every legacy outward value that could let an OS-AID consumer use a source whose
    /// policy is currently blocked or still awaiting consent.
    private func clearBlockedSourceSharedData() {
        clearSharedLoopReadings()

        let suiteName = UserDefaults.standard.loopShareType.sharedUserDefaultsSuiteName
        guard !suiteName.isEmpty, let sharedUserDefaults = UserDefaults(suiteName: suiteName) else {
            return
        }

        sharedUserDefaults.removeObject(forKey: "cgmTransmitterDeviceAddress")
        sharedUserDefaults.removeObject(forKey: "cgmTransmitter_CBUUID_Service")
        sharedUserDefaults.removeObject(forKey: "cgmTransmitter_CBUUID_Receive")
    }

    private func latestPreviouslySharedGlucoseAt() -> Date? {
        sharedGlucoseDate(from: UserDefaults.standard.readingsStoredInSharedUserDefaultsAsDictionary?.first)
    }

    private func sharedGlucoseDate(from reading: [String: Any]?) -> Date? {
        guard let timestamp = reading?["DT"] as? String else { return nil }
        return try? parseTimestamp(timestamp)
    }

    /// The Trio app-group reader added in PR #1205 accepts a richer top-level
    /// dictionary under the existing "latestReadings" key, but it only consumes:
    ///
    /// - "recentReadings": the existing Dexcom Share-style reading array
    /// - "cgm.status.localizedMessage", "imageName", "displayState"
    /// - "cgm.sensor.percentComplete", "progressState", "isInWarmup", "isExpired"
    ///
    /// Anything else would be our own invention rather than the PR contract, so
    /// keep the payload deliberately small. If xDrip4iOS does not know enough
    /// about the active sensor to calculate a lifecycle percentage, leave "cgm"
    /// out. Trio then behaves like it did before this extension instead of
    /// rendering a made-up status.
    private func trioLatestReadingsPayload(recentReadings: [Dictionary<String, Any>], includeWithoutCGM: Bool) -> [String: Any] {
        var payload: [String: Any] = ["recentReadings": recentReadings]

        if let cgm = trioCGMDictionary() {
            payload["cgm"] = cgm
        }

        return includeWithoutCGM || payload["cgm"] != nil ? payload : [:]
    }

    /// Builds only the CGM keys that Trio currently reads from the app group.
    /// If no active sensor lifecycle can be calculated, the CGM block is omitted.
    private func trioCGMDictionary() -> [String: Any]? {
        guard let sensor = trioSensorState() else { return nil }

        var cgm: [String: Any] = [
            "sensor": sensor.dictionary
        ]

        if let status = trioStatusDictionary(for: sensor) {
            cgm["status"] = status
        }

        return cgm
    }

    private struct TrioSensorState {
        let percentComplete: Double
        let progressState: String
        let isInWarmup: Bool
        let isExpired: Bool
        let remainingMinutes: Double

        var dictionary: [String: Any] {
            [
                "percentComplete": percentComplete,
                "progressState": progressState,
                "isInWarmup": isInWarmup,
                "isExpired": isExpired
            ]
        }
    }

    /// Converts the active sensor dates into Trio's generic lifecycle state.
    /// This avoids sending an expiry or warmup status when xDrip4iOS lacks the
    /// active sensor metadata needed to calculate it.
    private func trioSensorState() -> TrioSensorState? {
        guard let sensorStartDate = UserDefaults.standard.activeSensorStartDate else { return nil }

        let maxAgeInDays = UserDefaults.standard.activeSensorMaxSensorAgeInDays ?? 0
        let maxAgeInMinutes = maxAgeInDays * 24 * 60
        guard maxAgeInMinutes > 0 else { return nil }

        let ageInMinutes = Date().timeIntervalSince(sensorStartDate) / 60
        let percentComplete = min(max(ageInMinutes / maxAgeInMinutes, 0), 1)
        let remainingMinutes = maxAgeInMinutes - ageInMinutes
        let isExpired = remainingMinutes <= 0
        let isInWarmup = ageInMinutes < trioWarmupMinutes()

        // Trio's native CGMManager path shows the arc for the final 48 hours.
        // AppGroupSource does not currently parse an expiry date from xDrip4iOS,
        // so we mark this same window as "warning" to make the merged UI show
        // the arc for xDrip4iOS as well. "critical" is reserved for expired.
        let progressState: String
        if isExpired {
            progressState = "critical"
        } else if remainingMinutes <= 48 * 60 {
            progressState = "warning"
        } else {
            progressState = "normal"
        }

        return TrioSensorState(
            percentComplete: percentComplete,
            progressState: progressState,
            isInWarmup: isInWarmup,
            isExpired: isExpired,
            remainingMinutes: remainingMinutes
        )
    }

    /// Sends only the sensor statuses that Trio can show meaningfully without
    /// native CGMManager transmitter state.
    private func trioStatusDictionary(for sensor: TrioSensorState) -> [String: Any]? {
        if sensor.isInWarmup {
            return [
                "localizedMessage": "Sensor warming up",
                "imageName": "hourglass",
                "displayState": "warning"
            ]
        }

        if sensor.isExpired {
            return [
                "localizedMessage": "Sensor expired",
                "imageName": "exclamationmark.circle.fill",
                "displayState": "critical"
            ]
        }

        if sensor.remainingMinutes <= 48 * 60 {
            return [
                "localizedMessage": max(sensor.remainingMinutes, 0).minutesToDaysAndHours(),
                "imageName": "",
                "displayState": "warning"
            ]
        }

        // A blank localizedMessage is deliberately not sent. Trio ignores blank
        // status anyway, and omitting it is clearer than pretending we have a
        // transmitter/native CGMManager status highlight when we do not.
        return nil
    }

    /// Uses the same warmup duration that xDrip4iOS applies to the active source.
    /// Trio only receives the derived state, not the source-specific rule.
    private func trioWarmupMinutes() -> Double {
        if !UserDefaults.standard.isMaster && UserDefaults.standard.followerDataSourceType == .libreLinkUp {
            return ConstantsLibreLinkUp.sensorWarmUpRequiredInMinutesForLibre
        }

        let description = UserDefaults.standard.activeSensorDescription?.lowercased() ?? ""

        if description.contains("dexcom") {
            return activeSensorIsAnubisProvider()
                ? ConstantsMaster.minimumSensorWarmUpRequiredInMinutesDexcomG6Anubis
                : ConstantsMaster.minimumSensorWarmUpRequiredInMinutesDexcomG5G6
        }

        return ConstantsMaster.minimumSensorWarmUpRequiredInMinutes
    }

    private func parseTimestamp(_ timestamp: String) throws -> Date? {
        let regex = try NSRegularExpression(pattern: "\\((.*)\\)")
        if let match = regex.firstMatch(in: timestamp, range: NSMakeRange(0, timestamp.count)) {
            guard let milliseconds = Double((timestamp as NSString).substring(with: match.range(at: 1))) else {
                return nil
            }

            let epoch = milliseconds / 1000
            return Date(timeIntervalSince1970: epoch)
        }
        return nil
    }

    static var osAidSharingPermitted: Bool {
        UserDefaults.standard.canPublishOSAidData
    }

}
