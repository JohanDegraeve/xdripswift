import Foundation

/// all texts related to calibration
enum Texts_HomeView {
    static private let filename = "HomeView"
    
    static let snoozeButton:String = {
        return NSLocalizedString("presnooze", tableName: filename, bundle: Bundle.main, value: "Snooze", comment: "Text in button on home screen")
    }()
    
    static let snoozeAllTitle:String = {
        return NSLocalizedString("snoozeAllTitle", tableName: filename, bundle: Bundle.main, value: "Snooze All Alarms", comment: "snooze all text in snooze screen")
    }()
    
    static let snoozeAllDisabled:String = {
        return NSLocalizedString("snoozeAllDisabled", tableName: filename, bundle: Bundle.main, value: "No urgent alarms are snoozed", comment: "no urgent alarms are snoozed text in snooze screen")
    }()
    
    static let snoozeAllSnoozed:String = {
        return NSLocalizedString("snoozeAllSnoozed", tableName: filename, bundle: Bundle.main, value: "All alarms are snoozed!", comment: "snooze all text in snooze screen")
    }()
    
    static let snoozeAllSnoozedUntil:String = {
        return NSLocalizedString("snoozeAllSnoozedUntil", tableName: filename, bundle: Bundle.main, value: "All alarms are snoozed until", comment: "snooze all until text in snooze screen")
    }()
    
    static let snoozeUrgentAlarms:String = {
        return NSLocalizedString("snoozeUrgentAlarms", tableName: filename, bundle: Bundle.main, value: "Some urgent alarms are snoozed", comment: "text to inform that some of the urgent alarms are snoozed")
    }()
    
    static let sensor:String = {
        return NSLocalizedString("sensor", tableName: filename, bundle: Bundle.main, value: "Sensor", comment: "Literally 'Sensor', used as name in the button in the home screen, but also in text in pop ups")
    }()
    
    static let calibrationButton:String = {
        return NSLocalizedString("calibrate", tableName: filename, bundle: Bundle.main, value: "Calibrate", comment: "Text in button on home screen")
    }()

    static let sensorManagementTitle:String = {
        return NSLocalizedString("sensorManagementTitle", tableName: filename, bundle: Bundle.main, value: "Sensor", comment: "navigation title for the sensor management screen")
    }()

    static let sensorManagementSummaryTitle:String = {
        return NSLocalizedString("sensorManagementSummaryTitle", tableName: filename, bundle: Bundle.main, value: "Sensor Session", comment: "section title for sensor information")
    }()

    static let sensorManagementNoiseTitle:String = {
        return NSLocalizedString("sensorManagementNoiseTitle", tableName: filename, bundle: Bundle.main, value: "Sensor Noise", comment: "section title for sensor signal noise information")
    }()

    static let sensorManagementNoiseShortTerm:String = {
        return NSLocalizedString("sensorManagementNoiseShortTerm", tableName: filename, bundle: Bundle.main, value: "Last 30 Minutes", comment: "title for the short-term sensor noise measurement")
    }()

    static let sensorManagementNoiseLongTerm:String = {
        return NSLocalizedString("sensorManagementNoiseLongTerm", tableName: filename, bundle: Bundle.main, value: "Last 4 Hours", comment: "title for the long-term sensor noise measurement")
    }()

    static let sensorManagementNoiseCollecting:String = {
        return NSLocalizedString("sensorManagementNoiseCollecting", tableName: filename, bundle: Bundle.main, value: "Collecting data", comment: "sensor noise state while there are not enough readings")
    }()

    static let sensorManagementNoiseLow:String = {
        return NSLocalizedString("sensorManagementNoiseLow", tableName: filename, bundle: Bundle.main, value: "Low", comment: "low sensor noise state")
    }()

    static let sensorManagementNoiseElevated:String = {
        return NSLocalizedString("sensorManagementNoiseElevated", tableName: filename, bundle: Bundle.main, value: "Elevated", comment: "elevated sensor noise state")
    }()

    static let sensorManagementNoiseVeryHigh:String = {
        return NSLocalizedString("sensorManagementNoiseVeryHigh", tableName: filename, bundle: Bundle.main, value: "Very High", comment: "very high sensor noise state")
    }()

    static let sensorManagementNoiseExtreme:String = {
        return NSLocalizedString("sensorManagementNoiseExtreme", tableName: filename, bundle: Bundle.main, value: "Extreme", comment: "extreme sensor noise state")
    }()

    static let sensorManagementNoiseFlatline:String = {
        return NSLocalizedString("sensorManagementNoiseFlatline", tableName: filename, bundle: Bundle.main, value: "Sensor signal may be stuck.", comment: "warning that repeated identical sensor readings may indicate a fault")
    }()

    static let sensorManagementNoiseFooter:String = {
        return NSLocalizedString("sensorManagementNoiseFooter", tableName: filename, bundle: Bundle.main, value: "Sensitivity selected: %@", comment: "sensor management noise section footer, parameter is the selected sensitivity level")
    }()

    static let sensorNoiseHistoryTitle:String = {
        return NSLocalizedString("sensorNoiseHistoryTitle", tableName: filename, bundle: Bundle.main, value: "Noise History", comment: "navigation title for sensor noise history")
    }()

    static let sensorNoiseHistoryCurrentTitle:String = {
        return NSLocalizedString("sensorNoiseHistoryCurrentTitle", tableName: filename, bundle: Bundle.main, value: "Current Measurements", comment: "section title for current sensor noise measurements")
    }()

    static let sensorNoiseHistoryChartTitle:String = {
        return NSLocalizedString("sensorNoiseHistoryChartTitle", tableName: filename, bundle: Bundle.main, value: "Noise Over Time", comment: "title for the sensor noise history chart")
    }()

