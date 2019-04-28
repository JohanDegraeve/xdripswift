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
    private var log = OSLog(subsystem: Constants.Log.subSystem, category: Constants.Log.categoryAlertManager)
    
    /// BgReadings instance
    private let bgReadings:BgReadings
    
    /// Calibrations instance
    private let calibrations:Calibrations
    
    /// Sensors instance
    private let sensors:Sensors
    
    /// for getting alertTypes from coredata
    private var alertTypes:AlertTypes
    
    /// for getting alertEntries from coredata
    private var alertEntries:AlertEntries
    
    /// playSound instance
    private var soundPlayer:SoundPlayer
    
    // snooze parameters
    private var snoozeParameters = [Int: SnoozeParameters]()
    
    // helper array with all alert notification identifiers
    private var alertNotificationIdentifers = [String]()
    
    // permanent reference to notificationcenter
    private let uNUserNotificationCenter:UNUserNotificationCenter
    
    // snooze times in minutes
    private let snoozeValueMinutes = [5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 55, 60, 75, 90, 120, 150, 180, 240, 300, 360, 420, 480, 540, 600, 1440, 10080]
    
    // snooze times as shown to the user, actual strings will be replaced during init
    private var snoozeValueStrings = ["5 minutes", "10 minutes", "15 minutes", "20 minutes", "25 minutes", "30 minutes", "35 minutes",
                                                   "40 minutes", "45 minutes", "50 minutes", "55 minutes", "1 hour", "1 hour 15 minutes", "1,5 hours", "2 hours", "2,5 hours", "3 hours", "4 hours",
                                                   "5 hours", "6 hours", "7 hours", "8 hours", "9 hours", "10 hours", "1 day", "1 week"]
    
    // MARK: - initializer
    
    init(coreDataManager:CoreDataManager, soundPlayer:SoundPlayer) {
        // assign properties
        self.bgReadings = BgReadings(coreDataManager: coreDataManager)
        self.alertTypes = AlertTypes(coreDataManager: coreDataManager)
        self.alertEntries = AlertEntries(coreDataManager: coreDataManager)
        self.calibrations = Calibrations(coreDataManager: coreDataManager)
        self.sensors = Sensors(coreDataManager: coreDataManager)
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
        
        // need to set the alert notification categories, get the existing ones first
        UNUserNotificationCenter.current().getNotificationCategories(completionHandler: setAlertNotificationCategories(_:))
        
        // observe changes to app status, foreground or background
        UserDefaults.standard.addObserver(self, forKeyPath: UserDefaults.Key.appInForeGround.rawValue, options: .new, context: nil)

    }
    
    // MARK: - public functions
    
    /// check all alerts and fire if needed
    public func checkAlerts() {
        
        // first of all remove all existing notifications, there should be only one open alert on the home screen. The most relevant one will be reraised
        uNUserNotificationCenter.removeDeliveredNotifications(withIdentifiers: alertNotificationIdentifers)
        uNUserNotificationCenter.removePendingNotificationRequests(withIdentifiers: alertNotificationIdentifers)
        
        // get last bgreading, ignore sensor, because sensor is not known here, not necessary to check if the readings match the current sensor
        let latestBgReadings = bgReadings.getLatestBgReadings(limit: 2, howOld: nil, forSensor: nil, ignoreRawData: false, ignoreCalculatedValue: false)
        
        // get latest calibration
        var lastCalibration:Calibration?
        if let latestSensor = sensors.fetchActiveSensor() {
            lastCalibration = calibrations.lastCalibrationForActiveSensor(withActivesensor: latestSensor)
        }
        
        // get batteryLevel
        let batteryLevel = UserDefaults.standard.transmitterBatteryLevel
        
        if latestBgReadings.count > 0 {
            let lastBgReading = latestBgReadings[0]
            if let sensor = lastBgReading.sensor {
                // it's a reading with a sensor
                if sensor.endDate == nil {
                    // it's an active sensor
                    if abs(lastBgReading.timeStamp.timeIntervalSinceNow) < 60 {
                        // reading is for an active sensor and is less than 60 seconds old, let's check the alerts
                        // need to call checkAlert
                        
                        // if latestBgReadings[1] exists then assign it to lastButOneBgREading
                        var lastButOneBgREading:BgReading?
                        if latestBgReadings.count > 1 {
                            lastButOneBgREading = latestBgReadings[1]
                        }
                        
                        
                        // alerts are checked in order of importance - there should be only one alert raised, except missed reading alert which will always be checked.
                        // first check very low alert
                        if (!checkAlertAndFire(alertKind: .verylow, lastBgReading: lastBgReading, lastButOneBgREading: lastButOneBgREading, lastCalibration: lastCalibration, batteryLevel: batteryLevel)) {
                            // very low not fired, check low alert
                            if (!checkAlertAndFire(alertKind: .low, lastBgReading: lastBgReading, lastButOneBgREading: lastButOneBgREading, lastCalibration: lastCalibration, batteryLevel: batteryLevel)) {
                                //  low not fired, check very high alert
                                if (!checkAlertAndFire(alertKind: .veryhigh, lastBgReading: lastBgReading, lastButOneBgREading: lastButOneBgREading, lastCalibration: lastCalibration, batteryLevel: batteryLevel)) {
                                    // very high not fired, check high alert
                                    if (!checkAlertAndFire(alertKind: .high, lastBgReading: lastBgReading, lastButOneBgREading: lastButOneBgREading, lastCalibration: lastCalibration, batteryLevel: batteryLevel)) {
                                        // very high not fired check calibration alert
                                        if (!checkAlertAndFire(alertKind: .calibration, lastBgReading: lastBgReading, lastButOneBgREading: lastButOneBgREading, lastCalibration: lastCalibration, batteryLevel: batteryLevel)) {
                                            // finally let's check the battery level alert
                                            _ = checkAlertAndFire(alertKind: .batterylow, lastBgReading: lastBgReading, lastButOneBgREading: lastButOneBgREading, lastCalibration: lastCalibration, batteryLevel: batteryLevel)
                                        }
                                    }
                                }
                            }
                        }
                        // finally check missed reading alert
                        _ = checkAlertAndFire(alertKind: .missedreading, lastBgReading: lastBgReading, lastButOneBgREading: lastButOneBgREading, lastCalibration: lastCalibration, batteryLevel: batteryLevel)
                    }
                }
            }
        }
    }
    
    /// Function to be called that receives the notification actions. Will handle the response. completionHandler will not necessarily be called. Only if the identifier (response.notification.request.identifier) is one of the alert notification identifers, then it will handle the response and also call completionhandler.
    ///
    /// this function looks very similar to the UNUserNotificationCenterDelegate function, difference is that it returns an optional instance of PickerViewData. This will have the snooze data, ie title, actionHandler, cancelHandler, list of values, etc.  Goal is not to have UI related stuff in AlertManager class. it's the caller that needs to decide how to present the data
    /// - returns:
    ///     - PickerViewData : contains data that user needs to pick from, nil means nothing to pick from
    public func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) -> PickerViewData? {
        
        // loop through alertKinds to find matching notificationIdentifier
        loop: for alertKind in AlertKind.allCases {
            if response.notification.request.identifier == alertKind.notificationIdentifier() {
                
                // user clicked an alert notification, time to stop playing if play
                soundPlayer.stopPlaying()
                
                switch response.actionIdentifier {
                    
                case snoozeActionIdentifier:

                    os_log("in userNotificationCenter, received actionIdentifier : snoozeActionIdentifier", log: self.log, type: .info)

                    // get the appicable alertEntry so we can find the alertType and default snooze value
                    let (currentAlertEntry, _) = alertEntries.getCurrentAndNextAlertEntry(forAlertKind: alertKind, forWhen: Date(), alertTypes: alertTypes)
                    
                    // snooze
                    getSnoozeParameters(alertKind: alertKind).snooze(snoozePeriodInMinutes: Int(currentAlertEntry.alertType.snoozeperiod))

                    os_log("    snoozing alert %{public}@ for %{public}@ minutes", log: self.log, type: .info, alertKind.descriptionForLogging(), Int(currentAlertEntry.alertType.snoozeperiod).description)

                case UNNotificationDefaultActionIdentifier:
                    os_log("in userNotificationCenter, received actionIdentifier : UNNotificationDefaultActionIdentifier (user clicked the notification which opens the app, but not the snooze action)", log: self.log, type: .info)
                    
                case UNNotificationDismissActionIdentifier:
                    os_log("in userNotificationCenter, received actionIdentifier : UNNotificationDismissActionIdentifier", log: self.log, type: .info)
                    
                default:
                    os_log("in userNotificationCenter, received actionIdentifier : default", log: self.log, type: .info)
                    
                }
                
                // it is possible to play the sound, show the content and/or set the badge counter as explained here https://developer.apple.com/documentation/usernotifications/unnotificationpresentationoptions
                // none of them seems useful here
                completionHandler()
                
                break loop
            }
        }
        
        return nil
    }
    
    /// Function to be called that receives the notification actions. Will handle the response. completionHandler will not necessarily be called. Only if the identifier (response.notification.request.identifier) is one of the alert notification identifers, then it will handle the response and also call completionhandler.
    ///
    /// this function looks very similar to the UNUserNotificationCenterDelegate function, difference is that it returns an optional instance of PickerViewData. This will have the snooze data, ie title, actionHandler, cancelHandler, list of values, etc.  Goal is not to have UI related stuff in AlertManager class. it's the caller that needs to decide how to present the data
    /// - returns:
    ///     - PickerViewData : contains data that user needs to pick from, nil means nothing to pick from
    public func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) -> PickerViewData? {

        /// check if it's for one of the alert notification
        loop: for alertKind in AlertKind.allCases {
            if alertKind.notificationIdentifier() == notification.request.identifier {

                // it is possible to play the sound, show the content and/or set the badge counter as explained here https://developer.apple.com/documentation/usernotifications/unnotificationpresentationoptions
                // none of them seems useful here
                completionHandler([])
                
                return createPickerViewData(forAlertKind: alertKind)
                
            }
        }
        return nil
    }
    
    // MARK: - overriden functions
    
    // interested in changes to some of the settings
    public override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        
        if let keyPath = keyPath {
            if let keyPathEnum = UserDefaults.Key(rawValue: keyPath) {
                switch keyPathEnum {
                    
                case .appInForeGround:
                    // app comes to foreground, if app would still be playing sound, then it doesn't make sense to continue playing, it would mean that app was playing while in the background, most probably for an alert, user opens the app, there's no need to continue alerting the user
                    soundPlayer.stopPlaying()
                default:
                    break
                }
            }
        }
    }
    
    // MARK: - private helper functions
    
    private func createPickerViewData(forAlertKind alertKind:AlertKind) -> PickerViewData {
        // find the default snooze period, so we can set selectedRow in the pickerviewdata
        let defaultSnoozePeriodInMinutes = Int(alertEntries.getCurrentAndNextAlertEntry(forAlertKind: alertKind, forWhen: Date(), alertTypes: alertTypes).currentAlertEntry.alertType.snoozeperiod)
        var defaultRow = 0
        for (index, _) in snoozeValueMinutes.enumerated() {
            if snoozeValueMinutes[index] > defaultSnoozePeriodInMinutes {
                break
            } else {
                defaultRow = index
            }
        }
        
        return PickerViewData(withMainTitle: alertKind.alertPickerViewMainTitle(), withSubTitle: Texts_Alerts.selectSnoozeTime, withData: snoozeValueStrings, selectedRow: defaultRow, withPriority: .high, actionButtonText: Texts_Common.Ok, cancelButtonText: Texts_Common.Cancel,
                              onActionClick: {
                                (snoozeIndex:Int) -> Void in
                                self.soundPlayer.stopPlaying()
                                let alertPeriod = self.snoozeValueMinutes[snoozeIndex]
                                self.getSnoozeParameters(alertKind: alertKind).snooze(snoozePeriodInMinutes: alertPeriod)
                                os_log("    snoozing alert %{public}@ for %{public}@ minutes", log: self.log, type: .info, alertKind.descriptionForLogging(), alertPeriod.description)
        },
                              onCancelClick: {
                                () -> Void in
                                self.soundPlayer.stopPlaying()
        }
        )

    }
    
    /// will check if the alert of type alertKind needs to be fired and also fires it, plays the sound, and if yes return true, otherwise false
    private func checkAlertAndFire(alertKind:AlertKind, lastBgReading:BgReading?, lastButOneBgREading:BgReading?, lastCalibration:Calibration?, batteryLevel:Int?) -> Bool {
        
        // check if snoozed
        if getSnoozeParameters(alertKind: alertKind).getSnoozeValue().isSnoozed {
            os_log("in checkAlert, alert %{public}@ is currently snoozed", log: self.log, type: .info, alertKind.descriptionForLogging())
            return false
        }
        
        // get the applicable current and next alertType from core data
        let (currentAlertEntry, nextAlertEntry) = alertEntries.getCurrentAndNextAlertEntry(forAlertKind: alertKind, forWhen: Date(), alertTypes: alertTypes)
        
        // check if notification is required
        let (alertNeeded, alertBody, alertTitle, delayInSeconds) = alertKind.alertNeededChecker()(currentAlertEntry, nextAlertEntry, lastBgReading, lastButOneBgREading, lastCalibration, batteryLevel)
        
        if alertNeeded {
            // alert needs to be raised
            
            // find the applicable alertentry which depends on the delayInSeconds
            var applicableAlertType = currentAlertEntry.alertType
            if let delayInSeconds = delayInSeconds, let nextAlertEntry = nextAlertEntry {
                // check if current time + delayInSeconds falls within timezone of nextAlertEntry
                if Date().minutesSinceMidNightLocalTime() + delayInSeconds * 60 > nextAlertEntry.value {
                    applicableAlertType = nextAlertEntry.alertType
                }
            }

            // create the content for the alert notification, set body and text, category
            let content = UNMutableNotificationContent()
            
            // set body, text
            if let alertBody = alertBody {content.body = alertBody}
            if let alertTitle = alertTitle {content.title = alertTitle}
            
            // set categoryIdentifier
            content.categoryIdentifier = snoozeCategoryIdentifier

            // The sound
            // Start by creating the sound that will be added to the notification content
            // depending on mute override on or off, the sound will either be added to the notification content, or will be played by code here
            
            // soundToSet is the sound that will be played,
            // if soundToSet is nil ==> then default sound must be used,
            // if soundToSet = "" , empty string ==> no sound will be played
            // Start with default sound
            var soundToSet:String?
            
            // AlertType.soundname is optional
            if let alertTypeSoundName = applicableAlertType.soundname {
                if alertTypeSoundName == "" {
                    // no sound to play
                    soundToSet = ""
                } else {
                    // a sound name has been found in the alertType different empty string (ie a sound must be played and it's not the default iOS sound)
                    // start by setting it to to xdripalert, because the soundname found in the alert type might not be found in the list of sounds stored in the resources (although that shouldn't happen)
                    soundToSet = "xdripalert.aif"
                    soundloop: for sound in Constants.Sounds.allCases {
                        // Constants.Sounds defines available sounds. Per case there a string which is the soundname as shown in the UI and the filename of the sound in the Resources folder, seperated by backslash
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
            
            // assign the sound to the notification, or play it here, depending on overridemute value - except if it's the default sound, because we don't have the default iOS sound as a mp3 or whatever type of file
            // add the sound if there is one defined, otherwise the iOS default sound will be used
            if let soundToSet = soundToSet {
                if soundToSet == "" {
                    // no sound to play
                } else {
                    // if override mute is on, then play the sound via code here
                    // also delayInSeconds must be nil, if delayInSeconds is not nil then we can not play the sound here at now, it must be added to the notification
                    if applicableAlertType.overridemute && delayInSeconds == nil {
                        // play the sound
                        soundPlayer.playSound(soundFileName: soundToSet, withVolume: nil)
                    } else {
                        // mute should not be overriden, by adding the sound to the notification, we let iOS decide of the sound will be played or not
                        content.sound = UNNotificationSound.init(named: UNNotificationSoundName.init(soundToSet))
                    }
                }
            } else {
                // default sound to be played
                content.sound = UNNotificationSound.init(named: UNNotificationSoundName.init(""))
            }
            
            // create the trigger, only for notifications with delay
            var trigger:UNTimeIntervalNotificationTrigger?
            if let delay = delayInSeconds {
                trigger = UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval(delay), repeats: false)
            }
            
            // create the notificationrequest
            let notificationRequest = UNNotificationRequest(identifier: alertKind.notificationIdentifier(), content: content, trigger: trigger)
            
            // Add Request to User Notification Center
            uNUserNotificationCenter.add(notificationRequest) { (error) in
                if let error = error {
                    os_log("Unable to Add Notification Request %{public}@", log: self.log, type: .error, error.localizedDescription)
                }
            }

            // if vibrate required , and if delay is nil, then vibrate
            if delayInSeconds == nil, currentAlertEntry.alertType.vibrate {
                AudioServicesPlaySystemSound(kSystemSoundID_Vibrate);
            }
            
            // log the result
            os_log("in checkAlert, raising alert %{public}@", log: self.log, type: .info, alertKind.descriptionForLogging())
            if let delayInSeconds = delayInSeconds {
                os_log("   delay = %{public}@", log: self.log, type: .info, delayInSeconds.description)
            }

            return true
        } else {
            os_log("in checkAlert, there's no need to raise alert %{public}@", log: self.log, type: .info, alertKind.descriptionForLogging())
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
        
        // create the category
        let generalCategory = UNNotificationCategory(identifier: snoozeCategoryIdentifier, actions: [action], intentIdentifiers: [], options: [])
        
        // add the category to the UNUserNotificationCenter
        mutableExistingCategories.insert(generalCategory)
        
        // get UNUserNotificationCenter and set new list of categories
        UNUserNotificationCenter.current().setNotificationCategories(mutableExistingCategories)
        
    }

}
