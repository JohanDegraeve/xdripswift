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

    static let connectionMode = NSLocalizedString("dexcomConnectionMode", tableName: filename, bundle: .main, value: "Connection Mode", comment: "Title for the first Dexcom add-device step")
    static let primaryMode = NSLocalizedString("dexcomPrimaryMode", tableName: filename, bundle: .main, value: "Primary", comment: "Dexcom connection mode choice")
    static let coexistenceMode = NSLocalizedString("dexcomCoexistenceMode", tableName: filename, bundle: .main, value: "Coexistence", comment: "Dexcom connection mode choice")
    static let primaryModePickerOption = NSLocalizedString("dexcomPrimaryModePickerOption", tableName: filename, bundle: .main, value: "Primary Mode", comment: "Full title for the Dexcom primary connection mode")
    static let coexistenceModePickerOption = NSLocalizedString("dexcomCoexistenceModePickerOption", tableName: filename, bundle: .main, value: "Coexistence Mode", comment: "Full title for the Dexcom coexistence connection mode")
    static let dexcomConnectionModeSelectionExplanation = NSLocalizedString("dexcomConnectionModeSelectionExplanation", tableName: filename, bundle: .main, value: "Primary Mode connects this app directly and requires any other app that connects to the Dexcom device to be closed.\n\nCoexistence Mode relies on another app to maintain the Dexcom connection and receive readings.", comment: "Required explanation shown above the Dexcom connection mode picker")
    static let primaryModeAddFlowMessage = NSLocalizedString("dexcomPrimaryModeAddFlowMessage", tableName: filename, bundle: .main, value: "Connect directly as the main app. Close any other app that connects to this Dexcom device.", comment: "Explanation below the Primary choice")
    static let coexistenceModeAddFlowMessage = NSLocalizedString("dexcomCoexistenceModeAddFlowMessage", tableName: filename, bundle: .main, value: "Share the connection with another app. Keep the Dexcom or CamAPS app working correctly in the background.", comment: "Explanation below the Coexistence choice")
    static let dexcomG6ModeSelectionFooter = NSLocalizedString("dexcomG6ModeSelectionFooter", tableName: filename, bundle: .main, value: "You can change the connection mode later in the transmitter settings.", comment: "Footer below the G6 initial connection-mode choices")
    static let dexcomG7ModeSelectionFooter = NSLocalizedString("dexcomG7ModeSelectionFooter", tableName: filename, bundle: .main, value: "The selected connection mode cannot be changed later. Remove and add the sensor again to choose a different mode.", comment: "Footer below the G7 initial connection-mode choices")
    static let sensorCode = Texts_HomeView.sensorCode
    static let dexcomG7NoSensorLabelFound = NSLocalizedString("dexcomG7NoSensorLabelFound", tableName: filename, bundle: .main, value: "No Dexcom G7 sensor label was found in the photo.", comment: "No G7 Data Matrix found in selected photo")
    static let dexcomG7InvalidSensorLabelFound = NSLocalizedString("dexcomG7InvalidSensorLabelFound", tableName: filename, bundle: .main, value: "A Data Matrix was found, but it was not a valid Dexcom G7 sensor label.", comment: "Invalid G7 Data Matrix found in selected photo")
    
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

    static let batteryHistory = NSLocalizedString("batteryHistory", tableName: filename, bundle: .main, value: "Battery History", comment: "Title and row that open the saved battery history chart")
    static let batteryHistoryTransmitterID = NSLocalizedString("batteryHistoryTransmitterID", tableName: filename, bundle: .main, value: "Transmitter ID", comment: "Battery history row showing the Bluetooth device name")
    static let batteryHistoryNoData = NSLocalizedString("batteryHistoryNoData", tableName: filename, bundle: .main, value: "No battery history", comment: "Empty-state title before any genuine battery observation is saved")
    static let batteryHistoryBeginsAfterReading = NSLocalizedString("batteryHistoryBeginsAfterReading", tableName: filename, bundle: .main, value: "History begins after the next genuine battery reading.", comment: "Empty-state explanation for battery history")
    static let batteryHistoryRange = NSLocalizedString("batteryHistoryRange", tableName: filename, bundle: .main, value: "Range", comment: "Label for the battery history time-range selector")
    static let batteryHistoryRangeAccessibility = NSLocalizedString("batteryHistoryRangeAccessibility", tableName: filename, bundle: .main, value: "Battery history range", comment: "Accessibility label for the battery history time-range selector")
    static let batteryHistoryRangeExplanation = NSLocalizedString("batteryHistoryRangeExplanation", tableName: filename, bundle: .main, value: "Fixed ranges run from now back to the selected number of days. Gaps show periods without a reading.", comment: "Explanation below the battery history chart")

    static let versionCode: String = {
        return NSLocalizedString("versionCode", tableName: filename, bundle: Bundle.main, value: "Version Code", comment: "Dexcom G7 family firmware compatibility version code")
    }()

    static let voltageA: String = {
        return NSLocalizedString("voltageA", tableName: filename, bundle: Bundle.main, value: "Voltage A", comment: "Dexcom transmitter battery voltage A")
    }()

    static let voltageB: String = {
        return NSLocalizedString("voltageB", tableName: filename, bundle: Bundle.main, value: "Voltage B", comment: "Dexcom transmitter battery voltage B")
    }()

    static let waitingForData: String = {
        return NSLocalizedString("waitingForData", tableName: filename, bundle: Bundle.main, value: "Waiting for data...", comment: "Battery row before the first transmitter battery response")
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
    
    static let dexcomG6BluetoothSlot: String = {
        return NSLocalizedString("dexcomG6BluetoothSlot", tableName: filename, bundle: Bundle.main, value: "Bluetooth Channel", comment: "Dexcom G6 Bluetooth screen. Picker title for the authentication role/slot.")
    }()

    static let dexcomBluetoothChannelSelectionExplanation: String = {
        return NSLocalizedString("dexcomBluetoothChannelSelectionExplanation", tableName: filename, bundle: Bundle.main, value: "Choose the Bluetooth channel that this app will use. Select Mobile App unless you need to leave that channel available for another connection.", comment: "Required explanation shown above the Dexcom Bluetooth channel picker for every Dexcom model.")
    }()

    static let dexcomG6MobileAppSlot: String = {
        return NSLocalizedString("dexcomG6MobileAppSlot", tableName: filename, bundle: Bundle.main, value: "Slot 2: Mobile App (Default)", comment: "Dexcom G6 Bluetooth slot picker. Default mobile-app role.")
    }()

    static let dexcomG6MobileAppSlotShort: String = {
        return NSLocalizedString("dexcomG6MobileAppSlotShort", tableName: filename, bundle: Bundle.main, value: "Mobile App", comment: "Dexcom G6 Bluetooth screen. Compact detail value for the default mobile-app role.")
    }()

    static let dexcomG6MedicalDeviceSlot: String = {
        return NSLocalizedString("dexcomG6MedicalDeviceSlot", tableName: filename, bundle: Bundle.main, value: "Slot 1: Receiver or Pump", comment: "Dexcom G6 Bluetooth slot picker. Receiver-or-pump role.")
    }()

    static let dexcomG6MedicalDeviceSlotShort: String = {
        return NSLocalizedString("dexcomG6MedicalDeviceSlotShort", tableName: filename, bundle: Bundle.main, value: "Pump", comment: "Dexcom G6 Bluetooth screen. Compact detail value for the receiver or pump role.")
    }()

    static let dexcomG6AnubisSlot: String = {
        return NSLocalizedString("dexcomG6AnubisSlot", tableName: filename, bundle: Bundle.main, value: "Slot 3: Anubis Extra", comment: "Dexcom G6 Bluetooth slot picker. Extra slot implemented by Anubis transmitters.")
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

    static let dexcomG6CoexistenceModeFooter: String = {
        return NSLocalizedString("useOtherDexcomAppCoexistenceFooter", tableName: filename, bundle: Bundle.main, value: "Coexistence mode is selected. Another app such as Dexcom or CamAPS must keep running in the background.", comment: "Dexcom G6 Bluetooth screen. Footer explaining the selected coexistence mode.")
    }()

    static let dexcomG6PrimaryModeFooter: String = {
        return NSLocalizedString("useOtherDexcomAppPrimaryFooter", tableName: filename, bundle: Bundle.main, value: "Primary mode is selected. This app connects as the main app and controls the connection.", comment: "Dexcom G6 Bluetooth screen. Footer explaining the selected primary mode.")
    }()

    static let dexcomG7PairingCodeMessage: String = {
        return NSLocalizedString("dexcomG7PairingCodeMessage", tableName: filename, bundle: Bundle.main, value: "Enter the four-digit sensor pairing code from the current applicator. Primary mode cannot authenticate without this code.", comment: "Dexcom G7 bluetooth screen. Explanation for the native authentication pairing code.")
    }()

    static let dexcomG7BluetoothSlot: String = {
        return NSLocalizedString("dexcomG7BluetoothSlot", tableName: filename, bundle: Bundle.main, value: "Bluetooth Channel", comment: "Dexcom G7 Bluetooth screen. Picker title for the authentication role/slot.")
    }()

    static let dexcomG7MobileAppSlot: String = {
        return NSLocalizedString("dexcomG7MobileAppSlot", tableName: filename, bundle: Bundle.main, value: "Slot 2: Mobile App (Default)", comment: "Dexcom G7 Bluetooth slot picker. Default mobile-app role.")
    }()

    static let dexcomG7MobileAppSlotShort: String = {
        return NSLocalizedString("dexcomG7MobileAppSlotShort", tableName: filename, bundle: Bundle.main, value: "Mobile App", comment: "Dexcom G7 Bluetooth screen. Compact detail for the mobile-app role.")
    }()

    static let dexcomG7MedicalDeviceSlot: String = {
        return NSLocalizedString("dexcomG7MedicalDeviceSlot", tableName: filename, bundle: Bundle.main, value: "Slot 1: Receiver or Pump", comment: "Dexcom G7 Bluetooth slot picker. Receiver-or-pump role.")
    }()

    static let dexcomG7MedicalDeviceSlotShort: String = {
        return NSLocalizedString("dexcomG7MedicalDeviceSlotShort", tableName: filename, bundle: Bundle.main, value: "Pump", comment: "Dexcom G7 Bluetooth screen. Compact detail for the receiver-or-pump role.")
    }()

    static let dexcomG7SmartWatchSlot: String = {
        return NSLocalizedString("dexcomG7SmartWatchSlot", tableName: filename, bundle: Bundle.main, value: "Slot 3: Smart Watch", comment: "Dexcom G7 Bluetooth slot picker. Factory smart-watch role.")
    }()

    static let dexcomG7SmartWatchSlotShort: String = {
        return NSLocalizedString("dexcomG7SmartWatchSlotShort", tableName: filename, bundle: Bundle.main, value: "Smart Watch", comment: "Dexcom G7 Bluetooth screen. Compact detail for the smart-watch role.")
    }()

    static let dexcomG7MobileAppSlotFooter: String = {
        return NSLocalizedString("dexcomG7MobileAppSlotFooter", tableName: filename, bundle: Bundle.main, value: "The Mobile App channel (slot 2) is the default and is the currently validated native G7 connection.", comment: "Dexcom G7 Bluetooth screen. Footer for the default mobile-app channel.")
    }()

    static let dexcomG7MedicalDeviceSlotFooter: String = {
        return NSLocalizedString("dexcomG7MedicalDeviceSlotFooter", tableName: filename, bundle: Bundle.main, value: "The Receiver or Pump channel uses authentication slot 1.", comment: "Dexcom G7 Bluetooth screen. Footer for the receiver-or-pump channel.")
    }()

    static let dexcomG7SmartWatchSlotFooter: String = {
        return NSLocalizedString("dexcomG7SmartWatchSlotFooter", tableName: filename, bundle: Bundle.main, value: "The Smart Watch channel uses the factory authentication slot 3.", comment: "Dexcom G7 Bluetooth screen. Footer for the smart-watch channel.")
    }()
    
    static let dexcomG6CoexistenceModeSelectionMessage: String = {
        return String(format: NSLocalizedString("dexcomG6CoexistenceModeSelectionMessage", tableName: filename, bundle: Bundle.main, value: "Coexistence mode has been selected. Another app, such as Dexcom G6 or CamAPS, must connect to and authenticate with the G6 transmitter.\n\nKeep the other app running in the background or %@ will not receive readings.", comment: "Dexcom G6 Bluetooth screen. Message shown after selecting coexistence mode."), ConstantsHomeView.applicationName)
    }()

    static let dexcomG6PrimaryModeSelectionMessage: String = {
        return String(format: NSLocalizedString("dexcomG6PrimaryModeSelectionMessage", tableName: filename, bundle: Bundle.main, value: "Primary mode has been selected. %@ must be the only app connecting to and authenticating with the G6 transmitter.\n\nClose any other app that connects to the transmitter or disable its Bluetooth permission. Otherwise, %@ or the other app may not receive readings.", comment: "Dexcom G6 Bluetooth screen. Message shown after selecting primary mode."), ConstantsHomeView.applicationName, ConstantsHomeView.applicationName)
    }()
    
    static let nfcScanNeeded: String = {
        return NSLocalizedString("nfcScanNeeded", tableName: filename, bundle: Bundle.main, value: "NFC scan needed", comment: "text in status row, when waiting for a successful NFC scan before starting bluetooth scanning")
    }()
    
    static let nonFixedSlopeWarning: String = {
        return NSLocalizedString("nonFixedSlopeWarning", tableName: filename, bundle: Bundle.main, value: "Multi-point calibration is an advanced feature.\n\nPlease do not use this feature until you have read the calibration section of the online help and understand how it works.", comment: "text to inform the user that multi-point calibration is an advanced option and could be dangerous if used incorrectly")
    }()
    
    static let warmingUpUntil: String = {
        return NSLocalizedString("warmingUpUntil", tableName: filename, bundle: Bundle.main, value: "Warmup until", comment: "Compact sensor warm-up label followed by the localized completion time")
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
