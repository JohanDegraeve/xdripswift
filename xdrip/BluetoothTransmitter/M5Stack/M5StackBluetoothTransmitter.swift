import Foundation
import CoreBluetooth
import os

/// bluetoothTransmitter for an M5Stack
/// - will start scanning as soon as created or as soon as bluetooth is switched on
/// - there's only one characteristic which is used for write and notify, not read. To get data from the M5Stack, xdrip app will write a specific opcode, then M5Stack will reply and the reply will arrive as notify. So we don't use .withResponse
@objcMembers
final class M5StackBluetoothTransmitter: BluetoothTransmitter {
    
    // MARK: - public properties
    
    /// M5StackBluetoothTransmitter can be used for bluetoothPeripheralType's M5Stack or M5StickC. We need to store the type for which it is being used
    public let bluetoothPeripheralType: BluetoothPeripheralType

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
    private var blePasswordM5StackPacket:M5StackPacket?
    
    /// is the transmitter ready to receive data like parameter updates or reading values
    private(set) var isReadyToReceiveData: Bool = false
    
    /// possible rotation values, , the value is how it will be sent to the M5Stack but not  how it's stored in the M5Stack object - In the M5Stack object we store an Int value which is used as index in rotationValues and rotationStrings
    private let rotationValues: [UInt16] = [ 1, 2, 3, 0]
    
    public weak var m5StackBluetoothTransmitterDelegate: M5StackBluetoothTransmitterDelegate?

    // MARK: - initializer

    /// - parameters:
    ///     - address: if already connected before, then give here the address that was received during previous connect, if not give nil
    ///     - name : if already connected before, then give here the name that was received during previous connect, if not give nil
    ///     - m5StackBluetoothTransmitterDelegate : the M5StackBluetoothTransmitterDelegate
    ///     - bluetoothTransmitterDelegate : BluetoothTransmitterDelegate
    ///     - blePassword : optional. If nil then xdrip will send a M5StackReadBlePassWordTxMessage to the M5Stack, so this would be a case where the M5Stack (all M5Stacks managed by xdrip) do not have a fixed blepassword
    ///     - bluetoothPeripheralType : M5Stack or M5StickC
    ///     - bluetoothTransmitterDelegate : BluetoothTransmitterDelegate
    init(address:String?, name: String?, bluetoothTransmitterDelegate: BluetoothTransmitterDelegate, m5StackBluetoothTransmitterDelegate: M5StackBluetoothTransmitterDelegate, blePassword: String?, bluetoothPeripheralType: BluetoothPeripheralType) {
        
        // assign addressname and name, assume it's not been connected before
        var newAddressAndName:BluetoothTransmitter.DeviceAddressAndName = BluetoothTransmitter.DeviceAddressAndName.notYetConnected(expectedName: "M5Stack")
        
        // if address not nil, then we've already connected before to this device, we know the address and name
        if let address = address, let name = name {
            newAddressAndName = BluetoothTransmitter.DeviceAddressAndName.alreadyConnectedBefore(address: address, name: name)
        }
        
        // assign blePassword
        self.blePassword = blePassword
        
        // assign bluetoothPeripheralType
        self.bluetoothPeripheralType = bluetoothPeripheralType
        
        // assign m5StackBluetoothTransmitterDelegate
        self.m5StackBluetoothTransmitterDelegate = m5StackBluetoothTransmitterDelegate
        
        // call super
        super.init(addressAndName: newAddressAndName, CBUUID_Advertisement: nil, servicesCBUUIDs: [CBUUID(string: CBUUID_Service)], CBUUID_ReceiveCharacteristic: CBUUID_TxRxCharacteristic, CBUUID_WriteCharacteristic: CBUUID_TxRxCharacteristic, bluetoothTransmitterDelegate: bluetoothTransmitterDelegate)

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
            trace("in writeBgReadingInfo, not connected ", log: log, category: ConstantsLog.categoryM5StackBluetoothTransmitter, type: .info)
            return false
        }
        
        // create packets to send slopeName
        guard let packetWithSlopeName = M5StackUtilities.splitTextInBLEPackets(text: bgReading.slopeName, maxBytesInOneBLEPacket: ConstantsM5Stack.maximumMBLEPacketsize, opCode: M5StackTransmitterOpCodeTx.writeSlopeNameTx.rawValue) else {
            trace("in writeBgReading, failed to create packets to send slopeName", log: log, category: ConstantsLog.categoryM5StackBluetoothTransmitter, type: .error)
            return false
        }
        
