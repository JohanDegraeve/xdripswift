import Foundation
import CoreBluetooth
import os

@objcMembers
class CGMGNSEntryTransmitter: BluetoothTransmitter, CGMTransmitter {
    
    // MARK: - properties
    
    /// Device Information Service
    let CBUUID_DeviceInformationService = "0000180a-0000-1000-8000-00805f9b34fb"
    
    /// Battery Service
    let CBUUID_BatteryService = "0000180F-0000-1000-8000-00805f9b34fb"
    
    /// GNW Service
    let CBUUID_GNWService = "713D0000-503E-4C75-BA94-3148F18D941E"
    
    /// characteristic uuids (created them in an enum as there's a lot of them, it's easy to switch through the list)
    private enum CBUUID_Characteristic_UUID:String, CustomStringConvertible  {
        
        /// Serial Number Characteristic
        case CBUUID_SerialNumber = "00002a25-0000-1000-8000-00805f9b34fb"
        /// Firmware Characteristic
        case CBUUID_Firmware = "00002a28-0000-1000-8000-00805f9b34fb"
        /// Bootloader Characteristic
        case CBUUID_Bootloader = "00002a26-0000-1000-8000-00805f9b34fb"
        /// Battery level Characteristic
        case CBUUID_BatteryLevel = "00002A19-0000-1000-8000-00805f9b34fb"
        /// GNW Write
        case CBUUID_GNW_Write = "713D0003-503E-4C75-BA94-3148F18D941E"
        /// GNW NOtify
        case CBUUID_GNW_Notify = "713D0002-503E-4C75-BA94-3148F18D941E"
        
        var description: String {
            switch self {
            case .CBUUID_SerialNumber:
                return "CBUUID_SerialNumber"
            case .CBUUID_Firmware:
                return "CBUUID_Firmware"
            case .CBUUID_Bootloader:
                return "CBUUID_Bootloader"
            case .CBUUID_BatteryLevel:
                return "CBUUID_BatteryLevel"
            case .CBUUID_GNW_Write:
                return "CBUUID_GNW_Write"
            case .CBUUID_GNW_Notify:
                return "CBUUID_GNW_Notify"
            }
        }
    }
    
    // Stored Characteristics
    // serialNumberCharacteristic
    private var serialNumberCharacteristic:CBCharacteristic?
    // firmwareCharacteristic
    private var firmwareCharacteristic:CBCharacteristic?
    // bootLoaderCharacteristic
    private var bootLoaderCharacteristic:CBCharacteristic?
    // batteryLevelCharacteristic
    private var batteryLevelCharacteristic:CBCharacteristic?
    // GNWWriteCharacteristic
    private var GNWWriteCharacteristic:CBCharacteristic?
    // GNWNotifyCharacteristic
    private var GNWNotifyCharacteristic:CBCharacteristic?
    
    /// will be used to pass back bluetooth and cgm related events
    private(set) weak var cgmTransmitterDelegate:CGMTransmitterDelegate?
    
    /// CGMGNSEntryTransmitterDelegate
    public weak var cGMGNSEntryTransmitterDelegate: CGMGNSEntryTransmitterDelegate?
    
    /// is nonFixed enabled for the transmitter or not
    public var nonFixedSlopeEnabled: Bool

    /// for trace
    private let log = OSLog(subsystem: ConstantsLog.subSystem, category: ConstantsLog.categoryCGMGNSEntry)
    
    /// possible reading errors, as per GNSEntry documentation
    let GNW_BAND_NFC_HW_ERROR = 0
    let GNW_BAND_NFC_READING_ERROR = 1
    
    /// serial number received
    var actualSerialNumber:String?
    
    /// firmware version received
    var actualFirmWareVersion:String?
    
    /// bootloader received frm device
    var actualBootLoader:String?
    
    /// used as parameter in call to cgmTransmitterDelegate.cgmTransmitterInfoReceived, when there's no glucosedata to send
    var emptyArray: [GlucoseData] = []
    
