import CoreBluetooth
import CoreNFC
import Foundation
import os

@objcMembers
class CGMLibre2Transmitter: Libre2BluetoothTransmitter, CGMTransmitter {
    override var isConnectionAllowed: Bool {
        super.isConnectionAllowed && Libre2ConnectionStore.shared.snapshot?.allowsPhone == true
    }

    // MARK: - properties
    
    /// will be used to pass back bluetooth and cgm related events
    private(set) weak var cgmTransmitterDelegate: CGMTransmitterDelegate?
    
    /// CGMLibre2TransmitterDelegate
    public weak var cGMLibre2TransmitterDelegate: CGMLibre2TransmitterDelegate?
    
    /// is nonFixed enabled for the transmitter or not
    private var nonFixedSlopeEnabled: Bool
    
    /// Phone preferences and native-algorithm configuration.
    private let phoneSensor: Libre2PhoneSensor
    
    /// current sensor serial number, if nil then it's not known yet
    var sensorSerialNumber: String? {
        get { phoneSensor.serialNumber }
        set { phoneSensor.serialNumber = newValue }
    }
    
    /// temp storage of libreSensorSerialNumber, value will be stored after NFC scanning, but possible there's no transmitter created yet (if this is a first scan for a new transmitter), so we can't store the serial number yet in coredata. As soon as transmitter is connected,  and if tempSensorSerialNumber is not nil, it will be sent to the delegate
    var tempSensorSerialNumber: LibreSensorSerialNumber?
    /// Retains the phone's provisioning session; accessed by the NFC extension.
    var libreNFC: LibreNFC?
    
    /// sensor type
    var libreSensorType: LibreSensorType?

    /// Bluetooth name selected from the NFC result. Newer 7F sensors advertise the returned
    /// MAC-derived name instead of the legacy "ABBOTT" + sensor serial number.
    var expectedBluetoothNameFromNFC: String?
    
    // MARK: - Initialization

    /// - parameters:
    ///     - address: if already connected before, then give here the address that was received during previous connect, if not give nil
    ///     - name : if already connected before, then give here the name that was received during previous connect, if not give nil
    ///     - bluetoothTransmitterDelegate : a bluetoothTransmitterDelegate
    ///     - cGMLibre2TransmitterDelegate : a CGMLibre2TransmitterDelegate
    ///     - sensorSerialNumber : optional, sensor serial number, should be set if already known from previous session
    ///     - cGMTransmitterDelegate : a CGMTransmitterDelegate
    ///     - webOOPEnabled : enabled or not, if nil then default false
    init(address: String?, name: String?, bluetoothTransmitterDelegate: BluetoothTransmitterDelegate, cGMLibre2TransmitterDelegate: CGMLibre2TransmitterDelegate, sensorSerialNumber: String?, cGMTransmitterDelegate: CGMTransmitterDelegate, nonFixedSlopeEnabled: Bool?, webOOPEnabled: Bool?) {
        // assign addressname and name or expected devicename
        // (actually this now isn't really necessary as for new devices, sensorSerialNumber will be nil and we'll update the superclass expectedName anyway after the NFC scan via the delegate)
        var newAddressAndName = BluetoothTransmitter.DeviceAddressAndName.notYetConnected(expectedName: "ABBOTT" + (sensorSerialNumber ?? ""))
        
        if let address = address {
            newAddressAndName = BluetoothTransmitter.DeviceAddressAndName.alreadyConnectedBefore(address: address, name: "ABBOTT" + (sensorSerialNumber ?? ""))
        }
        
        // initialize sensorSerialNumber
        phoneSensor = Libre2PhoneSensor(serialNumber: sensorSerialNumber, webOOPEnabled: webOOPEnabled ?? false)

        // assign CGMTransmitterDelegate
        cgmTransmitterDelegate = cGMTransmitterDelegate
        
        // assign cGMLibre2TransmitterDelegate
        self.cGMLibre2TransmitterDelegate = cGMLibre2TransmitterDelegate
        
        // initialize nonFixedSlopeEnabled
        self.nonFixedSlopeEnabled = nonFixedSlopeEnabled ?? false
        
        // A committed return must restore the durable Watch counter before the first BLE attempt.
        let selection = Libre2ConnectionStore.shared.snapshot
        if selection?.phase == .phone, let id = selection?.sessionID,
           let returned = try? Libre2WatchSession.load(from: Libre2ConnectionStore.shared.sessionURL),
           returned.id == id, returned.sensorUID == UserDefaults.standard.libreSensorUID {
            UserDefaults.standard.libreActiveSensorUnlockCount = max(UserDefaults.standard.libreActiveSensorUnlockCount, returned.unlockCount)
        }
        super.init(addressAndName: newAddressAndName, sensor: phoneSensor, bluetoothTransmitterDelegate: bluetoothTransmitterDelegate)
        Libre2PhoneConnection.shared.transmitter = self
    }
    
