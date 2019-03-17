import Foundation
import CoreBluetooth
import os

class CGMGNSEntryTransmitter:BluetoothTransmitter, BluetoothTransmitterDelegate, CGMTransmitter {
    
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
    
    /// for OS_log
    private let log = OSLog(subsystem: Constants.Log.subSystem, category: Constants.Log.categoryCGMGNSEntry)
    
    // actual device address
    private var actualDeviceAddress:String?
    
    // used in parsing packet
    private var timeStampLastBgReadingInMinutes:Int
    
    // possible reading errors, as per GNSEntry documentation
    let GNW_BAND_NFC_HW_ERROR = 0
    let GNW_BAND_NFC_READING_ERROR = 1
    
    // MARK: - functions
    
    /// - parameters:
    ///     - address: if already connected before, then give here the address that was received during previous connect, if not give nil
    init?(address:String?, delegate:CGMTransmitterDelegate, timeStampLastBgReading:Date) {
        
        // assign addressname and name or expected devicename
        var newAddressAndName:BluetoothTransmitter.DeviceAddressAndName = BluetoothTransmitter.DeviceAddressAndName.notYetConnected(expectedName: "GNSentry")
        if let address = address {
            newAddressAndName = BluetoothTransmitter.DeviceAddressAndName.alreadyConnectedBefore(address: address)
            actualDeviceAddress = address
        }
        
        //initialize timeStampLastBgReading
        self.timeStampLastBgReadingInMinutes = Int(timeStampLastBgReading.toMillisecondsAsDouble()/1000/60)
        
        // initialize - CBUUID_Receive_Authentication.rawValue and CBUUID_Write_Control.rawValue will probably not be used in the superclass, also not the CBUUID_Service
        super.init(addressAndName: newAddressAndName, CBUUID_Advertisement: nil, servicesCBUUIDs: [CBUUID(string: CBUUID_GNWService), CBUUID(string: CBUUID_BatteryService), CBUUID(string: CBUUID_DeviceInformationService)], CBUUID_ReceiveCharacteristic: CBUUID_Characteristic_UUID.CBUUID_GNW_Notify.rawValue, CBUUID_WriteCharacteristic: CBUUID_Characteristic_UUID.CBUUID_GNW_Write.rawValue)
        
        //assign CGMTransmitterDelegate
        cgmTransmitterDelegate = delegate
        
        bluetoothTransmitterDelegate = self
    }
    
    // MARK: BluetoothTransmitterDelegate functions
    
    func centralManagerDidConnect(address:String?, name:String?) {
        cgmTransmitterDelegate?.cgmTransmitterDidConnect(address: address, name: name)
    }
    
    func centralManagerDidFailToConnect(error: Error?) {
    }
    
    func centralManagerDidUpdateState(state: CBManagerState) {
        cgmTransmitterDelegate?.deviceDidUpdateBluetoothState(state: state)
    }
    
    func centralManagerDidDisconnectPeripheral(error: Error?) {
        cgmTransmitterDelegate?.cgmTransmitterDidDisconnect()
    }
    
    func peripheralDidUpdateNotificationStateFor(characteristic: CBCharacteristic, error: Error?) {
        os_log("in peripheralDidUpdateNotificationStateFor", log: log, type: .info)
    }
    
