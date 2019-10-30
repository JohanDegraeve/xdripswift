import Foundation
import os
import UserNotifications
import AudioToolbox


/// has a function to check if an alert needs to be raised, and also raised the alert notification if needed.
///
/// has all the logic but should be not or almost not aware of the kind of alerts that exists. The logic that is different per type of alert is defined in type AlertKind.
public class AlertManager:NSObject {
    
    // MARK: - private properties
  
    /// snoozeActionIdentifier for alert notification
    private let snoozeActionIdentifier = "snoozeActionIdentifier"
    
    /// snoozeCategoryIdentifier for alert notification
    private let snoozeCategoryIdentifier = "snoozeCategoryIdentifier"
    
    /// for logging
    private var log = OSLog(subsystem: ConstantsLog.subSystem, category: ConstantsLog.categoryAlertManager)
    
    /// BgReadings instance
    private let bgReadingsAccessor:BgReadingsAccessor
    
    /// Calibrations instance
    private let calibrationsAccessor:CalibrationsAccessor
    
    /// Sensors instance
    private let sensorsAccessor:SensorsAccessor
    
    /// for getting alertTypes from coredata
    private var alertTypesAccessor:AlertTypesAccessor
    
    /// for getting alertEntries from coredata
    private var alertEntriesAccessor:AlertEntriesAccessor
    
    /// playSound instance
    private var soundPlayer:SoundPlayer?
    
    /// snooze parameters
    private var snoozeParameters = [Int: SnoozeParameters]()
    
    /// helper array with all alert notification identifiers
    private var alertNotificationIdentifers = [String]()
    
    /// permanent reference to notificationcenter
    private let uNUserNotificationCenter:UNUserNotificationCenter
    
    /// snooze times in minutes
    private let snoozeValueMinutes = [5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 55, 60, 75, 90, 120, 150, 180, 240, 300, 360, 420, 480, 540, 600, 1440, 10080]
    
    /// snooze times as shown to the user, actual strings will be replaced during init
    private var snoozeValueStrings = ["5 minutes", "10 minutes", "15 minutes", "20 minutes", "25 minutes", "30 minutes", "35 minutes",
                                                   "40 minutes", "45 minutes", "50 minutes", "55 minutes", "1 hour", "1 hour 15 minutes", "1,5 hours", "2 hours", "2,5 hours", "3 hours", "4 hours",
                                                   "5 hours", "6 hours", "7 hours", "8 hours", "9 hours", "10 hours", "1 day", "1 week"]
    
    /// constant for key in ApplicationManager.shared.addClosureToRunWhenAppWillEnterForeground - for closure that will stop playing sound
    private let applicationManagerKeyStopPlayingSound = "AlertManager-stopplayingsound"
    
    // MARK: - initializer
    
    init(coreDataManager:CoreDataManager, soundPlayer:SoundPlayer?) {
        // initialize properties
        self.bgReadingsAccessor = BgReadingsAccessor(coreDataManager: coreDataManager)
        self.alertTypesAccessor = AlertTypesAccessor(coreDataManager: coreDataManager)
        self.alertEntriesAccessor = AlertEntriesAccessor(coreDataManager: coreDataManager)
        self.calibrationsAccessor = CalibrationsAccessor(coreDataManager: coreDataManager)
        self.sensorsAccessor = SensorsAccessor(coreDataManager: coreDataManager)
        self.soundPlayer = soundPlayer
        self.uNUserNotificationCenter = UNUserNotificationCenter.current()
        
        // call super.init
        super.init()
        
        // initialize snoozeparameters
        for alertKind in AlertKind.allCases {
            snoozeParameters[alertKind.rawValue] = SnoozeParameters()
        }
        
        // in snoozeValueStrings, replace all occurrences of minutes, minute, etc... by language dependent value
        for (index, _) in snoozeValueStrings.enumerated() {
            snoozeValueStrings[index] = snoozeValueStrings[index].replacingOccurrences(of: "minutes", with: Texts_Common.minutes).replacingOccurrences(of: "hour", with: Texts_Common.hour).replacingOccurrences(of: "hours", with: Texts_Common.hours).replacingOccurrences(of: "day", with: Texts_Common.day).replacingOccurrences(of: "week", with: Texts_Common.week)
        }
        
        //  initialize array of alertNotifications
        initAlertNotificationIdentiferArray()
        
        // need to set the alert notification categories, get the existing categories first, call setAlertNotificationCategories in competionhandler
        UNUserNotificationCenter.current().getNotificationCategories(completionHandler: setAlertNotificationCategories(_:))
        
        // alertManager may have raised an alert with a sound played by soundplayer. If user brings the app to the foreground, the soundPlayer needs to stop playing
        ApplicationManager.shared.addClosureToRunWhenAppWillEnterForeground(key: applicationManagerKeyStopPlayingSound, closure: {
            if let soundPlayer = soundPlayer {
                soundPlayer.stopPlaying()
            }
            
        })
        
    }
    