    // MARK: - overriden  BluetoothTransmitter functions
    
    override func startScanning() -> BluetoothTransmitter.startScanningResult {
        // For Libre 2, a user-requested scan starts with NFC because the NFC read enables
        // Bluetooth streaming and refreshes the unlock state before BLE reconnects.

        // create libreNFC instance and start session
        if NFCTagReaderSession.readingAvailable {
            // startScanning is getting called several times, but we must restrict launch of nfc scan to one single time, therefore check if libreNFC == nil
            if libreNFC == nil {
                // One explicit Libre Connect/Add request creates one NFC session. Log that user-level
                // milestone here, where the session is actually created, rather than in the repeated
                // Bluetooth scanning callbacks that can occur while iOS changes radio state.
                trace(
                    "starting Libre NFC sensor scan",
                    log: log,
                    category: ConstantsLog.categoryCGMLibre2,
                    type: .info,
                    troubleshooting: .standard(.cgm(source: .libre2, activity: .nfcScanStarted))
                )

                // NFC session creation must be on main thread
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    if Libre2PhoneConnection.shared.busy { Libre2PhoneConnection.shared.cancelTransfer() }
                    let libreNFC = LibreNFC(libreNFCDelegate: self)
                    self.libreNFC = libreNFC
                    libreNFC.startSession()
                }
            }

        } else {
            trace(
                "Libre NFC sensor scanning is unavailable on this device",
                log: log,
                category: ConstantsLog.categoryCGMLibre2,
                type: .error,
                troubleshooting: .standard(.cgm(source: .libre2, activity: .nfcUnavailable))
            )

            // delegate may touch UI/Core Data → ensure main thread
            DispatchQueue.main.async { [weak self] in
                self?.bluetoothTransmitterDelegate?.error(message: TextsLibreNFC.deviceMustSupportNFC)
            }
        }

