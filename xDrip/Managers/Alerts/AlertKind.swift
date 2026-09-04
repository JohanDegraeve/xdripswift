import Foundation

// MARK: - AlertKind

struct NotLoopingDeviceStatus: Sendable {
    let createdAt: Date
    let lastCheckedDate: Date
    let lastLoopDate: Date

    init(createdAt: Date, lastCheckedDate: Date, lastLoopDate: Date) {
        self.createdAt = createdAt
        self.lastCheckedDate = lastCheckedDate
        self.lastLoopDate = lastLoopDate
    }

    init(deviceStatus: NightscoutDeviceStatus) {
        self.init(createdAt: deviceStatus.createdAt, lastCheckedDate: deviceStatus.lastCheckedDate, lastLoopDate: deviceStatus.lastLoopDate)
    }

    init(snapshot: NightscoutDeviceStatusSnapshot) {
        self.init(createdAt: snapshot.createdAt, lastCheckedDate: snapshot.lastCheckedDate, lastLoopDate: snapshot.lastLoopDate)
    }

    /// Rejects server dates that are too far ahead to be valid for an alert decision.
    func sanitizingFutureDates(referenceDate: Date = Date(), futureTolerance: TimeInterval = 20) -> NotLoopingDeviceStatus {
        let maximumAllowedDate = referenceDate.addingTimeInterval(futureTolerance)
        return NotLoopingDeviceStatus(
            createdAt: createdAt > maximumAllowedDate ? .distantPast : createdAt,
            lastCheckedDate: lastCheckedDate > maximumAllowedDate ? .distantPast : lastCheckedDate,
            lastLoopDate: lastLoopDate > maximumAllowedDate ? .distantPast : lastLoopDate
        )
    }
}

/// Defines the short settling period during which an initially low Dexcom battery value is not a
/// reliable indication of the battery's usable state.
struct DexcomBatteryAlertPolicy {
    /// A missing start date is treated as still inside the settling period. In particular, a G6
    /// battery response can arrive before its transmitter-time response during the first message
    /// flow. Allowing the alarm at that point would recreate the false warning this policy prevents.
    static func shouldSuppress(hardwareStartDate: Date?, now: Date = Date()) -> Bool {
        guard let hardwareStartDate else { return true }
        let suppressionInterval = TimeInterval(
            ConstantsAlerts.dexcomBatteryAlertSuppressionPeriodInHours * 60 * 60
        )
        return now < hardwareStartDate.addingTimeInterval(suppressionInterval)
    }
}

/// low, high, very low, very high, ...
public enum AlertKind: Int, CaseIterable {
    // when adding alertkinds, add new cases at the end (ie 9, ...)
    // if this is done in the middle ((eg rapid rise alert might seem better positioned after veryhigh), then a database migration would be required, because the rawvalue is stored as Int16 in the coredata, namely the alertkind - and also in SnoozeParameters
    // the order of the alerts will in the uiview is determined by the initializer init(forRowAt row: Int)

    case verylow = 0
    case low = 1
    case high = 2
    case veryhigh = 3
    case missedreading = 4
    case calibration = 5
    case batterylow = 6
    case fastdrop = 7
    case fastrise = 8
    case phonebatterylow = 9
    case notlooping = 10
    /// Configuration for a transmitter-reported terminal sensor or transmitter failure.
    /// The event arrives from the active BLE peripheral and fires once through AlertManager.
    /// Recoverable sensor-health episodes never use this AlertKind.
    case sensorTransmitterFailure = 11
    /// G5, G6 and ONE retain the established long-life transmitter Voltage B alarm.
    case dexcomG5BatteryLow = 12
    /// G7, ONE+ and Stelo use the disposable-sensor Voltage B alarm.
    case dexcomG7BatteryLow = 13

    /// Returns the single battery configuration that belongs to a configured CGM type.
    ///
    /// The three persisted battery alert kinds remain independent so their schedules, sounds and
    /// thresholds survive when the user changes CGM family. Presentation code must use this
    /// resolver instead of showing all three configurations at once.
    static func batteryAlertKind(for transmitterType: CGMTransmitterType?) -> AlertKind? {
        switch transmitterType {
        case .dexcom:
            return .dexcomG5BatteryLow
        case .dexcomG7:
            return .dexcomG7BatteryLow
        case .miaomiao, .Bubble, .Libre2:
            return .batterylow
        case .medtrumTouchCareNano, nil:
            // Medtrum does not currently provide a battery value through TransmitterBatteryInfo.
            // With no configured CGM there is likewise no meaningful battery alarm to edit.
            return nil
        }
    }

