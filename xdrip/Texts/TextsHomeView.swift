import Foundation

/// all texts related to calibration
enum Texts_HomeView {
    static private let filename = "HomeView"
    
    static let snoozeButton:String = {
        return NSLocalizedString("presnooze", tableName: filename, bundle: Bundle.main, value: "Snooze", comment: "Text in button on home screen")
    }()
    
    static let transmitter:String = {
        return NSLocalizedString("transmitter", tableName: filename, bundle: Bundle.main, value: "Transmitter", comment: "Literally 'Transmitter', used as name in the button in the home screen, but also in text in pop ups")
    }()
    
    static let calibrationButton:String = {
        return NSLocalizedString("calibrate", tableName: filename, bundle: Bundle.main, value: "Calibrate", comment: "Text in button on home screen")
    }()
    
    static let statusActionTitle:String = {
        return NSLocalizedString("statusactiontitle", tableName: filename, bundle: Bundle.main, value: "Status", comment: "when user clicks transmitterButton, this is the first action, to show the status")
    }()
    
    static let scanBluetoothDeviceActionTitle:String = {
        return NSLocalizedString("scanbluetoothdeviceactiontitle", tableName: filename, bundle: Bundle.main, value: "Scan Transmitter", comment: "when user clicks transmitterButton, this is the action to start scanning")
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
        return NSLocalizedString("startsensortimeinfo", tableName: filename, bundle: Bundle.main, value: "In the next dialogs, you will need to set the date and time the sensor was inserted. It is important that you set the date and time as correct as possible. This is important for the accuracy.", comment: "when user manually starts sensor, this is the message that explains that time should be correct")
    }()
    
    static let scanBluetoothDeviceOngoing:String = {
        return NSLocalizedString("scanbluetoothdeviceongoing", tableName: filename, bundle: Bundle.main, value: "Busy scanning for transmitter", comment: "when user manually starts scanning, this is the message that scanning is ongoing")
    }()
    
    static let bluetoothIsNotOn:String = {
        return NSLocalizedString("bluetoothisnoton", tableName: filename, bundle: Bundle.main, value: "Bluetooth is not on. Switch on Bluetooth first then try again.", comment: "when user manually starts scanning but bluetooth is not on")
    }()
   
    static let bluetoothDeviceConnectedInfo:String = {
        return NSLocalizedString("bluetoothdeviceconnectedinfo", tableName: filename, bundle: Bundle.main, value: "Connected to Transmitter. Device details are stored. Future connection attempts will only use this transmitter.\r\n\r\nTo use another transmitter, select first 'Forget Transmitter'", comment: "when user did manually start scanning, connection was successful")
    }()
    
    static let sensorStart:String = {
        return NSLocalizedString("sensorstart", tableName: filename, bundle: Bundle.main, value: "Sensor Start", comment: "status info : literally 'Sensor Start'")
    }()
    
    static let notStarted:String = {
        return NSLocalizedString("notstarted", tableName: filename, bundle: Bundle.main, value: "not started", comment: "status info : literally 'not started', used if sensor is not started")
    }()
    
    static let notKnown:String = {
        return NSLocalizedString("notknown", tableName: filename, bundle: Bundle.main, value: "not known", comment: "status info : literally 'not known', used if transmitter name is not known")
    }()

    static let lastConnection:String = {
        return NSLocalizedString("lastconnection", tableName: filename, bundle: Bundle.main, value: "Last connection", comment: "status info : literally 'Last connection', shows when the last connection to a transmitter occured")
    }()
    
    static let transmitterBatteryLevel:String = {
        return NSLocalizedString("transmitterbatterylevel", tableName: filename, bundle: Bundle.main, value: "Transmitter Battery Level", comment: "status info : literally 'Transmitter Battery Level', shows the battery level")
    }()
    
    static let connected:String = {
        return NSLocalizedString("connected", tableName: filename, bundle: Bundle.main, value: "Connected", comment: "status info : literally 'connected', if transmitter is currently connected")
    }()
    
    static let neverConnected:String = {
        return NSLocalizedString("neverconnected", tableName: filename, bundle: Bundle.main, value: "Didn't connect yet", comment: "status info : literally 'didn't connect yet', if it's a new transmitter that didn't connect before")
    }()
    
    static let ago:String = {
        return NSLocalizedString("ago", tableName: filename, bundle: Bundle.main, value: "ago", comment: "for home view, where it say how old the reading is, 'x minutes ago', literaly translation of 'ago'")
    }()

    static let licenseInfo:String = {
        return NSLocalizedString("licenseinfo", tableName: filename, bundle: Bundle.main, value: "This program is free software distributed under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or any later version.\r\nThis program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY.  See http://www.gnu.org/licenses/gpl.txt for more details\r\n\r\nInfo : ", comment: "for home view, license info")
    }()

    static let info:String = {
        return NSLocalizedString("info", tableName: filename, bundle: Bundle.main, value: "Info", comment: "for home view, title of pop up that gives info about how to select the transmitter. Simply the word Info")
    }()
    
    static let transmitterInfo:String = {
        return NSLocalizedString("transmitterinfo", tableName: filename, bundle: Bundle.main, value: "First go to the settings tab where you can select you transmitter type and (if applicable) transmitter id. Depending on device type, you will need to come back to this tab here (the Home) tab where you can start scanning.", comment: "for home view, Info how to start : set transmitter and id, then go back to home screen, start scanning")
    }()
    
    static let startSensorBeforeCalibration:String = {
        return NSLocalizedString("startsensorbeforecalibration", tableName: filename, bundle: Bundle.main, value: "You can not calibrate as long as there's no sensor started.", comment: "for home view, user clicks calibrate but there's no sensor started yet")
    }()
    
    static let thereMustBeAreadingBeforeCalibration:String = {
        return NSLocalizedString("theremustbeareadingbeforecalibration", tableName: filename, bundle: Bundle.main, value: "There must be at least two readings before you can calibrate. You will be requested to calibrate as soon as a reading arrives.", comment: "for home view, user clicks calibrate but there's no reading yet")
    }()
    
}