    override func prepareForRelease() {
        // Clear base CB delegates + unsubscribe common receiveCharacteristic synchronously on main
        super.prepareForRelease()
        // GNS Entry-specific cleanup
        let tearDown = {
            self.serialNumberCharacteristic = nil
            self.firmwareCharacteristic = nil
            self.bootLoaderCharacteristic = nil
            self.batteryLevelCharacteristic = nil
            self.GNWWriteCharacteristic = nil
            self.GNWNotifyCharacteristic = nil
            self.actualSerialNumber = nil
            self.actualFirmWareVersion = nil
            self.actualBootLoader = nil
            self.emptyArray.removeAll()
        }
        if Thread.isMainThread {
            tearDown()
        } else {
            DispatchQueue.main.sync(execute: tearDown)
        }
    }

    deinit {
        // Defensive cleanup beyond base class
        serialNumberCharacteristic = nil
        firmwareCharacteristic = nil
        bootLoaderCharacteristic = nil
        batteryLevelCharacteristic = nil
        GNWWriteCharacteristic = nil
        GNWNotifyCharacteristic = nil
    }

    // MARK: - public functions
    
    /// - parameters:
    ///     - address: if already connected before, then give here the address that was received during previous connect, if not give nil
    ///     - name: if already connected before, then give here the name that was received during previous connect, if not give nil
    ///     - bluetoothTransmitterDelegate : a BluetoothTransmitterDelegate
    ///     - cGMTransmitterDelegate : a CGMTransmitterDelegate
    ///     - cGMGNSEntryTransmitterDelegate : a CGMGNSEntryTransmitterDelegate
    init(address:String?, name: String?, bluetoothTransmitterDelegate: BluetoothTransmitterDelegate, cGMGNSEntryTransmitterDelegate : CGMGNSEntryTransmitterDelegate, cGMTransmitterDelegate:CGMTransmitterDelegate, nonFixedSlopeEnabled: Bool?) {
        
        // assign addressname and name or expected devicename
        var newAddressAndName:BluetoothTransmitter.DeviceAddressAndName = BluetoothTransmitter.DeviceAddressAndName.notYetConnected(expectedName: "GNSentry")
        if let address = address {
            newAddressAndName = BluetoothTransmitter.DeviceAddressAndName.alreadyConnectedBefore(address: address, name: name)
        }
        
        // initialize nonFixedSlopeEnabled
        self.nonFixedSlopeEnabled = nonFixedSlopeEnabled ?? false
        
        // initialize
        super.init(addressAndName: newAddressAndName, CBUUID_Advertisement: nil, servicesCBUUIDs: [CBUUID(string: CBUUID_GNWService), CBUUID(string: CBUUID_BatteryService), CBUUID(string: CBUUID_DeviceInformationService)], CBUUID_ReceiveCharacteristic: CBUUID_Characteristic_UUID.CBUUID_GNW_Notify.rawValue, CBUUID_WriteCharacteristic: CBUUID_Characteristic_UUID.CBUUID_GNW_Write.rawValue, bluetoothTransmitterDelegate: bluetoothTransmitterDelegate)
        
        //assign CGMTransmitterDelegate
        self.cgmTransmitterDelegate = cGMTransmitterDelegate
        
        // assign cGMGNSEntryTransmitterDelegate
        self.cGMGNSEntryTransmitterDelegate = cGMGNSEntryTransmitterDelegate
        
        
    }
    
    // MARK: - overriden  BluetoothTransmitter functions
    
    override func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        
        super.peripheral(peripheral, didUpdateValueFor: characteristic, error: error)
        
        // log the received characteristic value
        trace("in peripheralDidUpdateValueFor with characteristic UUID = %{public}@, matches characteristic name %{public}@", log: log, category: ConstantsLog.categoryCGMGNSEntry, type: .info, characteristic.uuid.uuidString, receivedCharacteristicUUIDToCharacteristic(characteristicUUID: characteristic.uuid.uuidString)?.description ?? "not available")
        
        if let error = error {
            trace("   error: %{public}@", log: log, category: ConstantsLog.categoryCGMGNSEntry, type: .error , error.localizedDescription)
        }
        
