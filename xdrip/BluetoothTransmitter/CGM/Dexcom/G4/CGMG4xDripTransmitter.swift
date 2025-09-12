import Foundation
import CoreBluetooth
import os

final class CGMG4xDripTransmitter: BluetoothTransmitter, CGMTransmitter {
    
    // MARK: - properties
    
    /// uuid used for scanning, can be empty string, if empty string then scan all devices - only possible if app is in foreground
    let CBUUID_Advertisement_G4: String = "0000FFE0-0000-1000-8000-00805F9B34FB"
    /// service to be discovered
    let CBUUID_Service_G4: String = "0000FFE0-0000-1000-8000-00805F9B34FB"
    /// receive characteristic
    let CBUUID_ReceiveCharacteristic_G4: String = "0000FFE1-0000-1000-8000-00805F9B34Fb"
    /// write characteristic
    let CBUUID_WriteCharacteristic_G4: String = "0000FFE1-0000-1000-8000-00805F9B34Fb"
    
    /// will be used to pass back bluetooth and cgm related events
    private(set) weak var cgmTransmitterDelegate:CGMTransmitterDelegate?
    
    /// CGMDexcomG4TransmitterDelegate
    public weak var cGMDexcomG4TransmitterDelegate: CGMDexcomG4TransmitterDelegate?
    
    /// for trace
    private let log = OSLog(subsystem: ConstantsLog.subSystem, category: ConstantsLog.categoryCGMxDripG4)
    
    /// transmitterId
    private let transmitterId:String
    
    // MARK: - initializer
    
    /// - parameters:
    ///     - address: if already connected before, then give here the address that was received during previous connect, if not give nil
    ///     - name : if already connected before, then give here the name that was received during previous connect, if not give nil
    ///     - transmitterID: expected transmitterID, 5 characters
    ///     - bluetoothTransmitterDelegate : a BluetoothTransmitterDelegate
    ///     - cGMTransmitterDelegate : a CGMTransmitterDelegate
    init(address:String?, name: String?, transmitterID:String, bluetoothTransmitterDelegate: BluetoothTransmitterDelegate, cGMDexcomG4TransmitterDelegate : CGMDexcomG4TransmitterDelegate, cGMTransmitterDelegate:CGMTransmitterDelegate) {
        // assign addressname and name or expected devicename
        var newAddressAndName:BluetoothTransmitter.DeviceAddressAndName = BluetoothTransmitter.DeviceAddressAndName.notYetConnected(expectedName: nil)
        if let address = address {
            newAddressAndName = BluetoothTransmitter.DeviceAddressAndName.alreadyConnectedBefore(address: address, name: name)
        }
        
        //assign CGMTransmitterDelegate
        self.cgmTransmitterDelegate = cGMTransmitterDelegate
        
        // assign cGMDexcomG4TransmitterDelegate
        self.cGMDexcomG4TransmitterDelegate = cGMDexcomG4TransmitterDelegate
        
        //assign transmitterId
        self.transmitterId = transmitterID

        super.init(addressAndName: newAddressAndName, CBUUID_Advertisement: CBUUID_Advertisement_G4, servicesCBUUIDs: [CBUUID(string: CBUUID_Service_G4)], CBUUID_ReceiveCharacteristic: CBUUID_ReceiveCharacteristic_G4, CBUUID_WriteCharacteristic: CBUUID_WriteCharacteristic_G4, bluetoothTransmitterDelegate: bluetoothTransmitterDelegate)
        
    }
    
    // MARK: - MARK: CBCentralManager overriden functions
    
    override func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        
        super.peripheral(peripheral, didUpdateValueFor: characteristic, error: error)
        
        //check if value is not nil
        guard let value = characteristic.value else {
            trace("in peripheral didUpdateValueFor, characteristic.value is nil", log: log, category: ConstantsLog.categoryCGMxDripG4, type: .info)
            return
        }
        
        //for xdrip G4, first byte is the packet length
        guard let packetLength = value.first else {
            trace("in peripheral didUpdateValueFor, packetLength is nil", log: log, category: ConstantsLog.categoryCGMxDripG4, type: .info)
            return
        }
        
