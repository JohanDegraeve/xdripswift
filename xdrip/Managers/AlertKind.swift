import Foundation

/// low, high, very low, very high, ...
public enum AlertKind:Int, CaseIterable {
    // when adding alertkinds, try to add new cases at the end (ie 7, ...)
    // if this is done in the middle ((eg rapid rise alert might seem better positioned after veryhigh), then a database migration would be required, because the rawvalue is stored as Int16 in the coredata, namely the alertkind
    // the order of the alerts will also be the order in the settings
    
    case verylow = 0
    case low = 1
    case high = 2
    case veryhigh = 3
    case missedreading = 4
    case calibration = 5
    case batterylow = 6
    
    /// example, low alert needs a value = value below which alert needs to fire - there's actually no alert right now that doesn't need a value, in iosxdrip there was the iphonemuted alert, but I removed this here. Function remains, never now it might come back
    ///
    /// probably only useful in UI - named AlertKind and not AlertType because there's already an AlertType which has a different goal
    func needsAlertValue() -> Bool {
        switch self {
        case .low, .high, .verylow,.veryhigh,.missedreading,.calibration,.batterylow:
            return true
        }
    }
    
    /// if value is a bg value, the conversion to mmol will be needed
    ///
    /// will only be useful in UI
    func valueNeedsConversionToMmol() -> Bool {
        switch self {
            
        case .low, .high, .verylow, .veryhigh:
            return true
        case .missedreading, .calibration, .batterylow:
            return false
        }
    }
    
