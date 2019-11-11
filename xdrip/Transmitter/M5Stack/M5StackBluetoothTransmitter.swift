import Foundation
import CoreBluetooth
import os

/// bluetoothTransmitter for an M5 Stack
/// - will start scanning as soon as created or as soon as bluetooth is switched on
/// - there's only one characteristic which is used for write and notify, not read. To get data from the M5Stack, xdrip app will write a specific opcode, then M5Stack will reply and the reply will arrive as notify. So we don't use .withResponse
final class M5StackBluetoothTransmitter: BluetoothTransmitter, BluetoothTransmitterDelegate {
    
    // MARK: - public properties
    
    /// will be used to pass data back
    ///
    /// there's two delegates, one public, one private. The private one will be assigned during object creation. There's two because two other classes want to receive feedback : M5StackManager and UIViewControllers. There's only one instance of M5StackManager and it's always the same. An instance will be assigned to m5StackBluetoothTransmitterDelegateFixed. There can be different UIViewController' and they can change, an instance will be assigned to m5StackBluetoothTransmitterDelegateVariable
    public weak var m5StackBluetoothTransmitterDelegateVariable: M5StackBluetoothDelegate?

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
    
    /// m5Stack instance for which this bluetooth transmitter is working, if nil then this bluetoothTransmitter is created to start scanning for a new, unknown M5Stack. In that case, the value needs to be assigned as soon as an M5Stack is created
    public var m5Stack: M5Stack?
    
    /// will be used to pass data back
    ///
    /// there's two delegates, one public, one private. The private one will be assigned during object creation. There's two because two other classes want to receive feedback : M5StackManager and UIViewControllers. There's only one instance of M5StackManager and it's always the same. An instance will be assigned to m5StackBluetoothTransmitterDelegateFixed. There can be different UIViewController' and they can change, an instance will be assigned to m5StackBluetoothTransmitterDelegateVariable
    private weak var m5StackBluetoothTransmitterDelegateFixed:M5StackBluetoothDelegate!
    
    /// is the transmitter ready to receive data like parameter updates or reading values
    private (set) var isReadyToReceiveData: Bool = false
    
    /// possible rotation values, , the value is how it will be sent to the M5Stack but not  how it's stored in the M5Stack object - In the M5Stack object we store an Int value which is used as index in rotationValues and rotationStrings
    private let rotationValues: [UInt16] = [ 1, 2, 3, 0]

    // MARK: - initializer

    /// - parameters:
    ///     - m5Stack : an instance of M5Stack, if nil then this instance is created to scan for a new M5Stack, address and name not yet known, so not possible yet to create an M5Stack instance
    ///     - delegateFixed : there's two delegates, one public, one private. The private one will be assigned during object creation. There's two because two other classes want to receive feedback : M5StackManager and UIViewControllers. There's only one instance of M5StackManager and it's always the same. An instance will be assigned to m5StackBluetoothTransmitterDelegateFixed. There can be different UIViewController' and they can change, an instance will be assigned to m5StackBluetoothTransmitterDelegateVariable
    ///     - blePassword : optional. If nil then xdrip will send a M5StackReadBlePassWordTxMessage to the M5Stack, so this would be a case where the M5Stack (all M5Stacks managed by xdrip) do not have a fixed blepassword
    /// The blepassword in the M5Stack object gets priority over the blePassword in the parameter list
    init(m5Stack: M5Stack?, delegateFixed: M5StackBluetoothDelegate, blePassword: String?) {
        
        // assign addressname and name or expected devicename
        var newAddressAndName:BluetoothTransmitter.DeviceAddressAndName = BluetoothTransmitter.DeviceAddressAndName.notYetConnected(expectedName: "M5Stack")
        if let m5Stack = m5Stack {
            newAddressAndName = BluetoothTransmitter.DeviceAddressAndName.alreadyConnectedBefore(address: m5Stack.address, name: m5Stack.name)
        }
        
        // as mentioned in the parameter documentation, the blePassword in the M5Stack parameter gets priority over the password in the parameter blePassword
        if let m5Stack = m5Stack, let blePassword = m5Stack.blepassword {
            // m5Stack object is not nil and does have a blePassword, use that value
            self.blePassword = blePassword
        } else {
            // use blePassword that was in the parameter list, possibly nil value
            self.blePassword = blePassword
        }

        self.m5Stack = m5Stack
        
        self.m5StackBluetoothTransmitterDelegateFixed = delegateFixed

        // call super
        super.init(addressAndName: newAddressAndName, CBUUID_Advertisement: nil, servicesCBUUIDs: [CBUUID(string: CBUUID_Service)], CBUUID_ReceiveCharacteristic: CBUUID_TxRxCharacteristic, CBUUID_WriteCharacteristic: CBUUID_TxRxCharacteristic, startScanningAfterInit: false)
        
        // set self as delegate for BluetoothTransmitterDelegate - this parameter is defined in the parent class BluetoothTransmitter
        bluetoothTransmitterDelegate = self
        
        // start scanning, probably the scanning will not yet start, this will happen only when centralManagerDidUpdateState is called
        _ = startScanning()

    }
    