    // MARK: - public functions
    
    /// check all alerts and fire if needed
    /// - parameters:
    ///     - maxAgeOfLastBgReadingInSeconds : for master mode max 1 minute should be ok, but for follower mode it could be interesting to take a higher value
    public func checkAlerts(maxAgeOfLastBgReadingInSeconds:Double) {
        
        // first of all remove all existing notifications, there should be only one open alert on the home screen. The most relevant one will be reraised
        uNUserNotificationCenter.removeDeliveredNotifications(withIdentifiers: alertNotificationIdentifers)
        uNUserNotificationCenter.removePendingNotificationRequests(withIdentifiers: alertNotificationIdentifers)
        
        // get last bgreading, ignore sensor, because it must also work for follower mode
        let latestBgReadings = bgReadingsAccessor.getLatestBgReadings(limit: 2, howOld: nil, forSensor: nil, ignoreRawData: true, ignoreCalculatedValue: false)
        
        // get latest calibration
        var lastCalibration:Calibration?
        if let latestSensor = sensorsAccessor.fetchActiveSensor() {
            lastCalibration = calibrationsAccessor.lastCalibrationForActiveSensor(withActivesensor: latestSensor)
        }
        
        // get transmitterBatteryInfo
        let transmitterBatteryInfo = UserDefaults.standard.transmitterBatteryInfo
        
        // all alerts will only be created if there's a reading, less than 60 seconds old
        // except for transmitterBatteryInfo alert
        if latestBgReadings.count > 0 {
            
            let lastBgReading = latestBgReadings[0]

            if abs(lastBgReading.timeStamp.timeIntervalSinceNow) < maxAgeOfLastBgReadingInSeconds {
                // reading is for an active sensor and is less than 60 seconds old, let's check the alerts
                // need to call checkAlert
                
                // if latestBgReadings[1] exists then assign it to lastButOneBgREading
                var lastButOneBgREading:BgReading?
                if latestBgReadings.count > 1 {
                    lastButOneBgREading = latestBgReadings[1]
                }
                
                
                // alerts are checked in order of importance - there should be only one alert raised, except missed reading alert which will always be checked.
                // first check very low alert
                if (!checkAlertAndFire(alertKind: .verylow, lastBgReading: lastBgReading, lastButOneBgREading: lastButOneBgREading, lastCalibration: lastCalibration, transmitterBatteryInfo: transmitterBatteryInfo)) {
                    // very low not fired, check low alert - if very low alert snoozed, skip the check for low alert and continue to next step
                    if getSnoozeParameters(alertKind: AlertKind.verylow).getSnoozeValue().isSnoozed || (!checkAlertAndFire(alertKind: .low, lastBgReading: lastBgReading, lastButOneBgREading: lastButOneBgREading, lastCalibration: lastCalibration, transmitterBatteryInfo: transmitterBatteryInfo)) {
                        //  low not fired, check very high alert
                        if (!checkAlertAndFire(alertKind: .veryhigh, lastBgReading: lastBgReading, lastButOneBgREading: lastButOneBgREading, lastCalibration: lastCalibration, transmitterBatteryInfo: transmitterBatteryInfo)) {
                            // very high not fired, check high alert - if very high alert snoozed, skip the check for high alert and continue to next step
                            if getSnoozeParameters(alertKind: AlertKind.veryhigh).getSnoozeValue().isSnoozed || (!checkAlertAndFire(alertKind: .high, lastBgReading: lastBgReading, lastButOneBgREading: lastButOneBgREading, lastCalibration: lastCalibration, transmitterBatteryInfo: transmitterBatteryInfo)) {
                                // very high not fired check calibration alert
                                if (!checkAlertAndFire(alertKind: .calibration, lastBgReading: lastBgReading, lastButOneBgREading: lastButOneBgREading, lastCalibration: lastCalibration, transmitterBatteryInfo: transmitterBatteryInfo)) {
                                    // finally let's check the battery level alert
                                    _ = checkAlertAndFire(alertKind: .batterylow, lastBgReading: lastBgReading, lastButOneBgREading: lastButOneBgREading, lastCalibration: lastCalibration, transmitterBatteryInfo: transmitterBatteryInfo)
                                }
                            }
                        }
                    }
                }
                // set missed reading alert, this will be a future planned alert
                _ = checkAlertAndFire(alertKind: .missedreading, lastBgReading: lastBgReading, lastButOneBgREading: lastButOneBgREading, lastCalibration: lastCalibration, transmitterBatteryInfo: transmitterBatteryInfo)
            } else {
                trace("in checkAlerts, latestBgReadings is older than %{public}@ minutes", log: self.log, type: .info, maxAgeOfLastBgReadingInSeconds.description)
            }
        } else {
            trace("in checkAlerts, latestBgReadings.count == 0", log: self.log, type: .info)
        }
    }
    
