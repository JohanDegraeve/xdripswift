import Foundation
import CoreBluetooth
import os

/// characteristic is write and notify, not read. To get data from the M5Stack, xdrip app will write a specific opcode, then M5Stack will reply and the reply will arrive as notify. So we don't use .withResponse
final class M5StackBluetoothTransmitter: BluetoothTransmitter, BluetoothTransmitterDelegate {
    
    // MARK: - private properties
    
    /// service to be discovered
    private let CBUUID_Service: String = "AF6E5F78-706A-43FB-B1F4-C27D7D5C762F"
    
    /// transmit and receive characteristic
    private let CBUUID_TxRxCharacteristic: String = "6D810E9F-0983-4030-BDA7-C7C9A6A19C1C"

    /// for trace
    private let log = OSLog(subsystem: ConstantsLog.subSystem, category: ConstantsLog.categoryM5StackBluetoothTransmitter)
    
    /// blepassword, used for authenticating xdrip app towards M5Stack
    private var blePassword: String?
    
    /// temporary storage for packages received from M5Stack, with the password in it
    private var blePasswordM5StackPacket =  M5StackPacket()
    
    /// will be used to pass data
    private(set) weak var m5StackDelegate:M5StackDelegate?


    // MARK: - initializer

    /// - parameters:
    ///     - address : if already conneted before then it should be known
    ///     - name : if already conneted before then it should be known
    init(address:String?, name: String?, delegate:M5StackDelegate, blePassword: String?) {
        
        // assign addressname and name or expected devicename
        var newAddressAndName:BluetoothTransmitter.DeviceAddressAndName = BluetoothTransmitter.DeviceAddressAndName.notYetConnected(expectedName: "M5_NightscoutMon")
        if let address = address {
            newAddressAndName = BluetoothTransmitter.DeviceAddressAndName.alreadyConnectedBefore(address: address, name: name)
        }
        
        self.blePassword = blePassword
        
        self.m5StackDelegate = delegate

        // call super
        super.init(addressAndName: newAddressAndName, CBUUID_Advertisement: nil, servicesCBUUIDs: [CBUUID(string: CBUUID_Service)], CBUUID_ReceiveCharacteristic: CBUUID_TxRxCharacteristic, CBUUID_WriteCharacteristic: CBUUID_TxRxCharacteristic, startScanningAfterInit: false)
        
        // set self as delegate for BluetoothTransmitterDelegate - this parameter is defined in the parent class BluetoothTransmitter
        bluetoothTransmitterDelegate = self

    }
    
    // MARK: public functions
    
    /// writes calculated Value, timestamp and slopeName of the reading as string to M5Stack
    /// - reading will be rounded to whole number
    /// - timestamp will be sent as long in seconds since 1.1.1970, UTC
    /// - slopeName is literally copied
    /// reading and timestamp are written in one packet to the M5stack, seperated by blanc, slopeName is written in seperate packet
    /// - parameters:
    ///     - readingValue : the value in mgdl
    ///     - timeStamp : timestamp of the reading
    func writeBgReadingInfo(bgReading: BgReading) {
        
        // create packets to send slopeName
        guard let packetWithSlopeName = M5StackUtilities.splitTextInBLEPackets(text: bgReading.slopeName, maxBytesInOneBLEPacket: ConstantsM5Stack.maximumMBLEPacketsize, opCode: M5StackTransmitterOpCodeTx.writeSlopeNameTx.rawValue) else {
            trace("in writeBgReading, failed to create packets to send slopeName", log: log, type: .error)
            return
        }
        
        // send slopename
        for packet in packetWithSlopeName {
            if !writeDataToPeripheral(data: packet, type: .withoutResponse) {
                trace("in writeBgReading, failed to send packet with slopename", log: log, type: .error)
            } else {
                trace("successfully written slopename to M5Stack", log: log, type: .error)
            }
        }
        
       // create text to send, reading value, one blanc, timestamp in seconds
        let textToSend = Int(round(bgReading.calculatedValue)).description + " " + bgReading.timeStamp.toSecondsAsInt64().description
        
        // create packets to send reading and timestamp
        guard let packetsWithReadingAndTimestamp = M5StackUtilities.splitTextInBLEPackets(text: textToSend, maxBytesInOneBLEPacket: ConstantsM5Stack.maximumMBLEPacketsize, opCode: M5StackTransmitterOpCodeTx.bgReadingTx.rawValue) else {
            trace("in writeBgReading, failed to create packets to send reading and timestamp", log: log, type: .error)
            return
        }
        
        // send reading and timestamp
        for packet in packetsWithReadingAndTimestamp {
            if !writeDataToPeripheral(data: packet, type: .withoutResponse) {
                trace("in writeBgReading, failed to send packet with reading and timestamp", log: log, type: .error)
            } else {
               trace("successfully written reading and timestamp to M5Stack", log: log, type: .error)
            }
        }
        
    }
    
