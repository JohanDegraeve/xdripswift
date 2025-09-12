import Foundation
import CoreBluetooth
import os

@objcMembers
class CGMBluconTransmitter: BluetoothTransmitter {
    
    // MARK: - properties
    
    /// CGMBubbleTransmitterDelegate
    public weak var cGMBluconTransmitterDelegate: CGMBluconTransmitterDelegate?

    /// will be used to pass back bluetooth and cgm related events
    private(set) weak var cgmTransmitterDelegate:CGMTransmitterDelegate?
    
    /// Blucon Service
    private let CBUUID_BluconService = "436A62C0-082E-4CE8-A08B-01D81F195B24"
    
    /// receive characteristic
    private let CBUUID_ReceiveCharacteristic_Blucon: String = "436A0C82-082E-4CE8-A08B-01D81F195B24"
    
    /// write characteristic
    private let CBUUID_WriteCharacteristic_Blucon: String = "436AA6E9-082E-4CE8-A08B-01D81F195B24"
    
    /// if value starts with this string, then it's assume that a battery low indication is sent by the Blucon
    private let unknownCommand2BatteryLowIndicator = "8bda02"
    
    /// is nonFixed enabled for the transmitter or not
    private var nonFixedSlopeEnabled: Bool
    
    /// for trace
    private let log = OSLog(subsystem: ConstantsLog.subSystem, category: ConstantsLog.categoryBlucon)
    
    /// timestamp of last received reading. When a new packet is received, then only the more recent readings will be treated
    private var timeStampLastBgReading:Date?
    
    // waiting successful pairing yes or not
    private var waitingSuccessfulPairing:Bool = false
    
    // current sensor serial number, if nil then it's not known yet
    private var sensorSerialNumber:String?
    
    /// used as parameter in call to cgmTransmitterDelegate.cgmTransmitterInfoReceived, when there's no glucosedata to send
    private var emptyArray: [GlucoseData] = []
    
    /// timestamp when wakeUpResponse was sent to Blucon
    private var timeStampLastWakeUpResponse:Date?
    
    /// BluconACKResponse will come in two different situations
    /// - after we have sent an ackwakeup command
    /// - after we have a sleep command
    /// shouldSendUnknown1CommandAfterReceivingWakeUpResponse and timeStampLastWakeUpResponsetime work together to determine the case
    private var shouldSendUnknown1CommandAfterReceivingBluconAckResponse = true
    
    /// used when processing Blucon data packet
    private var timestampFirstPacketReception:Date?
    
    // how long to wait for next packet before considering the session as failed
    private let maxWaitForHistoricDataInSeconds = 5.0

    // receive buffer for Blucon packets
    private var rxBuffer:Data
    
    // used in Blucon protocol
    private var nowGlucoseOffset:UInt8 = 0
    
    // used in Blucon protocol - corresponds to m_getNowGlucoseDataCommand
    private var waitingForGlucoseData = false
    
    // timestamp of sending singleBlockInfoPrefix command, if time of receiving singleBlockInfoResponsePrefix is too late, then reading will be ignored
    private var timeStampOfSendingSingleBlockInfoPrefix:Date?
    
    /// instance of libreDataParser
    private let libreDataParser: LibreDataParser
    
    // MARK: - public functions
    