    /// Function to be called that receives the notification actions. Will handle the response.
    ///
    /// this function looks very similar to the UNUserNotificationCenterDelegate function, difference is that it returns an optional instance of PickerViewData. This will have the snooze data, ie title, actionHandler, cancelHandler, list of values, etc.  Goal is not to have UI related stuff in AlertManager class. it's the caller that needs to decide how to present the data
    /// - returns:
    ///     - PickerViewData : contains data that user needs to pick from, nil means nothing to pick from
    public func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) -> PickerViewData? {
        
        // declare returnValue
        var returnValue:PickerViewData?
        
        // loop through alertKinds to find matching notificationIdentifier
        loop: for alertKind in AlertKind.allCases {
            if response.notification.request.identifier == alertKind.notificationIdentifier() {
                
                // user clicked an alert notification, time to stop playing if play
                if let soundPlayer = soundPlayer {
                    soundPlayer.stopPlaying()
                }
                
                switch response.actionIdentifier {
                    
                case snoozeActionIdentifier:

                    // get the appicable alertEntry so we can find the alertType and default snooze value
                    let (currentAlertEntry, _) = alertEntriesAccessor.getCurrentAndNextAlertEntry(forAlertKind: alertKind, forWhen: Date(), alertTypesAccessor: alertTypesAccessor)
                    
                    trace("in userNotificationCenter, received actionIdentifier : snoozeActionIdentifier, snoozing alert %{public}@ for %{public}@ minutes", log: self.log, type: .info, alertKind.descriptionForLogging(), Int(currentAlertEntry.alertType.snoozeperiod).description)
                    
                    // snooze
                    getSnoozeParameters(alertKind: alertKind).snooze(snoozePeriodInMinutes: Int(currentAlertEntry.alertType.snoozeperiod))


                case UNNotificationDefaultActionIdentifier:
                    trace("in userNotificationCenter, received actionIdentifier : UNNotificationDefaultActionIdentifier (user clicked the notification which opens the app, but not the snooze action)", log: self.log, type: .info)

                    // create pickerViewData for the alertKind for which alert went off, and return it to the caller who in turn needs to allow the user to select a snoozeperiod
                    returnValue = createPickerViewData(forAlertKind: alertKind)

                case UNNotificationDismissActionIdentifier:
                    trace("in userNotificationCenter, received actionIdentifier : UNNotificationDismissActionIdentifier", log: self.log, type: .info)

                default:
                    trace("in userNotificationCenter, received actionIdentifier : default", log: self.log, type: .info)
                    
                }
                
                break loop
            }
        }
        
        return returnValue
    }
    
    /// Function to be called that receives the notification actions. Will handle the response. completionHandler will not necessarily be called. Only if the identifier (response.notification.request.identifier) is one of the alert notification identifers, then it will handle the response and also call completionhandler.
    ///
    /// this function looks very similar to the UNUserNotificationCenterDelegate function, difference is that it returns an optional instance of PickerViewData. This will have the snooze data, ie title, actionHandler, cancelHandler, list of values, etc.  Goal is not to have UI related stuff in AlertManager class. it's the caller that needs to decide how to present the data
    /// - returns:
    ///     - PickerViewData : contains data that user needs to pick from, nil means nothing to pick from
    public func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) -> PickerViewData? {

        // declare returnValue
        var returnValue:PickerViewData?
        
        /// check if it's for one of the alert notification
        loop: for alertKind in AlertKind.allCases {
            if alertKind.notificationIdentifier() == notification.request.identifier {

                // it is possible to play the sound, show the content and/or set the badge counter as explained here https://developer.apple.com/documentation/usernotifications/unnotificationpresentationoptions
                // none of them seems useful here
                completionHandler([])
                
                // create pickerViewData for the alertKind for which alert went off, and return it to the caller who in turn needs to allow the user to select a snoozeperiod
                returnValue = createPickerViewData(forAlertKind: alertKind)
                
            }
        }
        return returnValue
    }
    
    // MARK: - private helper functions
    
    private func createPickerViewData(forAlertKind alertKind:AlertKind) -> PickerViewData {
        // find the default snooze period, so we can set selectedRow in the pickerviewdata
        let defaultSnoozePeriodInMinutes = Int(alertEntriesAccessor.getCurrentAndNextAlertEntry(forAlertKind: alertKind, forWhen: Date(), alertTypesAccessor: alertTypesAccessor).currentAlertEntry.alertType.snoozeperiod)
        var defaultRow = 0
        for (index, _) in snoozeValueMinutes.enumerated() {
            if snoozeValueMinutes[index] > defaultSnoozePeriodInMinutes {
                break
            } else {
                defaultRow = index
            }
        }
        
        return PickerViewData(withMainTitle: alertKind.alertTitle(), withSubTitle: Texts_Alerts.selectSnoozeTime, withData: snoozeValueStrings, selectedRow: defaultRow, withPriority: .high, actionButtonText: Texts_Common.Ok, cancelButtonText: Texts_Common.Cancel,
                              onActionClick: {
                                (snoozeIndex:Int) -> Void in
                                if let soundPlayer = self.soundPlayer {
                                    soundPlayer.stopPlaying()
                                }
                                let alertPeriod = self.snoozeValueMinutes[snoozeIndex]
                                self.getSnoozeParameters(alertKind: alertKind).snooze(snoozePeriodInMinutes: alertPeriod)
                                trace("    snoozing alert %{public}@ for %{public}@ minutes", log: self.log, type: .info, alertKind.descriptionForLogging(), alertPeriod.description)
        },
                              onCancelClick: {
                                () -> Void in
                                if let soundPlayer = self.soundPlayer {
                                    soundPlayer.stopPlaying()
                                }
        }, didSelectRowHandler: nil
        )

    }
    
    /// will check if the alert of type alertKind needs to be fired and also fires it, plays the sound, and if yes return true, otherwise false
    private func checkAlertAndFire(alertKind:AlertKind, lastBgReading:BgReading?, lastButOneBgREading:BgReading?, lastCalibration:Calibration?, transmitterBatteryInfo:TransmitterBatteryInfo?) -> Bool {
        
        // check if snoozed
        if getSnoozeParameters(alertKind: alertKind).getSnoozeValue().isSnoozed {
            trace("in checkAlert, alert %{public}@ is currently snoozed", log: self.log, type: .info, alertKind.descriptionForLogging())
            return false
        }
        
        // get the applicable current and next alertType from core data
        let (currentAlertEntry, nextAlertEntry) = alertEntriesAccessor.getCurrentAndNextAlertEntry(forAlertKind: alertKind, forWhen: Date(), alertTypesAccessor: alertTypesAccessor)
        
        // check if alert is required
        let (alertNeeded, alertBody, alertTitle, delayInSeconds) = alertKind.alertNeeded(currentAlertEntry: currentAlertEntry, nextAlertEntry: nextAlertEntry, lastBgReading: lastBgReading, lastButOneBgREading, lastCalibration: lastCalibration, transmitterBatteryInfo: transmitterBatteryInfo)
        
        // create a new property for delayInSeconds, if it's nil then set to 0 - because returnvalue might either be nil or 0, to be treated int he same way
        let delayInSecondsToUse = delayInSeconds == nil ? 0:delayInSeconds!
        
        if alertNeeded {
            // alert needs to be raised
            
            // find the applicable alertentry which depends on the delayInSeconds
            var applicableAlertType = currentAlertEntry.alertType
            if delayInSecondsToUse > 0, let nextAlertEntry = nextAlertEntry {
                
                // if start of nextAlertEntry < start of currentAlertEntry, then ad 24 hours, because it means the nextAlertEntry is actually the one of the day after
                var nextAlertEntryStartValueToUse = nextAlertEntry.start
                if nextAlertEntry.start < currentAlertEntry.start {
                    nextAlertEntryStartValueToUse += nextAlertEntryStartValueToUse + 24 * 60
                }

                // check if current time + delayInSeconds falls within timezone of nextAlertEntry
                if Date().minutesSinceMidNightLocalTime() + delayInSecondsToUse / 60 > nextAlertEntryStartValueToUse {
                    applicableAlertType = nextAlertEntry.alertType
                }
            }

            // create the content for the alert notification, set body and text, category
            let content = UNMutableNotificationContent()
            
            // set body, text
            if let alertBody = alertBody {content.body = alertBody}
            if let alertTitle = alertTitle {content.title = alertTitle}
            
            // if snooze from notification in homescreen is needed then set the categoryIdentifier
            if applicableAlertType.snooze {
                content.categoryIdentifier = snoozeCategoryIdentifier
            }

            // The sound
            // depending on mute override off or on, the sound will either be added to the notification content, or will be played by code here respectively - except if delayInSecondsToUse > 0, in which case we must use the sound in the notification
            
            // soundToSet is the sound that will be played,
            // if soundToSet is nil ==> then default sound must be used,
            // if soundToSet = "" , empty string ==> no sound needs to be played
            // Start with default sound
            var soundToSet:String?
            
            // if applicableAlertType.soundname is nil, then keep soundToSet nil, otherwise find the sound file name
            if let alertTypeSoundName = applicableAlertType.soundname {
                if alertTypeSoundName == "" {
                    // no sound to play
                    soundToSet = ""
                } else {
                    // a sound name has been found in the alertType different from empty string (ie a sound must be played and it's not the default iOS sound)
                    // need to find the corresponding sound file name in ConstantsSounds
                    // start by setting it to to xdripalert, because the soundname found in the alert type might not be found in the list of sounds stored in the resources (although that shouldn't happen)
                    soundToSet = "xdripalert.aif"
                    soundloop: for sound in ConstantsSounds.allCases {
                        // ConstantsSounds defines available sounds. Per case there a string which is the soundname as shown in the UI and the filename of the sound in the Resources folder, seperated by backslash
                        // get array of indexes, of location of "/"
                        let indexOfBackSlash = sound.rawValue.indexes(of: "/")
                        // define range to get the soundname (as shown in UI)
                        let soundNameRange = sound.rawValue.startIndex..<indexOfBackSlash[0]
                        // now get the soundName in a string
                        let soundName = String(sound.rawValue[soundNameRange])
                        // check if it matches the soundname in the alerttype
                        if soundName == alertTypeSoundName {
                            // get indexOfBackSlash[0] + 1 because we don't need to backslash
                            let indexOfBackSlashPlusOne = sound.rawValue.index(after: indexOfBackSlash[0])
                            // get the range of the filename where the sound is stored
                            let soundFileNameRange = indexOfBackSlashPlusOne..<sound.rawValue.endIndex
                            // now get the filename
                            soundToSet = String(sound.rawValue[soundFileNameRange])
                            break soundloop
                        }
                    }
                }
            }
            // now we have the name of the file that has the soundfilename, we'll use it later to assign it to the content
            
            // if soundToSet == nil, it means user selected the default iOS sound in the alert type, however we don't have the mp3, so if overridemute is on and delayInSeconds = nil, then we need to be able to play the sound here with the soundplayer, so we set soundToSet to xdrip sound
            if soundToSet == nil && applicableAlertType.overridemute && delayInSecondsToUse == 0 {
                soundToSet = "xdripalert.aif"
            }
            
            // assign the sound to the notification, or play it here, depending on value
            if let soundToSet = soundToSet {
                if soundToSet == "" {
                    // no sound to play
                } else {
                    // if override mute is on, then play the sound via code here
                    // also delayInSeconds must be nil, if delayInSeconds is not nil then we can not play the sound here at now, it must be added to the notification
                    if applicableAlertType.overridemute && delayInSecondsToUse == 0 {
                        // play the sound
                        if let soundPlayer = self.soundPlayer {
                            soundPlayer.playSound(soundFileName: soundToSet, withVolume: nil)
                        }
                    } else {
                        // mute should not be overriden, by adding the sound to the notification, we let iOS decide if the sound will be played or not
                        content.sound = UNNotificationSound.init(named: UNNotificationSoundName.init(soundToSet))
                    }
                }
            } else {
                // default sound to be played
                content.sound = UNNotificationSound.init(named: UNNotificationSoundName.init(""))
            }
            
            // create the trigger, only for notifications with delay
            var trigger:UNTimeIntervalNotificationTrigger?
            if delayInSecondsToUse > 0 {
                trigger = UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval(delayInSecondsToUse), repeats: false)
            }
            
            // create the notificationrequest
            let notificationRequest = UNNotificationRequest(identifier: alertKind.notificationIdentifier(), content: content, trigger: trigger)
            
            // Add Request to User Notification Center
            uNUserNotificationCenter.add(notificationRequest) { (error) in
                if let error = error {
                    trace("Unable to Add Notification Request %{public}@", log: self.log, type: .error, error.localizedDescription)
                }
            }

            // if vibrate required , and if delay is nil, then vibrate
            if delayInSecondsToUse == 0, currentAlertEntry.alertType.vibrate {
                AudioServicesPlaySystemSound(kSystemSoundID_Vibrate);
            }
            
            // log the result
            trace("in checkAlert, raising alert %{public}@", log: self.log, type: .info, alertKind.descriptionForLogging())
            if delayInSecondsToUse > 0 {
                trace("   delay = %{public}@ seconds, = %{public}@ minutes", log: self.log, type: .info, delayInSecondsToUse.description, ((round(Double(delayInSecondsToUse)/60*10))/10).description)
            }

            return true
        } else {
            trace("in checkAlert, there's no need to raise alert %{public}@", log: self.log, type: .info, alertKind.descriptionForLogging())
            return false
        }
    }
    
    private func getSnoozeParameters(alertKind: AlertKind) -> SnoozeParameters {
        if let snoozeParameters = snoozeParameters[alertKind.rawValue] {
            return snoozeParameters
        } else {
            fatalError("in snoozeParameters(alertKind: AlertKind) -> SnoozeParameters, failed to get snoozeparameters for alertKind")
        }
    }
    
    // helper method used during intialization of AlertManager
    private func initAlertNotificationIdentiferArray() {
        for alertKind in AlertKind.allCases {
            alertNotificationIdentifers.append(alertKind.notificationIdentifier())
        }
    }
    
    /// adds the alert notification categories to the existing categories
    /// - parameters:
    ///     - existingCategories : notification categories that currently exist
    func setAlertNotificationCategories(_ existingCategories: Set<UNNotificationCategory>) {
        
        // create var equal to existingCategories so we can add new categories
        var mutableExistingCategories = existingCategories
        
        // create the snooze action
        let action = UNNotificationAction(identifier: snoozeActionIdentifier, title: Texts_Alerts.snooze, options: [])
        
        // create the category - add option customDismissAction, this to make sure userNotificationCenter with didReceive will be called, which in turn will stop the soundPlayer, otherwise the user would dismiss the notification but in case off override mute, the sound keeps on playing
        let generalCategory = UNNotificationCategory(identifier: snoozeCategoryIdentifier, actions: [action], intentIdentifiers: [], options: [.customDismissAction])
        
        // add the category to the UNUserNotificationCenter
        mutableExistingCategories.insert(generalCategory)
        
        // get UNUserNotificationCenter and set new list of categories
        UNUserNotificationCenter.current().setNotificationCategories(mutableExistingCategories)
        
    }

}
