import Foundation

class Texts_BluetoothPeripheralView {
    
    static private let filename = "BluetoothPeripheralView"
    
    static let address: String = {
        return NSLocalizedString("address", tableName: filename, bundle: Bundle.main, value: "Address:", comment: "when M5Stack is shown, title of the cell with the address")
    }()

    static let status: String = {
        return NSLocalizedString("status", tableName: filename, bundle: Bundle.main, value: "Status:", comment: "when Bluetooth Peripheral is shown, title of the cell with the status")
    }()
    
    static let connected: String = {
        return NSLocalizedString("connected", tableName: filename, bundle: Bundle.main, value: "Connected", comment: "when Bluetooth Peripheral is shown, connection status, connected")
    }()
    
    static let donotconnect: String = {
        return NSLocalizedString("donotconnect", tableName: filename, bundle: Bundle.main, value: "Stop Scanning", comment: "text in button top right, this button will disable automatic connect")
    }()
    
    static let selectAliasText: String = {
        return NSLocalizedString("selectAliasText", tableName: filename, bundle: Bundle.main, value: "Choose an alias for this bluetooth device, the name will be shown in the app and is easier for you to recognize", comment: "Bluetooth Peripheral view, when user clicks alias field")
    }()
    
    static let aliasAlreadyExists: String = {
        return NSLocalizedString("aliasAlreadyExists", tableName: filename, bundle: Bundle.main, value: "There is already a bluetooth device with this alias", comment: "Bluetooth Peripheral view, when user clicks alias field")
    }()
    
    static let confirmDeletionBluetoothPeripheral: String = {
        return NSLocalizedString("confirmDeletionPeripheral", tableName: filename, bundle: Bundle.main, value: "Do you want to delete bluetooth device: ", comment: "Bluetooth Peripheral view, when user clicks the trash button - this is not the complete sentence, it will be followed either by 'name' or 'alias', depending on the availability of an alias")
    }()
    
    static let bluetoothPeripheralAlias: String = {
        return NSLocalizedString("bluetoothPeripheralAlias", tableName: filename, bundle: Bundle.main, value: "Alias:", comment: "BluetoothPeripheral view, this is a name of a BluetoothPeripheral assigned by the user, to recognize the device")
    }()

    static let sensorSerialNumber: String = {
        return NSLocalizedString("SensorSerialNumber", tableName: filename, bundle: Bundle.main, value: "Sensor Serial Number:", comment: "BluetoothPeripheral view, text of the cell with the sensor serial number")
    }()
    
    static let sensorType: String = {
        return NSLocalizedString("sensorType", tableName: filename, bundle: Bundle.main, value: "Sensor Type:", comment: "BluetoothPeripheral view, text of the cell with the sensor type (only used for Libre)")
    }()
    
    static let serialNumber: String = {
        return NSLocalizedString("serialNumber", tableName: filename, bundle: Bundle.main, value: "Serial Number:", comment: "BluetoothPeripheral view, text of the cell with the serial number (this is not the sensor serial number")
    }()
    
    static let battery: String = {
        return NSLocalizedString("Battery", tableName: filename, bundle: Bundle.main, value: "Battery:", comment: "BluetoothPeripheral view, section title with battery info")
    }()
    
    static let needsTransmitterId: String = {
        return NSLocalizedString("needsTransmitterId", tableName: filename, bundle: Bundle.main, value: "Missing Transmitter ID", comment: "cell text, if user needs to set the transmitter id")
    }()
    
    static let scan: String = {
        return NSLocalizedString("scan", tableName: filename, bundle: Bundle.main, value: "Scan", comment: "text in button to start scanning")
    }()
    
    static let readyToScan: String = {
        return NSLocalizedString("readyToScan", tableName: filename, bundle: Bundle.main, value: "Ready to Scan", comment: "text in status row, if ready to start scanning")
    }()
    
    static let scanning: String = {
        return NSLocalizedString("scanning", tableName: filename, bundle: Bundle.main, value: "Scanning", comment: "text in status row, if scanning ongoing")
    }()
    
    static let disconnect: String = {
        return NSLocalizedString("disconnect", tableName: filename, bundle: Bundle.main, value: "Disconnect", comment: "button text, to disconnect")
    }()
    
    static let tryingToConnect: String = {
        return NSLocalizedString("tryingToConnect", tableName: filename, bundle: Bundle.main, value: "Scanning", comment: "text in status rown, when not connect but app is trying to connect")
    }()
    
    static let notTryingToConnect: String = {
        return NSLocalizedString("notTryingToConnect", tableName: filename, bundle: Bundle.main, value: "Not Scanning", comment: "text in status row, when not connected and app is not scanning")
    }()
    
