import Foundation

/// low, high, very low, very high, ...
public enum AlertKind:Int, CaseIterable {
    case low = 0
    case high = 1
    case verylow = 2
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
    
    /// returns a closure that will verify if alert needs to be fired or not.
    ///
    /// The caller of this function must have checked already checked that lastBgReading is recent and that it has a running sensor - and that calibration is also for the last sensor
    ///
    /// The closure in the return value has several optional input parameters. Not every input parameter will be used, depending on the alertKind. For example, alertKind .calibration will not use the lastBgReading, it will use the lastCalibration
    ///
    /// The closure returns a bool which indicates if an alert needs to be raised or not, and an optional alertBody and alertTitle and an optional int, which is the optional delay
    ///
    /// For missed reading alert : this is the only case where the delay in the return will have a value.
    ///
    /// - returns:
    ///     - a closure that needs to be called to verify if an alert is needed or not. The closure returns a tuble with a bool, an alertbody, alerttitle and delay. If the bool is false, then there's no need to raise an alert. AlertBody, alertTitle and delay are used if an alert needs to be raised for the notification. The input to the closure are the currently applicable alertEntry, the next alertEntry (from time point of view), two bg readings, last and lastbutone, last calibration and batteryLevel is the current transmitter battery level
    func alertNeededChecker() -> (AlertEntry, AlertEntry?, BgReading?, BgReading?, Calibration?, Int?) -> (alertNeeded:Bool, alertBody:String?, alertTitle:String?, delay:Int?) {
        //Not all input parameters in the closure are needed for every type of alert. - this is to make it generic
        switch self {
            
        case .low,.verylow:
            return { (alertEntry:AlertEntry, nextAlertEntry:AlertEntry?, lastBgReading:BgReading?, _ lastButOneBgReading:BgReading?, lastCalibration:Calibration?, batteryLevel:Int?) -> (alertNeeded:Bool, alertBody:String?, alertTitle:String?, delay:Int?) in
                if let lastBgReading = lastBgReading {
                    // first check if lastBgReading not nil and calculatedValue > 0.0, never know that it's not been checked by caller
                    if lastBgReading.calculatedValue == 0.0 {return (false, nil, nil, nil)}
                    // now do the actual check if alert is applicable or not
                    if lastBgReading.calculatedValue < Double(alertEntry.value) {
                        return (true, lastBgReading.unitizedDeltaString(previousBgReading: lastButOneBgReading, showUnit: true, highGranularity: true), createAlertTitleForBgReadingAlerts(bgReading: lastBgReading, alertKind: self), nil)
                    } else {return (false, nil, nil, nil)}
                } else {return (false, nil, nil, nil)}
            }
        case .high,.veryhigh:
            return { (alertEntry:AlertEntry, nextAlertEntry:AlertEntry?, lastBgReading:BgReading?, _ lastButOneBgReading:BgReading?, lastCalibration:Calibration?, batteryLevel:Int?) -> (alertNeeded:Bool, alertBody:String?, alertTitle:String?, delay:Int?) in
                if let lastBgReading = lastBgReading {
                    // first check if calculatedValue > 0.0, never know that it's not been checked by caller
                    if lastBgReading.calculatedValue == 0.0 {return (false, nil, nil, nil)}
                    // now do the actual check if alert is applicable or not
                    if lastBgReading.calculatedValue > Double(alertEntry.value) {
                        return (true, lastBgReading.unitizedDeltaString(previousBgReading: lastButOneBgReading, showUnit: true, highGranularity: true), createAlertTitleForBgReadingAlerts(bgReading: lastBgReading, alertKind: self), nil)
                    } else {return (false, nil, nil, nil)}
                } else {return (false, nil, nil, nil)}
            }
        case .missedreading:
            return { (alertEntry:AlertEntry, nextAlertEntry:AlertEntry?, lastBgReading:BgReading?, _ lastButOneBgReading:BgReading?, lastCalibration:Calibration?, batteryLevel:Int?) -> (alertNeeded:Bool, alertBody:String?, alertTitle:String?, delay:Int?) in
                // TODO: finish this
                return (false, nil, nil, nil)
            }
        case .calibration:
            return { (alertEntry:AlertEntry, nextAlertEntry:AlertEntry?, lastBgReading:BgReading?, _ lastButOneBgReading:BgReading?, lastCalibration:Calibration?, batteryLevel:Int?) -> (alertNeeded:Bool, alertBody:String?, alertTitle:String?, delay:Int?) in
                // TODO: finish this
                return (false, nil, nil, nil)
            }
        case .batterylow:
            return { (alertEntry:AlertEntry, nextAlertEntry:AlertEntry?, lastBgReading:BgReading?, _ lastButOneBgReading:BgReading?, lastCalibration:Calibration?, batteryLevel:Int?) -> (alertNeeded:Bool, alertBody:String?, alertTitle:String?, delay:Int?) in
                // TODO: finish this
                return (false, nil, nil, nil)
            }
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
            return Constants.Notifications.NotificationIdentifiersForAlerts.subsequentCalibrationRequest
        case .batterylow:
            return Constants.Notifications.NotificationIdentifiersForAlerts.batteryLow
        }
    }
    
    /// returns category identifier for local notifications, for specific alertKind.
    func categoryIdentifier() -> String {
        switch self {
            
        case .low:
            return Constants.Notifications.CategoryIdentifiersForAlerts.lowAlert
        case .high:
            return Constants.Notifications.CategoryIdentifiersForAlerts.highAlert
        case .verylow:
            return Constants.Notifications.CategoryIdentifiersForAlerts.veryLowAlert
        case .veryhigh:
            return Constants.Notifications.CategoryIdentifiersForAlerts.veryHighAlert
        case .missedreading:
            return Constants.Notifications.CategoryIdentifiersForAlerts.missedReadingAlert
        case .calibration:
            return Constants.Notifications.CategoryIdentifiersForAlerts.subsequentCalibrationRequest
        case .batterylow:
            return Constants.Notifications.CategoryIdentifiersForAlerts.batteryLow
        }
    }
    
}

// specifically for high, low, very high, very low because these need the same kind of alertTitle
fileprivate func createAlertTitleForBgReadingAlerts(bgReading:BgReading, alertKind:AlertKind) -> String {
    var returnValue:String = ""
    
    // the start of the body, which says likz "High Alert"
    switch alertKind {
        
    case .low:
        returnValue = returnValue + Texts_Alerts.lowAlertBody
    case .high:
        returnValue = returnValue + Texts_Alerts.highAlertBody
    case .verylow:
        returnValue = returnValue + Texts_Alerts.veryLowAlertBody
    case .veryhigh:
        returnValue = returnValue + Texts_Alerts.veryHighAlertBody
    default:
        return returnValue
    }
    
    // add unit
    returnValue = returnValue + " " + bgReading.calculatedValue.bgValuetoString(mgdl: UserDefaults.standard.bloodGlucoseUnitIsMgDl)
    
    // add slopeArrow
    if !bgReading.hideSlope {
        returnValue = returnValue + " " + bgReading.slopeArrow()
    }
    
    return returnValue
}
