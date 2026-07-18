//
//  LoopManager.swift
//  xdrip
//
//  Created by Julian Groen on 05/04/2020.
//  Copyright © 2020 Johan Degraeve. All rights reserved.
//

import Foundation
import OSLog

public class LoopManager: NSObject {

    // MARK: - private properties

    /// reference to coreDataManager
    private var coreDataManager:CoreDataManager

    /// a BgReadingsAccessor
    private var bgReadingsAccessor:BgReadingsAccessor

    /// Whether the active Dexcom G6 transmitter is an Anubis.
    private let activeSensorIsAnubisProvider: () -> Bool

    // for trace,
    private let log = OSLog(subsystem: ConstantsLog.subSystem, category: ConstantsLog.categoryLoopManager)

    // MARK: - public properties

    /// latest glucose data values - to be used only if using loopDelay
    /// - first is the youngest
    ///
    /// actually there's redundancy in data. Readings are normally read from coredata here in this module, and stored in lastReadings - disadvantage is that BgReadings in coredata only contain readings per 5 minutes + the latest reading (which can be less than 5 minutes later than latest but one reading. But when using loopdelay, we omit the most recent values, and end up with an array of readings, 5 minutes apart from each other, as a result Loop would receive a reading only every 5 minutes. For that reason, this second array glucoseData is introduced (later in the project). This array has readings per minute, smoothed. Ideally, glucoseData could be used no matter of loopDelay is used or not, but to avoid uncatched coding errors, I kept both
    public var glucoseData = [GlucoseData]()

    // MARK: - initializer

    init(coreDataManager: CoreDataManager, activeSensorIsAnubisProvider: @escaping () -> Bool) {

        // initialize non optional private properties
        self.coreDataManager = coreDataManager
        self.bgReadingsAccessor = BgReadingsAccessor(coreDataManager: coreDataManager)
        self.activeSensorIsAnubisProvider = activeSensorIsAnubisProvider

        // call super.init
        super.init()

    }

    // MARK: - public functions

    /// share latest readings with Loop
    public func share() {

        // will return if loop share is disabled
        guard UserDefaults.standard.loopShareType != .disabled else { return }

        // will return if loop share is enabled but the user is receiving BG values from Medtrum Follower Mode
        // this is due to this sensor being pulled by European Health Agencies (March/April 2026) due to inaccurate results
        // and fears over inaccurate dosing by AID systems.
        // SPANISH: https://www.aemps.gob.es/informa/la-aemps-informa-del-cese-de-comercializacion-y-retirada-del-mercado-del-sensor-y-transmisor-del-sistema-de-monitorizacion-continua-de-glucosa-a8-touchcare/
        // basically guard to ensure "master" or "follower mode except Medtrum" to allow to proceed
        guard UserDefaults.standard.isMaster || (!UserDefaults.standard.isMaster && UserDefaults.standard.followerDataSourceType != .medtrumEasyView) else {
            clearSharedLoopReadings()
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

            return

        }

        trace("    in share, sharing data with selected OS-AID target",log: log, category: ConstantsLog.categoryLoopManager, type: .debug)

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
                    shareTrioStatusOnlyIfAvailable(sharedUserDefaults: sharedUserDefaults)
                }
                return
            }

        } else if lastReadings.count == 0 {
            // this is the case where loopdelay = 0 and lastReadings is empty
            if loopShareType == .trio {
                shareTrioStatusOnlyIfAvailable(sharedUserDefaults: sharedUserDefaults)
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

                // Loop should always receive the final post processed value shown in the app
                let date = "/Date(" + Int64(floor(reading.timeStamp.toMillisecondsAsDouble() / 1000) * 1000).description + ")/"
                var representation: [String : Any] = [
                    "Trend" : reading.slopeOrdinal(),
                    "ST" : date,
                    "DT" : date,
                    "Value" : round(reading.finalValue),
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
                shareTrioStatusOnlyIfAvailable(sharedUserDefaults: sharedUserDefaults)
            } else {
                sharedUserDefaults.removeObject(forKey: "latestReadings")
                UserDefaults.standard.readingsStoredInSharedUserDefaultsAsDictionary = nil
            }
            return
        }

        // Loop and iAPS expect "latestReadings" to contain a top-level array of
        // reading dictionaries. Trio PR #1205 added an xDrip4iOS-specific rich
        // shape under the same key:
        // https://github.com/nightscout/Trio/pull/1205
        //
        // Keep the existing array for Loop/iAPS because they will fail the first
        // JSON cast if we change the top-level type. Only the Trio app group gets
        // the richer dictionary, with the existing readings moved under
        // "recentReadings" and CGM lifecycle/status beside it.
        let payload: Any = loopShareType == .trio ? trioLatestReadingsPayload(recentReadings: dictionary, includeWithoutCGM: true) : dictionary

        guard let data = try? JSONSerialization.data(withJSONObject: payload) else {
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
        }

        UserDefaults.standard.readingsStoredInSharedUserDefaultsAsDictionary = nil
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

    // MARK: - private functions

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

    /// During warmup, expiry or similar states there may be no fresh readings to
    /// share. For Loop/iAPS we keep the existing behaviour and clear stale data.
    /// For Trio, the PR #1205 app-group parser can still use an empty
    /// "recentReadings" array plus "cgm" to show the sensor state on the home
    /// bobble. If we also have no CGM lifecycle, clear as before.
    private func shareTrioStatusOnlyIfAvailable(sharedUserDefaults: UserDefaults) {
        let payload = trioLatestReadingsPayload(recentReadings: [], includeWithoutCGM: false)

        guard !payload.isEmpty, let data = try? JSONSerialization.data(withJSONObject: payload) else {
            sharedUserDefaults.removeObject(forKey: "latestReadings")
            UserDefaults.standard.readingsStoredInSharedUserDefaultsAsDictionary = nil
            return
        }

        sharedUserDefaults.set(data, forKey: "latestReadings")
        UserDefaults.standard.readingsStoredInSharedUserDefaultsAsDictionary = []
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
            let epoch = Double((timestamp as NSString).substring(with: match.range(at: 1)))! / 1000
            return Date(timeIntervalSince1970: epoch)
        }
        return nil
    }

}
