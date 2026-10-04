import CoreBluetooth
import Foundation
import os

#if canImport(CoreNFC)
import CoreNFC

@objcMembers
class CGMLibre2Transmitter: BluetoothTransmitter, CGMTransmitter {
    // MARK: - properties
    
    /// service to be discovered
    private let CBUUID_Service_Libre2: String = "FDE3"
    
    /// receive characteristic
    private let CBUUID_ReceiveCharacteristic_Libre2: String = "F002"
    
    /// write characteristic
    private let CBUUID_WriteCharacteristic_Libre2: String = "F001"
    
    /// will be used to pass back bluetooth and cgm related events
    private(set) weak var cgmTransmitterDelegate: CGMTransmitterDelegate?
    
    /// CGMLibre2TransmitterDelegate
    public weak var cGMLibre2TransmitterDelegate: CGMLibre2TransmitterDelegate?
    
    /// is nonFixed enabled for the transmitter or not
    private var nonFixedSlopeEnabled: Bool
    
    /// for trace
    private let log = OSLog(subsystem: ConstantsLog.subSystem, category: ConstantsLog.categoryCGMLibre2)
    
    /// Reassembles complete Libre frames and clears each completed frame immediately.
    private var frameAssembler = Libre2FrameAssembler()

    /// A monotonic clock is used only to detect an incomplete frame assembly timeout.
    private let frameAssemblyClock = ContinuousClock()

    /// is the transmitter oop web enabled or not
    private var webOOPEnabled: Bool
    
    /// current sensor serial number, if nil then it's not known yet
    private var sensorSerialNumber: String?
    
    /// temp storage of libreSensorSerialNumber, value will be stored after NFC scanning, but possible there's no transmitter created yet (if this is a first scan for a new transmitter), so we can't store the serial number yet in coredata. As soon as transmitter is connected,  and if tempSensorSerialNumber is not nil, it will be sent to the delegate
    private var tempSensorSerialNumber: LibreSensorSerialNumber?
    
    // define libreNFC as NSObject, otherwise check on iOS14 wouuld need to be added.
    // it will be casted to LibreNFC when needed
    private var libreNFC: NSObject?
    
    /// sensor type
    private var libreSensorType: LibreSensorType?

    /// Bluetooth name selected from the NFC result. Newer 7F sensors advertise the returned
    /// MAC-derived name instead of the legacy "ABBOTT" + sensor serial number.
    private var expectedBluetoothNameFromNFC: String?
    
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
        self.sensorSerialNumber = sensorSerialNumber

        // assign CGMTransmitterDelegate
        cgmTransmitterDelegate = cGMTransmitterDelegate
        
        // assign cGMLibre2TransmitterDelegate
        self.cGMLibre2TransmitterDelegate = cGMLibre2TransmitterDelegate
        
        // initialize nonFixedSlopeEnabled
        self.nonFixedSlopeEnabled = nonFixedSlopeEnabled ?? false
        
        // initialize webOOPEnabled
        self.webOOPEnabled = webOOPEnabled ?? false

        super.init(addressAndName: newAddressAndName, CBUUID_Advertisement: nil, servicesCBUUIDs: [CBUUID(string: CBUUID_Service_Libre2)], CBUUID_ReceiveCharacteristic: CBUUID_ReceiveCharacteristic_Libre2, CBUUID_WriteCharacteristic: CBUUID_WriteCharacteristic_Libre2, bluetoothTransmitterDelegate: bluetoothTransmitterDelegate)
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

    override func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        super.centralManager(central, didConnect: peripheral)
        
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

    override func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        super.peripheral(peripheral, didUpdateValueFor: characteristic, error: error)
        
        // there should be already stored a value for libreSensorUID in the userdefaults at this moment, otherwise processing is not possible
        guard let libreSensorUID = UserDefaults.standard.libreSensorUID else {
            trace("in peripheral didUpdateValueFor but libreSensorUID is not known, no further processing", log: log, category: ConstantsLog.categoryCGMLibre2, type: .info)
            
            return
        }
        