    static let connect: String = {
        return NSLocalizedString("connect", tableName: filename, bundle: Bundle.main, value: "Connect", comment: "button text, to connect")
    }()
    
    static let connectedAt: String = {
        return NSLocalizedString("connectedAt", tableName: filename, bundle: Bundle.main, value: "Connected At:", comment: "cell text, where the connection timestamp is shown")
    }()
    
    static let disConnectedAt: String = {
        return NSLocalizedString("disConnectedAt", tableName: filename, bundle: Bundle.main, value: "Disconnected At:", comment: "cell text, where the disconnection timestamp is shown")
    }()
    
    static let resetRequired: String = {
        return NSLocalizedString("resetRequired", tableName: filename, bundle: Bundle.main, value: "Reset Transmitter", comment: "cell text, where user can select to reset a transmitter at next connect. Only for Dexcom")
    }()
    
    static let lastResetTimeStamp: String = {
        return NSLocalizedString("lastReset", tableName: filename, bundle: Bundle.main, value: "Last Reset:", comment: "cell text, shows when last reset was done, if known. Only for Dexcom")
    }()
    
    static let transmittterStartDate: String = {
        return NSLocalizedString("transmittterStartDate", tableName: filename, bundle: Bundle.main, value: "Transmitter Started", comment: "cell text, transmitter start time")
    }()
    
    static let transmittterExpiryDate: String = {
        return NSLocalizedString("transmittterExpiryDate", tableName: filename, bundle: Bundle.main, value: "Transmitter Expires", comment: "cell text, transmitter expiry date")
    }()
    
    static let sensorStartDate: String = {
        return NSLocalizedString("sensorStartDate", tableName: filename, bundle: Bundle.main, value: "Sensor Started", comment: "cell text, sensor start time")
    }()
    
    static let lastResetTimeStampNotKnown: String = {
        return NSLocalizedString("lastResetNotKnown", tableName: filename, bundle: Bundle.main, value: "Last Reset Timestamp is not known", comment: "cell text, shows when last reset was done, if known. Only for Dexcom")
    }()
   
    static let transmitterResetResult: String = {
        return NSLocalizedString("transmitterResultResult", tableName: filename, bundle: Bundle.main, value: "Transmitter Reset Result", comment: "To give result about transitter result in notification body")
    }()
    
    static let bootLoader: String = {
        return NSLocalizedString("bootLoader", tableName: filename, bundle: Bundle.main, value: "Bootloader", comment: "row in bluetoothperipheral view, title")
    }()

    static let cannotActiveCGMInFollowerMode: String = {
        return NSLocalizedString("cannotActiveCGMInFollowerMode", tableName: filename, bundle: Bundle.main, value: "You cannot activate or connect to a CGM whilst in Follower Mode.", comment: "User tries to add a CGM or connect an already existing CGM, while in follower mode.")
    }()
    
    static let confirmDisconnectTitle: String = {
        return NSLocalizedString("confirmDisconnectTitle", tableName: filename, bundle: Bundle.main, value: "Confirm Disconnect", comment: "Disconnect transmitter, title")
    }()
    
    static let confirmDisconnectMessage: String = {
        return NSLocalizedString("confirmDisconnectMessage", tableName: filename, bundle: Bundle.main, value: "Click 'Disconnect' to confirm that you really want to disconnect from the transmitter.", comment: "Confirm that the user wants to really disconnect the transmitter, title")
    }()
    
    static let useOtherDexcomApp: String = {
        return NSLocalizedString("useOtherDexcomApp", tableName: filename, bundle: Bundle.main, value: "Use With Other App", comment: "Dexcom bluetooth screen. Is another app used in parallel or not")
    }()
    
    static let useOtherDexcomAppMessageEnabled: String = {
        return String(format: NSLocalizedString("useOtherDexcomAppMessageEnabled", tableName: filename, bundle: Bundle.main, value: "Enabling this option will allow another app (such as Dexcom G6 or CamAPS apps) to run at the same time and connect to the G6 transmitter.\r\n\nThe other app will be responsible for providing authentication to the transmitter and must ALWAYS be running in the background or %@ will not get any readings.", comment: "Dexcom bluetooth screen. Message to explain that another app must be running to handle the authentication with the transmitter."), ConstantsHomeView.applicationName)
    }()
    
    static let useOtherDexcomAppMessageDisabled: String = {
        return String(format: NSLocalizedString("useOtherDexcomAppMessageDisabled", tableName: filename, bundle: Bundle.main, value: "Disabling this option means that %@ must be the only app connecting and authenticating with the G6 transmitter.\r\n\nIf any other app is also left open and connected, then it is likely that either %@ or the other app will not get readings.", comment: "Dexcom bluetooth screen. Message to explain that this app is the only one running to handle the authentication with the transmitter"), ConstantsHomeView.applicationName, ConstantsHomeView.applicationName)
    }()
    
