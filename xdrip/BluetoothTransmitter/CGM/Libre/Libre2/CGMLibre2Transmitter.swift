import Foundation
import os
import CoreBluetooth

#if canImport(CoreNFC)
import CoreNFC

class CGMLibre2Transmitter:BluetoothTransmitter, CGMTransmitter {
    
    // MARK: - properties
    
    /// service to be discovered
    private let CBUUID_Service_Libre2: String = "FDE3"
    
    /// receive characteristic
    private let CBUUID_ReceiveCharacteristic_Libre2: String = "F002"
    
    /// write characteristic
    private let CBUUID_WriteCharacteristic_Libre2: String = "F001"
    
    /// how many bytes should we receive from Libre 2
    private let expectedBufferSize = 46
    
    /// will be used to pass back bluetooth and cgm related events
    private(set) weak var cgmTransmitterDelegate: CGMTransmitterDelegate?
    
    /// CGMLibre2TransmitterDelegate
    public weak var cGMLibre2TransmitterDelegate: CGMLibre2TransmitterDelegate?
    
    /// is nonFixed enabled for the transmitter or not
    private var nonFixedSlopeEnabled: Bool
    
    /// for trace
    private let log = OSLog(subsystem: ConstantsLog.subSystem, category: ConstantsLog.categoryCGMLibre2)
    
    /// used as parameter in call to cgmTransmitterDelegate.cgmTransmitterInfoReceived, when there's no glucosedata to send
    private var emptyArray: [GlucoseData] = []

    /// used when processing Libre 2 data packet
    private var startDate:Date
    
    /// receive buffer for Libre 2 packets
    private var rxBuffer:Data
    
    /// how long to wait for next packet before resetting the rxBuffer
    private static let maxWaitForpacketInSeconds = 3.0

    /// is the transmitter oop web enabled or not
    private var webOOPEnabled: Bool
    
    /// current sensor serial number, if nil then it's not known yet
    private var sensorSerialNumber:String?
    
    /// temp storage of libreSensorSerialNumber, value will be stored after NFC scanning, but possible there's no transmitter created yet (if this is a first scan for a new transmitter), so we can't store the serial number yet in coredata. As soon as transmitter is connected,  and if tempSensorSerialNumber is not nil, it will be sent to the delegate
    private var tempSensorSerialNumber: LibreSensorSerialNumber?
    
    // define libreNFC as NSObject, otherwise check on iOS14 wouuld need to be added.
    // it will be casted to LibreNFC when needed
    private var libreNFC: NSObject?
    
    /// sensor type
    private var libreSensorType: LibreSensorType?
    
    // MARK: - Initialization
    /// - parameters:
    ///     - address: if already connected before, then give here the address that was received during previous connect, if not give nil
    ///     - name : if already connected before, then give here the name that was received during previous connect, if not give nil
    ///     - bluetoothTransmitterDelegate : a bluetoothTransmitterDelegate
    ///     - cGMLibre2TransmitterDelegate : a CGMLibre2TransmitterDelegate
    ///     - sensorSerialNumber : optional, sensor serial number, should be set if already known from previous session
    ///     - cGMTransmitterDelegate : a CGMTransmitterDelegate
    ///     - webOOPEnabled : enabled or not, if nil then default false
    init(address:String?, name: String?, bluetoothTransmitterDelegate: BluetoothTransmitterDelegate, cGMLibre2TransmitterDelegate : CGMLibre2TransmitterDelegate, sensorSerialNumber:String?, cGMTransmitterDelegate:CGMTransmitterDelegate, nonFixedSlopeEnabled: Bool?, webOOPEnabled: Bool?) {
        
        // assign addressname and name or expected devicename
        var newAddressAndName:BluetoothTransmitter.DeviceAddressAndName = BluetoothTransmitter.DeviceAddressAndName.notYetConnected(expectedName: "abbott")
        if let address = address {
            newAddressAndName = BluetoothTransmitter.DeviceAddressAndName.alreadyConnectedBefore(address: address, name: name)
        }
        
        // initialize sensorSerialNumber
        self.sensorSerialNumber = sensorSerialNumber

        // assign CGMTransmitterDelegate
        self.cgmTransmitterDelegate = cGMTransmitterDelegate
        
        // assign cGMLibre2TransmitterDelegate
        self.cGMLibre2TransmitterDelegate = cGMLibre2TransmitterDelegate
        
        // initialize nonFixedSlopeEnabled
        self.nonFixedSlopeEnabled = nonFixedSlopeEnabled ?? false
        
        // initialize rxbuffer
        rxBuffer = Data()
        
        // initialize startDate
        startDate = Date()
        
        // initialize webOOPEnabled
        self.webOOPEnabled = webOOPEnabled ?? false

        super.init(addressAndName: newAddressAndName, CBUUID_Advertisement: nil, servicesCBUUIDs: [CBUUID(string: CBUUID_Service_Libre2)], CBUUID_ReceiveCharacteristic: CBUUID_ReceiveCharacteristic_Libre2, CBUUID_WriteCharacteristic: CBUUID_WriteCharacteristic_Libre2, bluetoothTransmitterDelegate: bluetoothTransmitterDelegate)
        
    }
    
