import Foundation
import CoreBluetooth
import os

final class CGMG4xDripTransmitter: BluetoothTransmitter, BluetoothTransmitterDelegate, CGMTransmitterProtocol {
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
    
    /// for OS_log
    private let log = OSLog(subsystem: Constants.Log.subSystem, category: Constants.Log.categoryCGMxDripG4)
    
    // MARK: - functions
    
    /// - parameters:
    ///     - address: if already connected before, then give here the address that was received during previous connect, if not give nil
    ///     - transmitterID: expected transmitterID, 5 characters
    init(address:String?, transmitterID:String, delegate:CGMTransmitterDelegate) {
        
        // assign addressname and name or expected devicename
        var newAddressAndName:BluetoothTransmitter.DeviceAddressAndName = BluetoothTransmitter.DeviceAddressAndName.notYetConnected(expectedName: nil)
        if let address = address {
            newAddressAndName = BluetoothTransmitter.DeviceAddressAndName.alreadyConnectedBefore(address: address)
        }
        
        //assign CGMTransmitterDelegate
        cgmTransmitterDelegate = delegate

        super.init(addressAndName: newAddressAndName, CBUUID_Advertisement: CBUUID_Advertisement_G4, CBUUID_Service: CBUUID_Service_G4, CBUUID_ReceiveCharacteristic: CBUUID_ReceiveCharacteristic_G4, CBUUID_WriteCharacteristic: CBUUID_WriteCharacteristic_G4)
        
        bluetoothTransmitterDelegate = self
    }
    
    // MARK: - functions
    
    // MARK: - BluetoothTransmitterDelegate functions
    
    func centralManagerDidConnect() {
    }
    
    func centralManagerDidFailToConnect(error: Error?) {
    }
    
    func centralManagerDidUpdateState(state: CBManagerState) {
        cgmTransmitterDelegate?.didUpdateBluetoothState(state: state)
    }
    
    func centralManagerDidDisconnectPeripheral(error: Error?) {
        cgmTransmitterDelegate?.cgmTransmitterDidDisconnect()
    }
    
    func peripheralDidUpdateNotificationStateFor(characteristic: CBCharacteristic, error: Error?) {
        os_log("in peripheralDidUpdateNotificationStateFor, it's an xdrip, assuming here full connect status", log: log, type: .info)
        //In Spike and iosxdripreader, a device connection completed is transmitted in this case
        cgmTransmitterDelegate?.cgmTransmitterDidConnect()
    }
    
    func peripheralDidUpdateValueFor(characteristic: CBCharacteristic, error: Error?) {
        //check if value is not nil
        guard let value = characteristic.value else {
            os_log("in peripheral didUpdateValueFor, characteristic.value is nil", log: log, type: .info)
            return
        }
        
        //for xdrip G4, first byte is the packet length
        guard let packetLength = value.first else {
            os_log("in peripheral didUpdateValueFor, packetLength is nil", log: log, type: .info)
            return
        }
        
        //value length should be minimum 2
        guard value.count >= 2 else {
            //value length should be minimum 2
            os_log("in peripheral didUpdateValueFor, value length is less than 2, no further processing", log: log, type: .info)
            return
        }
        
        //only for logging
        let data = value.hexEncodedString()
        os_log("in peripheral didUpdateValueFor, data = %{public}@", log: log, type: .debug, data)

        switch XdripResponseType(rawValue: value[1]) {
        case .dataPacket?:
            //packet length should be 17
            guard packetLength == 17 else {
                //value doesn't start with a known xdripresponsetype
                os_log("in peripheral didUpdateValueFor, packet length is not 17,  no further processing", log: log, type: .info)
                return
            }
            
            //process value and get result, send it to delegate
            let result = processxDripData(value: value)
            if let glucoseData = result.glucoseData {
                var glucoseDataArray = [glucoseData]
                cgmTransmitterDelegate?.newReadingsReceived(glucoseData: &glucoseDataArray, transmitterBatteryInfo: result.transmitterBatteryInfo, sensorState: nil, sensorTimeInMinutes: nil, firmware: nil, hardware: nil)
            }
        case .beaconPacket?:
            os_log("in peripheral didUpdateValueFor, received beaconPacket", log: log, type: .info)
        default:
            //value doesn't start with a known xdripresponsetype
            os_log("unknown packet type, looks like an xdrip with old wxl code which starts with the raw_data encoded.", log: log, type: .info)
            
            //process value and get result, send it to delegate
            let result = processBasicXdripData(value: value)
            if let glucoseData = result.glucoseData {
                var glucoseDataArray = [glucoseData]
                cgmTransmitterDelegate?.newReadingsReceived(glucoseData: &glucoseDataArray, transmitterBatteryInfo: result.transmitterBatteryInfo, sensorState: nil, sensorTimeInMinutes: nil, firmware: nil, hardware: nil)
            }
        }
    }
    