    /// Returns the exact persisted alert kind which owns an incoming battery payload.
    ///
    /// Runtime alert evaluation deliberately uses the payload rather than the selected CGM type.
    /// This prevents a stale selection or an in-progress device change from applying a G5 threshold
    /// to G7 data, or a voltage threshold to a percentage value.
    static func batteryAlertKind(for transmitterBatteryInfo: TransmitterBatteryInfo?) -> AlertKind? {
        switch transmitterBatteryInfo {
        case .percentage:
            return .batterylow
        case .dexcom(let family, _, _, _, _, _):
            switch family {
            case .g5:
                return .dexcomG5BatteryLow
            case .g7:
                return .dexcomG7BatteryLow
            }
        case nil:
            return nil
        }
    }

    /// Defines the alarm order shown in Settings and Snooze for the configured CGM.
    /// Only the applicable battery configuration is inserted, immediately beside the other device
    /// alarms, while the inactive family configurations remain safely persisted but hidden.
    static func visibleAlertKinds(for transmitterType: CGMTransmitterType?) -> [AlertKind] {
        var kinds: [AlertKind] = [
            .verylow,
            .low,
            .fastdrop,
            .high,
            .veryhigh,
            .fastrise,
            .missedreading,
            .notlooping,
            .calibration,
            .sensorTransmitterFailure
        ]

        if let batteryAlertKind = batteryAlertKind(for: transmitterType) {
            kinds.append(batteryAlertKind)
        }

        kinds.append(.phonebatterylow)
        return kinds
    }
    
    /// if true, then this type of alert will (if raised) create an immediate notification which will have the current reading as text - simply means there's no need to create an additional notification with the current reading
    func createsImmediateNotificationWithBGReading() -> Bool {
        switch self {
        case .low, .high, .verylow, .veryhigh, .fastdrop, .fastrise:
            return true
        default:
            return false
        }
    }

    /// example, low alert needs a value = value below which alert needs to fire - there's actually no alert right now that doesn't need a value, in iosxdrip there was the iphonemuted alert, but I removed this here. Function remains, never now it might come back
    ///
    /// probably only useful in UI - named AlertKind and not AlertType because there's already an AlertType which has a different goal
    func needsAlertValue() -> Bool {
        return self != .sensorTransmitterFailure
    }

    /// A terminal failure is event-driven and has one all-day configuration.
    /// It cannot be divided into schedules because there is no value or time window to evaluate.
    func supportsAlertSchedules() -> Bool {
        return self != .sensorTransmitterFailure
    }

    /// A terminal failure is reported once by the active BLE peripheral and is never snoozable.
    func supportsSnooze() -> Bool {
        return self != .sensorTransmitterFailure
    }
    
    /// a trigger value used for some alert types that:
    ///  - fast drop: triggerValue specifies the BG value below which the alert will trigger
    ///  - fast rise: triggerValue specifies the BG value above which the alert will trigger
    func needsAlertTriggerValue() -> Bool {
        switch self {
        case .fastdrop, .fastrise:
            return true
        default:
            return false
        }
    }
    
    /// if value is a bg value, return true
    /// will only be useful in UI
    func valueIsABgValue() -> Bool {
        switch self {
        case .low, .high, .verylow, .veryhigh, .fastdrop, .fastrise:
            return true
        default:
            return false
        }
    }
    
    /// if the trigger value is a bg value, return true
    /// will only be useful in UI
    func triggervalueIsABgValue() -> Bool {
        switch self {
        case .fastdrop, .fastrise:
            return true
        default:
            return false
        }
    }
    
    /// at initial startup, a default alertentry will be created for every kind of alert. This function defines the default value to be used
    func defaultAlertValue() -> Int {
        switch self {
        case .low:
            return ConstantsDefaultAlertLevels.low
        case .high:
            return ConstantsDefaultAlertLevels.high
        case .verylow:
            return ConstantsDefaultAlertLevels.veryLow
        case .veryhigh:
            return ConstantsDefaultAlertLevels.veryHigh
        case .missedreading:
            return ConstantsDefaultAlertLevels.missedReading
        case .calibration:
            return ConstantsDefaultAlertLevels.calibration
        case .batterylow:
            if let transmitterType = UserDefaults.standard.cgmTransmitterType {
                return transmitterType.defaultBatteryAlertLevel()
            } else {
                return ConstantsDefaultAlertLevels.defaultBatteryAlertLevelMiaoMiao
            }
        case .dexcomG5BatteryLow:
            return ConstantsDefaultAlertLevels.defaultBatteryAlertLevelDexcomG5
        case .dexcomG7BatteryLow:
            return ConstantsDefaultAlertLevels.defaultBatteryAlertLevelDexcomG7
        case .fastdrop:
            return ConstantsDefaultAlertLevels.fastdrop
        case .fastrise:
            return ConstantsDefaultAlertLevels.fastrise
        case .phonebatterylow:
            return ConstantsDefaultAlertLevels.defaultBatteryAlertLevelPhone
        case .notlooping:
            return ConstantsDefaultAlertLevels.notLooping
        case .sensorTransmitterFailure:
            return 0
        }
    }