        //value length should be minimum 2
        guard value.count >= 2 else {
            //value length should be minimum 2
            trace("in peripheral didUpdateValueFor, value length is less than 2, no further processing", log: log, category: ConstantsLog.categoryCGMxDripG4, type: .info)
            return
        }
        
        switch XdripResponseType(rawValue: value[1]) {
        case .dataPacket?:
            //process value and get result
            let result = processxBridgeDataPacket(value: value)
            
            // check transmitterid, if not correct write correct value to the bridge, and return
            if let data = checkTransmitterId(receivedTransmitterId: result.transmitterID, expectedTransmitterId: self.transmitterId, log: log) {
                trace("    in peripheralDidUpdateValueFor, sending transmitterid %{public}@ to xdrip ", log: log, category: ConstantsLog.categoryCGMxDripG4, type: .info, self.transmitterId)
                _ = writeDataToPeripheral(data: data, type: .withoutResponse)//no need to log the result, this is already logged in BluetoothTransmitter.swift
                return
            }
            
            // Data packet Acknowledgement, to put wixel to sleep
            _ = writeDataToPeripheral(data: Data([0x02,0xF0]), type: .withoutResponse)
            
            // if glucoseData received, send to delegate. If transmitterBatteryInfo available, then also send this to cGMDexcomG4TransmitterDelegate
            if let glucoseData = result.glucoseData {
                
                let glucoseDataArray = [glucoseData]
                
                var transmitterBatteryInfo:TransmitterBatteryInfo? = nil
                
                if let level = result.batteryLevel {
                    
                    transmitterBatteryInfo = TransmitterBatteryInfo.DexcomG4(level: level)
                    
                    // delegate may touch UI/Core Data → ensure main thread
                    DispatchQueue.main.async { [weak self] in
                        guard let self = self else { return }
                        self.cGMDexcomG4TransmitterDelegate?.received(batteryLevel: level, from: self)
                    }
                    
                }
                
                // deliver glucose data to delegate on main; use a local copy for inout
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    var copy = glucoseDataArray
                    self.cgmTransmitterDelegate?.cgmTransmitterInfoReceived(glucoseData: &copy, transmitterBatteryInfo: transmitterBatteryInfo, sensorAge: nil)
                }
                
            }
            
        case .beaconPacket?:
            trace("    in peripheral didUpdateValueFor, received beaconPacket", log: log, category: ConstantsLog.categoryCGMxDripG4, type: .info)
            
            //packet length should be 7
            guard packetLength == 7 else {
                trace("    in peripheral didUpdateValueFor, packet length is not 7,  no further processing", log: log, category: ConstantsLog.categoryCGMxDripG4, type: .info)
                return
            }
            
            //read txid
            let receivedTransmitterId = decodeTxID(TxID: value.uint32(position: 2))
            trace("    in peripheral didUpdateValueFor, received beaconPacket with txid %{public}@", log: log, category: ConstantsLog.categoryCGMxDripG4, type: .info, receivedTransmitterId)
            
            // check transmitterid, if not correct write correct value
            if let data = checkTransmitterId(receivedTransmitterId: receivedTransmitterId, expectedTransmitterId: self.transmitterId, log: log) {
                trace("    in peripheralDidUpdateValueFor, sending transmitterid %{public}@ to xdrip ", log: log, category: ConstantsLog.categoryCGMxDripG4, type: .info, self.transmitterId)
                _ = writeDataToPeripheral(data: data, type: .withoutResponse)//no need to log the result, this is already logged in BluetoothTransmitter.swift
                return
            }
        default:
            //value doesn't start with a known xdripresponsetype
            trace("    unknown packet type, looks like an xdrip with old wxl code which starts with the raw_data encoded.", log: log, category: ConstantsLog.categoryCGMxDripG4, type: .info)
            