    // MARK: - overriden  BluetoothTransmitter functions
    
    override func startScanning() -> BluetoothTransmitter.startScanningResult {
        
        // overriding startScanning, because it's the time to trigger NFC Scan
        // when user clicks the scan button, an NFC read is initiated which will enable the bluetooth streaming
        // meanwhile, the real scanning can start
        
        // create libreNFC instance and start session
        if #available(iOS 14.0, *) {
            
            if NFCTagReaderSession.readingAvailable {

                // startScanning is getting called several times, but we must restrict launch of nfc scan to one single time, therefore check if libreNFC == nil
                if libreNFC == nil {
                    
                    libreNFC = LibreNFC(libreNFCDelegate: self)
                    
                    (libreNFC as! LibreNFC).startSession()
                    
                }

            } else {
                
                bluetoothTransmitterDelegate?.error(message: TextsLibreNFC.deviceMustSupportNFC)
                
            }
            
            
        } else {
            
            bluetoothTransmitterDelegate?.error(message: TextsLibreNFC.deviceMustSupportIOS14)
            
        }
        
        // start the bluetooth scanning
        return super.startScanning()

    }
    
    override func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        
        super.centralManager(central, didConnect: peripheral)
        
        if let sensorSerialNumber = tempSensorSerialNumber {
            
            // we need to send the sensorSerialNumber here. Possibly this is a new transmitter being scanned for, in which case the call to cGMLibre2TransmitterDelegate?.received(sensorSerialNumber: ..) in NFCTagReaderSessionDelegate functions wouldn't have stored the status in coredata, because it' doesn't find the transmitter, so let's store it again, at each connect, if not nil
            cGMLibre2TransmitterDelegate?.received(serialNumber: sensorSerialNumber.serialNumber, from: self)
            
            // set to nil so we don't send it again to the delegate when there's a new connect
            tempSensorSerialNumber = nil
            
            // for Libre 2, the device name includes the sensor id
            // if tempSensorSerialNumber != deviceName, then it means the user has connected to another (older?) Libre 2 with bluetooth than the one for which NFC scan was done, in that case, inform user
            // compare only the last 10 characters. Normally it should be 10, but for some reason, xDrip4iOS does not correctly decode the sensor uid, the first character is not correct
            if let deviceName = deviceName, sensorSerialNumber.serialNumber.suffix(9).uppercased() != deviceName.suffix(9) {
                
                bluetoothTransmitterDelegate?.error(message: TextsLibreNFC.connectedLibre2DoesNotMatchScannedLibre2)
                
            } else {

                // user should be informed not to scan with the Libre app
                bluetoothTransmitterDelegate?.error(message: TextsLibreNFC.donotusethelibrelinkapp)

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
            
        // logging libreSensorUID and libre1DerivedAlgorithmParameters just in case it's needed for debugging purposes
        var libre1DerivedAlgorithmParametersAsString: String!
        if let libre1DerivedAlgorithmParameters = UserDefaults.standard.libre1DerivedAlgorithmParameters {
            libre1DerivedAlgorithmParametersAsString = libre1DerivedAlgorithmParameters.description
        } else {
            libre1DerivedAlgorithmParametersAsString = "unknown"
        }
        
        trace("in peripheral didUpdateValueFor libreSensorUID = %{public}@, libre1DerivedAlgorithmParameters = %{public}@", log: log, category: ConstantsLog.categoryCGMLibre2, type: .info, libreSensorUID.toHexString(), libre1DerivedAlgorithmParametersAsString)

        
        if let value = characteristic.value {
            
            processValue(value: value, sensorUID: libreSensorUID)
            
        } else {
            trace("in peripheral didUpdateValueFor, value is nil, no further processing", log: log, category: ConstantsLog.categoryCGMLibre2, type: .error)
        }
        
    }
    
    override func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        
        super.peripheral(peripheral, didUpdateNotificationStateFor: characteristic, error: error)
        
        // there should be already stored a value for libreSensorUID in the userdefaults at this moment, otherwise processing is not possible
        guard let libreSensorUID = UserDefaults.standard.libreSensorUID else {
            
            trace("in peripheral didUpdateNotificationStateFor but libreSensorUID is not known, no further processing", log: log, category: ConstantsLog.categoryCGMLibre2, type: .info)
            
            return
            
        }
        
        // there should be already stored a value for librePatchInfo in the userdefaults at this moment, otherwise processing is not possible
        guard let librePatchInfo = UserDefaults.standard.librePatchInfo else {
            
            trace("in peripheral didUpdateNotificationStateFor but librePatchInfo is not known, no further processing", log: log, category: ConstantsLog.categoryCGMLibre2, type: .info)
            
            return
            
        }
        
        if error == nil && characteristic.isNotifying {
            
            UserDefaults.standard.libreActiveSensorUnlockCount += 1
            
            trace("sensorid as data =  %{public}@, patchinfo = %{public}@, unlockcode = %{public}@, unlockcount = %{public}@", log: log, category: ConstantsLog.categoryCGMLibre2, type: .info, libreSensorUID.toHexString(), librePatchInfo.toHexString(), UserDefaults.standard.libreActiveSensorUnlockCode.description, UserDefaults.standard.libreActiveSensorUnlockCount.description)
            
            let unLockPayLoad = Data(Libre2BLEUtilities.streamingUnlockPayload(sensorUID: libreSensorUID, info: librePatchInfo, enableTime: UserDefaults.standard.libreActiveSensorUnlockCode, unlockCount: UserDefaults.standard.libreActiveSensorUnlockCount))
            
            trace("in peripheral didUpdateNotificationStateFor, writing streaming unlock payload: %{public}@", log: log, category: ConstantsLog.categoryCGMLibre2, type: .info, unLockPayLoad.toHexString())
            
            _ = writeDataToPeripheral(data: unLockPayLoad, type: .withResponse)

        }
        
    }
    
    // MARK: - helpers
    
    /// reset rxBuffer, reset startDate, stop packetRxMonitorTimer, set resendPacketCounter to 0
    private func resetRxBuffer() {
        rxBuffer = Data()
        startDate = Date()
    }
    
    /// process value received from transmitter
    public func processValue(value: Data, sensorUID: Data) {
        
        //check if buffer needs to be reset
        if (Date() > startDate.addingTimeInterval(CGMLibre2Transmitter.maxWaitForpacketInSeconds)) {
            
            trace("in peripheral didUpdateValueFor, more than %{public}@ seconds since last update - or first update since app launch, resetting buffer", log: log, category: ConstantsLog.categoryCGMLibre2, type: .info, CGMLibre2Transmitter.maxWaitForpacketInSeconds.description)
            
            resetRxBuffer()
            
        }
        
        // add new value to rxBuffer
        rxBuffer.append(value)
        
        // check if enough bytes are received, and if yes start processing
        if rxBuffer.count == expectedBufferSize {
            
            do {
                
                // if libre1DerivedAlgorithmParameters not nil, but not matching serial number, then assign to nil (copied from LibreDataParser)
                // if weboopenabled, then don't proceed, because weboop needs libre1DerivedAlgorithmParameters
                // if libre1DerivedAlgorithmParameters is nil, but not weboopenabled, then also no further processing
                // this may happen in case the serialNumber is not correctly read from NFC or stored in coredata - if all goes well this shouldn't occur
                if isWebOOPEnabled() {

                    guard let libre1DerivedAlgorithmParameters = UserDefaults.standard.libre1DerivedAlgorithmParameters, libre1DerivedAlgorithmParameters.serialNumber == sensorSerialNumber else {

                        trace("web oop enabled but libre1DerivedAlgorithmParameters is nil or libre1DerivedAlgorithmParameters.serialNumber != sensorSerialNumber, no further processing", log: log, category: ConstantsLog.categoryCGMLibre2, type: .info)
                        
                        return

                    }
                    
                }
                
                // decrypt buffer and parse
                // if oop web not enabled, then don't pass libre1DerivedAlgorithmParameters
                var parsedBLEData = Libre2BLEUtilities.parseBLEData(Data(try Libre2BLEUtilities.decryptBLE(sensorUID: sensorUID, data: rxBuffer)), libre1DerivedAlgorithmParameters: isWebOOPEnabled() ? UserDefaults.standard.libre1DerivedAlgorithmParameters : nil)
                
                // send glucoseData and sensorTimeInMinutes to cgmTransmitterDelegate
                cgmTransmitterDelegate?.cgmTransmitterInfoReceived(glucoseData: &parsedBLEData.bleGlucose, transmitterBatteryInfo: nil, sensorTimeInMinutes: Int(parsedBLEData.sensorTimeInMinutes))
                
                // send sensorTimeInMinutes also to cGMLibre2TransmitterDelegate
                cGMLibre2TransmitterDelegate?.received(sensorTimeInMinutes: Int(parsedBLEData.sensorTimeInMinutes), from: self)
                
            } catch {
                
                trace("in peripheral didUpdateValueFor, error while parsing/decrypting data =  %{public}@ ", log: log, category: ConstantsLog.categoryCGMLibre2, type: .info, error.localizedDescription)
                
                resetRxBuffer()
                
            }
            
        }
        
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
    
    func requestNewReading() {
        // not supported for Libre 2
    }
    
    func maxSensorAgeInDays() -> Int? {
        
        return libreSensorType?.maxSensorAgeInDays()
        
    }
    
}