        // send slopename
        for packet in packetWithSlopeName {
            if !writeDataToPeripheral(data: packet, type: .withoutResponse) {
                trace("in writeBgReading, failed to send packet with slopename", log: log, category: ConstantsLog.categoryM5StackBluetoothTransmitter, type: .error)
            } else {
                trace("successfully written slopename to M5Stack", log: log, category: ConstantsLog.categoryM5StackBluetoothTransmitter, type: .error)
            }
        }
        
       // create text to send, reading value, one blanc, timestamp in seconds
        let textToSend = Int(round(bgReading.calculatedValue)).description + " " + bgReading.timeStamp.toSecondsAsInt64().description
        
        // create packets to send reading and timestamp
        guard let packetsWithReadingAndTimestamp = M5StackUtilities.splitTextInBLEPackets(text: textToSend, maxBytesInOneBLEPacket: ConstantsM5Stack.maximumMBLEPacketsize, opCode: M5StackTransmitterOpCodeTx.bgReadingTx.rawValue) else {
            trace("in writeBgReading, failed to create packets to send reading and timestamp", log: log, category: ConstantsLog.categoryM5StackBluetoothTransmitter, type: .error)
            return false
        }
        
        // send reading and timestamp
        for packet in packetsWithReadingAndTimestamp {
            if !writeDataToPeripheral(data: packet, type: .withoutResponse) {
                trace("in writeBgReading, failed to send packet with reading and timestamp", log: log, category: ConstantsLog.categoryM5StackBluetoothTransmitter, type: .error)
                return false
            } else {
               trace("successfully written reading and timestamp to M5Stack", log: log, category: ConstantsLog.categoryM5StackBluetoothTransmitter, type: .info)
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
            trace("in writeTextColor, failed to create textColor as data ", log: log, category: ConstantsLog.categoryM5StackBluetoothTransmitter, type: .error)// looks like a software error
            return false
        }

        trace("in writeTextColor, attempting to send", log: log, category: ConstantsLog.categoryM5StackBluetoothTransmitter, type: .info)
        return writeDataToPeripheral(data: textColorAsData, opCode: .writeTextColorTx)
        
    }
    
    /// writes backgroundColor to the M5Stack
    /// - returns:
    ///     true if successfully transmitted to M5Stack, doesn't mean M5Stack did receive it, but chance is high
    func writeBackGroundColor(backGroundColor: M5StackColor) -> Bool {
        
        guard let colorAsData = backGroundColor.data else {
            trace("in writeBackGroundColor, failed to create backGroundColor as data ", log: log, category: ConstantsLog.categoryM5StackBluetoothTransmitter, type: .error)// looks like a software error
            return false
        }
        
        trace("in writeBackGroundColor, attempting to send", log: log, category: ConstantsLog.categoryM5StackBluetoothTransmitter, type: .info)
        return writeDataToPeripheral(data: colorAsData, opCode: .writeBackGroundColorTx)
        
    }
    
    /// writes backgroundColor to the M5Stack
    /// - returns:
    ///     true if successfully transmitted to M5Stack, doesn't mean M5Stack did receive it, but chance is high
    /// - parameters:
    ///     rotation value as expected by M5Stack, 0 is horizontal, 1
    func writeRotation(rotation: Int) -> Bool {
        trace("in writeRotation, attempting to send", log: log, category: ConstantsLog.categoryM5StackBluetoothTransmitter, type: .info)
        guard rotation >= 0 && rotation < rotationValues.count else {
            trace("in writeRotation, invalid rotation index %{public}@", log: log, category: ConstantsLog.categoryM5StackBluetoothTransmitter, type: .error, String(rotation))
            return false
        }
        return writeDataToPeripheral(data: rotationValues[rotation].data, opCode: .writeRotationTx)
    }
    