    /// default enabled state for newly introduced alert kinds.
    func defaultIsDisabled() -> Bool {
        switch self {
        case .notlooping:
            return true
        default:
            return false
        }
    }
    
    /// at initial startup, a default alertentry will be created for every kind of alert. This function defines the default trigger value to be used if needed
    func defaultAlertTriggerValue() -> Int {
        switch self {
        case .fastdrop:
            return ConstantsDefaultAlertLevels.fastdropTriggerValue
        case .fastrise:
            return ConstantsDefaultAlertLevels.fastriseTriggerValue
        default:
            return 0
        }
    }
    
    /// description of the alert to be used for logging
    func descriptionForLogging() -> String {
        switch self {
        case .low:
            return "low"
        case .high:
            return "high"
        case .verylow:
            return "verylow"
        case .veryhigh:
            return "veryhigh"
        case .missedreading:
            return "missedreading"
        case .calibration:
            return "calibration"
        case .batterylow:
            return "batterylow"
        case .dexcomG5BatteryLow:
            return "dexcomG5BatteryLow"
        case .dexcomG7BatteryLow:
            return "dexcomG7BatteryLow"
        case .fastdrop:
            return "fastdrop"
        case .fastrise:
            return "fastrise"
        case .phonebatterylow:
            return "phonebatterylow"
        case .notlooping:
            return "notlooping"
        case .sensorTransmitterFailure:
            return "sensorTransmitterFailure"
        }
    }
    