#else

class CGMLibre2Transmitter:BluetoothTransmitter, CGMTransmitter {
    
}

#endif


// MARK: - LibreNFCDelegate functions

extension CGMLibre2Transmitter: LibreNFCDelegate {
    
    func received(fram: Data) {
        
        trace("received fram :  %{public}@", log: log, category: ConstantsLog.categoryCGMLibre2, type: .info, fram.toHexString())
        
        // if we already know the patchinfo (which we should because normally received(sensorUID: Data, patchInfo: Data) gets called before received(fram: Data), then patchInfo should not be nil
        // same for sensorUID
        if let patchInfo =  UserDefaults.standard.librePatchInfo, let sensorUID = UserDefaults.standard.libreSensorUID, let libreSensorType = LibreSensorType.type(patchInfo: patchInfo.hexEncodedString().uppercased()), let serialNumber = self.sensorSerialNumber {
            
            self.libreSensorType = libreSensorType
            
            var framCopy = fram
            
            if libreSensorType.decryptIfPossibleAndNeeded(rxBuffer: &framCopy, headerLength: 0, log: log, patchInfo: patchInfo.hexEncodedString().uppercased(), uid: sensorUID.bytes) {
                
                // we have all date to create libre1DerivedAlgorithmParameters
                UserDefaults.standard.libre1DerivedAlgorithmParameters = Libre1DerivedAlgorithmParameters(bytes: framCopy, serialNumber: serialNumber)
                
            }
            
        }
        
    }
    