    static let sensorNoiseHistoryRangeTitle:String = {
        return NSLocalizedString("sensorNoiseHistoryRangeTitle", tableName: filename, bundle: Bundle.main, value: "Time Range", comment: "accessibility title for the sensor noise chart range picker")
    }()

    static let sensorNoiseHistoryDayRange:String = {
        return NSLocalizedString("sensorNoiseHistoryDayRange", tableName: filename, bundle: Bundle.main, value: "24 h", comment: "one day sensor noise chart range")
    }()

    static let sensorNoiseHistoryThreeDayRange:String = {
        return NSLocalizedString("sensorNoiseHistoryThreeDayRange", tableName: filename, bundle: Bundle.main, value: "3 d", comment: "three day sensor noise chart range")
    }()

    static let sensorNoiseHistoryWeekRange:String = {
        return NSLocalizedString("sensorNoiseHistoryWeekRange", tableName: filename, bundle: Bundle.main, value: "7 d", comment: "one week sensor noise chart range")
    }()

    static let sensorNoiseHistoryAllRange:String = {
        return NSLocalizedString("sensorNoiseHistoryAllRange", tableName: filename, bundle: Bundle.main, value: "All", comment: "complete sensor session noise chart range")
    }()

    static let sensorNoiseHistoryShortCompact:String = {
        return NSLocalizedString("sensorNoiseHistoryShortCompact", tableName: filename, bundle: Bundle.main, value: "30 min", comment: "compact label for short-term sensor noise")
    }()

    static let sensorNoiseHistoryLongCompact:String = {
        return NSLocalizedString("sensorNoiseHistoryLongCompact", tableName: filename, bundle: Bundle.main, value: "4 h", comment: "compact label for long-term sensor noise")
    }()

    static let sensorNoiseHistoryLoading:String = {
        return NSLocalizedString("sensorNoiseHistoryLoading", tableName: filename, bundle: Bundle.main, value: "Building sensor history", comment: "message while historic sensor noise is calculated")
    }()

    static let sensorNoiseHistoryNoDataTitle:String = {
        return NSLocalizedString("sensorNoiseHistoryNoDataTitle", tableName: filename, bundle: Bundle.main, value: "Not enough noise data yet", comment: "title when the sensor noise chart has no measurements")
    }()

    static let sensorNoiseHistoryNoDataMessage:String = {
        return NSLocalizedString("sensorNoiseHistoryNoDataMessage", tableName: filename, bundle: Bundle.main, value: "The chart will appear after enough sensor readings have been collected.", comment: "explanation when the sensor noise chart has no measurements")
    }()

    static let sensorNoiseHistoryFooter:String = {
        return NSLocalizedString("sensorNoiseHistoryFooter", tableName: filename, bundle: Bundle.main, value: "The chart shows residual sensor jitter across this sensor session. Lower values are smoother. It does not measure glucose accuracy.", comment: "explanation below the sensor noise history chart")
    }()

    static let sensorNoiseHistoryChartAccessibility:String = {
        return NSLocalizedString("sensorNoiseHistoryChartAccessibility", tableName: filename, bundle: Bundle.main, value: "Sensor noise history chart", comment: "accessibility label for the sensor noise history chart")
    }()

    static let sensorNoiseWarningExtremeTitle:String = {
        return NSLocalizedString("sensorNoiseWarningExtremeTitle", tableName: filename, bundle: Bundle.main, value: "Extreme Sensor Noise", comment: "home screen warning title for extreme short-term sensor noise")
    }()

    static let sensorNoiseWarningPersistentTitle:String = {
        return NSLocalizedString("sensorNoiseWarningPersistentTitle", tableName: filename, bundle: Bundle.main, value: "Persistent Sensor Noise", comment: "home screen warning title for high long-term sensor noise")
    }()

    static let sensorNoiseWarningFlatlineTitle:String = {
        return NSLocalizedString("sensorNoiseWarningFlatlineTitle", tableName: filename, bundle: Bundle.main, value: "Sensor Signal May Be Stuck", comment: "home screen warning title for repeated identical sensor values")
    }()

    static let sensorManagementActionsTitle:String = {
        return NSLocalizedString("sensorManagementActionsTitle", tableName: filename, bundle: Bundle.main, value: "Sensor Actions", comment: "section title for sensor management actions")
    }()

    static let sensorManagementCalibrationTitle:String = {
        return NSLocalizedString("sensorManagementCalibrationTitle", tableName: filename, bundle: Bundle.main, value: "Calibration", comment: "section title for sensor calibration information")
    }()

    static let sensorManagementHistoryTitle:String = {
        return NSLocalizedString("sensorManagementHistoryTitle", tableName: filename, bundle: Bundle.main, value: "Calibration History", comment: "section title for calibration history")
    }()

    static let sensorManagementNotAvailableInFollower:String = {
        return NSLocalizedString("sensorManagementNotAvailableInFollower", tableName: filename, bundle: Bundle.main, value: "Sensor management is unavailable in follower mode.", comment: "message shown when sensor management is not available in follower mode")
    }()

    static let sensorManagementAutomaticSessionNote:String = {
        return NSLocalizedString("sensorManagementAutomaticSessionNote", tableName: filename, bundle: Bundle.main, value: "This sensor manages its session automatically, so manual start and stop are unavailable.", comment: "message shown when a sensor manages its own session")
    }()

    static let sensorManagementNoTransmitterNote:String = {
        return NSLocalizedString("sensorManagementNoTransmitterNote", tableName: filename, bundle: Bundle.main, value: "Connect a CGM transmitter to manage the sensor session.", comment: "message shown when no transmitter is available for sensor management")
    }()