    /// - parameters:
    ///     - address: if already connected before, then give here the address that was received during previous connect, if not give nil
    ///     - name: if already connected before, then give here the address that was received during previous connect, if not give nil
    ///     - transmitterID: expected transmitterID
    ///     - cGMTransmitterDelegate : CGMTransmitterDelegate
    ///     - sensorSerialNumber : is needed to allow detection of a new sensor.
    ///     - bluetoothTransmitterDelegate : a NluetoothTransmitterDelegate
    ///     - cGMTransmitterDelegate : a CGMTransmitterDelegate
    init(address:String?, name: String?, transmitterID:String, bluetoothTransmitterDelegate: BluetoothTransmitterDelegate, cGMBluconTransmitterDelegate: CGMBluconTransmitterDelegate, cGMTransmitterDelegate:CGMTransmitterDelegate, sensorSerialNumber:String?, nonFixedSlopeEnabled: Bool?) {
        
        // assign addressname and name or expected devicename
        // start by using expected device name
        var newAddressAndName:BluetoothTransmitter.DeviceAddressAndName = BluetoothTransmitter.DeviceAddressAndName.notYetConnected(expectedName: CGMBluconTransmitter.createExpectedDeviceName(transmitterIdSetByUser: transmitterID))
        if let address = address {
            // address not nil, means it already connected before, use that address
            newAddressAndName = BluetoothTransmitter.DeviceAddressAndName.alreadyConnectedBefore(address: address, name: name)
        }
        
        // initialize sensorSerialNumber
        self.sensorSerialNumber = sensorSerialNumber
        
        // initialize cGMBluconTransmitterDelegate
        self.cGMBluconTransmitterDelegate = cGMBluconTransmitterDelegate
        
        // initialize rxbuffer
        rxBuffer = Data()
        
        // initialize nonFixedSlopeEnabled
        self.nonFixedSlopeEnabled = nonFixedSlopeEnabled ?? false

        // initiliaze LibreDataParser
        self.libreDataParser = LibreDataParser()

        // initialize
        super.init(addressAndName: newAddressAndName, CBUUID_Advertisement: nil, servicesCBUUIDs: [CBUUID(string: CBUUID_BluconService)], CBUUID_ReceiveCharacteristic: CBUUID_ReceiveCharacteristic_Blucon, CBUUID_WriteCharacteristic: CBUUID_WriteCharacteristic_Blucon, bluetoothTransmitterDelegate: bluetoothTransmitterDelegate)

        //assign CGMTransmitterDelegate
        cgmTransmitterDelegate = cGMTransmitterDelegate
        
    }
    
    // MARK: - private helper functions
    
    /// will check if the transmitter id as set by the user is complete, and if not complete it
    ///
    /// user may just add the digits in which case this function will add BLU... with a number of 0's
    private static func createExpectedDeviceName(transmitterIdSetByUser: String) -> String {
        
        var returnValue = transmitterIdSetByUser
        
        if !returnValue.uppercased().startsWith("BLU") {
            while returnValue.count < 5 {
                returnValue = "0" + returnValue
            }
            returnValue = "BLU" + returnValue
        }

        return returnValue
    }
    
    /// writes command to blucon, withResponse, and also logs the command
    private func sendCommandToBlucon(opcode:BluconTransmitterOpCode) {

        trace("    send opcode %{public}@ to Blucon", log: log, category: ConstantsLog.categoryBlucon, type: .info, opcode.description)
        
        if let bytes = Data(hexadecimalString: opcode.rawValue) {
            _ = writeDataToPeripheral(data: bytes, type: .withResponse)
        } else {
            trace("    invalid opcode hex string: %{public}@", log: log, category: ConstantsLog.categoryBlucon, type: .error, opcode.rawValue)
        }

    }
    
    /// reset rxBuffer, reset timestampFirstPacketReception, stop packetRxMonitorTimer
    private func resetRxBuffer() {
        rxBuffer = Data()
        timestampFirstPacketReception = Date()
    }
    
    /// process new historic data block received from Blucon, one block is the contents when receiving multipleBlockResponseIndex, inclusive the opcode - this is used if we ask all Libre data from the transmitter, which includes sensorTime and sensorStatus
    /// - returns:
    ///     - did receive all data yes or no, if yes, then blucon can go to sleep
    /// also calls cGMTransmitterDelegate with result of new readings
    private func handleNewHistoricData(block: Data) -> Bool {
        
        //check if buffer needs to be reset
        if let timestampFirstPacketReception = timestampFirstPacketReception {
            if (Date() > timestampFirstPacketReception.addingTimeInterval(maxWaitForHistoricDataInSeconds - 1)) {
                trace("in handleNewHistoricData, more than %{public}@ seconds since last update - or first update since app launch, resetting buffer", log: log, category: ConstantsLog.categoryBlucon, type: .info, String(Int(maxWaitForHistoricDataInSeconds)))
                resetRxBuffer()
            }
        }

        //add new packet to buffer, ignoring the opcode (2 bytes), the number of the next block (1 byte), and the number of blocks in the data (1 byte)
        guard block.count >= 4 else {
            trace("in handleNewHistoricData, block too short (len=%{public}@)", log: log, category: ConstantsLog.categoryBlucon, type: .error, String(block.count))
            return false
        }
        rxBuffer.append(block[4..<block.count])
        
        // if rxBuffer has reached minimum lenght, then start processing
        if rxBuffer.count >= 344 {
            
            trace("in handleNewHistoricData, reached minimum length, processing data", log: log, category: ConstantsLog.categoryBlucon, type: .info)
            
            // crc check
            guard Crc.LibreCrc(data: &rxBuffer, headerOffset: 0, libreSensorType: nil) else {
                
                trace("    crc check failed, no further processing", log: log, category: ConstantsLog.categoryBlucon, type: .error)
                
                // transmitter can go to sleep
                return true
                
            }

            libreDataParser.libreDataProcessor(libreSensorSerialNumber: sensorSerialNumber, patchInfo: nil, webOOPEnabled: isWebOOPEnabled(), libreData: rxBuffer, cgmTransmitterDelegate: cgmTransmitterDelegate, dataIsDecryptedToLibre1Format: false, testTimeStamp: nil, completionHandler: { (sensorState: LibreSensorState?, xDripError: XdripError?) in
                
            })
            
            //reset the buffer
            resetRxBuffer()
            
            // transmitter can go to sleep
            return true
            
        }

        // transmitter should send more data
        return false
    }
    
