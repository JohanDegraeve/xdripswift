import Foundation
import os
import UserNotifications
import AudioToolbox

public class AlertManager:NSObject {
    
    // MARK: - properties
  
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
    var lowAlertSnoozeParameters = SnoozeParameters()
    var highAlertSnoozeParameters = SnoozeParameters()
    var verylowAlertSnoozeParameters = SnoozeParameters()
    var veryhighAlertSnoozeParameters = SnoozeParameters()
    var batteryAlertSnoozeParameters = SnoozeParameters()
    var missedReadingAlertSnoozeParameters = SnoozeParameters()
    var calibrationAlertSnoozeParameters = SnoozeParameters()
    
    // MARK: - initializer
    
    init(coreDataManager:CoreDataManager, soundPlayer:SoundPlayer) {
        // assign properties
        self.bgReadings = BgReadings(coreDataManager: coreDataManager)
        self.alertTypes = AlertTypes(coreDataManager: coreDataManager)
        self.alertEntries = AlertEntries(coreDataManager: coreDataManager)
        self.calibrations = Calibrations(coreDataManager: coreDataManager)
        self.sensors = Sensors(coreDataManager: coreDataManager)
        self.soundPlayer = soundPlayer
        
        // call super.init
        super.init()
        
        // need to set the alert notification categories, get the existing ones first
        UNUserNotificationCenter.current().getNotificationCategories(completionHandler: setAlertNotificationCategories(_:))
    }
    
    // MARK: - public functions
    
    /// get snoozeparameters for specific alertKind, snoozeparameters tell us if the alarm is snoozed or not and how long
    public func snoozeParameters(alertKind:AlertKind) -> SnoozeParameters {
        switch alertKind {
            
        case .low:
            return lowAlertSnoozeParameters
        case .high:
            return highAlertSnoozeParameters
        case .verylow:
            return verylowAlertSnoozeParameters
        case .veryhigh:
            return veryhighAlertSnoozeParameters
        case .missedreading:
            return missedReadingAlertSnoozeParameters
        case .calibration:
            return calibrationAlertSnoozeParameters
        case .batterylow:
            return batteryAlertSnoozeParameters
        }
    }
    
    /// check all alerts and fire if needed
    public func checkAlerts() {
        // get last bgreading, ignore sensor, because sensor is not known here, not necessary to check if the readings match the current sensor
        let latestBgReadings = bgReadings.getLatestBgReadings(limit: 2, howOld: nil, forSensor: nil, ignoreRawData: false, ignoreCalculatedValue: false)
        
        // get latest calibration
        var latestCalibration:Calibration?
        if let latestSensor = sensors.fetchActiveSensor() {
            latestCalibration = calibrations.lastCalibrationForActiveSensor(withActivesensor: latestSensor)
        }
        
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
                        
                        // first check very low alert
                        if (!checkAlertAndFire(alertKind: .verylow, lastBgReading: lastBgReading, lastButOneBgREading: lastButOneBgREading, calibration: latestCalibration)) {
                            // very low not fired, check low alert
                            if (!checkAlertAndFire(alertKind: .low, lastBgReading: lastBgReading, lastButOneBgREading: lastButOneBgREading, calibration: latestCalibration)) {
                                //  low not fired, check very high alert
                                if (!checkAlertAndFire(alertKind: .veryhigh, lastBgReading: lastBgReading, lastButOneBgREading: lastButOneBgREading, calibration: latestCalibration)) {
                                    // very high not fired, check high alert
                                    if (!checkAlertAndFire(alertKind: .high, lastBgReading: lastBgReading, lastButOneBgREading: lastButOneBgREading, calibration: latestCalibration)) {
                                        // very low not fired, check low alert
                                        
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        
    }
    
    // MARK: - private helper functions
    
    /// will check if the alert of type alertKind needs to be fired and also fires it, plays the sound, and if yes return true, otherwise false
    private func checkAlertAndFire(alertKind:AlertKind, lastBgReading:BgReading?, lastButOneBgREading:BgReading?, calibration:Calibration?) -> Bool {
        
        // get the applicable alertType from core data
        let (currentAlertEntry, nextAlertEntry) = alertEntries.getCurrentAndNextAlertEntry(alertKind: alertKind, forWhen: Date(), alertTypes: alertTypes)
        let alertType = currentAlertEntry.alertType
        
        // if not enabled, then no need for further processing
        if !alertType.enabled {
            os_log("in checkAlert, alert  : %{public}@ is currently not enabled", log: self.log, type: .info, alertKind.descriptionForLogging())
            return false
        }
        
        // check if snoozed
        if snoozeParameters(alertKind: alertKind).getSnoozeValue().isSnoozed {
            os_log("in checkAlert, alert  : %{public}@ is currently snoozed", log: self.log, type: .info, alertKind.descriptionForLogging())
            return false
        }
        
        // check if notification is required
        let (alertNeeded, alertBody, alertTitle, delayInSeconds) = alertKind.alertNeededChecker()(currentAlertEntry, nextAlertEntry, lastBgReading, lastButOneBgREading, calibration, UserDefaults.standard.transmitterBatteryLevel)
        
        if alertNeeded {
            // alert needs to be raised

            // create the content for the alert notification, set body and text
            let content = UNMutableNotificationContent()
            if let alertBody = alertBody {content.body = alertBody}
            if let alertText = alertTitle {content.title = alertText}
            

            // The sound
            // Start by creating the sound that will be added to the notification content
            // depending on mute override on or off, the sound will either be added to the notification content, or will be played by code here
            
            // soundToSet is the sound that will be played,
            // if soundToSet is nil ==> then default sound must be used,
            // if soundToSet = "" , empty string ==> no sound will be played
            // Start with default sound
            var soundToSet:String?
            
            // AlertType.soundname is optional
            if let alertTypeSoundName = alertType.soundname {
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
                    if alertType.overridemute && delayInSeconds == nil {
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
            UNUserNotificationCenter.current().add(notificationRequest) { (error) in
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
}

/// adds the alert notification categories to the existing categories
/// - parameters:
///     - existingCategories : notification categories that currently exist
func setAlertNotificationCategories(_ existingCategories: Set<UNNotificationCategory>) {

    // create var equal to existingCategories so we can add new categories
    var mutableExistingCategories = existingCategories
    
    // loop through the alertkind's and add one by one a category to the list of existing (if any) categories
    for alertKind in AlertKind.allCases {
        
        // create the snooze action
        let action = UNNotificationAction(identifier: alertKind.notificationIdentifier(), title: Texts_Alerts.snooze, options: [])
        
        // create the category
        let generalCategory = UNNotificationCategory(identifier: alertKind.categoryIdentifier(), actions: [action], intentIdentifiers: [], options: [])
        
        // add the category to the UNUserNotificationCenter
        mutableExistingCategories.insert(generalCategory)
    }

    // get UNUserNotificationCenter and set new list of categories
    UNUserNotificationCenter.current().setNotificationCategories(mutableExistingCategories)
    
}