    /// at initial startup, a default alertentry will be created for every kind of alert. This function defines the default value to be used
    func defaultAlertValue() -> Int {
        switch self {
            
        case .low:
            return Constants.DefaultAlertLevels.low
        case .high:
            return Constants.DefaultAlertLevels.high
        case .verylow:
            return Constants.DefaultAlertLevels.veryLow
        case .veryhigh:
            return Constants.DefaultAlertLevels.veryHigh
        case .missedreading:
            return Constants.DefaultAlertLevels.missedReading
        case .calibration:
            return Constants.DefaultAlertLevels.calibration
        case .batterylow:
            if let transmitterType = UserDefaults.standard.transmitterType {
                return transmitterType.defaultBatteryAlertLevel()
            } else {
                return Constants.DefaultAlertLevels.defaultBatteryAlertLevelMiaoMiao
            }
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
    func alertNeeded(currentAlertEntry:AlertEntry, nextAlertEntry:AlertEntry?, lastBgReading:BgReading?, _ lastButOneBgReading:BgReading?, lastCalibration:Calibration?, transmitterBatteryInfo:TransmitterBatteryInfo?) -> (alertNeeded:Bool, alertBody:String?, alertTitle:String?, delayInSeconds:Int?) {
        //Not all input parameters in the closure are needed for every type of alert. - this is to make it generic
        switch self {
            
        case .low,.verylow:
                // if alertEntry not enabled, return false
                if !currentAlertEntry.alertType.enabled {return (false, nil, nil, nil)}
                
                if let lastBgReading = lastBgReading {
                    // first check if lastBgReading not nil and calculatedValue > 0.0, never know that it's not been checked by caller
                    if lastBgReading.calculatedValue == 0.0 {return (false, nil, nil, nil)}
                    // now do the actual check if alert is applicable or not
                    if lastBgReading.calculatedValue < Double(currentAlertEntry.value) {
                        return (true, lastBgReading.unitizedDeltaString(previousBgReading: lastButOneBgReading, showUnit: true, highGranularity: true), createAlertTitleForBgReadingAlerts(bgReading: lastBgReading, alertKind: self), nil)
                    } else {return (false, nil, nil, nil)}
                } else {return (false, nil, nil, nil)}
            
        case .high,.veryhigh:
                // if alertEntry not enabled, return false
                if !currentAlertEntry.alertType.enabled {return (false, nil, nil, nil)}
                
                if let lastBgReading = lastBgReading {
                    // first check if calculatedValue > 0.0, never know that it's not been checked by caller
                    if lastBgReading.calculatedValue == 0.0 {return (false, nil, nil, nil)}
                    // now do the actual check if alert is applicable or not
                    if lastBgReading.calculatedValue > Double(currentAlertEntry.value) {
                        return (true, lastBgReading.unitizedDeltaString(previousBgReading: lastButOneBgReading, showUnit: true, highGranularity: true), createAlertTitleForBgReadingAlerts(bgReading: lastBgReading, alertKind: self), nil)
                    } else {return (false, nil, nil, nil)}
                } else {return (false, nil, nil, nil)}
            
        case .missedreading:
                // if no valid lastbgreading then there's definitely no need to plan an alert
                guard let lastBgReading = lastBgReading else {return (false, nil, nil, nil)}
                
                // this will be the delay of the planned notification, in seconds
                var delayToUseInSeconds:Int?
                //this will be the alertentry to use, either the current one, or the next one, or none
                var alertEntryToUse:AlertEntry?
                
                // so there's a reading, let's find the applicable alertentry
                if currentAlertEntry.alertType.enabled {
                    alertEntryToUse = currentAlertEntry
                } else {
                    if let nextAlertEntry = nextAlertEntry {
                        if nextAlertEntry.alertType.enabled {
                            alertEntryToUse = nextAlertEntry
                        }
                    }
                }
                
                // now see if we found an alertentry, and if yes prepare the return value
                if let alertEntryToUse = alertEntryToUse {
                    // the current alert entry is enabled, we'll use that one to plan the missed reading alert
                    let timeSinceLastReadingInMinutes:Int = Int((Date().toMillisecondsAsDouble() - lastBgReading.timeStamp.toMillisecondsAsDouble())/1000/60)
                    // delay to use in the alert is value in the alertEntry - time since last reading in minutes
                    delayToUseInSeconds = (Int(alertEntryToUse.value) - timeSinceLastReadingInMinutes) * 60
                    return (true, "", Texts_Alerts.missedReadingAlertTitle, delayToUseInSeconds)
                } else {
                    // none of alertentries enables missed reading, nothing to plan
                    return (false, nil, nil, nil)
                }
                
        case .calibration:
                // if alertEntry not enabled, return false
                if !currentAlertEntry.alertType.enabled || lastCalibration == nil {return (false, nil, nil, nil)}
                                
                // if lastCalibration not nil, check the timestamp and check if delay > value (in hours)
                if abs(lastCalibration!.timeStamp.timeIntervalSinceNow) > TimeInterval(Int(currentAlertEntry.value) * 3600) {
                    return(true, "", Texts_Alerts.calibrationNeededAlertTitle, nil)
                }
                return (false, nil, nil, nil)
            
        case .batterylow:
                // if alertEntry not enabled, return false
                if !currentAlertEntry.alertType.enabled {return (false, nil, nil, nil)}
                
                // if transmitterBatteryInfo is nil, return false
                guard let transmitterBatteryInfo = transmitterBatteryInfo else {return (false, nil, nil, nil)}
                
                // get level
                var batteryLevelToCheck:Int?
                
                switch transmitterBatteryInfo {
                case .percentage(let percentage):
                    batteryLevelToCheck = percentage
                case .DexcomG5(let voltageA, _, _, _, _):
                    batteryLevelToCheck = voltageA
                case .DexcomG4(let level):
                    batteryLevelToCheck = level
                }

                if let batteryLevelToCheck = batteryLevelToCheck, currentAlertEntry.value > batteryLevelToCheck {
                    return (true, "", Texts_Alerts.batteryLowAlertTitle, nil)
                }
                
                return (false, nil, nil, nil)
            }
    }
    
    /// returns notification identifier for local notifications, for specific alertKind.
    func notificationIdentifier() -> String {
        switch self {
            
        case .low:
            return Constants.Notifications.NotificationIdentifiersForAlerts.lowAlert
        case .high:
            return Constants.Notifications.NotificationIdentifiersForAlerts.highAlert
        case .verylow:
            return Constants.Notifications.NotificationIdentifiersForAlerts.veryLowAlert
        case .veryhigh:
            return Constants.Notifications.NotificationIdentifiersForAlerts.veryHighAlert
        case .missedreading:
            return Constants.Notifications.NotificationIdentifiersForAlerts.missedReadingAlert
        case .calibration:
            return Constants.Notifications.NotificationIdentifiersForCalibration.subsequentCalibrationRequest
        case .batterylow:
            return Constants.Notifications.NotificationIdentifiersForAlerts.batteryLow
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
        }
    }
    
    /// for UI, when value is requested, text should show also the unit (eg mgdl, mmol, minutes, days ...)
    /// What is this text ?
    func valueUnitText(transmitterType:CGMTransmitterType?) -> String {
        switch self {
            
        case .verylow, .low, .high, .veryhigh:
            return UserDefaults.standard.bloodGlucoseUnitIsMgDl ? Texts_Common.mgdl:Texts_Common.mmol
        case .missedreading:
            return Texts_Common.minutes
        case .calibration:
            return Texts_Common.hours
        case .batterylow:
            if let transmitterType = transmitterType {
                return transmitterType.batteryUnit()
            } else {
                return ""// even though 20 is used as default alert level (assuming 20%) give as default value empty string
            }
        }
    }
}

// specifically for high, low, very high, very low because these need the same kind of alertTitle
fileprivate func createAlertTitleForBgReadingAlerts(bgReading:BgReading, alertKind:AlertKind) -> String {
    var returnValue:String = ""
    
    // the start of the body, which says like "High Alert"
    switch alertKind {
        
    case .low:
        returnValue = returnValue + Texts_Alerts.lowAlertTitle
    case .high:
        returnValue = returnValue + Texts_Alerts.highAlertTitle
    case .verylow:
        returnValue = returnValue + Texts_Alerts.veryLowAlertTitle
    case .veryhigh:
        returnValue = returnValue + Texts_Alerts.veryHighAlertTitle
    default:
        return returnValue
    }
    
    // add unit
    returnValue = returnValue + " " + bgReading.calculatedValue.mgdlToMmolAndToString(mgdl: UserDefaults.standard.bloodGlucoseUnitIsMgDl)
    
    // add slopeArrow
    if !bgReading.hideSlope {
        returnValue = returnValue + " " + bgReading.slopeArrow()
    }
    
    return returnValue
}