    func received(sensorUID: Data, patchInfo: Data) {
        
        // store sensorUID as data in UserDefaults
        UserDefaults.standard.libreSensorUID = sensorUID
        
        // store the sensorUID as tempSensorSerialNumber (as LibreSensorSerialNumber)
        let receivedSensorSerialNumber = LibreSensorSerialNumber(withUID: sensorUID, with: LibreSensorType.type(patchInfo: patchInfo.toHexString()))
        if let receivedSensorSerialNumber = receivedSensorSerialNumber {
            self.tempSensorSerialNumber = receivedSensorSerialNumber
        }
        
        // sensor serial number as String
        let receivedSensorSerialNumberAsString = receivedSensorSerialNumber?.serialNumber
        
        if let receivedSensorSerialNumberAsString = receivedSensorSerialNumberAsString {
          
            // is it a new value ?
            if sensorSerialNumber != receivedSensorSerialNumberAsString {
                
                trace("new sensor detected :  %{public}@", log: log, category: ConstantsLog.categoryCGMLibre2, type: .info, receivedSensorSerialNumberAsString)
                
                self.sensorSerialNumber = receivedSensorSerialNumberAsString
                
                cgmTransmitterDelegate?.newSensorDetected()
                
                cGMLibre2TransmitterDelegate?.received(serialNumber: receivedSensorSerialNumberAsString, from: self)

            }
            
        } else {
            
            trace("could not created sensor serial number from received sensorUID, sensorUID = %{public}@", log: log, category: ConstantsLog.categoryCGMLibre2, type: .info, sensorUID.toHexString())
            
        }
        
        trace("patchInfo received :  %{public}@", log: log, category: ConstantsLog.categoryCGMLibre2, type: .info, patchInfo.toHexString())
        
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
    
}
