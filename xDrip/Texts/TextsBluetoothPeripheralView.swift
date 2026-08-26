import Foundation

class Texts_BluetoothPeripheralView {
    
    static private let filename = "BluetoothPeripheralView"
    
    static let address: String = {
        return NSLocalizedString("address", tableName: filename, bundle: Bundle.main, value: "Address:", comment: "when M5Stack is shown, title of the cell with the address")
    }()

    static let status: String = {
        return NSLocalizedString("status", tableName: filename, bundle: Bundle.main, value: "Status:", comment: "when Bluetooth Peripheral is shown, title of the cell with the status")
    }()

    static let runningInCoexistenceMode: String = {
        return NSLocalizedString("runningInCoexistenceMode", tableName: filename, bundle: Bundle.main, value: "Running in Coexistence mode", comment: "Dexcom bluetooth status footer. Another app authenticates with the transmitter.")
    }()

    static let runningInPrimaryMode: String = {
        return NSLocalizedString("runningInPrimaryMode", tableName: filename, bundle: Bundle.main, value: "Running in Primary mode", comment: "Dexcom bluetooth status footer. This app controls the transmitter connection.")
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
        return NSLocalizedString("battery", tableName: filename, bundle: Bundle.main, value: "Battery", comment: "BluetoothPeripheral view, section title with battery info")
    }()
    
    static let needsTransmitterId: String = {
        return NSLocalizedString("needsTransmitterId", tableName: filename, bundle: Bundle.main, value: "Missing Transmitter ID", comment: "cell text, if user needs to set the transmitter id")
    }()
    
    static let scan: String = {
        return NSLocalizedString("scan", tableName: filename, bundle: Bundle.main, value: "Scan", comment: "text in button to start scanning")
    }()

    static let medtrumNanoPumpScanNoticeTitle: String = {
        return NSLocalizedString("medtrumNanoPumpScanNoticeTitle", tableName: filename, bundle: Bundle.main, value: "Medtrum Nano Pump Connection", comment: "title of the notice shown before scanning for a Medtrum Nano Pump")
    }()

    static let medtrumNanoPumpScanNoticeMessage: String = {
        return NSLocalizedString(
            "medtrumNanoPumpScanNoticeMessage",
            tableName: filename,
            bundle: Bundle.main,
            value: "This option connects to the Medtrum Nano Pump, not directly to the Nano CGM transmitter.\n\nBefore scanning, make sure EasyPatch is running, connected to the pump, and receiving current CGM values.\n\nEasyPatch must remain running and continue receiving values at all times.",
            comment: "notice shown before scanning for a Medtrum Nano Pump, explaining that the CGM connection is relayed by the pump and requires EasyPatch"
        )
    }()

    static let libre2ScanNoticeTitle: String = {
        return NSLocalizedString("libre2ScanNoticeTitle", tableName: filename, bundle: Bundle.main, value: "Libre App Bluetooth", comment: "title of the notice shown before scanning for a Libre 2 sensor")
    }()

    static let libre2ScanNoticeMessage: String = {
        return NSLocalizedString(
            "libre2ScanNoticeMessage",
            tableName: filename,
            bundle: Bundle.main,
            value: "Before scanning, disable Bluetooth permission for the Libre app in your iPhone settings.\n\nBluetooth permission for the Libre app must remain disabled at all times. Otherwise, the Libre app may take over the sensor connection and stop this app from receiving values.",
            comment: "notice shown before scanning for a Libre 2 sensor, explaining that Bluetooth permission for the Libre app must remain disabled"
        )
    }()

    static let dexcomG6ScanNoticeTitle: String = {
        return NSLocalizedString("dexcomG6ScanNoticeTitle", tableName: filename, bundle: Bundle.main, value: "Dexcom App Connection", comment: "title of the notice shown before scanning for a Dexcom G6 or ONE transmitter")
    }()

    static let dexcomG6ScanNoticeMessage: String = {
        return NSLocalizedString(
            "dexcomG6ScanNoticeMessage",
            tableName: filename,
            bundle: Bundle.main,
            value: "Before scanning, force-close the Dexcom app or disable Bluetooth permission for it.\n\nThe Dexcom app must not be connected to the transmitter while this app is scanning or receiving values.",
            comment: "notice shown before scanning for a Dexcom G6 or ONE transmitter, explaining how to avoid a competing Dexcom app connection"
        )
    }()

    static let dexcomG7ScanNoticeTitle: String = {
        return NSLocalizedString("dexcomG7ScanNoticeTitle", tableName: filename, bundle: Bundle.main, value: "Dexcom G7 App Required", comment: "title of the notice shown before scanning for a Dexcom G7 sensor")
    }()

