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
    private var snoozeParameters = [SnoozeParameters]()
    
    /// helper array with all alert notification identifiers
    private var alertNotificationIdentifers = [String]()
    
    /// permanent reference to notificationcenter
    private let uNUserNotificationCenter:UNUserNotificationCenter
    
    // coredataManager instance
    private var coreDataManager: CoreDataManager
    
    /// snooze times in minutes
    private let snoozeValueMinutes = [5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 55, 60, 75, 90, 120, 150, 180, 240, 300, 360, 420, 480, 540, 600, 720, 1440, 10080]
    
    /// snooze times as shown to the user, actual strings will be replaced during init
    private var snoozeValueStrings = ["5 minutes", "10 minutes", "15 minutes", "20 minutes", "25 minutes", "30 minutes", "35 minutes",
                                                   "40 minutes", "45 minutes", "50 minutes", "55 minutes", "1 hour", "1 hour 15 minutes", "1,5 hours", "2 hours", "2,5 hours", "3 hours", "4 hours",
                                                   "5 hours", "6 hours", "7 hours", "8 hours", "9 hours", "10 hours", "12 hours", "1 day", "1 week"]
    
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
        self.coreDataManager = coreDataManager
        
        // call super.init
        super.init()
        
        // initialize snoozeparameters
        snoozeParameters = SnoozeParametersAccessor(coreDataManager: coreDataManager).getSnoozeParameters()
        
        // in snoozeValueStrings, replace all occurrences of minutes, minute, etc... by language dependent value
        for (index, _) in ConstantsAlerts.snoozeValueStrings.enumerated() {
            snoozeValueStrings[index] = snoozeValueStrings[index].replacingOccurrences(of: "minutes", with: Texts_Common.minutes).replacingOccurrences(of: "hours", with: Texts_Common.hours).replacingOccurrences(of: "hour", with: Texts_Common.hour).replacingOccurrences(of: "day", with: Texts_Common.day).replacingOccurrences(of: "week", with: Texts_Common.week)
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
        
        // add observer for changes in UserDefaults
        addObservers()
        
    }
    
    // MARK: - public functions
    
    /// check all alerts and fire if needed
    /// - parameters:
    ///     - maxAgeOfLastBgReadingInSeconds : for master mode max 1 minute should be ok, but for follower mode it could be interesting to take a higher value
    /// - returns:
    ///     - if true then an immediate notification is created (immediate being not a future planned, like missed reading), which contains the bg reading in the text - so there's no need to create an additional notificationwith the text in it
    public func checkAlerts(maxAgeOfLastBgReadingInSeconds:Double) -> Bool {
        
        // first of all remove all existing notifications, there should be only one open alert on the home screen. The most relevant one will be reraised
        uNUserNotificationCenter.removeDeliveredNotifications(withIdentifiers: alertNotificationIdentifers)
        uNUserNotificationCenter.removeAllPendingNotificationRequests()
        
        // check if "Snooze All" is activated. If so, then just return with nothing.
        if let snoozeAllAlertsUntilDate = UserDefaults.standard.snoozeAllAlertsUntilDate, snoozeAllAlertsUntilDate > Date() {
            trace("in alertNcheckAlertseeded, skipping all alarms as Snooze All is enabled until %{public}@.", log: self.log, category: ConstantsLog.categoryAlertManager, type: .info, snoozeAllAlertsUntilDate.formatted(date: .abbreviated, time: .standard))
            return false
        }
        
        /// this is the return value
        var immediateNotificationCreated = false
        
        // get last bgreading, ignore sensor, because it must also work for follower mode
        let latestBgReadings = bgReadingsAccessor.get2LatestBgReadings(minimumTimeIntervalInMinutes: 4.0)
        
        // get latest calibration
        var lastCalibration:Calibration?
        if let latestSensor = sensorsAccessor.fetchActiveSensor() {
            lastCalibration = calibrationsAccessor.lastCalibrationForActiveSensor(withActivesensor: latestSensor)
        }
        
        // get transmitterBatteryInfo
        let transmitterBatteryInfo = UserDefaults.standard.transmitterBatteryInfo
        
        // all alerts will only be created if there's a reading, less than maxAgeOfLastBgReadingInSeconds seconds old
        if latestBgReadings.count > 0 {
            
            let lastBgReading = latestBgReadings[0]

            if abs(lastBgReading.timeStamp.timeIntervalSinceNow) < maxAgeOfLastBgReadingInSeconds {
                // reading is maxAgeOfLastBgReadingInSeconds seconds old, let's check the alerts
                // need to call checkAlert
                
                // if latestBgReadings[1] exists then assign it to lastButOneBgReading
                var lastButOneBgReading:BgReading?
                if latestBgReadings.count > 1 {
                    lastButOneBgReading = latestBgReadings[1]
                }

                // alerts are checked in order of importance - there should be only one alert raised, except missed reading alert which will always be checked.
                
                // create helper to check and fire alerts
                let checkAlertAndFireHelper = { (_ alertKind : AlertKind) -> Bool in self.checkAlertAndFire(alertKind: alertKind, lastBgReading: lastBgReading, lastButOneBgReading: lastButOneBgReading, lastCalibration: lastCalibration, transmitterBatteryInfo: transmitterBatteryInfo) }
                
                // specify the order in which alerts should be checked and group those with related snoozes
                let alertGroupsByPreference: [[AlertKind]] = [[.fastdrop], [.verylow, .low], [.fastrise], [.veryhigh, .high], [.calibration], [.batterylow], [.phonebatterylow]]
                
                // only raise first alert group that's been tripped
                // check the result to see if it's an alert kind that creates an immediate notification that contains the reading value
                if let result = alertGroupsByPreference.first(where: { (alertGroup:[AlertKind]) -> Bool in
                    
                    checkAlertGroupAndFire(alertGroup, checkAlertAndFireHelper)
                    
                }) {
                    
                    // in this check were assuming that if there's one alertKind in a group that creates an immediate notification, then also the other(s) do(es)
                    for alertKind in result {
                        if alertKind.createsImmediateNotificationWithBGReading() {
                            immediateNotificationCreated = true
                        }
                    }
                    
                }
                    
                // the missed reading alert will be a future planned alert
                _ = checkAlertAndFireHelper(.missedreading)
                
            } else {
                trace("in checkAlerts, latestBgReadings is older than %{public}@ minutes", log: self.log, category: ConstantsLog.categoryAlertManager, type: .info, maxAgeOfLastBgReadingInSeconds.description)
            }
        } else {
            trace("in checkAlerts, latestBgReadings.count == 0", log: self.log, category: ConstantsLog.categoryAlertManager, type: .info)
        }
        
        return immediateNotificationCreated
        
    }
    
    /// Function to be called that receives the notification actions. Will handle the response. - called when user clicks a notification
    ///
    /// this function looks very similar to the function with the same name defined in  UNUserNotificationCenterDelegate, difference is that it returns an optional instance of PickerViewData. This will have the snooze data, ie title, actionHandler, cancelHandler, list of values, etc.  Goal is not to have UI related stuff in AlertManager class. it's the caller that needs to decide how to present the data
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
                    
                    trace("in userNotificationCenter, received actionIdentifier : snoozeActionIdentifier, snoozing alert %{public}@ for %{public}@ minutes (3)", log: self.log, category: ConstantsLog.categoryAlertManager, type: .info, alertKind.descriptionForLogging(), Int(currentAlertEntry.alertType.snoozeperiod).description)
                    
                    snooze(alertKind: alertKind, snoozePeriodInMinutes: Int(currentAlertEntry.alertType.snoozeperiod), response: response)
                    
                    // save changes in coredata
                    coreDataManager.saveChanges()
                    
                case UNNotificationDefaultActionIdentifier:
                    
                    trace("in userNotificationCenter, received actionIdentifier : UNNotificationDefaultActionIdentifier (user clicked the notification which opens the app, but not the snooze action in this notification)", log: self.log, category: ConstantsLog.categoryAlertManager, type: .info)

                    // create pickerViewData for the alertKind for which alert went off, and return it to the caller who in turn needs to allow the user to select a snoozeperiod
                    returnValue = createPickerViewData(forAlertKind: alertKind, content: response.notification.request.content, actionHandler: nil, cancelHandler: nil)

                case UNNotificationDismissActionIdentifier:
                    trace("in userNotificationCenter, received actionIdentifier : UNNotificationDismissActionIdentifier", log: self.log, category: ConstantsLog.categoryAlertManager, type: .info)
                    
                    // user is swiping away the notification without opening the app, and not choosing the snooze option even if there would be an option to snooze
                    // if it's a reading alert (low, high, ...) then it will go off again in 5 minutes
                    // if it's a missed reading alert, let's replan it in 5 minutes
                    if alertKind == .missedreading {
                        snooze(alertKind: .missedreading, snoozePeriodInMinutes: 5, response: response)
                        // save changes in coredata
                        coreDataManager.saveChanges()
                    }

                default:
                    
                    trace("in userNotificationCenter, received actionIdentifier %{public}@", log: self.log, category: ConstantsLog.categoryAlertManager, type: .info, response.actionIdentifier)
                    
                }
                
                break loop
            }
        }
        
        return returnValue
    }
    
    /// get the snoozeParameter for the alertKind
    public func getSnoozeParameters(alertKind: AlertKind) -> SnoozeParameters {
        return snoozeParameters[alertKind.rawValue]
    }
    
    /// check if any alerts are currently snoozed and return the correct status
    public func snoozeStatus() -> AlertSnoozeStatus {
        // set the default value to inactive. We'll then only override it as necessary
        var snoozeStatus: AlertSnoozeStatus = .inactive
        
        if let snoozeAllAlertsUntilDate = UserDefaults.standard.snoozeAllAlertsUntilDate, snoozeAllAlertsUntilDate > Date() {
            return .allSnoozed
        }
        
        // loop through the alertKinds so that we can define if an urgent alert is snoozed, if just a non-urgent one, or none at all.
        // this is used to update the root view controller snooze icon
        for alertKind in AlertKind.allCases {
            switch alertKind.alertUrgencyType() {
            case .urgent:
                if snoozeParameters[alertKind.rawValue].getSnoozeValue().isSnoozed {
                    snoozeStatus = .urgent
                }
            default:
                // only overwrite with non-urgent if urgent hasn't already been assigned
                if snoozeStatus != .urgent && snoozeParameters[alertKind.rawValue].getSnoozeValue().isSnoozed {
                    snoozeStatus = .notUrgent
                }
            }
        }
        
        return snoozeStatus
    }

    /// Function to be called that receives the notification actions. Will handle the response. completionHandler will not necessarily be called. Only if the identifier (response.notification.request.identifier) is one of the alert notification identifers, then it will handle the response and also call completionhandler.
    /// called when notification created while app is in foreground
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
                returnValue = createPickerViewData(forAlertKind: alertKind, content: notification.request.content, actionHandler: nil, cancelHandler: nil)
                
            }
        }
        return returnValue
    }
    
    /// to unSnooze an already snoozed alert
    public func unSnooze(alertKind: AlertKind) {
        
        // unsnooze
        getSnoozeParameters(alertKind: alertKind).unSnooze()
        
        // save changes in coredata
        coreDataManager.saveChanges()
        
    }
    
    /// creates PickerViewData which allows user to snooze an alert.
    /// - parameters:
    ///     - alertKind : alertKind for which PickerViewData should be created
    ///     - content : possible this pickerViewData is requested after user clicked an alert notification, in that case content is the content of that notification. It allows to re-use the sound, delay, etc. If nil then this is used for presnooze
    ///     - actionHandler : optional closure to execute after user clicks the ok button, the snooze it'self will be done by the pickerViewData, can be used for example to change the contents of a cell
    ///     - cancelHandler : optional closure to execute after user clicks the cancel button.
    public func createPickerViewData(forAlertKind alertKind:AlertKind, content: UNNotificationContent?, actionHandler: (() -> Void)?, cancelHandler: (() -> Void)?) -> PickerViewData {
        
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
        
        return PickerViewData(withMainTitle: alertKind.alertTitle(), withSubTitle: Texts_Alerts.selectSnoozeTime, withData: snoozeValueStrings, selectedRow: defaultRow, withPriority: .high, actionButtonText: Texts_Common.Ok, cancelButtonText: Texts_Common.Cancel, isFullScreen: true,
                              onActionClick: {
            
            (snoozeIndex:Int) -> Void in
            
            // if sound is currently playing then stop it
            if let soundPlayer = self.soundPlayer {
                soundPlayer.stopPlaying()
            }
            
            // get snooze period
            let snoozePeriod = self.snoozeValueMinutes[snoozeIndex]
            
            // snooze
            trace("    snoozing alert %{public}@ for %{public}@ minutes (1)", log: self.log, category: ConstantsLog.categoryAlertManager, type: .info, alertKind.descriptionForLogging(), snoozePeriod.description)
            self.getSnoozeParameters(alertKind: alertKind).snooze(snoozePeriodInMinutes: snoozePeriod)
            
            // save changes in coredata
            self.coreDataManager.saveChanges()
            
            // if it's a missed reading alert, then cancel any planned missed reading alerts and reschedule
            // if content is not nil, then it means a missed reading alert went off, the user clicked it, app opens, user clicks snooze, snoozing must be set
            // if content is nil, then this is an alert snoozed via presnooze button, missed reading alert needs to recalculated.
            if alertKind == .missedreading {
                
                if let content = content {
                    
                    // schedule missed reading alert with same content
                    self.scheduleMissedReadingAlert(snoozePeriodInMinutes: snoozePeriod, content: content)
                    
                } else if UserDefaults.standard.isMaster || (!UserDefaults.standard.isMaster && UserDefaults.standard.followerBackgroundKeepAliveType != .disabled && UserDefaults.standard.activeSensorStartDate != nil) {
                    
                    _ = self.checkAlertAndFire(alertKind: .missedreading, lastBgReading: nil, lastButOneBgReading: nil, lastCalibration: nil, transmitterBatteryInfo: nil)
                    
                }
                
            }
            
            // if actionHandler supplied by caller not nil, then execute it
            actionHandler?()
            
        },
                              onCancelClick: {
            
            () -> Void in
            
            // if sound is currently playing then stop it
            if let soundPlayer = self.soundPlayer {
                soundPlayer.stopPlaying()
            }
            
            // if cancelHandler supplied by caller not nil, then execute it
            cancelHandler?()
            
        }, didSelectRowHandler: nil
        )
        
    }
    
    /// - if it's a missed reading alert, then reschedule with a delay of snoozePeriodInMinutes, also with a repeat every snoozePeriodInMinutes
    /// - other alerts are snoozed normal
    /// - parameters:
    ///     - alertKind
    ///     - snoozePeriodInMinutes
    ///     - response  the UNNotificationResponse received from iOS when user clicks the notification
    public func snooze(alertKind: AlertKind, snoozePeriodInMinutes: Int, response: UNNotificationResponse?) {
        
        // if it's a missedreading alert, then reschedule the alert with a delay of snoozePeriodInMinutes, repeating, with same content
        if alertKind == .missedreading {
            
            if let response = response {
                    
                    scheduleMissedReadingAlert(snoozePeriodInMinutes: snoozePeriodInMinutes, content: response.notification.request.content)
                
            }
            
        } else {
            
            // any other type of alert, set it to snoozed
            getSnoozeParameters(alertKind: alertKind).snooze(snoozePeriodInMinutes: snoozePeriodInMinutes)
            trace("Snoozing alert %{public}@ for %{public}@ minutes (2)", log: log, category: ConstantsLog.categoryAlertManager, type: .info, alertKind.descriptionForLogging(), snoozePeriodInMinutes.description)
            
            // save changes in coredata
            coreDataManager.saveChanges()
            
        }
        
    }

    // MARK: - overriden functions
    
    public override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        
        if let keyPath = keyPath {
            
            if let keyPathEnum = UserDefaults.Key(rawValue: keyPath) {
                
                switch keyPathEnum {
                    
                case UserDefaults.Key.missedReadingAlertChanged :
                    
                    // if missedReadingAlertChanged didn't change to true then no further processing
                    guard UserDefaults.standard.missedReadingAlertChanged else {return}
                    
                    // user changed a missed reading alert setting, so we're going to call checkAlertAndFire for .missedreading, which will replan or cancel any existing missed reading alert
                    
                    // get last bgreading, ignore sensor, because it must also work for follower mode
                    // to check missed reading alert, we only need one reading
                    let latestBgReadings = bgReadingsAccessor.getLatestBgReadings(limit: 1, howOld: nil, forSensor: nil, ignoreRawData: true, ignoreCalculatedValue: false)
                    
                    if latestBgReadings.count > 0 {

                        // first of all remove all existing missedreading notifications
                        uNUserNotificationCenter.removeDeliveredNotifications(withIdentifiers: [AlertKind.missedreading.notificationIdentifier()])
                        uNUserNotificationCenter.removePendingNotificationRequests(withIdentifiers: [AlertKind.missedreading.notificationIdentifier()])
                        
                        _ = checkAlertAndFire(alertKind: .missedreading, lastBgReading: latestBgReadings[0], lastButOneBgReading: nil, lastCalibration: nil, transmitterBatteryInfo: nil)

                    }
                    
                    UserDefaults.standard.missedReadingAlertChanged = false
                    
                default:
                    break
                }
            }
        }
    }

    // MARK: - private helper functions
    
    /// Checks group of alerts - Not to be used for alerts with delay (ie missedreading)
    /// - parameters:
    ///     - alertGroup : array of AlertKind, function loops through alerts, as soon as one of them is snoozed, returns false. This is for example to allow that low alert goes off while very low is snoozed. In this case the array will be .verylow, .low  .verylow will be checked first
    ///     - checkAlertAndFireHelper : a function that will check the alert and if necessary fire (or plan it if for example missed reading alert)
    /// - returns:
    ///     - returns false early as soon as it finds a snoozed alert
    ///     - if no alert is snoozed, then returns true if as soon as one of the  alerts in the array is triggered
    private func checkAlertGroupAndFire(_ alertGroup:[AlertKind], _ checkAlertAndFireHelper: (_ : AlertKind) -> Bool) -> Bool {
        
        for(alertKind) in alertGroup {

            // first check if the alert needs to fire, even if the alert would be snoozed, this will ensure logging.
            if checkAlertAndFireHelper(alertKind) {return true}
            
            if let remainingSeconds = getSnoozeParameters(alertKind: alertKind).getSnoozeValue().remainingSeconds {

                trace("in checkAlertGroupAndFire before calling getSnoozeValue for alert %{public}@, remaining seconds = %{public}@", log: self.log, category: ConstantsLog.categoryAlertManager, type: .info, alertKind.descriptionForLogging(), remainingSeconds.description)

            }
            
            // if alertKind is snoozed then we don't want to check the next alert (example if verylow is snoozed then don't check low)
            if getSnoozeParameters(alertKind: alertKind).getSnoozeValue().isSnoozed {return false}
            
        }
        
        return false
        
    }
    
    /// will
    /// - remove any pending missed reading alert
    /// - create a new one repeating, repeat time will be equal to delay of first alert (that's what iOS allows us to do)
    private func scheduleMissedReadingAlert(snoozePeriodInMinutes: Int, content: UNNotificationContent) {
        
        // remove any planned missed reading alerts
        uNUserNotificationCenter.removePendingNotificationRequests(withIdentifiers: [AlertKind.missedreading.notificationIdentifier()])
        
        // replan missed reading alert, repeating with delay of snoozePeriodInMinutes
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval(Double(snoozePeriodInMinutes) * 60.0), repeats: true)
        
        // create the notificationrequest
        let notificationRequest = UNNotificationRequest(identifier: AlertKind.missedreading.notificationIdentifier(), content: content, trigger: trigger)
        
        // Add Request to User Notification Center
        uNUserNotificationCenter.add(notificationRequest) { (error) in
            if let error = error {
                trace("Unable to Add Notification Request %{public}@", log: self.log, category: ConstantsLog.categoryAlertManager, type: .error, error.localizedDescription)
            }
        }
        
        trace("Scheduled missed reading alert with delay (and repeat) %{public}@ minutes", log: self.log, category: ConstantsLog.categoryAlertManager, type: .info, snoozePeriodInMinutes.description)

    }
    
    /// will check if the alert of type alertKind needs to be fired and also fires it, plays the sound, and if yes returns true, otherwise false
    private func checkAlertAndFire(alertKind:AlertKind, lastBgReading:BgReading?, lastButOneBgReading:BgReading?, lastCalibration:Calibration?, transmitterBatteryInfo:TransmitterBatteryInfo?) -> Bool {

        trace("in checkAlertAndFire for alert = %{public}@", log: self.log, category: ConstantsLog.categoryAlertManager, type: .info, alertKind.descriptionForLogging())
        
        /// This is only for missed reading alert. How many minutes between now and the moment the snooze expires (meaning when is it not snoozed anymore)
        ///
        /// will be initialized later
        var minimumDelayInSecondsToUse:Int?
        
        let isMgDl = UserDefaults.standard.bloodGlucoseUnitIsMgDl
        
        if let remainingSeconds = getSnoozeParameters(alertKind: alertKind).getSnoozeValue().remainingSeconds {

            trace("in checkAlertAndFire before calling getSnoozeValue for alert %{public}@, remaining seconds = %{public}@", log: self.log, category: ConstantsLog.categoryAlertManager, type: .info, alertKind.descriptionForLogging(), remainingSeconds.description)

        }

        // check if snoozed
        if getSnoozeParameters(alertKind: alertKind).getSnoozeValue().isSnoozed {
            
            // depending on alertKind, check if the alert is snoozed. For missedreading, behaviour for snoozed alert is different than for the other alerts
            switch alertKind {
                
            case .missedreading: // any alert type that would be configured with a delay
                if getSnoozeParameters(alertKind: alertKind).snoozePeriodInMinutes > 0, let snoozeTimeStamp = getSnoozeParameters(alertKind: alertKind).snoozeTimeStamp {
                    
                    minimumDelayInSecondsToUse = -Int(Date().timeIntervalSince(Date(timeInterval: TimeInterval(Double(getSnoozeParameters(alertKind: alertKind).snoozePeriodInMinutes) * 60.0), since: snoozeTimeStamp)).rawValue)
                    trace("in checkAlertAndFire, minimumDelayInSecondsToUse = %{public}@" , log: log, category: ConstantsLog.categoryAlertManager, type: .info, minimumDelayInSecondsToUse!.description)

                } // if snoozePeriodInMinutes or snoozeTimeStamp is nil (which shouldn't be the case) continue without taking into account the snooze status
                
            case .calibration, .batterylow, .phonebatterylow, .low, .high, .verylow, .veryhigh, .fastdrop, .fastrise:
                trace("in checkAlertAndFire, alert %{public}@ is currently snoozed", log: self.log, category: ConstantsLog.categoryAlertManager, type: .info, alertKind.descriptionForLogging())
                return false
            }
            
        }
        
        // get the applicable current and next alertType from core data
        let (currentAlertEntry, nextAlertEntry) = alertEntriesAccessor.getCurrentAndNextAlertEntry(forAlertKind: alertKind, forWhen: Date(), alertTypesAccessor: alertTypesAccessor)
        
        // check if alert is required
        let (alertNeeded, alertBody, alertTitle, delayInSeconds) = alertKind.alertNeeded(currentAlertEntry: currentAlertEntry, nextAlertEntry: nextAlertEntry, lastBgReading: lastBgReading, lastButOneBgReading, lastCalibration: lastCalibration, transmitterBatteryInfo: transmitterBatteryInfo)
        
        // create a new property for delayInSeconds, if it's nil then set to 0 - because returnvalue might either be nil or 0, to be treated in the same way
        var delayInSecondsToUse = delayInSeconds == nil ? 0 : delayInSeconds!
        
        // if it's a delayed alert and if the alert is snoozed, then delay is either the momoment the alert expires, or the calculated delay, the maximu of the to values
        if let minimumDelayInSecondsToUse = minimumDelayInSecondsToUse {
            
            if minimumDelayInSecondsToUse > delayInSecondsToUse {
                trace("    increasing delayInSecondsToUse to %{public}@, because the alert is snoozed", log: self.log, category: ConstantsLog.categoryAlertManager, type: .info, minimumDelayInSecondsToUse.description)
                delayInSecondsToUse = minimumDelayInSecondsToUse
            }
            
        }
        
        if alertNeeded && (UserDefaults.standard.isMaster || (!UserDefaults.standard.isMaster && UserDefaults.standard.followerBackgroundKeepAliveType != .disabled)) {
            
            // alert needs to be raised
            
            // the applicable alertentry
            var applicableAlertType = currentAlertEntry.alertType
            
            // if delayInSecondsToUse > 0, then possibly we need to use another alertType
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

            // create the content for the alert notification, set body and text, category and also attachments and userInfo dict if available
            let content = UNMutableNotificationContent()
            
            // set body, title for the standard notification (this will only be used for the short view in both iOS and WatchOS)
            // after testing, the notification seems much clearer if we just use a single title line and include both title + body
            // we'll put an emoji prefix just to give the notification a bit more character
            if let alertTitle = alertTitle, let alertBody = alertBody {
                content.title = alertKind.alertUrgencyType().alertTitlePrefix + " " + alertTitle.uppercased() + " " + alertBody
            }
            
            // now let's start creating the custom content
            var alertNotificationDictionary = AlertNotificationDictionary()
            
            alertNotificationDictionary.alertTitle = alertKind.alertTitle().uppercased()
            alertNotificationDictionary.alertUrgencyTypeRawValue = alertKind.alertUrgencyType().rawValue
            
            // create two simple arrays to send to the live activiy. One with the bg values in mg/dL and another with the corresponding timestamps
            // this is needed due to the not being able to pass structs that are not codable/hashable
            let hoursOfBgReadingsToSend: Double = ConstantsGlucoseChartSwiftUI.hoursToShowNotificationExpanded
            
            let bgReadings = bgReadingsAccessor.getLatestBgReadings(limit: nil, fromDate: Date().addingTimeInterval(-3600 * hoursOfBgReadingsToSend), forSensor: nil, ignoreRawData: true, ignoreCalculatedValue: false)
            
            if bgReadings.count > 0 {
                alertNotificationDictionary.isMgDl = isMgDl
                alertNotificationDictionary.slopeOrdinal = 0
                alertNotificationDictionary.deltaValueInUserUnit = 0
                alertNotificationDictionary.urgentLowLimitInMgDl = UserDefaults.standard.urgentLowMarkValue
                alertNotificationDictionary.lowLimitInMgDl = UserDefaults.standard.lowMarkValue
                alertNotificationDictionary.urgentHighLimitInMgDl = UserDefaults.standard.urgentHighMarkValue
                alertNotificationDictionary.highLimitInMgDl = UserDefaults.standard.highMarkValue
                
                // add delta and slope if available
                if bgReadings.count > 1 {
                    var previousValueInUserUnit: Double = 0.0
                    var actualValueInUserUnit: Double = 0.0
                    
                    previousValueInUserUnit = bgReadings[1].calculatedValue.mgDlToMmol(mgDl: isMgDl)
                    actualValueInUserUnit = bgReadings[0].calculatedValue.mgDlToMmol(mgDl: isMgDl)
                    
                    // if the values are in mmol/L, then round them to the nearest decimal point in order to get the same precision out of the next operation
                    if !isMgDl {
                        previousValueInUserUnit = (previousValueInUserUnit * 10).rounded() / 10
                        actualValueInUserUnit = (actualValueInUserUnit * 10).rounded() / 10
                    }
                    
                    alertNotificationDictionary.deltaValueInUserUnit = actualValueInUserUnit - previousValueInUserUnit
                    
                    alertNotificationDictionary.slopeOrdinal = bgReadings[0].slopeOrdinal()
                }
                
                // create a new array, append all data and then assign that to the dictionary
                var bgReadingValues: [Double] = []
                var bgReadingDatesAsDouble: [Double] = []
                
                for bgReading in bgReadings {
                    bgReadingValues.append(bgReading.calculatedValue)
                    bgReadingDatesAsDouble.append(bgReading.timeStamp.timeIntervalSince1970)
                }
                
                alertNotificationDictionary.bgReadingValues = bgReadingValues
                alertNotificationDictionary.bgReadingDatesAsDouble = bgReadingDatesAsDouble
            }
            
            // check that we can correctly serialize the dictionary data and if so, add it to the notification content
            if let userInfo = alertNotificationDictionary.asDictionary {
                content.userInfo = userInfo
            }
            
            // add a small BG chart image as an attachment to the notification content
            let thumbnailAttachment = try! UNNotificationAttachment(identifier: "thumbnail", url: URL.documentsDirectory.appendingPathComponent("\(ConstantsGlucoseChartSwiftUI.filenameNotificationThumbnailImage).png"), options: [UNNotificationAttachmentOptionsThumbnailHiddenKey: false])
            
            content.attachments = [thumbnailAttachment]
            
            // if snooze from notification in homescreen is needed then set the categoryIdentifier
            if applicableAlertType.snooze {
                content.categoryIdentifier = snoozeCategoryIdentifier
            }

            // The sound
            // depending on mute override off or on, the sound will either be added to the notification content, or will be played by code here respectively - except if delayInSecondsToUse > 0, in which case we must use the sound in the notification
            //
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
            
            // if soundToSet == nil, it means user selected the default iOS sound in the alert type, however we don't have the mp3, so if override mute is on and delayInSeconds = nil, then we need to be able to play the sound here with the soundplayer, so we set soundToSet to xdrip sound
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
                            soundPlayer.playSound(soundFileName: soundToSet)
                        }
                    } else {
                        // mute should not be overriden, by adding the sound to the notification, we let iOS decide if the sound will be played or not
                        content.sound = UNNotificationSound.init(named: UNNotificationSoundName(soundToSet))
                    }
                }
            } else {
                // default sound to be played
                content.sound = UNNotificationSound.init(named: UNNotificationSoundName(""))
            }
            
            // create the trigger, only for notifications with delay
            var trigger:UNTimeIntervalNotificationTrigger?
            if delayInSecondsToUse > 0 {
                // set repeats to true
                trigger = UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval(Double(delayInSecondsToUse)), repeats: true)
            }
            
            // create the notificationrequest
            let notificationRequest = UNNotificationRequest(identifier: alertKind.notificationIdentifier(), content: content, trigger: trigger)
            
            // Add Request to User Notification Center
            uNUserNotificationCenter.add(notificationRequest) { (error) in
                if let error = error {
                    trace("Unable to Add Notification Request %{public}@", log: self.log, category: ConstantsLog.categoryAlertManager, type: .error, error.localizedDescription)
                }
            }
            
            // snooze default period, to avoid that alert goes off every minute for Libre 2, except if it's a delayed alert (for delayed alerts it looks a bit risky to me)
            if delayInSecondsToUse == 0 {
                
                trace("in checkAlert, snoozing alert %{public}@ for %{public}@ minutes", log: self.log, category: ConstantsLog.categoryAlertManager, type: .info, alertKind.descriptionForLogging(), ConstantsAlerts.defaultDelayBetweenAlertsOfSameKindInMinutes.description)
                
                getSnoozeParameters(alertKind: alertKind).snooze(snoozePeriodInMinutes: ConstantsAlerts.defaultDelayBetweenAlertsOfSameKindInMinutes)
                
            }
            
            // if vibrate required , and if delay is nil, then vibrate
            if delayInSecondsToUse == 0, currentAlertEntry.alertType.vibrate {
                AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
            }
            
            // log the result
            if delayInSecondsToUse == 0 {
                trace("in checkAlert, raising alert %{public}@", log: self.log, category: ConstantsLog.categoryAlertManager, type: .info, alertKind.descriptionForLogging())
            } else {
                trace("in checkAlert, raising alert %{public}@ with a delay of %{public}@ minutes - this is a scheduled future alert, it will not go off now", log: self.log, category: ConstantsLog.categoryAlertManager, type: .info, alertKind.descriptionForLogging(), ((Int(round(Double(delayInSecondsToUse)/60*10))/10)).description)
            }

            // check if app is allowed to send local notification and if not write info to trace
            UNUserNotificationCenter.current().getNotificationSettings { (notificationSettings) in
                
                switch notificationSettings.authorizationStatus {
                case .denied:
                    trace("   notificationSettings.authorizationStatus = denied", log: self.log, category: ConstantsLog.categoryAlertManager, type: .info)
                case .notDetermined:
                    trace("   notificationSettings.authorizationStatus = notDetermined", log: self.log, category: ConstantsLog.categoryAlertManager, type: .info)
                case .authorized, .ephemeral:
                    break
                case .provisional:
                    trace("   notificationSettings.authorizationStatus = provisional", log: self.log, category: ConstantsLog.categoryAlertManager, type: .info)
                    
                @unknown default:
                    fatalError("unsupported authorizationStatus in AlertManager")
                    
                }
            }
            
            return true
            
        } else {
            if !UserDefaults.standard.isMaster && UserDefaults.standard.followerBackgroundKeepAliveType == .disabled {
                trace("in checkAlert, there's no need to raise alert '%{public}@' because we're in follower mode and keep-alive is disabled", log: self.log, category: ConstantsLog.categoryAlertManager, type: .info, alertKind.descriptionForLogging())
            } else {
                trace("in checkAlert, there's no need to raise alert %{public}@", log: self.log, category: ConstantsLog.categoryAlertManager, type: .info, alertKind.descriptionForLogging())
            }
            return false
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
    private func setAlertNotificationCategories(_ existingCategories: Set<UNNotificationCategory>) {
        
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

    /// when user changes M5Stack related settings, then the transmitter need to get that info, add observers
    private func addObservers() {
        
        UserDefaults.standard.addObserver(self, forKeyPath: UserDefaults.Key.missedReadingAlertChanged.rawValue, options: .new, context: nil)
        
    }

}