    static let sensorManagementCalibrationUnavailable:String = {
        return NSLocalizedString("sensorManagementCalibrationUnavailable", tableName: filename, bundle: Bundle.main, value: "Calibration is temporarily unavailable.", comment: "generic error shown when calibration cannot be performed")
    }()

    static let sensorManagementStatusActive:String = {
        return NSLocalizedString("sensorManagementStatusActive", tableName: filename, bundle: Bundle.main, value: "Sensor Session Active", comment: "sensor management status label")
    }()

    static let sensorManagementStatusWarmingUp:String = {
        return NSLocalizedString("sensorManagementStatusWarmingUp", tableName: filename, bundle: Bundle.main, value: "Warming Up", comment: "sensor management status label")
    }()

    static let sensorManagementStatusExpired:String = {
        return NSLocalizedString("sensorManagementStatusExpired", tableName: filename, bundle: Bundle.main, value: "Expired", comment: "sensor management status label")
    }()

    static let sensorManagementStatusNotStarted:String = {
        return NSLocalizedString("sensorManagementStatusNotStarted", tableName: filename, bundle: Bundle.main, value: "Not Started", comment: "sensor management status label")
    }()

    static let sensorManagementNoSensor:String = {
        return NSLocalizedString("sensorManagementNoSensor", tableName: filename, bundle: Bundle.main, value: "No Sensor", comment: "banner title when no sensor session is active")
    }()

    static let sensorManagementElapsed:String = {
        return NSLocalizedString("sensorManagementElapsed", tableName: filename, bundle: Bundle.main, value: "Elapsed", comment: "sensor management row title")
    }()

    static let sensorManagementRemaining:String = {
        return NSLocalizedString("sensorManagementRemaining", tableName: filename, bundle: Bundle.main, value: "Remaining", comment: "sensor management row title")
    }()

    static let sensorManagementExpiryFooterFormat:String = {
        return NSLocalizedString("sensorManagementExpiryFooterFormat", tableName: filename, bundle: Bundle.main, value: "Sensor expires on %@", comment: "footer text shown in sensor session when an expiry date is known")
    }()

    static let sensorManagementCurrentCalibrationTitle:String = {
        return NSLocalizedString("sensorManagementCurrentCalibrationTitle", tableName: filename, bundle: Bundle.main, value: "Current Calibration", comment: "title for the current calibration subsection")
    }()

    static let sensorManagementHistoricCalibration:String = {
        return NSLocalizedString("sensorManagementHistoricCalibration", tableName: filename, bundle: Bundle.main, value: "Historic", comment: "label for a historic or unused calibration")
    }()

    static let sensorManagementCalibrationSafetyFooter:String = {
        return NSLocalizedString("sensorManagementCalibrationSafetyFooter", tableName: filename, bundle: Bundle.main, value: "Only calibrate if you understand how to do it safely.", comment: "safety text shown in the calibration entry screen")
    }()

    static let sensorManagementCalibrationHelp:String = {
        return NSLocalizedString("sensorManagementCalibrationHelp", tableName: filename, bundle: Bundle.main, value: "Calibration Help", comment: "button title to open the calibration help documentation")
    }()

    static let sensorManagementLargeCalibrationDifferenceWarningFormat:String = {
        return NSLocalizedString("sensorManagementLargeCalibrationDifferenceWarningFormat", tableName: filename, bundle: Bundle.main, value: "The calibration difference is big. It is possible that this will not work. Try to limit each calibration change to maximum %@ at a time.", comment: "warning shown when the entered calibration differs too much from the current glucose value")
    }()
    
    static let lockButton:String = {
        return NSLocalizedString("lock", tableName: filename, bundle: Bundle.main, value: "Lock", comment: "Text in button on home screen")
    }()
    
    static let unlockButton:String = {
        return NSLocalizedString("unlock", tableName: filename, bundle: Bundle.main, value: "Unlock", comment: "Text in button on home screen")
    }()
    
    static let screenLockTitle:String = {
        return NSLocalizedString("screenlocktitle", tableName: filename, bundle: Bundle.main, value: "Screen Lock Enabled", comment: "Screen Lock Title")
    }()
    
    static let screenLockInfo:String = {
        return NSLocalizedString("screenlockinfo", tableName: filename, bundle: Bundle.main, value: "This will keep the screen awake until you move to another app or click Unlock.\r\n\nIt is recommended that you keep the phone plugged into a charger to prevent battery drain.", comment: "Info message to explain screen lock function")
    }()
    
    static let statusActionTitle:String = {
        return NSLocalizedString("statusactiontitle", tableName: filename, bundle: Bundle.main, value: "Status", comment: "when user clicks transmitterButton, this is the first action, to show the status")
    }()
    
    static let scanBluetoothDeviceActionTitle:String = {
        return NSLocalizedString("scanbluetoothdeviceactiontitle", tableName: filename, bundle: Bundle.main, value: "Scan for Transmitter", comment: "when user clicks transmitterButton, this is the action to start scanning")
    }()
    
    static let forgetBluetoothDeviceActionTitle:String = {
        return NSLocalizedString("forgetbluetoothdeviceactiontitle", tableName: filename, bundle: Bundle.main, value: "Forget Transmitter", comment: "when user clicks transmitterButton, this is the action to forget the device, so that user can scan for a new device, in case user switches device")
    }()
    
    static let startSensorActionTitle:String = {
        return NSLocalizedString("startsensor", tableName: filename, bundle: Bundle.main, value: "Start Sensor", comment: "when user clicks transmitterButton, this is the action to start the sensor")
    }()
    
    static let stopSensorActionTitle:String = {
        return NSLocalizedString("stopsensor", tableName: filename, bundle: Bundle.main, value: "Stop Sensor", comment: "when user clicks transmitterButton, this is the action to stop the sensor")
    }()
    