    private func blockNumberForNowGlucoseData(input:Data) -> String? {
        
        guard input.count > 5 else { return nil }
        var nowGlucoseIndex2 = Int(input[5])
        
        // calculate byte position in sensor body
        nowGlucoseIndex2 = (nowGlucoseIndex2 * 6) + 4;
        
        // decrement index to get the index where the last valid BG reading is stored
        nowGlucoseIndex2 -= 6;
        
        // adjust round robin
        if (nowGlucoseIndex2 < 4) {
            nowGlucoseIndex2 = nowGlucoseIndex2 + 96
        }

        // calculate the absolute block number which correspond to trend index
        let nowGlucoseIndex3 = 3 + (nowGlucoseIndex2/8)
        
        let nowGlucoseDataAsHexString = nowGlucoseIndex3.description

        return nowGlucoseDataAsHexString
        
    }
    
    private func nowGetGlucoseValue(input:Data) -> Double {
        
        // example 8BDE07DB010F04C868DB01
        // value 1 = 0F
        // value 2 = 04
        //rawGlucose = (input[3 + nowGlucoseOffset + 1] & 0x0F) * 256 + input[3 + nowGlucoseOffset] = 1039
        let base = 3 + Int(nowGlucoseOffset)
        
        guard input.count > base + 1 else { return 0 }
        
        let value1 = input[base]
        let value2 = input[base + 1]
        
        let rawGlucose = Double((UInt16(value2 & 0x0F)<<8) | UInt16(value1 & 0xFF))
        
        // rescale for Libre
        let curGluc = rawGlucose * ConstantsBloodGlucose.libreMultiplier
        
        return(curGluc)
    }
    
    override func prepareForRelease() {
        // Clear base CB delegates + unsubscribe common receiveCharacteristic synchronously on main
        super.prepareForRelease()
        // Blucon-specific: clear rx buffer and reset session state
        let tearDown = {
            self.rxBuffer = Data()
            self.waitingForGlucoseData = false
            self.timestampFirstPacketReception = nil
            self.timeStampLastWakeUpResponse = nil
            self.shouldSendUnknown1CommandAfterReceivingBluconAckResponse = false
        }
        if Thread.isMainThread {
            tearDown()
        } else {
            DispatchQueue.main.sync(execute: tearDown)
        }
    }

    // MARK: - overriden  BluetoothTransmitter functions
    
    override func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        
        super.peripheral(peripheral, didUpdateNotificationStateFor: characteristic, error: error)
        
        trace("in peripheralDidUpdateNotificationStateFor", log: log, category: ConstantsLog.categoryBlucon, type: .info)
        