        if let value = characteristic.value {
            processValue(value: value, sensorUID: libreSensorUID)
            
        } else {
            trace("in peripheral didUpdateValueFor, value is nil, no further processing", log: log, category: ConstantsLog.categoryCGMLibre2, type: .error)
        }
    }
    
    override func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        super.peripheral(peripheral, didDiscoverCharacteristicsFor: service, error: error)

        guard
            error == nil,
            service.characteristics?.contains(where: { $0.uuid == CBUUID(string: CBUUID_WriteCharacteristic_Libre2) }) == true,
            service.characteristics?.contains(where: { $0.uuid == CBUUID(string: CBUUID_ReceiveCharacteristic_Libre2) }) == true
        else { return }
        
        // there should be already stored a value for libreSensorUID in the userdefaults at this moment, otherwise processing is not possible
        guard let libreSensorUID = UserDefaults.standard.libreSensorUID else {
            trace("in peripheral didDiscoverCharacteristicsFor but libreSensorUID is not known, no further processing", log: log, category: ConstantsLog.categoryCGMLibre2, type: .info)
            
            return
        }
        
        // there should be already stored a value for librePatchInfo in the userdefaults at this moment, otherwise processing is not possible
        guard let librePatchInfo = UserDefaults.standard.librePatchInfo else {
            trace("in peripheral didDiscoverCharacteristicsFor but librePatchInfo is not known, no further processing", log: log, category: ConstantsLog.categoryCGMLibre2, type: .info)
            
            return
        }

        // the unlock algorithm reads 6 bytes directly, so invalid restored sensor metadata must be rejected before creating the payload
        guard libreSensorUID.count >= 6, librePatchInfo.count >= 6 else {
            trace("in peripheral didDiscoverCharacteristicsFor but the stored sensor metadata is incomplete, no further processing", log: log, category: ConstantsLog.categoryCGMLibre2, type: .error)

            return
        }

        UserDefaults.standard.libreActiveSensorUnlockCount += 1

        trace("sensorid as data =  %{public}@, patchinfo = %{public}@, unlockcode = %{public}@, unlockcount = %{public}@", log: log, category: ConstantsLog.categoryCGMLibre2, type: .info, libreSensorUID.hexEncodedString(), librePatchInfo.hexEncodedString(), UserDefaults.standard.libreActiveSensorUnlockCode.description, UserDefaults.standard.libreActiveSensorUnlockCount.description)
        
        let unLockPayLoad = Data(Libre2BLEUtilities.streamingUnlockPayload(sensorUID: libreSensorUID, info: librePatchInfo, enableTime: UserDefaults.standard.libreActiveSensorUnlockCode, unlockCount: UserDefaults.standard.libreActiveSensorUnlockCount))

        // Queue the unlock directly after the notification subscription. Waiting for CoreBluetooth's
        // notification-state callback can delay it long enough for Libre 2 to disconnect.
        trace("in peripheral didDiscoverCharacteristicsFor, writing streaming unlock payload: %{public}@", log: log, category: ConstantsLog.categoryCGMLibre2, type: .info, unLockPayLoad.hexEncodedString())
            
        // user may have chosen to run xDrip4iOS in parallel with other apps, in this case suppress sending unlockpayload
        if !UserDefaults.standard.suppressUnLockPayLoad {
            _ = writeDataToPeripheral(data: unLockPayLoad, type: .withResponse)
        }
    }
    
    override func prepareForRelease() {
        // Clear base CB delegates + unsubscribe common receiveCharacteristic synchronously on main
        super.prepareForRelease()
        // Libre2-specific transient state cleanup
        let tearDown = {
            self.frameAssembler.reset()
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
    
    /// process value received from transmitter
    public func processValue(value: Data, sensorUID: Data) {
        let arrival = frameAssemblyClock.now
        let frameArrivalDate = Date()
        let appendResult = frameAssembler.append(value, arrival: arrival)

        if let timedOutPartialFrame = appendResult.timedOutPartialFrame {
            trace(
                "Libre 2 partial frame timed out: discardedBytes=%{public}@, assemblyElapsedSeconds=%{public}@, newFragmentBytes=%{public}@",
                log: log,
                category: ConstantsLog.categoryCGMLibre2,
                type: .error,
                timedOutPartialFrame.discardedByteCount.description,
                formatted(timedOutPartialFrame.assemblyDuration),
                value.count.description
            )
        }

        switch appendResult.frameResult {
        case .incomplete:
            return

        case let .oversized(receivedByteCount):
            trace("in peripheral didUpdateValueFor, assembled Libre 2 frame contains %{public}@ bytes instead of 46, discarding it", log: log, category: ConstantsLog.categoryCGMLibre2, type: .error, receivedByteCount.description)

        case let .complete(encryptedFrame, assemblyDuration):
            processCompleteFrame(
                encryptedFrame,
                sensorUID: sensorUID,
                frameArrivalDate: frameArrivalDate,
                assemblyDuration: assemblyDuration
            )
        }
    }

    /// Decrypts a complete frame before parsing it with the time at which CoreBluetooth delivered
    /// the final fragment. The Libre sensor-minute counter is an age counter, not a wall clock, and
    /// its real cadence is not exactly 60 seconds. It must therefore never be compared with elapsed
    /// wall-clock time to decide whether an otherwise valid frame should be accepted.
    private func processCompleteFrame(
        _ encryptedFrame: Data,
        sensorUID: Data,
        frameArrivalDate: Date,
        assemblyDuration: TimeInterval
    ) {
        do {
            let decryptedFrame = Data(try Libre2BLEUtilities.decryptBLE(sensorUID: sensorUID, data: encryptedFrame))

            // Keep parser history and its downstream delegates on the main queue. Capturing the
            // arrival date above prevents a scheduling delay here from giving the frame a later
            // timestamp, without guessing its age from the sensor-minute counter.
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }

                self.processFrameOnMain(
                    decryptedFrame,
                    frameArrivalDate: frameArrivalDate,
                    assemblyDuration: assemblyDuration
                )
            }

            // TODO: add sensor start date -> userdefaults
        } catch {
            trace("in peripheral didUpdateValueFor, error while parsing/decrypting data = %{public}@", log: log, category: ConstantsLog.categoryCGMLibre2, type: .error, error.localizedDescription)
        }
    }

    private func processFrameOnMain(
        _ decryptedFrame: Data,
        frameArrivalDate: Date,
        assemblyDuration: TimeInterval
    ) {
        dispatchPrecondition(condition: .onQueue(.main))

        let libre1DerivedAlgorithmParameters: Libre1DerivedAlgorithmParameters?
        if isWebOOPEnabled() {
            guard let storedParameters = UserDefaults.standard.libre1DerivedAlgorithmParameters,
                  storedParameters.serialNumber == sensorSerialNumber else {
                trace("web oop enabled but libre1DerivedAlgorithmParameters is nil or libre1DerivedAlgorithmParameters.serialNumber != sensorSerialNumber, no further processing", log: log, category: ConstantsLog.categoryCGMLibre2, type: .info)
                return
            }
            libre1DerivedAlgorithmParameters = storedParameters
        } else {
            libre1DerivedAlgorithmParameters = nil
        }

        let parsedBLEData = Libre2BLEUtilities.parseBLEData(
            decryptedFrame,
            libre1DerivedAlgorithmParameters: libre1DerivedAlgorithmParameters,
            newestReadingDate: frameArrivalDate
        )

        Libre2BLEUtilities.commitRawValueHistory(from: parsedBLEData)

        trace(
            "accepted Libre 2 frame: sensorTime=%{public}@, generatedReadingCount=%{public}@, newestGeneratedTimestampSecondsSince1970=%{public}@, assemblySeconds=%{public}@, appInForeground=%{public}@",
            log: log,
            category: ConstantsLog.categoryCGMLibre2,
            type: .info,
            parsedBLEData.sensorTimeInMinutes.description,
            parsedBLEData.bleGlucose.count.description,
            formatted(parsedBLEData.bleGlucose.first?.timeStamp.timeIntervalSince1970),
            formatted(assemblyDuration),
            UserDefaults.standard.appInForeGround.description
        )

        var copy = parsedBLEData.bleGlucose
        cgmTransmitterDelegate?.cgmTransmitterInfoReceived(glucoseData: &copy, transmitterBatteryInfo: nil, sensorAge: TimeInterval(minutes: Double(parsedBLEData.sensorTimeInMinutes)))
        cGMLibre2TransmitterDelegate?.received(sensorTimeInMinutes: Int(parsedBLEData.sensorTimeInMinutes), from: self)
    }

    private func formatted(_ value: TimeInterval?) -> String {
        guard let value else { return "n/a" }
        return String(format: "%.3f", value)
    }

    // MARK: - CGMTransmitter protocol functions
    
    func setNonFixedSlopeEnabled(enabled: Bool) {
        if nonFixedSlopeEnabled != enabled {
            nonFixedSlopeEnabled = enabled
        }
    }
    
    /// set webOOPEnabled value
    func setWebOOPEnabled(enabled: Bool) {
        if webOOPEnabled != enabled {
            webOOPEnabled = enabled
        }
    }
    
    func cgmTransmitterType() -> CGMTransmitterType {
        return .Libre2
    }
    
    func isWebOOPEnabled() -> Bool {
        return webOOPEnabled
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

#else

@objcMembers
class CGMLibre2Transmitter: BluetoothTransmitter, CGMTransmitter {}

#endif

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
    
    func streamingEnabled(successful: Bool) {
        if successful {
            trace("received streaming enabled message from NFC with result successful, setting unlockCount to 0", log: log, category: ConstantsLog.categoryCGMLibre2, type: .info)
            
            UserDefaults.standard.libreActiveSensorUnlockCount = 0

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
    
    func startBLEScanning() {
        _ = super.startScanning()
    }
    
    func nfcScanExpectedDevice(serialNumber: String, macAddress: String) {
        let expectedBluetoothName = libreSensorType?.usesMacAddressAsBluetoothName == true
            ? macAddress
            : "ABBOTT" + serialNumber

        expectedBluetoothNameFromNFC = expectedBluetoothName
        updateExpectedDeviceName(name: expectedBluetoothName)
    }
}