    static let nfcScanNeeded: String = {
        return NSLocalizedString("nfcScanNeeded", tableName: filename, bundle: Bundle.main, value: "NFC scan needed", comment: "text in status row, when waiting for a successful NFC scan before starting bluetooth scanning")
    }()
    
    static let nonFixedSlopeWarning: String = {
        return NSLocalizedString("nonFixedSlopeWarning", tableName: filename, bundle: Bundle.main, value: "Multi-point calibration is an advanced feature.\n\nPlease do not use this feature until you have read the calibration section of the online help and understand how it works.", comment: "text to inform the user that multi-point calibration is an advanced option and could be dangerous if used incorrectly")
    }()
    
    static let warmingUpUntil: String = {
        return NSLocalizedString("warmingUpUntil", tableName: filename, bundle: Bundle.main, value: "Warming up until", comment: "sensor warm-up text")
    }()
    
    static let nativeAlgorithm: String = {
        return NSLocalizedString("nativeAlgorithm", tableName: filename, bundle: Bundle.main, value: "Native Algorithm", comment: "native or transmitter algorithm type text")
    }()
    
    static let xDripAlgorithm: String = {
        return NSLocalizedString("xDripAlgorithm", tableName: filename, bundle: Bundle.main, value: "xDrip Algorithm", comment: "xDrip algorithm type text")
    }()
    
    static let confirmAlgorithmChangeToTransmitterMessage: String = {
        return NSLocalizedString("confirmAlgorithmChangeToTransmitterMessage", tableName: filename, bundle: Bundle.main, value: "Please confirm that you want to change back to the native/transmitter algorithm.", comment: "Confirm that the user wants to really change the transmitter or native algorithm type, message")
    }()
    
    static let confirmAlgorithmChangeToxDripMessage: String = {
        return NSLocalizedString("confirmAlgorithmChangeToxDripMessage", tableName: filename, bundle: Bundle.main, value: "Please confirm that you want to change the the xDrip algorithm.\n\nThis will stop readings for a short time and ask you for a initial calibration value when ready.", comment: "Confirm that the user wants to really change the xDrip algorithm type, message")
    }()
    
    static let confirmCalibrationChangeToSinglePointMessage: String = {
        return NSLocalizedString("confirmCalibrationChangeToSinglePointMessage", tableName: filename, bundle: Bundle.main, value: "Please confirm that you want to change the calibration type to the standard calibration\n\nThis will stop readings for a short time and ask you for a initial calibration value when ready.", comment: "Confirm that the user wants to really change the calibration type to multi-point, message")
    }()
    
    static let confirmCalibrationChangeToMultiPointMessage: String = {
        return NSLocalizedString("confirmCalibrationChangeToMultiPointMessage", tableName: filename, bundle: Bundle.main, value: "Please confirm that you want to change the calibration type to multi-point\n\n⚠️ Please note that this method is only for advanced users and could potentially give dangerous results if not correctly calibrated.\n\nIf you are unsure how to use this method, please press Cancel.", comment: "Confirm that the user wants to really change the calibration type to multi-point, message")
    }()
    
    static let confirm: String = {
        return NSLocalizedString("confirm", tableName: filename, bundle: Bundle.main, value: "Confirm", comment: "button text, confirm")
    }()
    
    static let maxSensorAgeInDaysOverridenAnubis: String = {
        return NSLocalizedString("maxSensorAgeInDaysOverridenAnubis", tableName: filename, bundle: Bundle.main, value: "Maximum Sensor Days", comment: "user can override the maximum sensor days if using an anubis transmitter")
    }()
    
    static let maxSensorAgeInDaysOverridenAnubisMessage = {
        return String(format: NSLocalizedString("maxSensorAgeInDaysOverridenAnubisMessage", tableName: filename, bundle: Bundle.main, value: "\nIf using an Anubis transmitter, you can enter here the maximum number of days for the sensor lifetime (maximum %@)\n\nNote that this is only a visual reminder. It will not end the sensor session when reached.\n\nEnter 0 to use the default of %@ days", comment: "user can override the maximum sensor days if using an anubis transmitter"), ConstantsDexcomG5.maxSensorAgeInDaysOverridenAnubisMaximum.stringWithoutTrailingZeroes, ConstantsDexcomG5.maxSensorAgeInDays.stringWithoutTrailingZeroes)
    }()
    
    static let isAnubis: String = {
        return NSLocalizedString("isAnubis", tableName: filename, bundle: Bundle.main, value: "Is Anubis?", comment: "Dexcom bluetooth screen. Is it an anubis transmitter")
    }()
    
}