    func peripheralDidUpdateValueFor(characteristic: CBCharacteristic, error: Error?) {
        // log the receivec characteristic value
        os_log("in peripheralDidUpdateValueFor with characteristic %{public}@", log: log, type: .info, CBUUID_Characteristic_UUID(rawValue: characteristic.uuid.uuidString)?.description ?? "(not available)")
        
        if let error = error {
            os_log("error: %{public}@", log: log, type: .error , error.localizedDescription)
        }
        
        if let receivedCharacteristic = CBUUID_Characteristic_UUID(rawValue: characteristic.uuid.uuidString), let value = characteristic.value {
            
            // convert to hex string, GNS entry seems to use hex string in many cases
            let dataAsString = value.hexEncodedString()
            os_log("   received value : %{public}@", log: log, type: .info, dataAsString)
            
            switch receivedCharacteristic {
                
            case .CBUUID_SerialNumber:
                break
            case .CBUUID_Firmware:
                break
            case .CBUUID_Bootloader:
                break
            case .CBUUID_BatteryLevel:
                if let batteryLevel = Int(dataAsString, radix: 16) {
                    var emptyArray: [RawGlucoseData] = []
                    cgmTransmitterDelegate?.cgmTransmitterInfoReceived(glucoseData: &emptyArray, transmitterBatteryInfo: TransmitterBatteryInfo.percentage(percentage: batteryLevel), sensorState: nil, sensorTimeInMinutes: nil, firmware: nil, hardware: nil)
                } else {
                    os_log("   in peripheralDidUpdateValueFor, could not read batterylevel, received hex value = %{public}@", log: log, type: .error , dataAsString)
                }
            case .CBUUID_GNW_Write:
                break
            case .CBUUID_GNW_Notify:
                // decode as explained in GNSEntry documentation
                var arrayData = XORENC(inD: [UInt8](value))
                
                // reading status, as per GNSEntry documentation
                let readingStatus = getIntAtPosition(numberOfBytes: 1, position: 0, data: &arrayData)
                
                if readingStatus == GNW_BAND_NFC_HW_ERROR || readingStatus == GNW_BAND_NFC_READING_ERROR {
                    os_log("   in peripheralDidUpdateValueFor, readingStatus is not OK", log: log, type: .info)
                    // TODO: what to do here ?
                } else {
                    
                    // get sensor elapsed time and initialize sensorStartTimeInMilliseconds
                    let sensorElapsedTimeInMinutes = getIntAtPosition(numberOfBytes: 2, position: 3, data: &arrayData)
                    // we will add the most recent readings, but then we'll only add the readings that are at least 5 minutes apart (giving 10 seconds spare)
                    // for that variable timeStampLastAddedGlucoseData is used. It's initially set to now + 5 minutes
                    let currentTimeInMinutes:Int = Int(Date().toMillisecondsAsDouble()/1000/60)
                    var timeStampLastAddedGlucoseDataInMinutes:Int = currentTimeInMinutes + 5
                    
                    // read sensor status
                    let sensorStatus = SensorState(stateByte: UInt8(getIntAtPosition(numberOfBytes: 1, position: 5, data: &arrayData)))
                    
                    // initialize empty array of bgreadings
                    var readings:Array<RawGlucoseData> = []
                    
                    // amountofReadingsPerMinute = how many readings per minute - see example code GNSEntry, if only one packet of 20 bytes transmitted, then only 5 readings 1 minute seperated
                    var amountOfPerMinuteReadings = 5
                    var amountOfPer15MinuteReadings = 0
                    if arrayData.count > 20 {
                        amountOfPerMinuteReadings = 17
                        amountOfPer15MinuteReadings = 33
                    }
                    
                    // variable to loop through the readdings
                    var i = 0
                    
                    loop: while 7 + i * 2 < arrayData.count - 1 && i < amountOfPerMinuteReadings + amountOfPer15MinuteReadings {
                        // timestamp of the reading in minutes, counting from 1 1 1970
                        let readingTimeStampInMinutes = currentTimeInMinutes - (i < amountOfPerMinuteReadings ? i : i * 15)
                        
                        // get the reading value (mgdl)
                        let readingValueInMgDl = getIntAtPosition(numberOfBytes: 2, position: 7 + i * 2, data: &arrayData)
                        
                        //new reading should be at least 30 seconds younger than timeStampLastBgReadingStoredInDatabase
                        if readingTimeStampInMinutes > ((timeStampLastBgReadingInMinutes * 2) + 1)/2 {
                            
                            if readingTimeStampInMinutes * 60 * 1000 < timeStampLastAddedGlucoseDataInMinutes * 60 * 1000 - (5 * 60 * 1000 - 10000) {
                                let glucoseData = RawGlucoseData(timeStamp: Date(timeIntervalSince1970: Double(readingTimeStampInMinutes) * 60.0), glucoseLevelRaw: Double(readingValueInMgDl) * Constants.Libre.libreMultiplier)
                                readings.append(glucoseData)
                                timeStampLastAddedGlucoseDataInMinutes = readingTimeStampInMinutes
                            }
                        } else {
                            break loop
                        }
                        
                        // increase counter
                        i = i + 1
                    }
                    
                    cgmTransmitterDelegate?.cgmTransmitterInfoReceived(glucoseData: &readings, transmitterBatteryInfo: nil, sensorState: sensorStatus, sensorTimeInMinutes: Int(sensorElapsedTimeInMinutes), firmware: nil, hardware: nil)
                    
                    //set timeStampLastBgReading to timestamp of latest reading in the response so that next time we parse only the more recent readings
                    if readings.count > 0 {
                        timeStampLastBgReadingInMinutes = Int(readings[0].timeStamp.toMillisecondsAsDouble()/1000/60)
                    }
                }
            }
        }
    }
    