    // MARK: public functions
    
    /// writes calculated Value, timestamp and slopeName of the reading as string to M5Stack
    /// - calculated value will be rounded to whole number
    /// - timestamp will be sent as long in seconds since 1.1.1970, UTC
    /// - slopeName is literally copied -
    /// reading and timestamp are written in one packet to the M5stack, seperated by blanc, slopeName is written in seperate packet
    /// - parameters:
    ///     - bgReading : the reading
    /// - returns:
    ///         true if successfully transmitted to M5Stack, doesn't mean M5Stack did receive it
    func writeBgReadingInfo(bgReading: BgReading) -> Bool {
        
        guard getConnectionStatus() == CBPeripheralState.connected else {
            trace("in writeBgReadingInfo, not connected ", log: log, type: .info)
            return false
        }
        
        // create packets to send slopeName
        guard let packetWithSlopeName = M5StackUtilities.splitTextInBLEPackets(text: bgReading.slopeName, maxBytesInOneBLEPacket: ConstantsM5Stack.maximumMBLEPacketsize, opCode: M5StackTransmitterOpCodeTx.writeSlopeNameTx.rawValue) else {
            trace("in writeBgReading, failed to create packets to send slopeName", log: log, type: .error)
            return false
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
            return false
        }
        
        // send reading and timestamp
        for packet in packetsWithReadingAndTimestamp {
            if !writeDataToPeripheral(data: packet, type: .withoutResponse) {
                trace("in writeBgReading, failed to send packet with reading and timestamp", log: log, type: .error)
                return false
            } else {
               trace("successfully written reading and timestamp to M5Stack", log: log, type: .info)
                return true
            }
        }
        
        // if we're here then it means there was no packet in packetsWithReadingAndTimestamp
        return false
    }
    
    /// writes textColor to the M5Stack
    /// - returns:
    ///     true if successfully transmitted to M5Stack, doesn't mean M5Stack did receive it, but chance is high
    func writeTextColor(textColor: M5StackColor) -> Bool {

        guard let textColorAsData = textColor.data else {
            trace("in writeTextColor, failed to create textColor as data ", log: log, type: .error)// looks like a software error
            return false
        }

        trace("in writeTextColor, attempting to send", log: log, type: .info)
        return writeDataToPeripheral(data: textColorAsData, opCode: .writeTextColorTx)
        
    }
    
    /// writes backgroundColor to the M5Stack
    /// - returns:
    ///     true if successfully transmitted to M5Stack, doesn't mean M5Stack did receive it, but chance is high
    func writeBackGroundColor(backGroundColor: M5StackColor) -> Bool {
        
        guard let colorAsData = backGroundColor.data else {
            trace("in writeBackGroundColor, failed to create backGroundColor as data ", log: log, type: .error)// looks like a software error
            return false
        }
        
        trace("in writeBackGroundColor, attempting to send", log: log, type: .info)
        return writeDataToPeripheral(data: colorAsData, opCode: .writeBackGroundColorTx)
        
    }
    
    /// writes backgroundColor to the M5Stack
    /// - returns:
    ///     true if successfully transmitted to M5Stack, doesn't mean M5Stack did receive it, but chance is high
    /// - parameters:
    ///     rotation value as expected by M5Stack, 0 is horizontal, 1
    func writeRotation(rotation: Int) -> Bool {
        
        trace("in writeRotation, attempting to send", log: log, type: .info)
        return writeDataToPeripheral(data: rotationValues[rotation].data, opCode: .writeRotationTx)
        
    }
    
    /// writes a wifi name
    /// - parameters:
    ///     - name : the wifi name or ssid, if nil then nothing is sent
    ///     - number : the wifi number (1 to 10)
    /// - returns: true if successfully called writeDataToPeripheral, doesn't mean it's been successfully received by the M5Stack
    ///
    /// byte 0 will be opcode, byte 1 and 2 packetnumber and number of packets respectively, byte 3 will number of the wifi converted to string, next bytes are the actually name
    func writeWifiName(name: String?, number: UInt8) -> Bool {
        
        guard let name = name else {
            trace("    name is nil", log: log, type: .info)
            return false
        }
        
        // we will send the number as a string followed by the actual wifiname
        let numberAndName = number.description + name
        
        // use writeStringToPeripheral to send it
        return writeStringToPeripheral(text: numberAndName, opCode: .writeWlanSSIDTx)
        
    }