    // MARK: - BluetoothTransmitterDelegate functions
    
    func centralManagerDidConnect(address: String?, name: String?) {
        debuglogging("TODO M5StackBluetoothTransmitter centralManagerDidConnect")
    }
    
    func centralManagerDidFailToConnect(error: Error?) {
        debuglogging("TODO M5StackBluetoothTransmitter centralManagerDidFailToConnect")
    }
    
    func centralManagerDidUpdateState(state: CBManagerState) {
        debuglogging("TODO M5StackBluetoothTransmitter centralManagerDidUpdateState, new state = " + state.toString())
    }
    
    func centralManagerDidDisconnectPeripheral(error: Error?) {
        debuglogging("TODO M5StackBluetoothTransmitter centralcentralManagerDidDisconnectPeripheralManagerDidConnect")
    }
    
    func peripheralDidUpdateNotificationStateFor(characteristic: CBCharacteristic, error: Error?) {
        
        // check if subscribe to notifications succeeded
        if characteristic.isNotifying {
            
            // time to send password to M5Stack, if there isn't one known in the settings then we assume that the user didn't set a password in the M5Stack config (M5NS.INI) and that we didn't connect to this M5Stack yet after the last M5Stack restart. So in that case we will request a random password
            if let blePassword = blePassword, let authenticateTxMessageData = M5StackAuthenticateTXMessage(password: blePassword).data {

                if !writeDataToPeripheral(data: authenticateTxMessageData, type: .withoutResponse) {
                    trace("failed to send authenticateTx to M5Stack", log: log, type: .error)
                } else {
                    trace("successfully sent authenticateTx to M5Stack", log: log, type: .error)
                }
                
            } else {
                
                if !writeDataToPeripheral(data: M5StackReadBlePassWordTxMessage().data, type: .withoutResponse) {
                    trace("failed to send readBlePassWordTx to M5Stack", log: log, type: .error)
                } else {
                    trace("successfully sent readBlePassWordTx to M5Stack", log: log, type: .error)
                }

            }
            
        } else {
           trace("in peripheralDidUpdateNotificationStateFor, failed to subscribe for characteristic %{public}@", log: log, type: .error, characteristic.uuid.description)
        }
    }
    