    /// writes brightness to the M5Stack
    /// - returns:
    ///     true if successfully transmitted to M5Stack, doesn't mean M5Stack did receive it, but chance is high
    /// - parameters:
    ///     brightness value as expected by M5Stack, between 0 and 100
    func writeBrightness(brightness: Int) -> Bool {
        
        trace("in writeBrightness, attempting to send", log: log, category: ConstantsLog.categoryM5StackBluetoothTransmitter, type: .info)
        return writeDataToPeripheral(data: brightness.toData(), opCode: .writeBrightnessTx)
        
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
            trace("    name is nil", log: log, category: ConstantsLog.categoryM5StackBluetoothTransmitter, type: .info)
            return false
        }
        guard (1...10).contains(number) else {
            trace("    wifi slot out of range (1-10): %{public}@", log: log, category: ConstantsLog.categoryM5StackBluetoothTransmitter, type: .error, String(number))
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
            trace("    password is nil", log: log, category: ConstantsLog.categoryM5StackBluetoothTransmitter, type: .info)
            return false
        }
        guard (1...10).contains(number) else {
            trace("    wifi slot out of range (1-10): %{public}@", log: log, category: ConstantsLog.categoryM5StackBluetoothTransmitter, type: .error, String(number))
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
    
    /// writes value of connectToWiFi
    /// - returns: true if successfully called writeDataToPeripheral, doesn't mean it's been successfully received by the M5Stack
    func writeConnectToWiFi(connect: Bool) -> Bool {
        
        return writeStringToPeripheral(text: connect ? "true":"false", opCode: .writeConnectToWiFiTx)
        
    }
    
    /// writes nightscout url to M5Stack
    /// - parameters:
    ///     - url : the nightscout url, if nil then nothing is sent
    /// - returns: true if successfully called writeDataToPeripheral, doesn't mean it's been successfully received by the M5Stack
    func writeNightscoutUrl(url: String?) -> Bool {
        
        if let url = url {
            return writeStringToPeripheral(text: url, opCode: .writeNightscoutUrlTx)
        } else {return false}
        
    }
    
    /// writes nightscout apikey to M5Stack
    /// - parameters:
    ///     - apikey : the apikeyl, if nil then nothing is sent
    /// - returns: true if successfully called writeDataToPeripheral, doesn't mean it's been successfully received by the M5Stack
    func writeNightscoutAPIKey(apiKey: String?) -> Bool {
        
        if let apiKey = apiKey {
            return writeStringToPeripheral(text: apiKey, opCode: .writeNightscoutAPIKeyTx)
        } else {return false}
        
    }
    
    /// to ask batteryLevel to M5Stack
    func readBatteryLevel() -> Bool {
        return writeOpCodeToPeripheral(opCode: .readBatteryLevelTx)
    }
    
    /// to ask powerOff
    func powerOff() -> Bool {
        return writeOpCodeToPeripheral(opCode: .writepowerOffTx)
    }
    
    override func prepareForRelease() {
        // Clear base CB delegates + unsubscribe common receiveCharacteristic synchronously on main
        super.prepareForRelease()
        // M5Stack-specific: clear transient state synchronously on main
        let tearDown = {
            self.blePasswordM5StackPacket = nil
            self.isReadyToReceiveData = false
        }
        if Thread.isMainThread {
            tearDown()
        } else {
            DispatchQueue.main.sync(execute: tearDown)
        }
    }

    deinit {
        // Delegate cleanup is handled in the base class; just clear packet buffer
        blePasswordM5StackPacket = nil
    }

    // MARK: - overriden BluetoothTransmitter functions
    
    override func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        
        super.centralManager(central, didDisconnectPeripheral: peripheral, error: error)
        
        // can not write data anymore to the device
        isReadyToReceiveData = false
        
    }
    
    override func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        
        super.peripheral(peripheral, didUpdateNotificationStateFor: characteristic, error: error)
        