    /// writes a wifi password
    /// - parameters:
    ///     - password : the wifi password, if nil then nothing is sent
    ///     - number : the wifi number (1 to 10)
    /// - returns: true if successfully called writeDataToPeripheral, doesn't mean it's been successfully received by the M5Stack
    ///
    /// byte 0 will be opcode, byte 1 and 2 packetnumber and number of packets respectively, byte 3 will number of the wifi converted to string, next bytes are the actually password
    func writeWifiPassword(password: String?, number: UInt8) -> Bool {
        
        guard let password = password else {
            trace("    password is nil", log: log, type: .info)
            return false
        }
        
        // we will send the number as a string followed by the actual password
        let numberAndPassword = number.description + password
        
        return writeStringToPeripheral(text: numberAndPassword, opCode: .writeWlanPassTx)
    }

    /// writes bloodglucose unit to M5Stack
    /// - returns: true if successfully called writeDataToPeripheral, doesn't mean it's been successfully received by the M5Stack
    func writeBloodGlucoseUnit(isMgDl: Bool) -> Bool {
        
        return writeStringToPeripheral(text: isMgDl ? "true":"false", opCode: .writemgdlTx)
    }
    
    /// writes nightscout url to M5Stack
    /// - parameters:
    ///     - url : the nightscout url, if nil then nothing is sent
    /// - returns: true if successfully called writeDataToPeripheral, doesn't mean it's been successfully received by the M5Stack
    func writeNightScoutUrl(url: String?) -> Bool {
        
        if let url = url {
            return writeStringToPeripheral(text: url, opCode: .writeNightScoutUrlTx)
        } else {return false}
    }
    
    /// writes nightscout apikey to M5Stack
    /// - parameters:
    ///     - apikey : the apikeyl, if nil then nothing is sent
    /// - returns: true if successfully called writeDataToPeripheral, doesn't mean it's been successfully received by the M5Stack
    func writeNightScoutAPIKey(apiKey: String?) -> Bool {
        
        if let apiKey = apiKey {
            return writeStringToPeripheral(text: apiKey, opCode: .writeNightScoutAPIKeyTx)
        } else {return false}
    }
    
    // MARK: - BluetoothTransmitterDelegate functions
    
    func centralManagerDidConnect(address: String?, name: String?) {
        m5StackBluetoothTransmitterDelegateFixed.didConnect(forM5Stack: m5Stack, address: address, name: name, bluetoothTransmitter: self)
        m5StackBluetoothTransmitterDelegateVariable?.didConnect(forM5Stack: m5Stack, address: address, name: name, bluetoothTransmitter: self)
    }
    
    func centralManagerDidFailToConnect(error: Error?) {
        trace("in centralManagerDidFailToConnect", log: log, type: .error)
    }
    
    func centralManagerDidUpdateState(state: CBManagerState) {
        
        if let m5Stack = m5Stack {
            
            m5StackBluetoothTransmitterDelegateFixed!.deviceDidUpdateBluetoothState(state: state, forM5Stack: m5Stack)
            m5StackBluetoothTransmitterDelegateVariable?.deviceDidUpdateBluetoothState(state: state, forM5Stack: m5Stack)
            
        } else {
            /// this bluetoothTransmitter is created to start scanning for a new, unknown M5Stack, so start scanning
            _ = startScanning()
        }
        
    }
    