    static let dexcomG7ScanNoticeMessage: String = {
        return NSLocalizedString(
            "dexcomG7ScanNoticeMessage",
            tableName: filename,
            bundle: Bundle.main,
            value: "Before scanning, make sure the Dexcom G7 app is running in the background, connected to the sensor, and receiving current glucose values.\n\nThe Dexcom G7 app must remain running and continue receiving values at all times.",
            comment: "notice shown before scanning for a Dexcom G7 sensor, explaining that the Dexcom G7 app must remain running and receiving values"
        )
    }()
    
    static let readyToScan: String = {
        return NSLocalizedString("readyToScan", tableName: filename, bundle: Bundle.main, value: "Ready to Scan", comment: "text in status row, if ready to start scanning")
    }()
    
    static let scanning: String = {
        return NSLocalizedString("scanning", tableName: filename, bundle: Bundle.main, value: "Scanning", comment: "text in status row, if scanning ongoing")
    }()

    static let scanningForTransmitter: String = {
        return NSLocalizedString("scanningForTransmitter", tableName: filename, bundle: Bundle.main, value: "Scanning...", comment: "full status while discovering a new unknown Bluetooth transmitter")
    }()

    static let connecting: String = {
        return NSLocalizedString("connecting", tableName: filename, bundle: Bundle.main, value: "Connecting", comment: "compact status before the first successful Bluetooth connection after activation")
    }()

    static let connectingToTransmitter: String = {
        return NSLocalizedString("connectingToTransmitter", tableName: filename, bundle: Bundle.main, value: "Connecting...", comment: "full status before the first successful Bluetooth connection after activation")
    }()

    static let reconnecting: String = {
        return NSLocalizedString("reconnecting", tableName: filename, bundle: Bundle.main, value: "Reconnecting", comment: "compact warning status for an unexpectedly disconnected continuously connected device")
    }()

    static let reconnectingToTransmitter: String = {
        return NSLocalizedString("reconnectingToTransmitter", tableName: filename, bundle: Bundle.main, value: "Reconnecting...", comment: "full warning status for an unexpectedly disconnected continuously connected device")
    }()

    static let waiting: String = {
        return NSLocalizedString("waiting", tableName: filename, bundle: Bundle.main, value: "Waiting...", comment: "healthy status for an intermittent Dexcom device between normal Bluetooth advertisements; used in both full and compact presentations")
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
        return NSLocalizedString("useOtherDexcomApp", tableName: filename, bundle: Bundle.main, value: "Coexistence Mode", comment: "Dexcom bluetooth screen. Toggle title. When enabled, another app such as Dexcom or CamAPS authenticates with the transmitter while this app receives alongside it.")
    }()

    static let dexcomG6BluetoothSlot: String = {
        return NSLocalizedString("dexcomG6BluetoothSlot", tableName: filename, bundle: Bundle.main, value: "Bluetooth Channel", comment: "Dexcom G6 Bluetooth screen. Picker title for the authentication role/slot.")
    }()

    static let dexcomG6MobileAppSlot: String = {
        return NSLocalizedString("dexcomG6MobileAppSlot", tableName: filename, bundle: Bundle.main, value: "Mobile App (Default)", comment: "Dexcom G6 Bluetooth slot picker. Default mobile-app role.")
    }()

    static let dexcomG6MobileAppSlotShort: String = {
        return NSLocalizedString("dexcomG6MobileAppSlotShort", tableName: filename, bundle: Bundle.main, value: "Mobile App", comment: "Dexcom G6 Bluetooth screen. Compact detail value for the default mobile-app role.")
    }()

    static let dexcomG6MedicalDeviceSlot: String = {
        return NSLocalizedString("dexcomG6MedicalDeviceSlot", tableName: filename, bundle: Bundle.main, value: "Receiver or Pump (Experimental)", comment: "Dexcom G6 Bluetooth slot picker. Experimental medical-device role.")
    }()

    static let dexcomG6MedicalDeviceSlotShort: String = {
        return NSLocalizedString("dexcomG6MedicalDeviceSlotShort", tableName: filename, bundle: Bundle.main, value: "Pump", comment: "Dexcom G6 Bluetooth screen. Compact detail value for the receiver or pump role.")
    }()

    static let dexcomG6AnubisSlot: String = {
        return NSLocalizedString("dexcomG6AnubisSlot", tableName: filename, bundle: Bundle.main, value: "Slot 3 (Anubis Experimental)", comment: "Dexcom G6 Bluetooth slot picker. Experimental third slot implemented by Anubis transmitters.")
    }()