        // check if subscribe to notifications succeeded
        if characteristic.isNotifying {
            
            // time to send password to M5Stack, if there isn't one known in the settings then we assume that the user didn't set a password in the M5Stack config (M5NS.INI) and that we didn't connect to this M5Stack yet after the last M5Stack restart. So in that case we will request a random password
            if let blePassword = blePassword, let authenticateTxMessageData = M5StackAuthenticateTXMessage(password: blePassword).data {
                
                if !writeDataToPeripheral(data: authenticateTxMessageData, type: .withoutResponse) {
                    trace("failed to send authenticateTx to M5Stack", log: log, category: ConstantsLog.categoryM5StackBluetoothTransmitter, type: .error)
                } else {
                    trace("successfully sent authenticateTx to M5Stack", log: log, category: ConstantsLog.categoryM5StackBluetoothTransmitter, type: .error)
                }
                
            } else {
                
                if !writeDataToPeripheral(data: M5StackReadBlePassWordTxMessage().data, type: .withoutResponse) {
                    trace("failed to send readBlePassWordTx to M5Stack", log: log, category: ConstantsLog.categoryM5StackBluetoothTransmitter, type: .error)
                } else {
                    trace("successfully sent readBlePassWordTx to M5Stack", log: log, category: ConstantsLog.categoryM5StackBluetoothTransmitter, type: .error)
                }
                
            }
            
        } else {
            trace("in peripheralDidUpdateNotificationStateFor, failed to subscribe for characteristic %{public}@", log: log, category: ConstantsLog.categoryM5StackBluetoothTransmitter, type: .error, characteristic.uuid.description)
        }

    }
    
    override func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        
        super.peripheral(peripheral, didUpdateValueFor: characteristic, error: error)
     
        //check if value is not nil
        guard let value = characteristic.value else {
            trace("in peripheral didUpdateValueFor, characteristic.value is nil", log: log, category: ConstantsLog.categoryM5StackBluetoothTransmitter, type: .info)
            return
        }
        
        // value length should be at least 1
        guard value.count > 0 else {
            trace("    value length is 0, no further processing", log: log, category: ConstantsLog.categoryM5StackBluetoothTransmitter, type: .error)
            return
        }
        
        guard let opCode = M5StackTransmitterOpCodeRx(rawValue: value[0]) else {
            trace("    failed to create opCode", log: log, category: ConstantsLog.categoryM5StackBluetoothTransmitter, type: .error)
            return
        }
        trace("    opcode = %{public}@", log: log, category: ConstantsLog.categoryM5StackBluetoothTransmitter, type: .info, opCode.description)
        
        switch opCode {
            
        case .readBlePassWordRx:
            // received new password from M5Stack
            
            trace("    received new password, will store it", log: log, category: ConstantsLog.categoryM5StackBluetoothTransmitter, type: .error)
            
            if blePasswordM5StackPacket == nil {
                blePasswordM5StackPacket = M5StackPacket()
            }
            blePasswordM5StackPacket!.addNewPacket(value: value)
            
            if let newBlePassword = blePasswordM5StackPacket!.getText() {
                
                self.blePassword = newBlePassword
                
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    self.m5StackBluetoothTransmitterDelegate?.newBlePassWord(newBlePassword: newBlePassword, m5StackBluetoothTransmitter: self)
                }
                
                // memory clean up
                blePasswordM5StackPacket = nil
                
            }
            
            finalizeConnectionSetup()
            
        case .authenticateSuccessRx:
            // received from M5Stack, need to inform delegates, send timestamp to M5Stack, and also set isReadyToReceiveData to true
            
            trace("    successfully authenticated", log: log, category: ConstantsLog.categoryM5StackBluetoothTransmitter, type: .error)
            
            // inform delegates
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.m5StackBluetoothTransmitterDelegate?.authentication(success: true, m5StackBluetoothTransmitter: self)
            }
            
            // final steps after successful communication
            finalizeConnectionSetup()
            
        case .authenticateFailureRx:
            // received authentication failure, inform delegates
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.m5StackBluetoothTransmitterDelegate?.authentication(success: false, m5StackBluetoothTransmitter: self)
            }
            
        case .readBlePassWordError1Rx:
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.m5StackBluetoothTransmitterDelegate?.blePasswordMissing(m5StackBluetoothTransmitter: self)
            }
            
        case .readBlePassWordError2Rx:
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.m5StackBluetoothTransmitterDelegate?.m5StackResetRequired(m5StackBluetoothTransmitter: self)
            }
            
        case .readTimeStampRx:
            
            // M5Stack is requesting for timestamp
            sendLocalTimeAndUTCTimeOffSetInSecondsToM5Stack()
            
        case .readAllParametersRx:
            
            // M5Stack is asking for all parameters
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.m5StackBluetoothTransmitterDelegate?.isAskingForAllParameters(m5StackBluetoothTransmitter: self)
            }
            
        case .readBatteryLevelRx:
            
            guard value.count >= 2 else {
                
                trace("   value length should be minimum 2", log: log, category: ConstantsLog.categoryM5StackBluetoothTransmitter, type: .error)
                return
            }
            
            let receivedBatteryLevel = Int(value[1])
            
            // M5Stack is sending batteryLevel, which is in the second byte
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.m5StackBluetoothTransmitterDelegate?.receivedBattery(level: receivedBatteryLevel, m5StackBluetoothTransmitter: self)
            }
            
        case .heartbeat:
            // this is a trigger for calling the heartbeat
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.bluetoothTransmitterDelegate?.heartBeat()
            }
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
            trace("   failed to create packets for sending offset", log: log, category: ConstantsLog.categoryM5StackBluetoothTransmitter, type: .error)
            return
        }
        
        // send the packets with offset
        for packet in packetsWithOffset {
            if !writeDataToPeripheral(data: packet, type: .withoutResponse) {
                trace("    failed to send packet with offset to M5Stack", log: log, category: ConstantsLog.categoryM5StackBluetoothTransmitter, type: .error)
            } else {
                trace("    successfully sent packet with offset to M5Stack", log: log, category: ConstantsLog.categoryM5StackBluetoothTransmitter, type: .error)
            }
        }
        
        // create packets to send with local time
        guard let packetsWithLocalTime = M5StackUtilities.splitTextInBLEPackets(text: localTimeInSeconds.description, maxBytesInOneBLEPacket: ConstantsM5Stack.maximumMBLEPacketsize, opCode: M5StackTransmitterOpCodeTx.writeTimeStampTx.rawValue) else {
            trace("   failed to create packets for sending timestamp", log: log, category: ConstantsLog.categoryM5StackBluetoothTransmitter, type: .error)
            return
        }
        
        // send packets with localtime
        for packet in packetsWithLocalTime {
            if !writeDataToPeripheral(data: packet, type: .withoutResponse) {
                trace("    failed to send packet with local timestamp to M5Stack", log: log, category: ConstantsLog.categoryM5StackBluetoothTransmitter, type: .error)
            } else {
                trace("    successfully sent packet with local timestamp to M5Stack", log: log, category: ConstantsLog.categoryM5StackBluetoothTransmitter, type: .error)
            }
        }
        
    }
    
    /// handles common functions when writing data to M5Stack :
    /// - if no connection returns false
    /// - calls writeDataToPeripheral(data: Data, type: CBCharacteristicWriteType) and returns the result
    private func writeDataToPeripheral(data: Data, opCode : M5StackTransmitterOpCodeTx) -> Bool {
        
        guard getConnectionStatus() == CBPeripheralState.connected else {
            trace("    not connected ", log: log, category: ConstantsLog.categoryM5StackBluetoothTransmitter, type: .info)
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
            trace("    failed to send", log: log, category: ConstantsLog.categoryM5StackBluetoothTransmitter, type: .error)
            return false
        } else {
            trace("    sent", log: log, category: ConstantsLog.categoryM5StackBluetoothTransmitter, type: .error)
            return true
        }

    }
    
    private func writeOpCodeToPeripheral(opCode : M5StackTransmitterOpCodeTx) ->  Bool {
        
        // initialize dataToSend
        var dataToSend = Data()
        
        // add opcode
        dataToSend.append(opCode.rawValue.data)
        
        if !writeDataToPeripheral(data: dataToSend, type: .withoutResponse) {
            trace("    failed to send opcode", log: log, category: ConstantsLog.categoryM5StackBluetoothTransmitter, type: .error)
            return false
        } else {
            trace("    successfully sent opcode to M5Stack", log: log, category: ConstantsLog.categoryM5StackBluetoothTransmitter, type: .info)
            return true
        }
        
    }
    
    private func writeStringToPeripheral(text: String, opCode : M5StackTransmitterOpCodeTx) -> Bool {
        
        // create packets to send with offset
        guard let packetsWithOffset = M5StackUtilities.splitTextInBLEPackets(text: text, maxBytesInOneBLEPacket: ConstantsM5Stack.maximumMBLEPacketsize, opCode: opCode.rawValue) else {
            trace("   failed to create packets for sending string", log: log, category: ConstantsLog.categoryM5StackBluetoothTransmitter, type: .error)
            return false
        }
        
        // initialize result
        var success = true
        
        // send the packets
        for packet in packetsWithOffset {
            if !writeDataToPeripheral(data: packet, type: .withoutResponse) {
                trace("    failed to send packet", log: log, category: ConstantsLog.categoryM5StackBluetoothTransmitter, type: .error)
                success = false
                break
            } else {
                trace("    successfully sent packet to M5Stack", log: log, category: ConstantsLog.categoryM5StackBluetoothTransmitter, type: .info)
            }
        }

        return success
    }
    
    /// final communication steps when authentication is done
    private func finalizeConnectionSetup() {
        
        // even though not requested, and even if M5Stack may already have it, send the local time
        sendLocalTimeAndUTCTimeOffSetInSecondsToM5Stack()
        
        // read batteryLevel
        _ = readBatteryLevel()
        
        // this is the time when the M5stack is ready to receive readings or parameter updates
        isReadyToReceiveData = true
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.m5StackBluetoothTransmitterDelegate?.isReadyToReceiveData(m5StackBluetoothTransmitter: self)
        }
    }
    
}