            //process value and get result, send it to delegate
            let result = processBasicXdripDataPacket(value: value)
            if let glucoseData = result.glucoseData {
                let glucoseDataArray = [glucoseData]
                var transmitterBatteryInfo:TransmitterBatteryInfo? = nil
                if let level = result.batteryLevel {
                    
                    transmitterBatteryInfo = TransmitterBatteryInfo.DexcomG4(level: level)
                    
                    // delegate may touch UI/Core Data → ensure main thread
                    DispatchQueue.main.async { [weak self] in
                        guard let self = self else { return }
                        self.cGMDexcomG4TransmitterDelegate?.received(batteryLevel: level, from: self)
                    }
                    
                }
                
                // deliver glucose data to delegate on main; use a local copy for inout
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    var copy = glucoseDataArray
                    self.cgmTransmitterDelegate?.cgmTransmitterInfoReceived(glucoseData: &copy, transmitterBatteryInfo: transmitterBatteryInfo, sensorAge: nil)
                }
            }
        }
        
    }
    
    override func prepareForRelease() {
        // Clear base CB delegates + unsubscribe common receiveCharacteristic synchronously on main
        super.prepareForRelease()
        // CGMG4xDrip-specific: no additional timers/characteristics cached here
    }

    // MARK: - CGMTransmitter protocol functions
    
    func cgmTransmitterType() -> CGMTransmitterType {
        return .dexcomG4
    }

    func getCBUUID_Service() -> String {
        return CBUUID_Service_G4
    }
    
    func getCBUUID_Receive() -> String {
        return CBUUID_ReceiveCharacteristic_G4
    }

    // MARK:- helper functions
    
    private func processxBridgeDataPacket(value:Data) -> (glucoseData:GlucoseData?, batteryLevel:Int?, transmitterID:String?) {
        guard value.count >= 10 else {
            trace("processxBridgeDataPacket, value.count = %{public}d, expecting minimum 10 so that we can find at least rawdata", log: log, category: ConstantsLog.categoryCGMxDripG4, type: .info, value.count)
            return (nil, nil, nil)
        }
        
        //initialize returnvalues
        var glucoseData:GlucoseData?
        var batteryLevel:Int?
        var transmitterID:String?
        
        //get rawdata
        let rawData = value.uint32(position: 2)
        
        //get transmitter battery voltage, only if value size is big enough to hold it
        if value.count >= 11 {
            batteryLevel = Int(value[10])
        }
        
        //get transmitterID, only if value size is big enough to hold it
        if value.count >= 16 {
            transmitterID = decodeTxID(TxID: value.uint32(position: 12))
        }
        
        //create glucosedata
        glucoseData = GlucoseData(timeStamp: Date(), glucoseLevelRaw: Double(rawData))

        return (glucoseData, batteryLevel, transmitterID)
    }
    
    ///Supports for example xdrip delivered by xdripkit.co.uk
    ///
    ///Expected format is \"raw_data transmitter_battery_level bridge_battery_level with bridge_battery_level always 0"
    ///
    ///Example 123632 218 0
    ///
    ///Those packets don't start with a fixed packet length and packet type, as they start with representation of an Integer
    private func processBasicXdripDataPacket(value:Data) -> (glucoseData:GlucoseData?, batteryLevel:Int?) {
        //initialize returnvalues
        var glucoseData:GlucoseData?
        var batteryLevel:Int?
        
        //convert value to string
        if let bufferAsString = String(bytes: value, encoding: .utf8) {
            //find indexes of " " and store in array
            let indexesOfSplitter = bufferAsString.indexes(of: " ")
            guard !indexesOfSplitter.isEmpty else {
                trace("processBasicXdripDataPacket, no space separators found in payload string", log: log, category: ConstantsLog.categoryCGMxDripG4, type: .info)
                return (nil, nil)
            }
            // start with finding rawData
            var range = bufferAsString.startIndex..<indexesOfSplitter[0]
            let rawData:Int? = Int(bufferAsString[range])
            //next find the battery info
            if indexesOfSplitter.count > 1 {
                let batteryindex = bufferAsString.index(indexesOfSplitter[0], offsetBy: 1)
                range = batteryindex..<indexesOfSplitter[1]
                batteryLevel = Int(bufferAsString[range])
            }
            //create glucoseData
            if let rawData = rawData {
                trace("in peripheral didUpdateValueFor, dataPacket received with rawData = %{public}d and batteryInfo =  %{public}d", log: log, category: ConstantsLog.categoryCGMxDripG4, type: .info, rawData, batteryLevel ?? 0)
                glucoseData = GlucoseData(timeStamp: Date(), glucoseLevelRaw: Double(rawData))
            } else {
                trace("in peripheral didUpdateValueFor, no rawdata", log: log, category: ConstantsLog.categoryCGMxDripG4, type: .info)
            }
        } else {
            trace("value could not be converted to string", log: log, category: ConstantsLog.categoryCGMxDripG4, type: .info)
        }
        
        return (glucoseData, batteryLevel)
    }
}