    /// verify if alert needs to be fired or not.
    ///
    /// The caller of this function must have checked already checked that lastBgReading is recent and that it has a running sensor - and that calibration is also for the last sensor
    ///
    /// Not every input parameter will be used, depending on the alertKind. For example, alertKind .calibration will not use the lastBgReading, it will use the lastCalibration
    ///
    /// - parameters:
    ///     - currentAlertEntry : the currently applicable AlertEntry, meaning for the actual time of the day
    ///     - nextAlertEntry : the next applicable AlertEntry, ie the one that comes after currentAlertEntry
    ///     - lastBgReading : should be reading for the currently active sensor with calculated value != 0
    ///     - lastButOneBgReading : should als be for the currently active sensor with calculated value != 0, it is only there to be able to calculate the unitizedDeltaString for the alertBody
    ///     - lastCalibration : is to allow to raise a calibration alert
    ///     - transmitterBatteryInfo : is to allow to raise a battery level alert
    /// - returns:
    ///     - bool : If the bool is false, then there's no need to raise an alert.
    ///     - alertbody : AlertBody, AlertTitle and delay are used if an alert needs to be raised for the notification.
    ///     - alerttitle : AlertBody, AlertTitle and delay are used if an alert needs to be raised for the notification.
    ///     - delayInSeconds : If delayInSeconds not nil and > 0 or if delayInSeconds is nil, then the alert will be a future planned Alert. This will only be applicable to missed reading alerts.
    func alertNeeded(currentAlertEntry: AlertEntry, nextAlertEntry: AlertEntry?, lastBgReading: BgReading?, _ lastButOneBgReading: BgReading?, lastCalibration: Calibration?, transmitterBatteryInfo: TransmitterBatteryInfo?, deviceStatus: NotLoopingDeviceStatus? = nil) -> (alertNeeded: Bool, alertBody: String?, alertTitle: String?, delayInSeconds: Int?) {
        // Not all input parameters in the closure are needed for every type of alert. - this is to make it generic
        
        let isMgDl = UserDefaults.standard.bloodGlucoseUnitIsMgDl
        
        switch self {
        case .low, .verylow:
            // if alertEntry not enabled, return false
            if !currentAlertEntry.alertType.enabled { return (false, nil, nil, nil) }
                
            if let lastBgReading = lastBgReading {
                // first check if lastBgReading not nil and calculatedValue > 0.0, never know that it's not been checked by caller
                if lastBgReading.finalValue == 0.0 { return (false, nil, nil, nil) }
                // now do the actual check if alert is applicable or not
                if lastBgReading.finalValue.bgValueRounded(mgDl: isMgDl) < Double(currentAlertEntry.value).bgValueRounded(mgDl: isMgDl) {
                    return (true, createAlertBodyForBgReadingAlerts(bgReading: lastBgReading, alertKind: self), createAlertTitleForBgReadingAlerts(alertKind: self), nil)
                } else { return (false, nil, nil, nil) }
            } else { return (false, nil, nil, nil) }
            
        case .high, .veryhigh:
            // if alertEntry not enabled, return false
            if !currentAlertEntry.alertType.enabled { return (false, nil, nil, nil) }
                
            if let lastBgReading = lastBgReading {
                // first check if calculatedValue > 0.0, never know that it's not been checked by caller
                if lastBgReading.finalValue == 0.0 { return (false, nil, nil, nil) }
                // now do the actual check if alert is applicable or not
                if lastBgReading.finalValue.bgValueRounded(mgDl: isMgDl) > Double(currentAlertEntry.value).bgValueRounded(mgDl: isMgDl) {
                    return (true, createAlertBodyForBgReadingAlerts(bgReading: lastBgReading, alertKind: self), createAlertTitleForBgReadingAlerts(alertKind: self), nil)
                } else { return (false, nil, nil, nil) }
            } else { return (false, nil, nil, nil) }
            
        case .fastdrop:
            // if alertEntry not enabled, return false
            if !currentAlertEntry.alertType.enabled { return (false, nil, nil, nil) }

            if let lastBgReading = lastBgReading, let lastButOneBgReading = lastButOneBgReading {
                // lastbut one reading and last reading shoud be maximum 5 minutes apart (+10 seconds to give some margin!)
                if (lastBgReading.timeStamp.timeIntervalSince(lastButOneBgReading.timeStamp)) < (5 * 60 + 10) {
                    // first check if calculatedValue > 0.0, never know that it's not been checked by caller
                    if lastBgReading.finalValue == 0.0 || lastButOneBgReading.finalValue == 0.0 { return (false, nil, nil, nil) }
                    // now do the actual check if alert is applicable or not. As this is fast drop, we'll only fire when *under* the trigger value
                    if (lastButOneBgReading.finalValue.bgValueRounded(mgDl: isMgDl) - lastBgReading.finalValue.bgValueRounded(mgDl: isMgDl) > Double(currentAlertEntry.value).bgValueRounded(mgDl: isMgDl)) && (lastBgReading.finalValue.bgValueRounded(mgDl: isMgDl) < Double(currentAlertEntry.triggerValue).bgValueRounded(mgDl: isMgDl)) {
                            return (true, createAlertBodyForBgReadingAlerts(bgReading: lastBgReading, alertKind: self), createAlertTitleForBgReadingAlerts(alertKind: self), nil)
                    } else { return (false, nil, nil, nil) }
                } else { return (false, nil, nil, nil) }
            } else { return (false, nil, nil, nil) }

        case .fastrise:
            // if alertEntry not enabled, return false
            if !currentAlertEntry.alertType.enabled { return (false, nil, nil, nil) }

            if let lastBgReading = lastBgReading, let lastButOneBgReading = lastButOneBgReading {
                // lastbut one reading and last reading shoud be maximum 5 minutes apart (+10 seconds to give some margin!)
                if (lastBgReading.timeStamp.timeIntervalSince(lastButOneBgReading.timeStamp)) < (5 * 60 + 10) {
                    // first check if calculatedValue > 0.0, never know that it's not been checked by caller
                    if lastBgReading.finalValue == 0.0 || lastButOneBgReading.finalValue == 0.0 { return (false, nil, nil, nil) }
                    // now do the actual check if alert is applicable or not. As this is fast rise, we'll only fire when *over* the trigger value
                    if lastBgReading.finalValue.bgValueRounded(mgDl: isMgDl) - lastButOneBgReading.finalValue.bgValueRounded(mgDl: isMgDl) > Double(currentAlertEntry.value).bgValueRounded(mgDl: isMgDl) && (lastBgReading.finalValue.bgValueRounded(mgDl: isMgDl) > Double(currentAlertEntry.triggerValue).bgValueRounded(mgDl: isMgDl)) {
                            return (true, createAlertBodyForBgReadingAlerts(bgReading: lastBgReading, alertKind: self), createAlertTitleForBgReadingAlerts(alertKind: self), nil)
                        } else { return (false, nil, nil, nil) }
                } else { return (false, nil, nil, nil) }
            } else { return (false, nil, nil, nil) }

        case .missedreading:
            // if no valid lastbgreading then there's definitely no need to plan an alert
            guard let lastBgReading = lastBgReading else { return (false, nil, nil, nil) }
            
            // this will be the delay of the planned notification, in seconds
            var delayToUseInSeconds: Int?
            
            // calculate time since last reading in minutes
            let timeSinceLastReadingInMinutes = Int((Date().toMillisecondsAsDouble() - lastBgReading.timeStamp.toMillisecondsAsDouble())/1000/60)
            
            // first check if currentalertEntry has an enabled alerttype
            if currentAlertEntry.alertType.enabled {
                // delay to use in the alert is value in the alertEntry - time since last reading in minutes
                delayToUseInSeconds = (Int(currentAlertEntry.value) - timeSinceLastReadingInMinutes) * 60
                
                // check now if there's a next alert entry , and if so, check if the alert time would be in the time period of that next alert, and if it's not enabled,  if so then no alert will not be scheduled
                if let nextAlertEntry = nextAlertEntry {
                    // if start of nextAlertEntry < start of currentAlertEntry, then ad 24 hours, because it means the nextAlertEntry is actually the one of the day after
                    var nextAlertEntryStartValueToUse = nextAlertEntry.start
                    if nextAlertEntry.start < currentAlertEntry.start {
                        nextAlertEntryStartValueToUse += 24 * 60
                    }
                    
                    if !nextAlertEntry.alertType.enabled {
                        // calculate when alert would fire and check if >= nextAlertEntry.start , if so don't plan an alert
                        if Date().minutesSinceMidNightLocalTime() + delayToUseInSeconds!/60 >= nextAlertEntryStartValueToUse {
                            // no need to plan a missed reading alert
                            return (false, nil, nil, nil)
                        }
                        
                    } else {
                        // next alertentry is enabled, maybe the missed reading alert value is higher
                        if nextAlertEntry.value > currentAlertEntry.value && Date().minutesSinceMidNightLocalTime() + delayToUseInSeconds!/60 > nextAlertEntryStartValueToUse {
                            delayToUseInSeconds = (Int(nextAlertEntry.value) - timeSinceLastReadingInMinutes) * 60
                        }
                    }
                }
                    
                // there's no nextAlertEntry, use the already calculated value for delayToUseInSeconds based on currentAlertEntry
                return (true, "", Texts_Alerts.missedReadingAlertTitle, delayToUseInSeconds)
                
            } else {
                // current alertEntry is not enabled but maybe the next one is and it's enabled
                if let nextAlertEntry = nextAlertEntry, nextAlertEntry.alertType.enabled {
                    // earliest expiry of alert should be time that nextAlertEntry is valid
                    // if the diff between that time and time of latestreading is less than nextAlertEntry.value, then we set actual delay to nextAlertEntry.value
                    
                    // start with maximum value
                    delayToUseInSeconds = (Int(nextAlertEntry.value) - timeSinceLastReadingInMinutes) * 60 // usually timeSinceLastReadingInMinutes will be 0 because this code is executed immediately after having received a reading
                    
                    // if start of nextAlertEntry < start of currentAlertEntry, then ad 24 hours, because it means the nextAlertEntry is actually the one of the day after
                    var nextAlertEntryStartValueToUse = nextAlertEntry.start
                    if nextAlertEntry.start < currentAlertEntry.start {
                        nextAlertEntryStartValueToUse += 24 * 60
                    }
                    
                    // if this would be before start of nextAlertEntry then increase the delay
                    var minutesSinceMidnightOfExpirtyTime = Date(timeInterval: TimeInterval(Double(delayToUseInSeconds!)), since: lastBgReading.timeStamp).minutesSinceMidNightLocalTime()
                    if minutesSinceMidnightOfExpirtyTime < Date().minutesSinceMidNightLocalTime() {
                        minutesSinceMidnightOfExpirtyTime += 24 * 60
                    }
                    let diffInMinutes = Int(nextAlertEntryStartValueToUse) - minutesSinceMidnightOfExpirtyTime
                    if diffInMinutes > 0 {
                        delayToUseInSeconds = delayToUseInSeconds! + diffInMinutes * 60
                    }
                    
                    return (true, "", Texts_Alerts.missedReadingAlertTitle, delayToUseInSeconds)
                    
                } else {
                    // none of alertentries enables missed reading, nothing to plan
                    return (false, nil, nil, nil)
                }
            }

        case .calibration:
            // if alertEntry not enabled, return false
            // if lastCalibration == nil then also no need to create an alert, could be an oop web enabled transmitter
            if !currentAlertEntry.alertType.enabled || lastCalibration == nil { return (false, nil, nil, nil) }
                                
            // if lastCalibration not nil, check the timestamp and check if delay > value (in hours)
            if abs(lastCalibration!.timeStamp.timeIntervalSinceNow) > TimeInterval(Double(currentAlertEntry.value) * 3600.0) {
                return (true, "", Texts_Alerts.calibrationNeededAlertTitle, nil)
            }
            return (false, nil, nil, nil)
            
        case .batterylow, .dexcomG5BatteryLow, .dexcomG7BatteryLow:
            // if alertEntry not enabled, return false
            if !currentAlertEntry.alertType.enabled { return (false, nil, nil, nil) }
                
            // if transmitterBatteryInfo is nil, return false
            guard let transmitterBatteryInfo = transmitterBatteryInfo else { return (false, nil, nil, nil) }
                
            // Each persisted alert kind owns exactly one unit and battery family. Reject a battery
            // from every other family so the percentage, G5 and G7 alarms cannot all fire for the
            // same packet.
            let batteryLevelToCheck = matchingBatteryLevel(from: transmitterBatteryInfo)

            if let batteryLevelToCheck = batteryLevelToCheck, currentAlertEntry.value > batteryLevelToCheck {
                return (true, "", alertTitle(), nil)
            }
                
            return (false, nil, nil, nil)

        case .phonebatterylow:
            // if alertEntry not enabled, return false
            if !currentAlertEntry.alertType.enabled { return (false, nil, nil, nil) }
            
            // Create battery info similar to transmitter battery info
            let device = UIDevice.current
            device.isBatteryMonitoringEnabled = true

            // The user has already taken the required action when the phone is connected to power,
            // so don't raise a low phone battery alert while it is charging or fully charged.
            // https://developer.apple.com/documentation/uikit/uidevice/batterystate-swift.enum
            if device.batteryState == .charging || device.batteryState == .full {
                return (false, nil, nil, nil)
            }

            // Apple returns a negative battery level when the value is unavailable. Ignore it to
            // avoid incorrectly treating an unknown level as an extremely low battery.
            let batteryLevel = device.batteryLevel
            guard batteryLevel >= 0 else { return (false, nil, nil, nil) }

            let phoneBatteryLevel = Int(batteryLevel * 100)
            
            // Check if battery level is below threshold, similar to transmitter check
            if currentAlertEntry.value > phoneBatteryLevel {
                return (true, "", Texts_Alerts.phoneBatteryLowAlertTitle, nil)
            }
            
            return (false, nil, nil, nil)

        case .notlooping:
            guard currentAlertEntry.alertType.enabled, let deviceStatus else { return (false, nil, nil, nil) }

            let alertValue = Int(currentAlertEntry.value)
            let threshold = TimeInterval(Double(alertValue) * 60.0)
            let now = Date()
            let freshnessBoundary = now.addingTimeInterval(-threshold)
            guard deviceStatus.lastCheckedDate > freshnessBoundary,
                  deviceStatus.createdAt > freshnessBoundary else {
                return (false, nil, nil, nil)
            }

            if deviceStatus.lastLoopDate == .distantPast {
                return (true, "", Texts_Alerts.notLoopingAlertTitle, nil)
            } else {
                let secondsSinceLastLoop = now.timeIntervalSince(deviceStatus.lastLoopDate)
                guard secondsSinceLastLoop >= threshold else { return (false, nil, nil, nil) }
            }

            return (true, "", Texts_Alerts.notLoopingAlertTitle, nil)

        case .sensorTransmitterFailure:
            // Terminal failures are pushed by the active CGM peripheral. They are not found by the
            // normal value and schedule checks. AlertManager reads this kind's enabled state and
            // assigned Alert Type only when SensorHealthIssueManager passes the event across.
            return (false, nil, nil, nil)
        }
    }