    //MARK: CGMTransmitterProtocol functions
    func canDetectNewSensor() -> Bool {
        return false
    }
    
    // MARK: - helper functions
    
    private func processxDripData(value:Data) -> (glucoseData:RawGlucoseData?, transmitterBatteryInfo:Int?) {
        //initialize returnvalues
        var glucoseData:RawGlucoseData?
        var transmitterBatteryInfo:Int?
        
        //get rawdata
        let rawData = value.uint32(position: 2)
        
        //get filtereddata
        let filteredData = value.uint32(position: 6)
        
        //get transmitter battery volrage
        transmitterBatteryInfo = Int(value[10])
        
        os_log("in peripheral didUpdateValueFor, dataPacket received with rawData = %{public}d and filteredData = %{public}d  and transmitterBatteryInfo = %{public}d", log: log, type: .info, rawData, filteredData, transmitterBatteryInfo ?? 0)
        
        //create glucosedata
        glucoseData = RawGlucoseData(timeStamp: Date(), glucoseLevelRaw: Double(rawData), glucoseLevelFiltered: Double(filteredData))

        return (glucoseData, transmitterBatteryInfo)
    }
    
    ///Supports for example xdrip delivered by xdripkit.co.uk
    ///
    ///Expected format is \"raw_data transmitter_battery_level bridge_battery_level with bridge_battery_level always 0"
    ///
    ///Example 123632 218 0
    ///
    ///Those packets don't start with a fixed packet length and packet type, as they start with representation of an Integer
    private func processBasicXdripData(value:Data) -> (glucoseData:RawGlucoseData?, transmitterBatteryInfo:Int?) {
        //initialize returnvalues
        var glucoseData:RawGlucoseData?
        var transmitterBatteryInfo:Int?
        
        //convert value to string
        if let bufferAsString = String(bytes: value, encoding: .utf8) {
            //find indexes of " " and store in array
            var indexesOfSplitter = bufferAsString.indexes(of: " ")
            // start with finding rawData
            var range = bufferAsString.startIndex..<indexesOfSplitter[0]
            let rawData:Int? = Int(bufferAsString[range])
            //next find the battery info
            if indexesOfSplitter.count > 1 {
                let batteryindex = bufferAsString.index(indexesOfSplitter[0], offsetBy: 1)
                range = batteryindex..<indexesOfSplitter[1]
                transmitterBatteryInfo = Int(bufferAsString[range])
            }
            //create glucoseData
            if let rawData = rawData {
                os_log("in peripheral didUpdateValueFor, dataPacket received with rawData = %{public}d and batteryInfo =  %{public}d", log: log, type: .info, rawData, transmitterBatteryInfo ?? 0)
                glucoseData = RawGlucoseData(timeStamp: Date(), glucoseLevelRaw: Double(rawData))
            } else {
                os_log("in peripheral didUpdateValueFor, no rawdata", log: log, type: .info)
            }
        } else {
            os_log("value could not be converted to string", log: log, type: .info)
        }
        
        return (glucoseData, transmitterBatteryInfo)
    }
}


fileprivate enum XdripResponseType: UInt8 {
    case dataPacket = 0x00
    case beaconPacket = 0xD6
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