        // check if error occurred
        if let error = error {
            
            // no need to log the error, it's already logged in BluetoothTransmitter
            
            // check if it's an encryption error, if so call cGMTransmitterDelegate
            if error.localizedDescription.uppercased().contains(find: "ENCRYPTION IS INSUFFICIENT") {
                
                // inform delegate on main
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    self.bluetoothTransmitterDelegate?.transmitterNeedsPairing(bluetoothTransmitter: self)
                }

                waitingSuccessfulPairing = true
            }
        } else {
            if waitingSuccessfulPairing {
                // inform delegate on main
                DispatchQueue.main.async { [weak self] in
                    self?.bluetoothTransmitterDelegate?.pairingFailed()
                }
                waitingSuccessfulPairing = false
            }
        }

    }
    
    override func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        
        super.peripheral(peripheral, didUpdateValueFor: characteristic, error: error)
        
        // log the received characteristic value
        trace("in peripheralDidUpdateValueFor with characteristic UUID = %{public}@", log: log, category: ConstantsLog.categoryBlucon, type: .info, characteristic.uuid.uuidString)
        
        // this is only applicable the very first time that blucon connects and pairing is done
        if waitingSuccessfulPairing {
            DispatchQueue.main.async { [weak self] in
                self?.bluetoothTransmitterDelegate?.successfullyPaired()
            }
            waitingSuccessfulPairing = false
        }
        
        // check if error occured
        if let error = error {
            trace("   error: %{public}@", log: log, category: ConstantsLog.categoryBlucon, type: .error , error.localizedDescription)
        }
        
        if let value = characteristic.value {
            
            // convert to string and log the value
            let valueAsString = value.hexEncodedString()
            
            // get Opcode
            if let opCode = BluconTransmitterOpCode(withOpCodeValue: valueAsString) {
                
                trace("    received opcode = %{public}@ from Blucon", log: log, category: ConstantsLog.categoryBlucon, type: .info, opCode.description)
                
                switch opCode {
                    
                case .getPatchInfoRequest, .wakeUpResponse, .sleep, .unknown1Command, .unknown2Command, .getHistoricDataAllBlocksCommand, .getNowDataIndex, .singleBlockInfoPrefix:
                    // these are commands that app sends to Blucon, shouldn't receive any of them
                    break
                    
                case .wakeUpRequest:
                    
                    // start by setting waitingForGlucoseData to false, it might still have value true due to protocol error
                    waitingForGlucoseData = false
                    
                    // send getPatchInfoRequest
                    sendCommandToBlucon(opcode: BluconTransmitterOpCode.getPatchInfoRequest)
                    
                    // by default set battery level to 100
                    DispatchQueue.main.async { [weak self] in
                        guard let self = self else { return }
                        let empty = self.emptyArray
                        var copy = empty
                        self.cgmTransmitterDelegate?.cgmTransmitterInfoReceived(glucoseData: &copy, transmitterBatteryInfo: TransmitterBatteryInfo.percentage(percentage: 100), sensorAge: nil)
                        self.cGMBluconTransmitterDelegate?.received(batteryLevel: 100, from: self)
                    }

                case .error14:
                    
                    // Blucon didn't receive the next command it was waiting for, need to wait 5 minutes
                    trace("    Timeout received, need to  wait 5 minutes or push button to restart!", log: log, category: ConstantsLog.categoryBlucon, type: .error)
                    
                    // and send Blucon to sleep
                    sendCommandToBlucon(opcode: .sleep)
                    
                case .sensorNotDetected:
                    
                    // Blucon didn't detect sensor, call cGMTransmitterDelegate on main
                    DispatchQueue.main.async { [weak self] in
                        self?.cgmTransmitterDelegate?.sensorNotDetected()
                    }
                    
                    // and send Blucon to sleep
                    sendCommandToBlucon(opcode: .sleep)
                    
                case .getPatchInfoResponse:
                    
                    // get serial number
                    let newSerialNumber = BluconUtilities.decodeSerialNumber(input: value)
                    
                    // verify serial number and if changed inform cGMTransmitterDelegate
                    if newSerialNumber != sensorSerialNumber {
                        
                        trace("    new sensor detected :  %{public}@", log: log, category: ConstantsLog.categoryBlucon, type: .info, newSerialNumber)
                        
                        sensorSerialNumber = newSerialNumber
                        
                        // inform cGMTransmitterDelegate about new sensor detected
                        // assign sensorStartDate, for this type of transmitter the sensorAge is passed in another call to cgmTransmitterDelegate
                        DispatchQueue.main.async { [weak self] in
                            guard let self = self else { return }
                            self.cgmTransmitterDelegate?.newSensorDetected(sensorStartDate: nil)
                            self.cGMBluconTransmitterDelegate?.received(serialNumber: self.sensorSerialNumber, from: self)
                        }
                        
                    }
                    
                    // read sensorState
                    guard value.count > 17 else {
                        trace("    getPatchInfoResponse too short (no state byte)", log: log, category: ConstantsLog.categoryBlucon, type: .error)
                        return
                    }
                    
                    let sensorState = LibreSensorState(stateByte: value[17])
                    
                    // if sensor is ready then send Ack, otherwise send sleep
                    if sensorState == LibreSensorState.ready {
                        
                        timeStampLastWakeUpResponse = Date()
                        shouldSendUnknown1CommandAfterReceivingBluconAckResponse = true
                        
                        sendCommandToBlucon(opcode: BluconTransmitterOpCode.wakeUpResponse)
                        
                    } else {
                        
                        trace("    sensorState =  %{public}@", log: log, category: ConstantsLog.categoryBlucon, type: .info, sensorState.description)
                        
                        sendCommandToBlucon(opcode: BluconTransmitterOpCode.sleep)
                        
                    }
                    
                    // inform cGMTransmitterDelegate about sensorSerialNumber and sensorState (on main)
                    DispatchQueue.main.async { [weak self] in
                        guard let self = self else { return }
                        let empty = self.emptyArray
                        var copy = empty
                        self.cgmTransmitterDelegate?.cgmTransmitterInfoReceived(glucoseData: &copy, transmitterBatteryInfo: nil, sensorAge: nil)
                    }
                    
                    return
                    
                case .bluconAckResponse:
                    
                    // BluconACKResponse will come in two different situations
                    // 1) after we have sent an ackwakeup command ==> need to send unknown1Command
                    // 2) after we have sent a sleep command ==> no command to send
                    // to verify in which case we are, timeStampLastWakeUpResponse is used
                    // assuming bluconAckResponse will arrive less than 5 seconds after having send wakeUpResponse
                    if let timeStampLastWakeUpResponse = timeStampLastWakeUpResponse, abs(timeStampLastWakeUpResponse.timeIntervalSinceNow) < 5 && shouldSendUnknown1CommandAfterReceivingBluconAckResponse {
                        
                        // set to false to be sure
                        shouldSendUnknown1CommandAfterReceivingBluconAckResponse = false
                        
                        // send unknown1Command
                        sendCommandToBlucon(opcode: BluconTransmitterOpCode.unknown1Command)
                        
                    } else {
                        
                        trace("    no further processing, Blucon is sleeping now and should send a new reading in 5 minutes", log: log, category: ConstantsLog.categoryBlucon, type: .info)
                        
                    }
                    
                case .unknown1CommandResponse:
                    
                    sendCommandToBlucon(opcode: BluconTransmitterOpCode.unknown2Command)
                    
                case .unknown2CommandResponse:
                    
                    // check if there's a battery low indication
                    if valueAsString.startsWith(unknownCommand2BatteryLowIndicator) {
                        
                        // this is considered as battery level 5%
                        DispatchQueue.main.async { [weak self] in
                            guard let self = self else { return }
                            let empty = self.emptyArray
                            var copy = empty
                            self.cgmTransmitterDelegate?.cgmTransmitterInfoReceived(glucoseData: &copy, transmitterBatteryInfo: TransmitterBatteryInfo.percentage(percentage: 5),  sensorAge: nil)
                            self.cGMBluconTransmitterDelegate?.received(batteryLevel: 5, from: self)
                        }
                        
                    }
                    
                    // if timeStampLastBgReading > 5 minutes ago, then we'll get historic data, otherwise just get the latest reading
                    if let timeStampLastBgReading = timeStampLastBgReading,  abs(timeStampLastBgReading.timeIntervalSinceNow) > 5 * 60 + 10 {
                        
                        sendCommandToBlucon(opcode: BluconTransmitterOpCode.getHistoricDataAllBlocksCommand)
                        
                    } else {
                        
                        // not asking for sensorAge as in Spike and xdripplus, we know the sensorAge because we started with getHistoricDataAllBlocksCommand
                        sendCommandToBlucon(opcode: BluconTransmitterOpCode.getNowDataIndex)
                        
                    }
                    
                case .multipleBlockResponseIndex:
                    
                    if handleNewHistoricData(block: value) {
                        
                        // when Blucon responds with bluconAckResponse, then there's no need to send unknown1Command
                        shouldSendUnknown1CommandAfterReceivingBluconAckResponse = false
                        
                        // send sleep command
                        sendCommandToBlucon(opcode: .sleep)
                        
                    }
                    
                case .singleBlockInfoResponsePrefix:
                    
                    if !waitingForGlucoseData {
                        
                        guard let blockNumber = blockNumberForNowGlucoseData(input: value) else {
                            trace("    failed to create blockNumber", log: log, category: ConstantsLog.categoryBlucon, type: .error)
                            return
                        }
                        
                        // get blockNumber and compose command
                        let commandToSend = BluconTransmitterOpCode.singleBlockInfoPrefix.rawValue + blockNumber
                        
                        // convert command to hexstring, might fail if blockNumberForNowGlucoseData returned an invalid value
                        if let commandToSendAsData = Data(hexadecimalString: commandToSend) {
                            
                            trace("    send %{public}@ to Blucon", log: log, category: ConstantsLog.categoryBlucon, type: .info, commandToSend)
                            _ = writeDataToPeripheral(data: commandToSendAsData, type: .withResponse)
                            
                            waitingForGlucoseData = true
                            
                        } else {
                            
                            trace("    failed to convert commandToSend to Data", log: log, category: ConstantsLog.categoryBlucon, type: .error)
                        }
                        
                    }  else {
                        
                        // reset waitingForGlucoseData to false as we will not wait for glucosedata, after having processed this reading
                        waitingForGlucoseData = false
                        
                        // to be sure that waitingForGlucoseData is not having value true due to having broken protcol, verify when SingleBlockInfoPrefix was sent
                        if let timeStampOfSendingSingleBlockInfoPrefix = timeStampOfSendingSingleBlockInfoPrefix {
                            // should be a matter of milliseconds, so take 2 seconds
                            if abs(timeStampOfSendingSingleBlockInfoPrefix.timeIntervalSinceNow) > 2 {
                                
                                trace("    time since sending SingleBlockInfoPrefix is more than 2 seconds, ignoring this reading", log: log, category: ConstantsLog.categoryBlucon, type: .error)
                                
                                // send sleep command
                                sendCommandToBlucon(opcode: .sleep)
                                
                                return
                                
                            }
                        }
                        
                        trace("    creating glucoseValue", log: log, category: ConstantsLog.categoryBlucon, type: .info)
                        
                        // create glucose reading with timestamp now
                        timeStampLastBgReading = Date()
                        
                        // get glucoseValue from value
                        let glucoseValue = nowGetGlucoseValue(input: value)
                        
                        let glucoseData = GlucoseData(timeStamp: Date(), glucoseLevelRaw: glucoseValue)
                        let glucoseDataArray = [glucoseData]
                        DispatchQueue.main.async { [weak self] in
                            guard let self = self else { return }
                            var copy = glucoseDataArray
                            self.cgmTransmitterDelegate?.cgmTransmitterInfoReceived(glucoseData: &copy, transmitterBatteryInfo: nil,  sensorAge: nil)
                        }

                        sendCommandToBlucon(opcode: .sleep)
                        
                    }
                    
                case .bluconBatteryLowIndication1:
                    
                    // this is considered as battery level 3%
                    DispatchQueue.main.async { [weak self] in
                        guard let self = self else { return }
                        let empty = self.emptyArray
                        var copy = empty
                        self.cgmTransmitterDelegate?.cgmTransmitterInfoReceived(glucoseData: &copy, transmitterBatteryInfo: TransmitterBatteryInfo.percentage(percentage: 3), sensorAge: nil)
                        self.cGMBluconTransmitterDelegate?.received(batteryLevel: 3, from: self)
                    }

                case .bluconBatteryLowIndication2:
                    
                    // this is considered as battery level 2%
                    DispatchQueue.main.async { [weak self] in
                        guard let self = self else { return }
                        let empty = self.emptyArray
                        var copy = empty
                        self.cgmTransmitterDelegate?.cgmTransmitterInfoReceived(glucoseData: &copy, transmitterBatteryInfo: TransmitterBatteryInfo.percentage(percentage: 2), sensorAge: nil)
                        self.cGMBluconTransmitterDelegate?.received(batteryLevel: 2, from: self)
                    }
                    
                }
                
            }
            
        } else {
            trace("in peripheral didUpdateValueFor, value is nil, no further processing", log: log, category: ConstantsLog.categoryBlucon, type: .error)
        }

    }

}

extension CGMBluconTransmitter: CGMTransmitter {
    
    func requestNewReading() {
        // not supported for blucon
    }

    func setNonFixedSlopeEnabled(enabled: Bool) {
        nonFixedSlopeEnabled = enabled
    }
    
    func cgmTransmitterType() -> CGMTransmitterType {
        return .Blucon
    }

    func isNonFixedSlopeEnabled() -> Bool {
        return nonFixedSlopeEnabled
    }
    
    func getCBUUID_Service() -> String {
        return CBUUID_BluconService
    }
    
    func getCBUUID_Receive() -> String {
        return CBUUID_ReceiveCharacteristic_Blucon
    }

}