    /// Returns a level only when this alert kind owns the supplied battery representation.
    /// Keeping this routing independent from Core Data makes it directly testable and prevents a
    /// later alert refactor from reintroducing duplicate G5/G7/percentage notifications.
    func matchingBatteryLevel(from transmitterBatteryInfo: TransmitterBatteryInfo) -> Int? {
        switch transmitterBatteryInfo {
        case .percentage(let percentage):
            return self == .batterylow ? percentage : nil

        case .dexcom(let family, _, let voltageB, _, _, _):
            switch (self, family) {
            case (.dexcomG5BatteryLow, .g5), (.dexcomG7BatteryLow, .g7):
                // Dexcom uses zero while a real Voltage B value is unavailable. The battery UI
                // already presents this as unknown, so the alert must not interpret it as an
                // exceptionally low battery. Negative protocol values are likewise invalid.
                return voltageB > 0 ? voltageB : nil
            default:
                return nil
            }
        }
    }
    
    /// returns notification identifier for local notifications, for specific alertKind.
    func notificationIdentifier() -> String {
        switch self {
        case .low:
            return ConstantsNotifications.NotificationIdentifiersForAlerts.lowAlert
        case .high:
            return ConstantsNotifications.NotificationIdentifiersForAlerts.highAlert
        case .verylow:
            return ConstantsNotifications.NotificationIdentifiersForAlerts.veryLowAlert
        case .veryhigh:
            return ConstantsNotifications.NotificationIdentifiersForAlerts.veryHighAlert
        case .missedreading:
            return ConstantsNotifications.NotificationIdentifiersForAlerts.missedReadingAlert
        case .calibration:
            return ConstantsNotifications.NotificationIdentifiersForCalibration.subsequentCalibrationRequest
        case .batterylow:
            return ConstantsNotifications.NotificationIdentifiersForAlerts.batteryLow
        case .dexcomG5BatteryLow:
            return ConstantsNotifications.NotificationIdentifiersForAlerts.dexcomG5BatteryLow
        case .dexcomG7BatteryLow:
            return ConstantsNotifications.NotificationIdentifiersForAlerts.dexcomG7BatteryLow
        case .fastdrop:
            return ConstantsNotifications.NotificationIdentifiersForAlerts.fastDropAlert
        case .fastrise:
            return ConstantsNotifications.NotificationIdentifiersForAlerts.fastRiseAlert
        case .phonebatterylow:
            return ConstantsNotifications.NotificationIdentifiersForAlerts.phoneBatteryLow
        case .notlooping:
            return ConstantsNotifications.NotificationIdentifiersForAlerts.notLoopingAlert
        case .sensorTransmitterFailure:
            return ConstantsNotifications.NotificationIdentifiersForAlerts.sensorTransmitterFailure
        }
    }
    