    func centralManagerDidDisconnectPeripheral(error: Error?) {
        
        // can not write data anymore to the device
        isReadyToReceiveData = false
        
        if let m5Stack = m5Stack {
            m5StackBluetoothTransmitterDelegateFixed!.didDisconnect(forM5Stack: m5Stack)
            m5StackBluetoothTransmitterDelegateVariable?.didDisconnect(forM5Stack: m5Stack)
        }
        
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
            // received new password from M5Stack
            
            trace("    received new password, will store it", log: log, type: .error)
            
            guard let m5Stack = m5Stack else {return}// would be a software error if this happens
            
            blePasswordM5StackPacket.addNewPacket(value: value)
            
            if let newBlePassword = blePasswordM5StackPacket.getText() {
                
                self.blePassword = newBlePassword
                
                m5StackBluetoothTransmitterDelegateFixed!.newBlePassWord(newBlePassword: newBlePassword, forM5Stack: m5Stack)
                m5StackBluetoothTransmitterDelegateVariable?.newBlePassWord(newBlePassword: newBlePassword, forM5Stack: m5Stack)
                
            }

            // this is usually a case where M5Stack has restarted, so it needs to get time and timeoffset
            sendLocalTimeAndUTCTimeOffSetInSecondsToM5Stack()
            
            // this is the time when the M5stack is ready to receive readings or parameter updates
            isReadyToReceiveData = true
            m5StackBluetoothTransmitterDelegateFixed!.isReadyToReceiveData(m5Stack: m5Stack)
            m5StackBluetoothTransmitterDelegateVariable?.isReadyToReceiveData(m5Stack: m5Stack)
            
            
        case .authenticateSuccessRx:
            // received from M5Stack, need to inform delegates, send timestamp to M5Stack, and also set isReadyToReceiveData to true
            
            trace("    successfully authenticated", log: log, type: .error)
            
            guard let m5Stack = m5Stack else {return}// would be a software error if this happens
            
            // inform delegates
            m5StackBluetoothTransmitterDelegateFixed!.authentication(success: true, forM5Stack: m5Stack)
            m5StackBluetoothTransmitterDelegateVariable?.authentication(success: true, forM5Stack: m5Stack)

            // even though not requested, and even if M5Stack may already have it, send the local time
            sendLocalTimeAndUTCTimeOffSetInSecondsToM5Stack()
            
            // this is the time when the M5stack is ready to receive readings or parameter updates
            isReadyToReceiveData = true
            m5StackBluetoothTransmitterDelegateFixed!.isReadyToReceiveData(m5Stack: m5Stack)
            m5StackBluetoothTransmitterDelegateVariable?.isReadyToReceiveData(m5Stack: m5Stack)
            
        case .authenticateFailureRx:
            // received authentication failure, inform delegates
            if let m5Stack = m5Stack {
                m5StackBluetoothTransmitterDelegateFixed!.authentication(success: false, forM5Stack: m5Stack)
                m5StackBluetoothTransmitterDelegateVariable?.authentication(success: false, forM5Stack: m5Stack)
            }
            
        case .readBlePassWordError1Rx:
            if let m5Stack = m5Stack {
                m5StackBluetoothTransmitterDelegateFixed!.blePasswordMissing(forM5Stack: m5Stack)
                m5StackBluetoothTransmitterDelegateVariable?.blePasswordMissing(forM5Stack: m5Stack)
            }
            
        case .readBlePassWordError2Rx:
            if let m5Stack = m5Stack {
                
                m5StackBluetoothTransmitterDelegateFixed!.m5StackResetRequired(forM5Stack: m5Stack)
                m5StackBluetoothTransmitterDelegateVariable?.m5StackResetRequired(forM5Stack: m5Stack)
            }
            
        case .readTimeStampRx:
            // M5Stack is requesting for timestamp
            sendLocalTimeAndUTCTimeOffSetInSecondsToM5Stack()
            
        case .readAllParametersRx:
            // M5Stack is asking for all parameters
            
            guard let m5Stack = m5Stack else {return}// would be a software error if this happens
            
            m5StackBluetoothTransmitterDelegateFixed!.isAskingForAllParameters(m5Stack: m5Stack)
            m5StackBluetoothTransmitterDelegateVariable?.isAskingForAllParameters(m5Stack: m5Stack)
            
        }
    }

    // MARK: private helper functions
    
    /// sends local time in seconds since 1.1.1970 and also timeoffset from UTC in seconds. to M5Stack
    ///
    /// local time = UTC time + offset /// UTC time = local time - offset
    private func sendLocalTimeAndUTCTimeOffSetInSecondsToM5Stack() {
        
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
    
    /// handles common functions when writing data to M5Stack :
    /// - if no connection returns false
    /// - calls writeDataToPeripheral(data: Data, type: CBCharacteristicWriteType) and returns the result
    private func writeDataToPeripheral(data: Data, opCode : M5StackTransmitterOpCodeTx) -> Bool {
        
        guard getConnectionStatus() == CBPeripheralState.connected else {
            trace("    not connected ", log: log, type: .info)
            return false
        }
        
        // initialize dataToSend
        var dataToSend = Data()
        
        // add opcode
        dataToSend.append(opCode.rawValue.data)
        
        // add textcolor as uint16
        dataToSend.append(data)
        
        // send
        if !writeDataToPeripheral(data: dataToSend, type: .withoutResponse) {
            trace("    failed to send", log: log, type: .error)
            return false
        } else {
            trace("    sent", log: log, type: .error)
            return true
        }

    }
    
    private func writeStringToPeripheral(text: String, opCode : M5StackTransmitterOpCodeTx) -> Bool {
        
        // create packets to send with offset
        guard let packetsWithOffset = M5StackUtilities.splitTextInBLEPackets(text: text, maxBytesInOneBLEPacket: ConstantsM5Stack.maximumMBLEPacketsize, opCode: opCode.rawValue) else {
            trace("   failed to create packets for sending string", log: log, type: .error)
            return false
        }
        
        // initialize result
        var success = true
        
        // send the packets
        for packet in packetsWithOffset {
            if !writeDataToPeripheral(data: packet, type: .withoutResponse) {
                trace("    failed to send packet", log: log, type: .error)
                success = false
                break
            } else {
                trace("    successfully sent packet to M5Stack", log: log, type: .info)
            }
        }

        return success
    }
    
}