    static let startSensorTimeInfo:String = {
        return NSLocalizedString("startsensortimeinfo", tableName: filename, bundle: Bundle.main, value: "In the next dialogs, you will need to set the date and time the sensor was inserted. It is important that you set the date and time as accurately as possible.", comment: "when user manually starts sensor, this is the message that explains that time should be correct")
    }()
    
    static let scanBluetoothDeviceOngoing:String = {
        return NSLocalizedString("scanbluetoothdeviceongoing", tableName: filename, bundle: Bundle.main, value: "Scanning for Transmitter...", comment: "when user manually starts scanning, this is the message that scanning is ongoing")
    }()
    
    static let bluetoothIsNotOn:String = {
        return NSLocalizedString("bluetoothisnoton", tableName: filename, bundle: Bundle.main, value: "Bluetooth is not on. Switch on bluetooth first and then try again.", comment: "when user starts scanning but bluetooth is not on")
    }()
    
    static let bluetoothIsNotAuthorized: String = {
        return String(format: NSLocalizedString("bluetoothIsNotAuthorized", tableName: filename, bundle: Bundle.main, value: "You did not give bluetooth permission for %@. Go to the settings, find the %@ app, and enable Bluetooth.", comment: "when user starts scanning for bluetooth device, but bluetooth is not authorized"), ConstantsHomeView.applicationName, ConstantsHomeView.applicationName)
    }()
    
    static let startScanningInfo: String = {
        return String(format: NSLocalizedString("startScanningInfo", tableName: filename, bundle: Bundle.main, value: "Scanning Started.\n\nKeep %@ open in the foreground until a connection is made.\n\n(There's no need to turn off Auto-Lock. Just don't press the home button and don't lock your iPhone)", comment: "After clicking scan button, this message will appear"), ConstantsHomeView.applicationName)
    }()
   
    static let sensorStart:String = {
        return NSLocalizedString("sensorstart", tableName: filename, bundle: Bundle.main, value: "Sensor Started", comment: "status info : literally 'Sensor Start'")
    }()
    
    static let sensorDuration:String = {
        return NSLocalizedString("sensorDuration", tableName: filename, bundle: Bundle.main, value: "Sensor Duration", comment: "status info : literally 'Sensor Duration'")
    }()

    static let sensorEnd:String = {
        return NSLocalizedString("sensorend", tableName: filename, bundle: Bundle.main, value: "Sensor End", comment: "status info : literally 'Sensor End'")
    }()
    
    static let sensorRemaining:String = {
        return NSLocalizedString("sensorRemaining", tableName: filename, bundle: Bundle.main, value: "Sensor Remaining", comment: "status info : literally 'Sensor Remaining'")
    }()
    
    static let notStarted:String = {
        return NSLocalizedString("notstarted", tableName: filename, bundle: Bundle.main, value: "Not Started", comment: "status info : literally 'not started', used if sensor is not started")
    }()
    
    static let notKnown:String = {
        return NSLocalizedString("notknown", tableName: filename, bundle: Bundle.main, value: "Not Known", comment: "status info : literally 'not known', used if transmitter name is not known")
    }()

    static let lastConnection:String = {
        return NSLocalizedString("lastconnection", tableName: filename, bundle: Bundle.main, value: "Last Connection", comment: "status info : literally 'Last connection', shows when the last connection to a transmitter occured")
    }()
    
    static let ago:String = {
        return NSLocalizedString("ago", tableName: filename, bundle: Bundle.main, value: "ago", comment: "for home view, where it say how old the reading is, 'x minutes ago', literaly translation of 'ago'")
    }()
    
    static let remaining: String = {
        return NSLocalizedString("remaining", tableName: filename, bundle: Bundle.main, value: "remaining", comment: "for home view, where it say how old much time is left, literaly translation of 'remaining'")
    }()

    // make sure any translations are short enough to display nicely in the Home view
    static func sensorLifetimeRemaining(_ duration: String) -> String {
        return String(format: NSLocalizedString("sensorLifetimeRemainingFormat", tableName: filename, bundle: Bundle.main, value: "%@ remaining", comment: "for home view, where it says how much sensor lifetime is left, %@ will be replaced by the remaining days and hours"), duration)
    }

    static let licenseInfo:String = {
        return String(format: NSLocalizedString("licenseinfo", tableName: filename, bundle: Bundle.main, value: "This program is free software distributed under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or any later version.\r\n\nThis program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY.\r\n\nSee http://www.gnu.org/licenses/gpl.txt for more details.\r\n\r\nInfo: ", comment: "for home view, license info"), ConstantsHomeView.applicationName, ConstantsHomeView.applicationName)
    }()

    static let info:String = {
        return NSLocalizedString("info", tableName: filename, bundle: Bundle.main, value: "Please Read", comment: "for home view, title of pop up that gives info about how to select the transmitter. Simply the word Info")
    }()
    
    static let transmitterInfo:String = {
        return NSLocalizedString("transmitterinfo", tableName: filename, bundle: Bundle.main, value: "First go to the Bluetooth screen where you can add and scan for your transmitter.\r\n\nThen come back to the Home screen and start your sensor.", comment: "for home view, Info how to start : set transmitter and id, then go back to home screen, start scanning")
    }()
    
    static let startSensorBeforeCalibration:String = {
        return NSLocalizedString("startsensorbeforecalibration", tableName: filename, bundle: Bundle.main, value: "You cannot calibrate unless you have started a sensor.", comment: "for home view, user clicks calibrate but there's no sensor started yet")
    }()
    