    // MARK: CBCentralManager overriden functions
    
    override func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        os_log("didDiscoverCharacteristicsFor", log: log, type: .info)
        
        // log error if any
        if let error = error {
            os_log("    error: %{public}@", log: log, type: .error , error.localizedDescription)
        }
        
        if let characteristics = service.characteristics {
            for characteristic in characteristics {
                let ASCIIstring = characteristic.uuid.uuidString
                os_log("characteristic uuid: %{public}@", log: log, type: .info, ASCIIstring)
                
                if CBUUID_Characteristic_UUID.CBUUID_BatteryLevel.rawValue.containsIgnoringCase(find: characteristic.uuid.uuidString) {
                    os_log("    found batteryLevelCharacteristic", log: log, type: .info)
                    batteryLevelCharacteristic = characteristic
                    peripheral.setNotifyValue(true, for: characteristic)
                } else if CBUUID_Characteristic_UUID.CBUUID_Bootloader.rawValue.containsIgnoringCase(find: characteristic.uuid.uuidString) {
                    os_log("    found bootLoaderCharacteristic", log: log, type: .info)
                    bootLoaderCharacteristic = characteristic
                } else if CBUUID_Characteristic_UUID.CBUUID_SerialNumber.rawValue.containsIgnoringCase(find: characteristic.uuid.uuidString) {
                    os_log("    found serialNumberCharacteristic", log: log, type: .info)
                    serialNumberCharacteristic = characteristic
                } else if CBUUID_Characteristic_UUID.CBUUID_Firmware.rawValue.containsIgnoringCase(find: characteristic.uuid.uuidString) {
                    os_log("    found firmwareCharacteristic", log: log, type: .info)
                    firmwareCharacteristic = characteristic
                } else if CBUUID_Characteristic_UUID.CBUUID_GNW_Write.rawValue.containsIgnoringCase(find: characteristic.uuid.uuidString) {
                    os_log("    found GNWWriteCharacteristic", log: log, type: .info)
                    GNWWriteCharacteristic = characteristic
                } else if CBUUID_Characteristic_UUID.CBUUID_GNW_Notify.rawValue.containsIgnoringCase(find: characteristic.uuid.uuidString) {
                    os_log("    found GNWNotifyCharacteristic", log: log, type: .info)
                    GNWNotifyCharacteristic = characteristic
                    peripheral.setNotifyValue(true, for: characteristic)
                } else  {
                    os_log("    characteristic UUID unknown", log: log, type: .error)
                }
                
            }
        } else {
            os_log("characteristics is nil. There must be some error.", log: log, type: .error)
        }
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