        if let receivedCharacteristic = receivedCharacteristicUUIDToCharacteristic(characteristicUUID: characteristic.uuid.uuidString), let value = characteristic.value {
            
            switch receivedCharacteristic {
                
            case .CBUUID_SerialNumber:
                
                actualSerialNumber = String(data: value, encoding: String.Encoding.utf8)
                
                if let actualSerialNumber = actualSerialNumber {
                    DispatchQueue.main.async { [weak self] in
                        guard let self = self else { return }
                        self.cGMGNSEntryTransmitterDelegate?.received(serialNumber: actualSerialNumber, from: self)
                    }
                }

            case .CBUUID_Firmware:
                
                actualFirmWareVersion = String(data: value, encoding: String.Encoding.utf8)

                if let actualFirmWareVersion = actualFirmWareVersion {
                    DispatchQueue.main.async { [weak self] in
                        guard let self = self else { return }
                        self.cGMGNSEntryTransmitterDelegate?.received(firmwareVersion: actualFirmWareVersion, from: self)
                    }
                }
                
            case .CBUUID_Bootloader:
                
                actualBootLoader = String(data: value, encoding: String.Encoding.utf8)

                if let actualBootLoader = actualFirmWareVersion {
                    DispatchQueue.main.async { [weak self] in
                        guard let self = self else { return }
                        self.cGMGNSEntryTransmitterDelegate?.received(bootLoader: actualBootLoader, from: self)
                    }
                }
                
            case .CBUUID_BatteryLevel:
                
                let dataAsString = value.hexEncodedString()
                trace("   in peripheralDidUpdateValueFor, battery level received = %{public}@", log: log, category: ConstantsLog.categoryCGMGNSEntry, type: .info , dataAsString)
                
            case .CBUUID_GNW_Write:
                break
            case .CBUUID_GNW_Notify:
                // decode as explained in GNSEntry documentation
                var valueDecoded = XORENC(inD: [UInt8](value))
                
                // reading status, as per GNSEntry documentation
                let readingStatus = getIntAtPosition(numberOfBytes: 1, position: 0, data: &valueDecoded)
                
                if readingStatus == GNW_BAND_NFC_HW_ERROR || readingStatus == GNW_BAND_NFC_READING_ERROR {
                    trace("   in peripheralDidUpdateValueFor, readingStatus is not OK", log: log, category: ConstantsLog.categoryCGMGNSEntry, type: .error)
                    // TODO: what to do here ?
                } else {
                    
                    // get sensor elapsed time and initialize sensorStartTimeInMilliseconds
                    let sensorElapsedTimeInMinutes = getIntAtPosition(numberOfBytes: 2, position: 3, data: &valueDecoded)
                    // we will add the most recent readings, but then we'll only add the readings that are at least 5 minutes apart (giving 10 seconds spare)
                    // for that variable timeStampLastAddedGlucoseData is used. It's initially set to now + 5 minutes
                    let currentTimeInMinutes:Double = Date().toMillisecondsAsDouble()/1000/60
                    var timeStampLastAddedGlucoseDataInMinutes:Double = currentTimeInMinutes + 5.0
                    
                    // initialize empty array of bgreadings
                    var readings:Array<GlucoseData> = []
                    
                    // amountofReadingsPerMinute = how many readings per minute - see example code GNSEntry, if only one packet of 20 bytes transmitted, then only 5 readings 1 minute seperated
                    var amountOfPerMinuteReadings:Double = 5.0
                    var amountOfPer15MinuteReadings:Double = 0.0
                    if valueDecoded.count > 20 {
                        amountOfPerMinuteReadings = 17.0
                        amountOfPer15MinuteReadings = 33.0
                    }
                    
                    // variable to loop through the readdings
                    var i = 0.0
                    
                    loop: while Int(7.0 + i * 2.0) < valueDecoded.count - 1 && i < amountOfPerMinuteReadings + amountOfPer15MinuteReadings {
                        // timestamp of the reading in minutes, counting from 1 1 1970
                        let readingTimeStampInMinutes:Double = currentTimeInMinutes - (i < amountOfPerMinuteReadings ? i : i * 15.0)
                        
                        // get the reading value (mgdl)
                        let readingValueInMgDl = getIntAtPosition(numberOfBytes: 2, position: Int(7 + i * 2), data: &valueDecoded)
                        
                        // sometimes 0 values are received, skip those
                        if readingValueInMgDl > 0 {
                            if readingTimeStampInMinutes * 60 * 1000 < timeStampLastAddedGlucoseDataInMinutes * 60 * 1000 - (5 * 60 * 1000 - 10000) {
                                let glucoseData = GlucoseData(timeStamp: Date(timeIntervalSince1970: Double(readingTimeStampInMinutes) * 60.0), glucoseLevelRaw: Double(readingValueInMgDl) * ConstantsBloodGlucose.libreMultiplier)
                                readings.append(glucoseData)
                                timeStampLastAddedGlucoseDataInMinutes = readingTimeStampInMinutes
                            }
                        }
                        
                        // increase counter
                        i = i + 1
                    }
                    
                    DispatchQueue.main.async { [weak self] in
                        guard let self = self else { return }
                        var copy = readings
                        self.cgmTransmitterDelegate?.cgmTransmitterInfoReceived(glucoseData: &copy, transmitterBatteryInfo: nil, sensorAge: TimeInterval(minutes: Double(sensorElapsedTimeInMinutes)))
                    }
                    
                }
            }
        }
        
    }
    
    // MARK: - CGMTransmitter protocol functions
    
    func setNonFixedSlopeEnabled(enabled: Bool) {
        nonFixedSlopeEnabled = enabled
    }
    
    func cgmTransmitterType() -> CGMTransmitterType {
        return .GNSentry
    }
    
    func isNonFixedSlopeEnabled() -> Bool {
        return nonFixedSlopeEnabled
    }
    
    func getCBUUID_Service() -> String {
        return CBUUID_GNWService
    }
    
    func getCBUUID_Receive() -> String {
        return CBUUID_Characteristic_UUID.CBUUID_GNW_Notify.rawValue
    }

    // MARK: - CBCentralManager overriden functions
    
    override func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        trace("didDiscoverCharacteristicsFor", log: log, category: ConstantsLog.categoryCGMGNSEntry, type: .info)
        
        // log error if any
        if let error = error {
            trace("    error: %{public}@", log: log, category: ConstantsLog.categoryCGMGNSEntry, type: .error , error.localizedDescription)
        }
        
        if let characteristics = service.characteristics {
            for characteristic in characteristics {
                let ASCIIstring = characteristic.uuid.uuidString
                trace("characteristic uuid: %{public}@", log: log, category: ConstantsLog.categoryCGMGNSEntry, type: .info, ASCIIstring)
                
                if let receivedCharacteristic = receivedCharacteristicUUIDToCharacteristic(characteristicUUID: characteristic.uuid.uuidString) {
                    switch receivedCharacteristic {
                        
                    case .CBUUID_SerialNumber:
                        trace("    found serialNumberCharacteristic", log: log, category: ConstantsLog.categoryCGMGNSEntry, type: .info)
                        serialNumberCharacteristic = characteristic
                        if actualSerialNumber == nil {
                            peripheral.setNotifyValue(true, for: characteristic)
                            peripheral.readValue(for: characteristic)
                        }
                    case .CBUUID_Firmware:
                        trace("    found firmwareCharacteristic", log: log, category: ConstantsLog.categoryCGMGNSEntry, type: .info)
                        firmwareCharacteristic = characteristic
                        if actualFirmWareVersion == nil {
                            peripheral.setNotifyValue(true, for: characteristic)
                            peripheral.readValue(for: characteristic)
                        }
                    case .CBUUID_Bootloader:
                        trace("    found bootLoaderCharacteristic", log: log, category: ConstantsLog.categoryCGMGNSEntry, type: .info)
                        bootLoaderCharacteristic = characteristic
                        if actualBootLoader == nil {
                            peripheral.setNotifyValue(true, for: characteristic)
                            peripheral.readValue(for: characteristic)
                        }
                    case .CBUUID_BatteryLevel:
                        trace("    found batteryLevelCharacteristic", log: log, category: ConstantsLog.categoryCGMGNSEntry, type: .info)
                        batteryLevelCharacteristic = characteristic
                        peripheral.setNotifyValue(true, for: characteristic)
                        peripheral.readValue(for: characteristic)
                    case .CBUUID_GNW_Write:
                        trace("    found GNWWriteCharacteristic", log: log, category: ConstantsLog.categoryCGMGNSEntry, type: .info)
                        GNWWriteCharacteristic = characteristic
                    case .CBUUID_GNW_Notify:
                        trace("    found GNWNotifyCharacteristic", log: log, category: ConstantsLog.categoryCGMGNSEntry, type: .info)
                        GNWNotifyCharacteristic = characteristic
                        peripheral.setNotifyValue(true, for: characteristic)
                    }
                } else {
                    trace("    characteristic UUID unknown", log: log, category: ConstantsLog.categoryCGMGNSEntry, type: .error)
                }
            }
        } else {
            trace("characteristics is nil. There must be some error.", log: log, category: ConstantsLog.categoryCGMGNSEntry, type: .error)
        }
    }
    
    // MARK: - private helper functions
    
    /// creates CBUUID_Characteristic_UUID for the characteristicUUID
    private func receivedCharacteristicUUIDToCharacteristic(characteristicUUID:String) -> CBUUID_Characteristic_UUID? {
        if CBUUID_Characteristic_UUID.CBUUID_BatteryLevel.rawValue.containsIgnoringCase(find: characteristicUUID) {
            return CBUUID_Characteristic_UUID.CBUUID_BatteryLevel
        }
        if CBUUID_Characteristic_UUID.CBUUID_Firmware.rawValue.containsIgnoringCase(find: characteristicUUID) {
            return CBUUID_Characteristic_UUID.CBUUID_Firmware
        }
        if CBUUID_Characteristic_UUID.CBUUID_GNW_Write.rawValue.containsIgnoringCase(find: characteristicUUID) {
            return CBUUID_Characteristic_UUID.CBUUID_GNW_Write
        }
        if CBUUID_Characteristic_UUID.CBUUID_GNW_Notify.rawValue.containsIgnoringCase(find: characteristicUUID) {
            return CBUUID_Characteristic_UUID.CBUUID_GNW_Notify
        }
        if CBUUID_Characteristic_UUID.CBUUID_Bootloader.rawValue.containsIgnoringCase(find: characteristicUUID) {
            return CBUUID_Characteristic_UUID.CBUUID_Bootloader
        }
        if CBUUID_Characteristic_UUID.CBUUID_SerialNumber.rawValue.containsIgnoringCase(find: characteristicUUID) {
            return CBUUID_Characteristic_UUID.CBUUID_SerialNumber
        }
        return nil
    }
    
}