    static let theresNoCGMTransmitterActive:String = {
        return NSLocalizedString("theresNoCGMTransmitterActive", tableName: filename, bundle: Bundle.main, value: "You cannot calibrate unless you have a transmitter connected.", comment: "When user has no CGM transmitter created with 'Always connect', and tries to calibrate, then this message is shown")
    }()
    
    static let thereMustBeAreadingBeforeCalibration:String = {
        return NSLocalizedString("theremustbeareadingbeforecalibration", tableName: filename, bundle: Bundle.main, value: "There must be at least two readings before you can calibrate. You will be requested to calibrate as soon as there is another reading.", comment: "for home view, user clicks calibrate but there's no reading yet")
    }()
    
    static let sensorNotDetected:String = {
        return NSLocalizedString("sensornotdetected", tableName: filename, bundle: Bundle.main, value: "The sensor was not detected. Check if the Transmitter is correctly placed on the sensor.", comment: "for home view, miaomiao doesn't detect a sensor")
    }()
    
    static let transmitterNotPaired:String = {
        return NSLocalizedString("transmitternotpaired", tableName: filename, bundle: Bundle.main, value: "The Transmitter is not paired with this iPhone. Open the application.", comment: "If transmitter needs pairing, user needs to click the notification")
    }()
    
    static let transmitterPairingTooLate:String = {
        return NSLocalizedString("transmitterpairingtoolate", tableName: filename, bundle: Bundle.main, value: "Too late! The Transmitter has already been disconnected. You should get a new pairing request in a few minutes.", comment: "If transmitter needs pairing, a notification was fired, user clicked it more than 60 seconds later, which is too late")
    }()

    static let transmitterPairingSuccessful:String = {
        return NSLocalizedString("transmitterpairingsuccessful", tableName: filename, bundle: Bundle.main, value: "The Transmitter was successfully paired.", comment: "To give info to user that the transmitter is successfully paired")
    }()
    
    static let transmitterPairingAttemptTimeout:String = {
        return NSLocalizedString("transmitterpairingattempttimeout", tableName: filename, bundle: Bundle.main, value: "Transmitter did not reply to pairing request.", comment: "To give info to user that the transmitter pairing requeset timed out")
    }()
    
    static let success:String = {
        return NSLocalizedString("success", tableName: filename, bundle: Bundle.main, value: "Success", comment: "To give result about transitter result in notification body, successful")
    }()
    
    static let failed:String = {
        return NSLocalizedString("failed", tableName: filename, bundle: Bundle.main, value: "Failed", comment: "To give result about transitter result in notification body, failed")
    }()
    
    static let calibrationNotNecessary:String = {
        return NSLocalizedString("calibrationNotNecessary", tableName: filename, bundle: Bundle.main, value: "When using the native transmitter algorithm, manual calibration is not available.\n\nIf you want to calibrate, you can switch to the xDrip algorithm in the transmitter screen (if available).", comment: "if web oop enabled, and also if transmitter supports this, user clicks calibrate button, but calibration is not possible")
    }()
 
    static let dexcomBatteryTooLow: String = {
        return NSLocalizedString("dexcomBatteryTooLow", tableName: filename, bundle: Bundle.main, value: "The Transmitter battery is too low!", comment: "Error message in case Dexcom G5 (and G6?) battery is too low. This is deteced by wrong G5 values 2096896")
    }()
    
    static let enterSensorCode: String = {
        return NSLocalizedString("enterSensorCode", tableName: filename, bundle: Bundle.main, value: "If you don't know the sensor code use 0000 but be aware that you will need to manually calibrate before you get readings.", comment: "When user needs to enter sensor code, to start firefly sensor")
    }()
    
    static let stopSensorConfirmation: String = {
        return NSLocalizedString("stopSensorConfirmation", tableName: filename, bundle: Bundle.main, value: "Are you sure you want to stop the sensor?", comment: "When user clicks stop sensor, ask confirmation")
    }()
    
    static let noSensorData: String = {
        return NSLocalizedString("noSensorData", tableName: filename, bundle: Bundle.main, value: "No sensor data", comment: "no sensor data is available")
    }()
    
    static let noDataSourceConnected: String = {
        return NSLocalizedString("noDataSourceConnected", tableName: filename, bundle: Bundle.main, value: "No CGM data source connected", comment: "no data source is enabled or connected")
    }()
    
    // the same as noDataSourceConnected but shorter to display nicely in the Watch app
    static let noDataSourceConnectedWatch: String = {
        return NSLocalizedString("noDataSourceConnectedWatch", tableName: filename, bundle: Bundle.main, value: "No data source", comment: "no data source is enabled or connected")
    }()
    
    static let reconnectLibreDataSource: String = {
        return NSLocalizedString("reconnectLibreDataSource", tableName: filename, bundle: Bundle.main, value: "Disconnect and reconnect Libre sensor", comment: "ask the user to disconnect and reconnect the sensor")
    }()
    
    // used when a CGM Transmitter is connected, but there is no active sensor data yet
    static let waitingForDataSource: String = {
        return NSLocalizedString("waitingForDataSource", tableName: filename, bundle: Bundle.main, value: "CGM connected. Waiting for data...", comment: "waiting for data to arrive")
    }()
    
    // make sure any translations are less than 20-22 characters long (including the "%@")
    static let hidingUrlForXSeconds:String = {
        return String(format: NSLocalizedString("hidingUrlForXSeconds", tableName: filename, bundle: Bundle.main, value: "Hiding URL for %@s...", comment: "After clicking scan button, this message will appear"), String(ConstantsHomeView.hideUrlDuringTimeInSeconds))
    }()
    
    static let nightscoutNotEnabled: String = {
        return NSLocalizedString("nightscoutNotEnabled", tableName: filename, bundle: Bundle.main, value: "Nightscout is disabled", comment: "nightscout is not enabled")
    }()
    