    /// to be used in when name of alert needs be shown, eg pickerview, or in list of alert setings
    func alertTitle() -> String {
        switch self {
        case .low:
            return Texts_Alerts.lowAlertTitle
        case .high:
            return Texts_Alerts.highAlertTitle
        case .verylow:
            return Texts_Alerts.veryLowAlertTitle
        case .veryhigh:
            return Texts_Alerts.veryHighAlertTitle
        case .missedreading:
            return Texts_Alerts.missedReadingAlertTitle
        case .calibration:
            return Texts_Alerts.calibrationNeededAlertTitle
        case .batterylow, .dexcomG5BatteryLow, .dexcomG7BatteryLow:
            // Settings exposes one active-family battery alarm. Keep its visible name short and
            // stable while logging and notification identifiers retain the internal family.
            return Texts_Alerts.batteryLowAlertTitle
        case .fastdrop:
            return Texts_Alerts.fastDropTitle
        case .fastrise:
            return Texts_Alerts.fastRiseTitle
        case .phonebatterylow:
            return Texts_Alerts.phoneBatteryLowAlertTitle
        case .notlooping:
            return Texts_Alerts.notLoopingAlertTitle
        case .sensorTransmitterFailure:
            return Texts_Alerts.sensorTransmitterFailureAlertTitle
        }
    }