fileprivate func XORENC(inD: [UInt8]) -> [UInt8] {
    
    let asciiKeyArray = "zXqlKHYsmFEmGidsltkGS2dWaNEL7GJIlwgz5C163jy7BoaagaEuOwbQ4uf0OxP7g2A4dn0vbnKS6GsiPiadzarZQJ7sVtPnUMW2X6WD".unicodeScalars.filter{$0.isASCII}.map{$0.value}
    
    
    var byteKey: [UInt8] = []
    for character in asciiKeyArray {
        byteKey.append(UInt8(character) & UInt8(0xFF))
    }
    
    var output: [UInt8] = []
    var x: Int = 0
    for byte in inD {
        var currVal = Int(byte) & 0x000000FF
        var i: Int = 0
        for bKey in byteKey {
            let temp = (Int(currVal)^Int(bKey))^(x * i)
            currVal = temp
            i = i + 1
        }
        output.append(UInt8(currVal & 0x000000FF))
        x = x + 1
    }
    return output
}

fileprivate func getIntAtPosition(numberOfBytes: Int, position:Int, data:inout [UInt8]) -> Int {
    var stringBytes = ""
    for i in position...position + numberOfBytes - 1 {
        let index = i
        let value = data[index]
        stringBytes += value < 16 ? "0" + String(data[index], radix: 16) : String(value, radix: 16)
    }
    return Int(stringBytes, radix: 16)!
}