    static let dexcomG6AnubisSlotShort: String = {
        return NSLocalizedString("dexcomG6AnubisSlotShort", tableName: filename, bundle: Bundle.main, value: "Slot 3", comment: "Dexcom G6 Bluetooth screen. Compact detail value for the experimental Anubis third slot.")
    }()

    static let dexcomG6MobileAppSlotFooter: String = {
        return NSLocalizedString("dexcomG6MobileAppSlotFooter", tableName: filename, bundle: Bundle.main, value: "The Mobile App channel is the default for phone connections.", comment: "Dexcom G6 Bluetooth screen. Footer shown while the default mobile-app channel is selected.")
    }()

    static let dexcomG6MedicalDeviceSlotFooter: String = {
        return NSLocalizedString("dexcomG6MedicalDeviceSlotFooter", tableName: filename, bundle: Bundle.main, value: "The Receiver or Pump channel is normally reserved for the Dexcom receiver or a compatible pump. Using it for this app leaves the Mobile App channel available for a phone or another device.", comment: "Dexcom G6 Bluetooth screen. Footer shown while the receiver or pump channel is selected.")
    }()

    static let dexcomG6AnubisSlotFooter: String = {
        return NSLocalizedString("dexcomG6AnubisSlotFooter", tableName: filename, bundle: Bundle.main, value: "Slot 3 is available only on Anubis transmitters. It is experimental and leaves the Mobile App and Receiver or Pump channels available for other devices.", comment: "Dexcom G6 Bluetooth screen. Footer shown while the experimental Anubis third slot is selected.")
    }()

    static let dexcomG6BluetoothSlotUnavailableInCoexistenceMode: String = {
        return NSLocalizedString("dexcomG6BluetoothSlotUnavailableInCoexistenceMode", tableName: filename, bundle: Bundle.main, value: "Unavailable in Co-existence mode", comment: "Dexcom G6 Bluetooth screen. Footer shown when Bluetooth channel selection is disabled by Coexistence Mode.")
    }()

    static let dexcomG6MedicalDeviceSlotWarning: String = {
        return NSLocalizedString("dexcomG6MedicalDeviceSlotWarning", tableName: filename, bundle: Bundle.main, value: "The Receiver or Pump channel is normally reserved for a Dexcom receiver or compatible pump. Selecting it can prevent that device from connecting.\n\nUsing the Receiver or Pump channel should be considered for experimental use only. The selection takes effect on the next authentication.", comment: "Safety warning before selecting the experimental Dexcom G6 receiver-or-pump Bluetooth channel.")
    }()

    static let dexcomG6AnubisSlotWarning: String = {
        return NSLocalizedString("dexcomG6AnubisSlotWarning", tableName: filename, bundle: Bundle.main, value: "Slot 3 is an experimental channel available only on Anubis transmitters.\n\nUse Slot 3 for testing only. The selection takes effect on the next authentication.", comment: "Safety warning before selecting the experimental Anubis third Bluetooth slot.")
    }()

    static let useOtherDexcomAppCoexistenceFooter: String = {
        return NSLocalizedString("useOtherDexcomAppCoexistenceFooter", tableName: filename, bundle: Bundle.main, value: "Coexistence mode allows us to work with another app such as the Dexcom or CamAPS apps. That app must keep running in the background.", comment: "Dexcom bluetooth screen. Footer explaining coexistence mode.")
    }()

    static let useOtherDexcomAppPrimaryFooter: String = {
        return NSLocalizedString("useOtherDexcomAppPrimaryFooter", tableName: filename, bundle: Bundle.main, value: "Primary mode connects as the main app and controls the connection.", comment: "Dexcom bluetooth screen. Footer explaining primary mode.")
    }()
    
    static let useOtherDexcomAppMessageEnabled: String = {
        return String(format: NSLocalizedString("useOtherDexcomAppMessageEnabled", tableName: filename, bundle: Bundle.main, value: "Enabling this option will allow another app (such as Dexcom G6 or CamAPS apps) to run at the same time and connect to the G6 transmitter.\r\n\nThe other app will be responsible for providing authentication to the transmitter and must ALWAYS be running in the background or %@ will not get any readings.", comment: "Dexcom bluetooth screen. Message to explain that another app must be running to handle the authentication with the transmitter."), ConstantsHomeView.applicationName)
    }()
    
    static let useOtherDexcomAppMessageDisabled: String = {
        return String(format: NSLocalizedString("useOtherDexcomAppMessageDisabled", tableName: filename, bundle: Bundle.main, value: "Disabling this option means that %@ must be the only app connecting and authenticating with the G6 transmitter.\r\n\nIf any other app is also left open and connected, then it is likely that either %@ or the other app will not get readings.", comment: "Dexcom bluetooth screen. Message to explain that this app is the only one running to handle the authentication with the transmitter"), ConstantsHomeView.applicationName, ConstantsHomeView.applicationName)
    }()
    