        // start the NFC scan (not BLE scanning)
        return .nfcScanNeeded
    }

    /// Start BLE discovery after provisioning, without opening an NFC session.
    func startBLEScanning() {
        _ = super.startScanning()
    }

    override func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        super.centralManager(central, didConnect: peripheral)
        guard isConnectionAllowed else { return }
        
        if let sensorSerialNumber = tempSensorSerialNumber {
            // we need to send the sensorSerialNumber here. Possibly this is a new transmitter being scanned for, in which case the call to cGMLibre2TransmitterDelegate?.received(sensorSerialNumber: ..) in NFCTagReaderSessionDelegate functions wouldn't have stored the status in coredata, because it' doesn't find the transmitter, so let's store it again, at each connect, if not nil
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.cGMLibre2TransmitterDelegate?.received(serialNumber: sensorSerialNumber.serialNumber, from: self)
            }
            
            // set to nil so we don't send it again to the delegate when there's a new connect
            tempSensorSerialNumber = nil
            
            // Validate using the identity advertised by this sensor generation. Older Libre 2
            // sensors include their serial number in the Bluetooth name, while 7F sensors use
            // the MAC-derived name returned by the NFC enable-streaming command.
            if connectedDeviceMatchesScannedSensor(serialNumber: sensorSerialNumber) == false {
                DispatchQueue.main.async { [weak self] in
                    self?.bluetoothTransmitterDelegate?.error(message: TextsLibreNFC.connectedLibre2DoesNotMatchScannedLibre2)
                }
                
            } else {
                // user should be informed not to scan with the Libre app
                DispatchQueue.main.async { [weak self] in
                    self?.bluetoothTransmitterDelegate?.error(message: TextsLibreNFC.donotusethelibrelinkapp)
                }
            }
        }
    }

    override func prepareForRelease() {
        // Clear base CB delegates + unsubscribe common receiveCharacteristic synchronously on main
        super.prepareForRelease()
        // Libre2-specific transient state cleanup
        let tearDown = {
            self.tempSensorSerialNumber = nil
            self.libreNFC = nil
            self.libreSensorType = nil
            self.expectedBluetoothNameFromNFC = nil
        }
        if Thread.isMainThread {
            tearDown()
        } else {
            DispatchQueue.main.sync(execute: tearDown)
        }
    }

    // MARK: - helpers

    /// Returns nil when the connected peripheral cannot be validated. A missing identifier must
    /// not be reported as a wrong sensor because connection and payload authentication still
    /// provide their own checks.
    private func connectedDeviceMatchesScannedSensor(serialNumber: LibreSensorSerialNumber) -> Bool? {
        guard let deviceName = deviceName else { return nil }

        if libreSensorType?.usesMacAddressAsBluetoothName == true {
            guard let expectedBluetoothNameFromNFC = expectedBluetoothNameFromNFC else { return nil }

            return deviceName.caseInsensitiveCompare(expectedBluetoothNameFromNFC) == .orderedSame
        }

        // Preserve the legacy comparison: historically the first decoded serial character was
        // unreliable, so only the final nine characters were used to identify ABBOTT-named sensors.
        return serialNumber.serialNumber.suffix(9).uppercased() == deviceName.suffix(9).uppercased()
    }
    
    override func received(glucoseData: [GlucoseData], sensorTimeInMinutes: UInt16) {
        Libre2PhoneConnection.shared.received(glucoseData, from: self)
        var copy = glucoseData
        cgmTransmitterDelegate?.cgmTransmitterInfoReceived(glucoseData: &copy, transmitterBatteryInfo: nil, sensorAge: TimeInterval(minutes: Double(sensorTimeInMinutes)))
        cGMLibre2TransmitterDelegate?.received(sensorTimeInMinutes: Int(sensorTimeInMinutes), from: self)
    }

    func watchSession(id: UUID) throws -> Libre2WatchSession {
        guard let uid = UserDefaults.standard.libreSensorUID,
              let patchInfo = UserDefaults.standard.librePatchInfo,
              let serial = sensorSerialNumber, let name = deviceName,
              let parameters = UserDefaults.standard.libre1DerivedAlgorithmParameters,
              isWebOOPEnabled(), !UserDefaults.standard.suppressUnLockPayLoad else {
            throw Libre2ConnectionError("Libre Native Algorithm and unlock payload must be enabled for a provisioned sensor.")
        }
        let session = Libre2WatchSession(id: id, sensorUID: uid, patchInfo: patchInfo,
            serialNumber: serial, bluetoothName: name,
            unlockCode: UserDefaults.standard.libreActiveSensorUnlockCode,
            unlockCount: UserDefaults.standard.libreActiveSensorUnlockCount, algorithmParameters: parameters)
        try session.validate()
        return session
    }

    // MARK: - CGMTransmitter protocol functions
    
    func setNonFixedSlopeEnabled(enabled: Bool) {
        if nonFixedSlopeEnabled != enabled {
            nonFixedSlopeEnabled = enabled
        }
    }
    
    /// set webOOPEnabled value
    func setWebOOPEnabled(enabled: Bool) {
        if phoneSensor.webOOPEnabled != enabled {
            phoneSensor.webOOPEnabled = enabled
        }
    }
    
    func cgmTransmitterType() -> CGMTransmitterType {
        return .Libre2
    }
    
    func isWebOOPEnabled() -> Bool {
        return phoneSensor.webOOPEnabled
    }
    
    func isNonFixedSlopeEnabled() -> Bool {
        return nonFixedSlopeEnabled
    }
    
    func maxSensorAgeInDays() -> Double? {
        return libreSensorType?.maxSensorAgeInDays()
    }
    
    func getCBUUID_Service() -> String {
        return CBUUID_Service_Libre2
    }
    
    func getCBUUID_Receive() -> String {
        return CBUUID_ReceiveCharacteristic_Libre2
    }
}

// MARK: - LibreNFCDelegate functions

extension CGMLibre2Transmitter: LibreNFCDelegate {
    func received(fram: Data) {
        trace("received fram :  %{public}@", log: log, category: ConstantsLog.categoryCGMLibre2, type: .info, fram.hexEncodedString())

        // if we already know the patchinfo (which we should because normally received(sensorUID: Data, patchInfo: Data) gets called before received(fram: Data), then patchInfo should not be nil
        // same for sensorUID
        if let patchInfo = UserDefaults.standard.librePatchInfo, let sensorUID = UserDefaults.standard.libreSensorUID, let libreSensorType = LibreSensorType.type(patchInfo: patchInfo.hexEncodedString().uppercased()), let serialNumber = sensorSerialNumber {
            self.libreSensorType = libreSensorType

            var framCopy = fram

            if libreSensorType.decryptIfPossibleAndNeeded(rxBuffer: &framCopy, headerLength: 0, log: log, patchInfo: patchInfo.hexEncodedString().uppercased(), uid: Array(sensorUID)) {
                // we have all date to create libre1DerivedAlgorithmParameters
                UserDefaults.standard.libre1DerivedAlgorithmParameters = Libre1DerivedAlgorithmParameters(bytes: framCopy, serialNumber: serialNumber, libreSensorType: libreSensorType)
            }
        }
    }