    static let nightscoutURLMissing: String = {
        return NSLocalizedString("nightscoutURLMissing", tableName: filename, bundle: Bundle.main, value: "URL missing", comment: "nightscout is not enabled")
    }()
    
    static let followerAccountCredentialsMissing: String = {
        return NSLocalizedString("followerAccountCredentialsMissing", tableName: filename, bundle: Bundle.main, value: "Username/password missing", comment: "username and/or password is missing")
    }()
    
    static let followerAccountCredentialsInvalid: String = {
        return NSLocalizedString("followerAccountCredentialsInvalid", tableName: filename, bundle: Bundle.main, value: "Invalid Account", comment: "username and/or password is invalid")
    }()
    
    static let showHideItemsTitle: String = {
        return NSLocalizedString("showHideItemsTitle", tableName: filename, bundle: Bundle.main, value: "Quick Show/Hide", comment: "show or hide various interface items")
    }()

    static let showHideHomeScreenTitle: String = {
        return NSLocalizedString("showHideHomeScreenTitle", tableName: filename, bundle: Bundle.main, value: "Home Screen", comment: "quick show hide section title for home screen items")
    }()

    static let showHideHomeScreenFooter: String = {
        return NSLocalizedString("showHideHomeScreenFooter", tableName: filename, bundle: Bundle.main, value: "Show or hide main home screen elements, useful when using smaller iPhone screen sizes", comment: "quick show hide footer for home screen items")
    }()

    static let showHideGlucoseChartTitle: String = {
        return NSLocalizedString("showHideGlucoseChartTitle", tableName: filename, bundle: Bundle.main, value: "Glucose Chart", comment: "quick show hide section title for chart items")
    }()

    static let showHideStandByModeTitle: String = {
        return NSLocalizedString("showHideStandByModeTitle", tableName: filename, bundle: Bundle.main, value: "StandBy Mode", comment: "quick show hide section title for standby settings")
    }()

    static let showHideStandByModeFooter: String = {
        return NSLocalizedString("showHideStandByModeFooter", tableName: filename, bundle: Bundle.main, value: "Changes how the StandBy mode will be displayed if activated in the iPhone settings", comment: "quick show hide footer for standby settings")
    }()

    static let showHideAdditionalItemsTitle: String = {
        return NSLocalizedString("showHideAdditionalItemsTitle", tableName: filename, bundle: Bundle.main, value: "Additional Items", comment: "quick show hide section title for additional items")
    }()
    
    static let postProcessingTitle: String = {
        return NSLocalizedString("postProcessingTitle", tableName: filename, bundle: Bundle.main, value: "Glucose Adjustments", comment: "title for the blood glucose post processing view")
    }()

    static let postProcessingPreviewHours: String = {
        return NSLocalizedString("postProcessingPreviewHours", tableName: filename, bundle: Bundle.main, value: "Preview Hours", comment: "post processing preview chart hours selector label")
    }()

    static let postProcessingAdjustment: String = {
        return NSLocalizedString("postProcessingAdjustment", tableName: filename, bundle: Bundle.main, value: "Adjustment", comment: "post processing section title for adjustment")
    }()

    static let postProcessingEnable: String = {
        return NSLocalizedString("postProcessingEnable", tableName: filename, bundle: Bundle.main, value: "Enable", comment: "post processing enable toggle title")
    }()

    static let postProcessingOffset: String = {
        return NSLocalizedString("postProcessingOffset", tableName: filename, bundle: Bundle.main, value: "Offset", comment: "post processing offset label")
    }()

    static let postProcessingScale: String = {
        return NSLocalizedString("postProcessingScale", tableName: filename, bundle: Bundle.main, value: "Scale", comment: "post processing scale label")
    }()

    static let postProcessingShape: String = {
        return NSLocalizedString("postProcessingShape", tableName: filename, bundle: Bundle.main, value: "Emphasis", comment: "post processing emphasis picker title")
    }()

    static let postProcessingShapeExplanation: String = {
        return NSLocalizedString("postProcessingShapeExplanation", tableName: filename, bundle: Bundle.main, value: "Emphasis changes where Scale has the most effect on the curve. This can help if a sensor seems to exaggerate higher or lower glucose values more than the rest of the range.", comment: "post processing explanation for emphasis selection")
    }()

    static let postProcessingSofterHighs: String = {
        return NSLocalizedString("postProcessingSofterHighs", tableName: filename, bundle: Bundle.main, value: "Highs", comment: "post processing emphasis option for highs")
    }()

    static let postProcessingSofterHighsDescription: String = {
        return NSLocalizedString("postProcessingSofterHighsDescription", tableName: filename, bundle: Bundle.main, value: "Applies more of the scale effect at higher glucose values and less at lower values.", comment: "post processing explanation for highs emphasis option")
    }()

    static let postProcessingNeutral: String = {
        return NSLocalizedString("postProcessingNeutral", tableName: filename, bundle: Bundle.main, value: "Normal", comment: "post processing shape option normal")
    }()

    static let postProcessingNeutralDescription: String = {
        return NSLocalizedString("postProcessingNeutralDescription", tableName: filename, bundle: Bundle.main, value: "Applies the scale effect evenly through the glucose range.", comment: "post processing explanation for neutral emphasis option")
    }()

    static let postProcessingSofterLows: String = {
        return NSLocalizedString("postProcessingSofterLows", tableName: filename, bundle: Bundle.main, value: "Lows", comment: "post processing emphasis option for lows")
    }()

    static let postProcessingSofterLowsDescription: String = {
        return NSLocalizedString("postProcessingSofterLowsDescription", tableName: filename, bundle: Bundle.main, value: "Applies more of the scale effect at lower glucose values and less at higher values.", comment: "post processing explanation for lows emphasis option")
    }()