    static let is15DayDexcomG7: String = {
        return NSLocalizedString("is15DayDexcomG7", tableName: filename, bundle: Bundle.main, value: "15 Day Sensor", comment: "Dexcom bluetooth screen. Is this a 15-day G7 sensor?")
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
        return String(format: NSLocalizedString("maxSensorAgeInDaysOverridenAnubisMessage", tableName: filename, bundle: Bundle.main, value: "If using an Anubis transmitter, you can enter here the maximum number of days for the sensor lifetime (maximum %@)\n\nNote that this is only a visual reminder. It will not end the sensor session when reached.\n\nEnter 0 to use the default of %@ days", comment: "user can override the maximum sensor days if using an anubis transmitter"), ConstantsDexcomG5.maxSensorAgeInDaysOverridenAnubisMaximum.stringWithoutTrailingZeroes, ConstantsDexcomG5.maxSensorAgeInDays.stringWithoutTrailingZeroes)
    }()
    
    static let isAnubis: String = {
        return NSLocalizedString("isAnubis", tableName: filename, bundle: Bundle.main, value: "Is Anubis?", comment: "Dexcom bluetooth screen. Is it an anubis transmitter")
    }()
    
    static let readSuccess: String = {
        return NSLocalizedString("readSuccess", tableName: filename, bundle: Bundle.main, value: "Read Success", comment: "Bluetooth peripheral screen. row title for the read success line")
    }()

    static let readSuccessLast24Hours: String = {
        return NSLocalizedString("readSuccessLast24Hours", tableName: filename, bundle: Bundle.main, value: "Last 24 Hours", comment: "Bluetooth peripheral Read Success screen. Section title for the hourly read success timeline")
    }()

    static let readSuccessNow: String = {
        return NSLocalizedString("readSuccessNow", tableName: filename, bundle: Bundle.main, value: "Now", comment: "Bluetooth peripheral Read Success screen. Timeline axis label for the current time")
    }()

    static func readSuccessReadingsReceived(actual: Int, expected: Int) -> String {
        return String(format: NSLocalizedString("readSuccessReadingsReceived", tableName: filename, bundle: Bundle.main, value: "%d of %d readings received", comment: "Bluetooth peripheral Read Success screen. Summary of received readings out of expected readings"), actual, expected)
    }

    static func readSuccessCadenceFooter(bluetoothPeripheralType: String) -> String {
        return String(format: NSLocalizedString("readSuccessCadenceFooter", tableName: filename, bundle: Bundle.main, value: "Expected readings are based on the observed transmitter cadence for %@.", comment: "Bluetooth peripheral Read Success screen. Footer explaining how expected readings are calculated. Placeholder is the transmitter type"), bluetoothPeripheralType)
    }

    static let readSuccessLegendGood: String = {
        return NSLocalizedString("readSuccessLegendGood", tableName: filename, bundle: Bundle.main, value: "Good", comment: "Bluetooth peripheral Read Success screen. Timeline legend label for good read success")
    }()

    static let readSuccessLegendLow: String = {
        return NSLocalizedString("readSuccessLegendLow", tableName: filename, bundle: Bundle.main, value: "Low", comment: "Bluetooth peripheral Read Success screen. Timeline legend label for reduced read success")
    }()

    static let readSuccessLegendPoor: String = {
        return NSLocalizedString("readSuccessLegendPoor", tableName: filename, bundle: Bundle.main, value: "Poor", comment: "Bluetooth peripheral Read Success screen. Timeline legend label for poor read success")
    }()

    static let readSuccessLegendNoData: String = {
        return NSLocalizedString("readSuccessLegendNoData", tableName: filename, bundle: Bundle.main, value: "No data", comment: "Bluetooth peripheral Read Success screen. Timeline legend label when no readings are expected or available")
    }()

    static let readSuccessNoReadingsExpected: String = {
        return NSLocalizedString("readSuccessNoReadingsExpected", tableName: filename, bundle: Bundle.main, value: "No readings expected", comment: "Bluetooth peripheral Read Success screen. Accessibility label for timeline hours with no expected readings")
    }()

    static func readSuccessTimelineAccessibility(success: Double, actual: Int, expected: Int) -> String {
        return String(format: NSLocalizedString("readSuccessTimelineAccessibility", tableName: filename, bundle: Bundle.main, value: "%0.1f percent, %d of %d readings", comment: "Bluetooth peripheral Read Success screen. Accessibility label for an hourly timeline bucket"), success, actual, expected)
    }
}
