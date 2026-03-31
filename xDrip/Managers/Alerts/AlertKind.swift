import Foundation

// MARK: - AlertKind

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

    /// this is used for presentation in UI table view. It allows to order the alert kinds in the view, different than they case ordering, and so allows to add new cases
    init?(forSection section: Int) {
        switch section {
        case 0:
            self = .verylow
        case 1:
            self = .low
        case 2:
            self = .fastdrop
        case 3:
            self = .high
        case 4:
            self = .veryhigh
        case 5:
            self = .fastrise
        case 6:
            self = .missedreading
        case 7:
            self = .calibration
        case 8:
            self = .batterylow
        case 9:
            self = .phonebatterylow
        default:
            fatalError("in AlertKind initializer init(forRowAt row: Int), there's no case for the rownumber")
        }
    }
    
    /// gives the raw value of the alertkind for a specific section in a uitableview, is the opposite of the initializer
    static func alertKindRawValue(forSection section: Int) -> Int {
        switch section {
        case 0: // very low
            return 0
        case 1: // low
            return 1
        case 2: // fast drop
            return 7
        case 3: // high
            return 2
        case 4: // very high
            return 3
        case 5: // fast rise
            return 8
        case 6: // missed reading
            return 4
        case 7: // calibration
            return 5
        case 8: // battery low
            return 6
        case 9: // phone battery low
            return 9
        default:
            fatalError("in alertKindRawValue, unknown case")
        }
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
        return true
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
        case .fastdrop:
            return ConstantsDefaultAlertLevels.fastdrop
        case .fastrise:
            return ConstantsDefaultAlertLevels.fastrise
        case .phonebatterylow:
            return ConstantsDefaultAlertLevels.defaultBatteryAlertLevelPhone
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
        case .fastdrop:
            return "fastdrop"
        case .fastrise:
            return "fastrise"
        case .phonebatterylow:
            return "phonebatterylow"
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
    func alertNeeded(currentAlertEntry: AlertEntry, nextAlertEntry: AlertEntry?, lastBgReading: BgReading?, _ lastButOneBgReading: BgReading?, lastCalibration: Calibration?, transmitterBatteryInfo: TransmitterBatteryInfo?) -> (alertNeeded: Bool, alertBody: String?, alertTitle: String?, delayInSeconds: Int?) {
        // Not all input parameters in the closure are needed for every type of alert. - this is to make it generic
        
        let isMgDl = UserDefaults.standard.bloodGlucoseUnitIsMgDl
        
        switch self {
        case .low, .verylow:
            // if alertEntry not enabled, return false
            if !currentAlertEntry.alertType.enabled { return (false, nil, nil, nil) }
                
            if let lastBgReading = lastBgReading {
                // first check if lastBgReading not nil and calculatedValue > 0.0, never know that it's not been checked by caller
                if lastBgReading.calculatedValue == 0.0 { return (false, nil, nil, nil) }
                // now do the actual check if alert is applicable or not
                if lastBgReading.calculatedValue.bgValueRounded(mgDl: isMgDl) < Double(currentAlertEntry.value).bgValueRounded(mgDl: isMgDl) {
                    return (true, createAlertBodyForBgReadingAlerts(bgReading: lastBgReading, alertKind: self), createAlertTitleForBgReadingAlerts(alertKind: self), nil)
                } else { return (false, nil, nil, nil) }
            } else { return (false, nil, nil, nil) }
            
        case .high, .veryhigh:
            // if alertEntry not enabled, return false
            if !currentAlertEntry.alertType.enabled { return (false, nil, nil, nil) }
                
            if let lastBgReading = lastBgReading {
                // first check if calculatedValue > 0.0, never know that it's not been checked by caller
                if lastBgReading.calculatedValue == 0.0 { return (false, nil, nil, nil) }
                // now do the actual check if alert is applicable or not
                if lastBgReading.calculatedValue.bgValueRounded(mgDl: isMgDl) > Double(currentAlertEntry.value).bgValueRounded(mgDl: isMgDl) {
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
                    if lastBgReading.calculatedValue == 0.0 || lastButOneBgReading.calculatedValue == 0.0 { return (false, nil, nil, nil) }
                    // now do the actual check if alert is applicable or not. As this is fast drop, we'll only fire when *under* the trigger value
                    if (lastButOneBgReading.calculatedValue.bgValueRounded(mgDl: isMgDl) - lastBgReading.calculatedValue.bgValueRounded(mgDl: isMgDl) > Double(currentAlertEntry.value).bgValueRounded(mgDl: isMgDl)) && (lastBgReading.calculatedValue.bgValueRounded(mgDl: isMgDl) < Double(currentAlertEntry.triggerValue).bgValueRounded(mgDl: isMgDl)) {
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
                    if lastBgReading.calculatedValue == 0.0 || lastButOneBgReading.calculatedValue == 0.0 { return (false, nil, nil, nil) }
                    // now do the actual check if alert is applicable or not. As this is fast rise, we'll only fire when *over* the trigger value
                    if lastBgReading.calculatedValue.bgValueRounded(mgDl: isMgDl) - lastButOneBgReading.calculatedValue.bgValueRounded(mgDl: isMgDl) > Double(currentAlertEntry.value).bgValueRounded(mgDl: isMgDl) && (lastBgReading.calculatedValue.bgValueRounded(mgDl: isMgDl) > Double(currentAlertEntry.triggerValue).bgValueRounded(mgDl: isMgDl)) {
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
                        nextAlertEntryStartValueToUse += nextAlertEntryStartValueToUse + 24 * 60
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
                        nextAlertEntryStartValueToUse += nextAlertEntryStartValueToUse + 24 * 60
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
            
        case .batterylow:
            // if alertEntry not enabled, return false
            if !currentAlertEntry.alertType.enabled { return (false, nil, nil, nil) }
                
            // if transmitterBatteryInfo is nil, return false
            guard let transmitterBatteryInfo = transmitterBatteryInfo else { return (false, nil, nil, nil) }
                
            // get level
            var batteryLevelToCheck: Int?
                
            switch transmitterBatteryInfo {
            case .percentage(let percentage):
                batteryLevelToCheck = percentage
            case .DexcomG5(_, let voltageB, _, _, _):
                batteryLevelToCheck = voltageB
            }

            if let batteryLevelToCheck = batteryLevelToCheck, currentAlertEntry.value > batteryLevelToCheck {
                return (true, "", Texts_Alerts.batteryLowAlertTitle, nil)
            }
                
            return (false, nil, nil, nil)

        case .phonebatterylow:
            // if alertEntry not enabled, return false
            if !currentAlertEntry.alertType.enabled { return (false, nil, nil, nil) }
            
            // Create battery info similar to transmitter battery info
            UIDevice.current.isBatteryMonitoringEnabled = true
            let phoneBatteryLevel = Int(UIDevice.current.batteryLevel * 100)
            
            // Check if battery level is below threshold, similar to transmitter check
            if currentAlertEntry.value > phoneBatteryLevel {
                return (true, "", Texts_Alerts.phoneBatteryLowAlertTitle, nil)
            }
            
            return (false, nil, nil, nil)
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
        case .fastdrop:
            return ConstantsNotifications.NotificationIdentifiersForAlerts.fastDropAlert
        case .fastrise:
            return ConstantsNotifications.NotificationIdentifiersForAlerts.fastRiseAlert
        case .phonebatterylow:
            return ConstantsNotifications.NotificationIdentifiersForAlerts.phoneBatteryLow
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
        case .batterylow:
            return Texts_Alerts.batteryLowAlertTitle
        case .fastdrop:
            return Texts_Alerts.fastDropTitle
        case .fastrise:
            return Texts_Alerts.fastRiseTitle
        case .phonebatterylow:
            return Texts_Alerts.phoneBatteryLowAlertTitle
        }
    }
    
    /// for UI, when value is requested, text should show also the unit (eg mgdl, mmol, minutes, days ...)
    /// What is this text ?
    func valueUnitText(transmitterType: CGMTransmitterType?) -> String {
        switch self {
        case .verylow, .low, .high, .veryhigh, .fastdrop, .fastrise:
            return UserDefaults.standard.bloodGlucoseUnitIsMgDl ? Texts_Common.mgdl : Texts_Common.mmol
        case .missedreading:
            return Texts_Common.minutes
        case .calibration:
            return Texts_Common.hours
        case .batterylow:
            if let transmitterType = transmitterType {
                return transmitterType.batteryUnit()
            } else {
                return "" // even though 20 is used as default alert level (assuming 20%) give as default value empty string
            }
        case .phonebatterylow:
            return "%"
        }
    }
    
    /// this categorizes the different alert types into an AlertUrgencyType. Used for deciding how to display the UI and notification content
    /// - Returns: the type of alert (i.e. if urgent, notUrgent etc)
    func alertUrgencyType() -> AlertUrgencyType {
        switch self {
        case .verylow, .veryhigh, .fastdrop:
            return .urgent
        case .low, .high, .fastrise:
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
    case .missedreading, .calibration, .batterylow, .phonebatterylow:
        return ""
    }
}

// specifically for high, low, very high, very low because these need to show an alert body with the BG value etc
private func createAlertBodyForBgReadingAlerts(bgReading: BgReading, alertKind: AlertKind) -> String {
    var returnValue = ""
    
    // add unit
    returnValue = returnValue + " " + bgReading.calculatedValue.mgDlToMmolAndToString(mgDl: UserDefaults.standard.bloodGlucoseUnitIsMgDl)
    
    // add slopeArrow
    if !bgReading.hideSlope {
        returnValue = returnValue + " " + bgReading.slopeArrow()
    }
    
    return returnValue
}