    func received(sensorUID: Data, patchInfo: Data) {
        // store sensorUID as data in UserDefaults
        UserDefaults.standard.libreSensorUID = sensorUID

        // store the sensorUID as tempSensorSerialNumber (as LibreSensorSerialNumber)
        let receivedSensorSerialNumber = LibreSensorSerialNumber(withUID: sensorUID, with: LibreSensorType.type(patchInfo: patchInfo.hexEncodedString()))
        if let receivedSensorSerialNumber = receivedSensorSerialNumber {
            tempSensorSerialNumber = receivedSensorSerialNumber
        }

        // sensor serial number as String
        let receivedSensorSerialNumberAsString = receivedSensorSerialNumber?.serialNumber

        if let receivedSensorSerialNumberAsString = receivedSensorSerialNumberAsString {
            // is it a new value ?
            if sensorSerialNumber != receivedSensorSerialNumberAsString {
                trace("new sensor detected :  %{public}@", log: log, category: ConstantsLog.categoryCGMLibre2, type: .info, receivedSensorSerialNumberAsString)

                sensorSerialNumber = receivedSensorSerialNumberAsString

                // assign sensorStartDate, for this type of transmitter the sensorAge is passed in another call to cgmTransmitterDelegate
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    self.cgmTransmitterDelegate?.newSensorDetected(sensorStartDate: nil)
                    self.cGMLibre2TransmitterDelegate?.received(serialNumber: receivedSensorSerialNumberAsString, from: self)
                }
            }

        } else {
            trace("could not created sensor serial number from received sensorUID, sensorUID = %{public}@", log: log, category: ConstantsLog.categoryCGMLibre2, type: .info, sensorUID.hexEncodedString())
        }

        trace("patchInfo received :  %{public}@", log: log, category: ConstantsLog.categoryCGMLibre2, type: .info, patchInfo.hexEncodedString())

        UserDefaults.standard.librePatchInfo = patchInfo
    }

    func streamingEnabled(successful: Bool, unlockCode: UInt32) {
        if successful {
            trace("received streaming enabled message from NFC with result successful, setting unlockCount to 0", log: log, category: ConstantsLog.categoryCGMLibre2, type: .info)

            // A previous installation may have saved a different code. Adopt the one
            // that this NFC scan actually provisioned before BLE sends its next unlock.
            if Libre2ConnectionStore.shared.snapshot?.sessionID != nil || Libre2ConnectionStore.shared.snapshot == nil {
                // Serialize the experimental reset with transfer replies. Ordinary provisioning
                // keeps its original path and does not create experimental state or send messages.
                let reset = {
                    UserDefaults.standard.libreActiveSensorUnlockCode = unlockCode
                    UserDefaults.standard.libreActiveSensorUnlockCount = 0
                    Libre2PhoneConnection.shared.sensorProvisioned()
                }
                if Thread.isMainThread { reset() } else { DispatchQueue.main.sync(execute: reset) }
            } else {
                UserDefaults.standard.libreActiveSensorUnlockCode = unlockCode
                UserDefaults.standard.libreActiveSensorUnlockCount = 0
            }

        } else {
            trace("received streaming enabled message from NFC with result unsuccessful", log: log, category: ConstantsLog.categoryCGMLibre2, type: .info)
        }
    }

    func nfcScanResult(_ result: LibreNFCScanResult) {
        // Keep the Core NFC error and sensor payload in the developer trace. Only this closed result
        // crosses into the shareable Activity Log, so cancellation and timeout remain distinct from
        // an actual scan failure without exposing a sensor serial number or raw NFC response.
        let activity: TroubleshootingCGMActivity
        let developerResult: String
        switch result {
        case .succeeded:
            activity = .nfcScanSucceeded
            developerResult = "successful"
        case .failed:
            activity = .nfcScanFailed
            developerResult = "failed"
        case .cancelled:
            activity = .nfcScanCancelled
            developerResult = "cancelled"
        case .timedOut:
            activity = .nfcScanTimedOut
            developerResult = "timed out"
        }

        trace(
            "received NFC scan result from NFC with result %{public}@",
            log: log,
            category: ConstantsLog.categoryCGMLibre2,
            type: result == .succeeded ? .info : .error,
            troubleshooting: .standard(.cgm(source: .libre2, activity: activity)),
            developerResult
        )

        if result == .succeeded {
            // Avoid triggering the success observer more than once for the same scan.
            if !UserDefaults.standard.nfcScanSuccessful {
                UserDefaults.standard.nfcScanSuccessful = true
            }
        } else if !UserDefaults.standard.nfcScanFailed {
            // The current UI offers the same retry sheet for failure, cancellation and timeout. The
            // Activity Log has already retained the more accurate reason above.
            UserDefaults.standard.nfcScanFailed = true
        }
    }

    func nfcScanExpectedDevice(serialNumber: String, macAddress: String) {
        let expectedBluetoothName = libreSensorType?.usesMacAddressAsBluetoothName == true
            ? macAddress
            : "ABBOTT" + serialNumber

        expectedBluetoothNameFromNFC = expectedBluetoothName
        updateExpectedDeviceName(name: expectedBluetoothName)
    }
}