    static let postProcessingSmoothing: String = {
        return NSLocalizedString("postProcessingSmoothing", tableName: filename, bundle: Bundle.main, value: "Smoothing", comment: "post processing section title for smoothing")
    }()

    static let postProcessingStrength: String = {
        return NSLocalizedString("postProcessingStrength", tableName: filename, bundle: Bundle.main, value: "Strength", comment: "post processing smoothing strength picker title")
    }()

    static let postProcessingAlgorithm: String = {
        return NSLocalizedString("postProcessingAlgorithm", tableName: filename, bundle: Bundle.main, value: "Algorithm", comment: "post processing smoothing algorithm picker title")
    }()

    static let postProcessingAlgorithmSavitzkyGolay: String = {
        return NSLocalizedString("postProcessingAlgorithmSavitzkyGolay", tableName: filename, bundle: Bundle.main, value: "Savitzky-Golay", comment: "post processing Savitzky-Golay smoothing algorithm")
    }()

    static let postProcessingAlgorithmSavitzkyGolayDescription: String = {
        return NSLocalizedString("postProcessingAlgorithmSavitzkyGolayDescription", tableName: filename, bundle: Bundle.main, value: "Savitzky-Golay smooths the glucose curve by fitting short local windows while preserving the general shape of peaks and troughs.", comment: "post processing footer text explaining the selected Savitzky-Golay smoothing algorithm")
    }()

    static let postProcessingAlgorithmExponential: String = {
        return NSLocalizedString("postProcessingAlgorithmExponential", tableName: filename, bundle: Bundle.main, value: "Exponential", comment: "post processing exponential smoothing algorithm")
    }()

    static let postProcessingAlgorithmExponentialDescription: String = {
        return NSLocalizedString("postProcessingAlgorithmExponentialDescription", tableName: filename, bundle: Bundle.main, value: "Exponential smoothing uses low-lag forward and backward weighted passes, making recent glucose moves look calmer without flattening them as aggressively.", comment: "post processing footer text explaining the selected exponential smoothing algorithm")
    }()

    static let postProcessingAlgorithmKalman: String = {
        return NSLocalizedString("postProcessingAlgorithmKalman", tableName: filename, bundle: Bundle.main, value: "Kalman", comment: "post processing Kalman smoothing algorithm")
    }()

    static let postProcessingAlgorithmKalmanDescription: String = {
        return NSLocalizedString("postProcessingAlgorithmKalmanDescription", tableName: filename, bundle: Bundle.main, value: "Kalman smoothing models glucose as a noisy live signal and updates a running estimate, usually producing a steadier curve with more obvious filtering than the default shape-preserving smoother.", comment: "post processing footer text explaining the selected Kalman smoothing algorithm")
    }()

    static let postProcessingAlgorithmLoess: String = {
        return NSLocalizedString("postProcessingAlgorithmLoess", tableName: filename, bundle: Bundle.main, value: "LOESS", comment: "post processing LOESS smoothing algorithm")
    }()

    static let postProcessingAlgorithmLoessDescription: String = {
        return NSLocalizedString("postProcessingAlgorithmLoessDescription", tableName: filename, bundle: Bundle.main, value: "LOESS fits a small weighted regression around each reading, usually preserving ramps and bends while looking smoother and less rigid than a simple filter pass.", comment: "post processing footer text explaining the selected LOESS smoothing algorithm")
    }()

    static let postProcessingAlgorithmHampelSavitzkyGolay: String = {
        return NSLocalizedString("postProcessingAlgorithmHampelSavitzkyGolay", tableName: filename, bundle: Bundle.main, value: "Hampel + Savitzky-Golay", comment: "post processing Hampel plus Savitzky-Golay smoothing algorithm")
    }()

    static let postProcessingAlgorithmHampelSavitzkyGolayDescription: String = {
        return NSLocalizedString("postProcessingAlgorithmHampelSavitzkyGolayDescription", tableName: filename, bundle: Bundle.main, value: "This hybrid first suppresses isolated spike-like outliers with a Hampel pass, then applies Savitzky-Golay smoothing to keep the broader glucose curve natural.", comment: "post processing footer text explaining the selected Hampel plus Savitzky-Golay smoothing algorithm")
    }()

    static let postProcessingLight: String = {
        return NSLocalizedString("postProcessingLight", tableName: filename, bundle: Bundle.main, value: "Light", comment: "post processing smoothing light option")
    }()

    static let postProcessingMedium: String = {
        return NSLocalizedString("postProcessingMedium", tableName: filename, bundle: Bundle.main, value: "Medium", comment: "post processing smoothing medium option")
    }()

    static let postProcessingStrong: String = {
        return NSLocalizedString("postProcessingStrong", tableName: filename, bundle: Bundle.main, value: "Strong", comment: "post processing smoothing strong option")
    }()

    static let postProcessingFiveMinuteReadings: String = {
        return NSLocalizedString("postProcessingFiveMinuteReadings", tableName: filename, bundle: Bundle.main, value: "5-minute readings", comment: "post processing option to reduce faster CGM streams to visible 5 minute readings")
    }()

    static let postProcessingReadingFrequency: String = {
        return NSLocalizedString("postProcessingReadingFrequency", tableName: filename, bundle: Bundle.main, value: "Reading Frequency", comment: "post processing section title for output cadence controls such as reducing faster streams to 5 minute readings")
    }()

    static let postProcessingApplyFrom: String = {
        return NSLocalizedString("postProcessingApplyFrom", tableName: filename, bundle: Bundle.main, value: "Apply From", comment: "post processing section title and picker title for apply from")
    }()