    /// Returns the alert title used while configuring or snoozing an alert.
    ///
    /// Only one transmitter battery alarm is visible at a time, but the family suffix makes it
    /// immediately clear which independently persisted threshold is being edited. Percentage-based
    /// transmitters keep the normal title because they do not share the Dexcom voltage settings.
    func configurationTitle() -> String {
        alertTitle() + configurationFamilySuffix()
    }

    /// Identifies the independently persisted Dexcom threshold wherever a short settings label is
    /// otherwise ambiguous. Other alerts do not need a family suffix.
    func configurationFamilySuffix() -> String {
        switch self {
        case .dexcomG5BatteryLow:
            return " (G6)"
        case .dexcomG7BatteryLow:
            return " (G7)"
        default:
            return ""
        }
    }

    /// A concise, independently localized title for the large snooze presentation.
    /// Other alert kinds already have compact titles and can keep their normal name.
    func largeSnoozeTitle() -> String {
        switch self {
        case .low:
            return Texts_Alerts.lowSnoozeTitle
        case .high:
            return Texts_Alerts.highSnoozeTitle
        case .verylow:
            return Texts_Alerts.veryLowSnoozeTitle
        case .veryhigh:
            return Texts_Alerts.veryHighSnoozeTitle
        case .fastdrop:
            return Texts_Alerts.fastDropSnoozeTitle
        case .fastrise:
            return Texts_Alerts.fastRiseSnoozeTitle
        default:
            return alertTitle()
        }
    }
    