fileprivate enum XdripResponseType: UInt8 {
    case dataPacket = 0x00
    case beaconPacket = 0xF1
}

// MARK: functions and properties to encode and decode transmitterid

fileprivate let srcNameTable:Array = [ "0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "A", "B", "C", "D", "E", "F", "G", "H", "J", "K", "L", "M", "N", "P", "Q", "R", "S", "T", "U", "W", "X", "Y" ]

fileprivate func encodeTxID(TxID:String) -> (UInt8, UInt8, UInt8, UInt8 ) {
    var returnValue:UInt32 = 0
    let tmpSrc:String = TxID.uppercased()
    returnValue |= getSrcValue(ch: tmpSrc[0..<1]) << 20
    returnValue |= getSrcValue(ch: tmpSrc[1..<2]) << 15
    returnValue |= getSrcValue(ch: tmpSrc[2..<3]) << 10
    returnValue |= getSrcValue(ch: tmpSrc[3..<4]) << 5
    returnValue |= getSrcValue(ch: tmpSrc[4..<5])
    let firstByte = UInt8(returnValue & 0x000000FF)
    let secondByte = UInt8((returnValue & 0x0000FF00) >> 8)
    let thirdByte = UInt8((returnValue & 0x00FF0000) >> 16)
    let forthByte = UInt8((returnValue & 0xFF000000) >> 24)
    return (firstByte, secondByte, thirdByte, forthByte)
}

fileprivate func decodeTxID(TxID:UInt32) -> String {
    var returnValue:String = ""
    returnValue += srcNameTable[(Int)((TxID >> 20) & 0x1F)]
    returnValue += srcNameTable[(Int)((TxID >> 15) & 0x1F)]
    returnValue += srcNameTable[(Int)((TxID >> 10) & 0x1F)]
    returnValue += srcNameTable[(Int)((TxID >> 5) & 0x1F)]
    returnValue += srcNameTable[(Int)((TxID >> 0) & 0x1F)]
    return returnValue
}

fileprivate func getSrcValue(ch:String) -> UInt32 {
    for (index, character) in srcNameTable.enumerated() {
        if character == ch {
            return (UInt32)(index)
        }
    }
    return 0
}

/// - returns:
///     - nil if no transmitter id's match. If no match, then data needs to be written to writecharacteristic
fileprivate func checkTransmitterId(receivedTransmitterId:String?, expectedTransmitterId:String, log:OSLog) -> Data? {
    if let receivedTransmitterId = receivedTransmitterId {
        if receivedTransmitterId != expectedTransmitterId {
            var datatoSend = Data()
            datatoSend.append(0x06)
            datatoSend.append(0x01)
            let result = encodeTxID(TxID: expectedTransmitterId.uppercased())
            datatoSend.append(result.0)
            datatoSend.append(result.1)
            datatoSend.append(result.2)
            datatoSend.append(result.3)
            return datatoSend
        }
    }
    return nil
}

extension XdripResponseType: CustomStringConvertible {
    public var description: String {
        switch self {
        case .dataPacket:
            return "Data packet received"
        case .beaconPacket:
            return "Beacon packet received"
        }
    }
}
