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
        return NSLocalizedString("snoozeAllSnoozedUntil", tableName: filename, bundle: Bundle.main, value: "All alarms are snoozed!", comment: "snooze all text in snooze screen")
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
    
    static let transmitterBatteryLevel:String = {
        return NSLocalizedString("transmitterbatterylevel", tableName: filename, bundle: Bundle.main, value: "Transmitter Battery Level", comment: "status info : literally 'Transmitter Battery Level', shows the battery level")
    }()
    
    static let ago:String = {
        return NSLocalizedString("ago", tableName: filename, bundle: Bundle.main, value: "ago", comment: "for home view, where it say how old the reading is, 'x minutes ago', literaly translation of 'ago'")
    }()
    
    static let remaining: String = {
        return NSLocalizedString("remaining", tableName: filename, bundle: Bundle.main, value: "remaining", comment: "for home view, where it say how old much time is left, literaly translation of 'remaining'")
    }()

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
        return NSLocalizedString("nightscoutURLMissing", tableName: filename, bundle: Bundle.main, value: "Nightscout URL missing", comment: "nightscout is not enabled")
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
    
    static let showTreatments: String = {
        return NSLocalizedString("showTreatments", tableName: filename, bundle: Bundle.main, value: "Show Treatments", comment: "show the treatments on the chart")
    }()
    
}