    /// for UI, when value is requested, text should show also the unit (eg mgdl, mmol, minutes, days ...)
    /// What is this text ?
    func valueUnitText(transmitterType: CGMTransmitterType?) -> String {
        switch self {
        case .verylow, .low, .high, .veryhigh, .fastdrop, .fastrise:
            return UserDefaults.standard.bloodGlucoseUnitIsMgDl ? Texts_Common.mgdl : Texts_Common.mmol
        case .missedreading, .notlooping:
            return Texts_Common.minutes
        case .calibration:
            return Texts_Common.hours
        case .batterylow:
            if let transmitterType = transmitterType {
                return transmitterType.batteryUnit()
            } else {
                return "" // even though 20 is used as default alert level (assuming 20%) give as default value empty string
            }
        case .dexcomG5BatteryLow, .dexcomG7BatteryLow:
            // Dexcom packets store Voltage B in 10 mV units, but Settings presents real mV.
            return "mV"
        case .phonebatterylow:
            return "%"
        case .sensorTransmitterFailure:
            return ""
        }
    }

    /// Converts a persisted alert value into the unit shown to the user.
    /// Dexcom values remain stored in their native 10 mV unit so alert comparisons can use the
    /// packet value directly without conversion or rounding at the safety-critical firing point.
    func displayedAlertValue(fromStoredValue value: Int) -> Int {
        switch self {
        case .dexcomG5BatteryLow, .dexcomG7BatteryLow:
            return DexcomBatteryStatus.millivolts(fromRawVoltage: value)
        default:
            return value
        }
    }

    /// True for each persisted transmitter/sensor battery configuration, but not the phone battery.
    var isTransmitterBatteryAlert: Bool {
        switch self {
        case .batterylow, .dexcomG5BatteryLow, .dexcomG7BatteryLow:
            return true
        default:
            return false
        }
    }

    /// Converts a value entered in Settings back to the persisted comparison unit.
    /// Dexcom thresholds must be a whole 10 mV step because that is the packet resolution.
    func storedAlertValue(fromDisplayedValue value: Double) -> Int? {
        guard value.isFinite else { return nil }

        switch self {
        case .dexcomG5BatteryLow, .dexcomG7BatteryLow:
            guard value.rounded() == value else { return nil }
            let integerValue = Int(value)
            guard integerValue > 0, integerValue % 10 == 0 else { return nil }
            return integerValue / 10
        default:
            // Preserve the existing behaviour for glucose and percentage inputs: conversion to the
            // Int16 persistence unit truncates any fractional remainder after validation.
            return Int(value)
        }
    }
    
    /// this categorizes the different alert types into an AlertUrgencyType. Used for deciding how to display the UI and notification content
    /// - Returns: the type of alert (i.e. if urgent, notUrgent etc)
    func alertUrgencyType() -> AlertUrgencyType {
        switch self {
        case .verylow, .veryhigh, .fastdrop:
            return .urgent
        case .low, .high, .fastrise, .notlooping:
            return .warning
        default:
            return .normal
        }
    }
}

// specifically for high, low, very high, very low because these need the same kind of alertTitle
private func createAlertTitleForBgReadingAlerts(alertKind: AlertKind) -> String {
    // the start of the body, which says like "High Alert"
    switch alertKind {
    case .low:
        return Texts_Alerts.lowAlertTitle
    case .high:
        return Texts_Alerts.highAlertTitle
    case .verylow:
        return Texts_Alerts.veryLowAlertTitle
    case .veryhigh:
        return Texts_Alerts.veryHighAlertTitle
    case .fastdrop:
        return Texts_Alerts.fastDropTitle
    case .fastrise:
        return Texts_Alerts.fastRiseTitle
    case .missedreading, .calibration, .batterylow, .dexcomG5BatteryLow, .dexcomG7BatteryLow,
         .phonebatterylow, .notlooping, .sensorTransmitterFailure:
        return ""
    }
}

// specifically for high, low, very high, very low because these need to show an alert body with the BG value etc
private func createAlertBodyForBgReadingAlerts(bgReading: BgReading, alertKind: AlertKind) -> String {
    var returnValue = ""
    
    // add unit
    returnValue = returnValue + " " + bgReading.finalValue.mgDlToMmolAndToString(mgDl: UserDefaults.standard.bloodGlucoseUnitIsMgDl)
    
    // add slopeArrow
    if !bgReading.hideSlope {
        returnValue = returnValue + " " + bgReading.slopeArrow()
    }
    
    return returnValue
}