    func peripheralDidUpdateValueFor(characteristic: CBCharacteristic, error: Error?) {
        
        //check if value is not nil
        guard let value = characteristic.value else {
            trace("in peripheral didUpdateValueFor, characteristic.value is nil", log: log, type: .info)
            return
        }
        
        //only for logging
        let data = value.hexEncodedString()
        trace("in peripheral didUpdateValueFor, data = %{public}@", log: log, type: .debug, data)
        
        // value length should be at least 1
        guard value.count > 0 else {
            trace("    value length is 0, no further processing", log: log, type: .error)
            return
        }
        
        guard let opCode = M5StackTransmitterOpCodeRx(rawValue: value[0]) else {
            trace("    failed to create opCode", log: log, type: .error)
            return
        }
        trace("    opcode = %{public}@", log: log, type: .info, opCode.description)
        
        switch opCode {
            
        case .readBlePassWordRx:
            
            blePasswordM5StackPacket.addNewPacket(value: value)
            
            if let newBlePassword = blePasswordM5StackPacket.getText() {
                
                self.blePassword = newBlePassword
                m5StackDelegate?.newBlePassWord(newBlePassword: newBlePassword)
                
                sendLocalTimeAndUTCTimeOffSetInSecondsToM5Stack()
            }
            
        case .authenticateSuccessRx:
            
            m5StackDelegate?.authentication(success: true)
            
            // even though not requested, and even if M5Stack may already have it, send the local time
            sendLocalTimeAndUTCTimeOffSetInSecondsToM5Stack()
            
        case .authenticateFailureRx:
            m5StackDelegate?.authentication(success: false)
            
        case .readBlePassWordError1Rx:
            m5StackDelegate?.blePasswordMissingInSettings()
            
        case .readBlePassWordError2Rx:
            m5StackDelegate?.m5StackResetRequired()
            
        case .readTimeStampRx:
            sendLocalTimeAndUTCTimeOffSetInSecondsToM5Stack()
            
        }
    }

    // MARK: helper functions
    
    /// sends local time in seconds since 1.1.1970 and also timeoffset from UTC in seconds. to M5Stack
    ///
    /// local time = UTC time + offset /// UTC time = local time - offset
    private func sendLocalTimeAndUTCTimeOffSetInSecondsToM5Stack() {
        
        // NOTE : why creating multiple packets (splitTextInBLEPackets) even though it will all fit in one packet ?
        // goal is to be able to send longer strings, to M5 Stack. Then we could create one string which contains the timestamp and offset (split by blanc). But then for sure there will be multiple packets, and I didn't yet develop the logic to reconcatenate strings in the M5Stack
        
        // create local time in seconds as Int64
        let localTimeInSeconds = Date().toSecondsAsInt64Local()
        
        // create offset from UTC
        let uTCTimeInSeconds = Date().toSecondsAsInt64()
        let offSet = localTimeInSeconds - uTCTimeInSeconds
        
        // create packets to send with offset
        guard let packetsWithOffset = M5StackUtilities.splitTextInBLEPackets(text: offSet.description, maxBytesInOneBLEPacket: ConstantsM5Stack.maximumMBLEPacketsize, opCode: M5StackTransmitterOpCodeTx.writeTimeOffsetTx.rawValue) else {
            trace("   failed to create packets for sending offset", log: log, type: .error)
            return
        }
        
        // send the packets with offset
        for packet in packetsWithOffset {
            if !writeDataToPeripheral(data: packet, type: .withoutResponse) {
                trace("    failed to send packet with offset to M5Stack", log: log, type: .error)
            } else {
                trace("    successfully sent packet with offset to M5Stack", log: log, type: .error)
            }
        }
        
        // create packets to send with local time
        guard let packetsWithLocalTime = M5StackUtilities.splitTextInBLEPackets(text: localTimeInSeconds.description, maxBytesInOneBLEPacket: ConstantsM5Stack.maximumMBLEPacketsize, opCode: M5StackTransmitterOpCodeTx.writeTimeStampTx.rawValue) else {
            trace("   failed to create packets for sending timestamp", log: log, type: .error)
            return
        }
        
        // send packets with localtime
        for packet in packetsWithLocalTime {
            if !writeDataToPeripheral(data: packet, type: .withoutResponse) {
                trace("    failed to send packet with local timestamp to M5Stack", log: log, type: .error)
            } else {
                trace("    successfully sent packet with local timestamp to M5Stack", log: log, type: .error)
            }
        }
        
    }
    
}
