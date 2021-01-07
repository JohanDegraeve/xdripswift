import Foundation
import os
import CoreBluetooth
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
    
    // receive buffer for Libre 2 packets
    private var rxBuffer:Data
    
    // how long to wait for next packet before resetting the rxBuffer
    private static let maxWaitForpacketInSeconds = 3.0

    /// is the transmitter oop web enabled or not
    private var webOOPEnabled: Bool
    
    // current sensor serial number, if nil then it's not known yet
    private var sensorSerialNumber:String?
    
    // define libreNFC as NSObject, otherwise check on iOS14 wouuld need to be added.
    // it will be casted to LibreNFC when needed
    private var libreNFC: NSObject?
    
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
            
            trace("sensorid =  %{public}@, patchinfo = %{public}@, unlockcode = %{public}@, unlockcount = %{public}@", log: log, category: ConstantsLog.categoryCGMLibre2, type: .info, libreSensorUID.toHexString(), librePatchInfo.toHexString(), UserDefaults.standard.libreActiveSensorUnlockCode.description, UserDefaults.standard.libreActiveSensorUnlockCount.description)
            
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
                // we should be able to read libreSensorUID via bluetooth
                if let libre1DerivedAlgorithmParameters = UserDefaults.standard.libre1DerivedAlgorithmParameters, libre1DerivedAlgorithmParameters.serialNumber != sensorSerialNumber {
                    
                    UserDefaults.standard.libre1DerivedAlgorithmParameters = nil
                    
                }
                
                // decrypt buffer and parse
                // if oop web not enabled, then don't pass libre1DerivedAlgorithmParameters
                var parsedBLEData = Libre2BLEUtilities.parseBLEData(Data(try Libre2BLEUtilities.decryptBLE(sensorUID: sensorUID, data: rxBuffer)), libre1DerivedAlgorithmParameters: isWebOOPEnabled() ? UserDefaults.standard.libre1DerivedAlgorithmParameters : nil)
                
                cgmTransmitterDelegate?.cgmTransmitterInfoReceived(glucoseData: &parsedBLEData.bleGlucose, transmitterBatteryInfo: nil, sensorTimeInMinutes: Int(parsedBLEData.sensorTimeInMinutes))
                
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
    
    func setWebOOPSite(oopWebSite: String) {/*not used*/}
    
    func setWebOOPToken(oopWebToken: String) {/*not used*/}
    
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
    
}

// MARK: - NFCTagReaderSessionDelegate functions

extension CGMLibre2Transmitter: LibreNFCDelegate {
    
    func received(fram: Data) {
        
        trace("received fram :  %{public}@", log: log, category: ConstantsLog.categoryCGMLibre2, type: .info, fram.toHexString())
        
        // first get sensor status and send to delegate
        if fram.count >= 5 {
            
            let sensorState = LibreSensorState(stateByte: fram[4])
            
            cGMLibre2TransmitterDelegate?.received(sensorStatus: sensorState, from: self)
            
        }
        
        // if we already know the patchinfo (which we should because normally received(patchInfo: Data gets called before received(fram: Data), then patchInfo should not be nil
        // same for sensorUID
        if let patchInfo =  UserDefaults.standard.librePatchInfo, let sensorUID = UserDefaults.standard.libreSensorUID, let libreSensorType = LibreSensorType.type(patchInfo: patchInfo.hexEncodedString().uppercased()), let serialNumber = self.sensorSerialNumber {
            
            var framCopy = fram
            
            if libreSensorType.decryptIfPossibleAndNeeded(rxBuffer: &framCopy, headerLength: 0, log: log, patchInfo: patchInfo.hexEncodedString().uppercased(), uid: sensorUID.bytes) {
                
                // we have all date to create libre1DerivedAlgorithmParameters
                UserDefaults.standard.libre1DerivedAlgorithmParameters = Libre1DerivedAlgorithmParameters(bytes: framCopy, serialNumber: serialNumber)
                
            }
            
        }
        
    }
    
    func received(sensorUID: Data) {
        
        // store sensorUID as data in UserDefaults
        UserDefaults.standard.libreSensorUID = sensorUID
        
        // check if it's a new sensor serial number and if yes send to delegate and store it
        // here it's the sensor serial number as String
        let receivedSensorSerialNumber = LibreSensorSerialNumber(withUID: sensorUID)?.serialNumber
        
        if let receivedSensorSerialNumber = receivedSensorSerialNumber {
          
            if sensorSerialNumber != receivedSensorSerialNumber {
                
                trace("new sensor detected :  %{public}@", log: log, category: ConstantsLog.categoryCGMLibre2, type: .info, receivedSensorSerialNumber)
                
                self.sensorSerialNumber = receivedSensorSerialNumber
                
                cgmTransmitterDelegate?.newSensorDetected()
                
                cGMLibre2TransmitterDelegate?.received(serialNumber: receivedSensorSerialNumber, from: self)
                
            }
            
        } else {
            
            trace("could not created sensor serial number from received sensorUID, sensorUID = %{public}@", log: log, category: ConstantsLog.categoryCGMLibre2, type: .info, sensorUID.toHexString())
            
        }
    }
    
    func received(patchInfo: Data) {
        
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