    static let postProcessingNow: String = {
        return NSLocalizedString("postProcessingNow", tableName: filename, bundle: Bundle.main, value: "Now", comment: "post processing apply from now option")
    }()

    static let postProcessingApply: String = {
        return NSLocalizedString("postProcessingApply", tableName: filename, bundle: Bundle.main, value: "Apply", comment: "post processing apply button")
    }()

    static let postProcessingDexcomShareDataNotUpdated: String = {
        return NSLocalizedString("postProcessingDexcomShareDataNotUpdated", tableName: filename, bundle: Bundle.main, value: "Dexcom Share data will not be updated", comment: "post processing helper text when following Dexcom Share and Dexcom Share writes are disabled")
    }()

    static let postProcessingOriginal: String = {
        return NSLocalizedString("postProcessingOriginal", tableName: filename, bundle: Bundle.main, value: "Original", comment: "post processing chart context original value title")
    }()

    static let postProcessingAdjusted: String = {
        return NSLocalizedString("postProcessingAdjusted", tableName: filename, bundle: Bundle.main, value: "Adjusted", comment: "post processing chart context adjusted value title")
    }()

    static let postProcessingSmoothed: String = {
        return NSLocalizedString("postProcessingSmoothed", tableName: filename, bundle: Bundle.main, value: "Smoothed", comment: "post processing chart context smoothed value title")
    }()

    static let postProcessingUpdateAllReadingsLastPeriod: String = {
        return NSLocalizedString("postProcessingUpdateAllReadingsLastPeriod", tableName: filename, bundle: Bundle.main, value: "Overwrite all values in the last %@", comment: "post processing helper text for historical apply window using a dynamic time period such as 1h36m")
    }()

    static let postProcessingNightscoutDataNotUpdated: String = {
        return NSLocalizedString("postProcessingNightscoutDataNotUpdated", tableName: filename, bundle: Bundle.main, value: "Nightscout data will not be updated", comment: "post processing helper text when following Nightscout and Nightscout writes are disabled")
    }()

    static let postProcessingMasterNightscoutUploadDisabled: String = {
        return NSLocalizedString("postProcessingMasterNightscoutUploadDisabled", tableName: filename, bundle: Bundle.main, value: "Upload to Nightscout is disabled", comment: "post processing helper text when master Nightscout BG upload is disabled")
    }()

    static let postProcessingOriginalGlucose: String = {
        return NSLocalizedString("postProcessingOriginalGlucose", tableName: filename, bundle: Bundle.main, value: "Original Glucose", comment: "post processing input row title for original glucose")
    }()

    static let postProcessingCurrentValue: String = {
        return NSLocalizedString("postProcessingCurrentValue", tableName: filename, bundle: Bundle.main, value: "Current Value", comment: "shared row title for the current glucose value")
    }()

    static let postProcessingAdjustedGlucose: String = {
        return NSLocalizedString("postProcessingAdjustedGlucose", tableName: filename, bundle: Bundle.main, value: "Adjusted glucose", comment: "post processing input row title for adjusted glucose")
    }()

    static let postProcessingEnterValue: String = {
        return NSLocalizedString("postProcessingEnterValue", tableName: filename, bundle: Bundle.main, value: "Enter value", comment: "post processing placeholder to enter a glucose value")
    }()

    static let postProcessingEnterGlucose: String = {
        return NSLocalizedString("postProcessingEnterGlucose", tableName: filename, bundle: Bundle.main, value: "Enter Glucose", comment: "post processing input screen title")
    }()

    static let postProcessingNoCurrentValues: String = {
        return NSLocalizedString("postProcessingNoCurrentValues", tableName: filename, bundle: Bundle.main, value: "No current values", comment: "post processing placeholder shown above the preview chart when there are no glucose values to display")
    }()
    
    static let postProcessingValidGlucoseRange: String = {
        return NSLocalizedString("postProcessingValidGlucoseRange", tableName: filename, bundle: Bundle.main, value: "Enter a value between %@ and %@", comment: "post processing helper text describing the valid glucose input range")
    }()
    
    static let postProcessingOffsetBgCheckHint: String = {
        return NSLocalizedString("postProcessingOffsetBgCheckHint", tableName: filename, bundle: Bundle.main, value: "At least one recent BG check recommended", comment: "post processing hint shown when no BG check is visible in the preview while adjusting offset")
    }()
    
    static let postProcessingScaleBgCheckHint: String = {
        return NSLocalizedString("postProcessingScaleBgCheckHint", tableName: filename, bundle: Bundle.main, value: "At least two recent BG checks recommended", comment: "post processing hint shown when fewer than two BG checks are visible in the preview while adjusting scale or emphasis")
    }()
    
    static let postProcessingAdjustmentDisabledBecauseSensorIsCalibrated: String = {
        return NSLocalizedString("postProcessingAdjustmentDisabledBecauseSensorIsCalibrated", tableName: filename, bundle: Bundle.main, value: "Adjustment is disabled because this sensor already uses its own calibration.", comment: "post processing footer text when glucose adjustment is disabled because the active sensor already uses calibration")
    }()
    
    static let postProcessingAdjustmentDisabledUseNativeAlgorithm: String = {
        return NSLocalizedString("postProcessingAdjustmentDisabledUseNativeAlgorithm", tableName: filename, bundle: Bundle.main, value: "Adjustment is disabled because this sensor already uses its own calibration. Change to the native algorithm to allow glucose adjustments.", comment: "post processing footer text when glucose adjustment is disabled for a Libre sensor using xDrip calibration")
    }()
    
    static let showTreatments: String = {
        return NSLocalizedString("showTreatments", tableName: filename, bundle: Bundle.main, value: "Show Treatments", comment: "show the treatments on the chart")
    }()
    
}
