import Foundation
import CoreBluetooth
import os

class CGMMiaoMiaoTransmitter:BluetoothTransmitter, CGMTransmitter {
    
    // MARK: - properties
    
    /// service to be discovered
    let CBUUID_Service_MiaoMiao: String = "6E400001-B5A3-F393-E0A9-E50E24DCCA9E"
    /// receive characteristic
    let CBUUID_ReceiveCharacteristic_MiaoMiao: String = "6E400003-B5A3-F393-E0A9-E50E24DCCA9E"
    /// write characteristic
    let CBUUID_WriteCharacteristic_MiaoMiao: String = "6E400002-B5A3-F393-E0A9-E50E24DCCA9E"
    
    /// expected device name
    let expectedDeviceNameMiaoMiao:String = "MiaoMiao"
    
    /// will be used to pass back bluetooth and cgm related events
    private(set) weak var cgmTransmitterDelegate:CGMTransmitterDelegate?

    /// CGMMiaoMiaoTransmitterDelegate
    public weak var cGMMiaoMiaoTransmitterDelegate: CGMMiaoMiaoTransmitterDelegate?

    // maximum times resend request due to crc error
    let maxPacketResendRequests = 3;
    
    /// for trace
    private let log = OSLog(subsystem: ConstantsLog.subSystem, category: ConstantsLog.categoryCGMMiaoMiao)
    
    /// counts number of times resend was requested due to crc error
    private var resendPacketCounter:Int = 0
    
    /// used when processing MiaoMiao data packet
    private var timestampLastPacketReception:Date
    
    /// receive buffer for miaomiao packets
    private var rxBuffer:Data
    
    /// how long to wait for next packet before sending startreadingcommand
    private static let maxWaitForpacketInSeconds = 3.0
    
    /// length of header added by MiaoMiao in front of data dat is received from Libre sensor
    private let miaoMiaoHeaderLength = 18
    
    /// is the transmitter oop web enabled or not
    private var webOOPEnabled: Bool
    
    /// is nonFixed enabled for the transmitter or not
    private var nonFixedSlopeEnabled: Bool
    
    // current sensor serial number, if nil then it's not known yet
    private var sensorSerialNumber:String?

    /// used as parameter in call to cgmTransmitterDelegate.cgmTransmitterInfoReceived, when there's no glucosedata to send
    var emptyArray: [GlucoseData] = []

    /// instance of libreDataParser
    private let libreDataParser: LibreDataParser

    /// sensor type
    private var libreSensorType: LibreSensorType?

    // MARK: - Initialization
    /// - parameters:
    ///     - address: if already connected before, then give here the address that was received during previous connect, if not give nil
    ///     - name : if already connected before, then give here the name that was received during previous connect, if not give nil
    ///     - webOOPEnabled : enabled or not
    ///     - bluetoothTransmitterDelegate : a BluetoothTransmitterDelegate
    ///     - cGMTransmitterDelegate : a CGMTransmitterDelegate
    ///     - cGMMiaoMiaoTransmitterDelegate : a CGMMiaoMiaoTransmitterDelegate
    init(address:String?, name: String?, bluetoothTransmitterDelegate: BluetoothTransmitterDelegate, cGMMiaoMiaoTransmitterDelegate : CGMMiaoMiaoTransmitterDelegate, cGMTransmitterDelegate:CGMTransmitterDelegate, sensorSerialNumber:String?, webOOPEnabled: Bool?, nonFixedSlopeEnabled: Bool?) {
        
        // assign addressname and name or expected devicename
        var newAddressAndName:BluetoothTransmitter.DeviceAddressAndName = BluetoothTransmitter.DeviceAddressAndName.notYetConnected(expectedName: expectedDeviceNameMiaoMiao)
        if let address = address {
            newAddressAndName = BluetoothTransmitter.DeviceAddressAndName.alreadyConnectedBefore(address: address, name: name)
        }

        // assign CGMTransmitterDelegate
        self.cgmTransmitterDelegate = cGMTransmitterDelegate
        
        // assign cGMMiaoMiaoTransmitterDelegate
        self.cGMMiaoMiaoTransmitterDelegate = cGMMiaoMiaoTransmitterDelegate
        
        // initialize sensorSerialNumber
        self.sensorSerialNumber = sensorSerialNumber

        // initialize rxbuffer
        rxBuffer = Data()
        timestampLastPacketReception = Date()
        
        // initialize webOOPEnabled
        self.webOOPEnabled = webOOPEnabled ?? false
        
        // initialize nonFixedSlopeEnabled
        self.nonFixedSlopeEnabled = nonFixedSlopeEnabled ?? false
        
        // initiliaze LibreDataParser
        self.libreDataParser = LibreDataParser()

        super.init(addressAndName: newAddressAndName, CBUUID_Advertisement: nil, servicesCBUUIDs: [CBUUID(string: CBUUID_Service_MiaoMiao)], CBUUID_ReceiveCharacteristic: CBUUID_ReceiveCharacteristic_MiaoMiao, CBUUID_WriteCharacteristic: CBUUID_WriteCharacteristic_MiaoMiao, bluetoothTransmitterDelegate: bluetoothTransmitterDelegate)
        
    }
    
    // MARK: - public functions
    
    func sendStartReadingCommand() -> Bool {
        if writeDataToPeripheral(data: Data.init([0xF0]), type: .withoutResponse) {
            return true
        } else {
            trace("in sendStartReadingCommand, write failed", log: log, category: ConstantsLog.categoryCGMMiaoMiao, type: .error)
            return false
        }
    }
    
    // MARK: - overriden  BluetoothTransmitter functions
    
    override func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        
        super.peripheral(peripheral, didUpdateNotificationStateFor: characteristic, error: error)
        
        if error == nil && characteristic.isNotifying {
            _ = sendStartReadingCommand()
        }
        
    }

    override func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        
        super.peripheral(peripheral, didUpdateValueFor: characteristic, error: error)
        
        if let value = characteristic.value {
            
            //check if buffer needs to be reset
            if (Date() > timestampLastPacketReception.addingTimeInterval(CGMMiaoMiaoTransmitter.maxWaitForpacketInSeconds)) {
                trace("in peripheral didUpdateValueFor, more than %{public}@ seconds since last update - or first update since app launch, resetting buffer", log: log, category: ConstantsLog.categoryCGMMiaoMiao, type: .info, CGMMiaoMiaoTransmitter.maxWaitForpacketInSeconds.description)
                resetRxBuffer()
            }
            
            // set timestampLastPacketReception to now, this gives the MM again maxWaitForpacketInSeconds seconds to send the next packet
            timestampLastPacketReception = Date()
            
            //add new packet to buffer
            rxBuffer.append(value)
            
            //check type of message and process according to type
            if let firstByte = rxBuffer.first {
                if let miaoMiaoResponseState = MiaoMiaoResponseType(rawValue: firstByte) {
                    switch miaoMiaoResponseState {
                        
                    case .dataPacket:
                        //if buffer complete, then start processing
                        if rxBuffer.count >= 363  {
                            trace("in peripheral didUpdateValueFor, Buffer complete", log: log, category: ConstantsLog.categoryCGMMiaoMiao, type: .info)
                            
                            /// gives information about type of sensor (Libre1, Libre2, etc..) - if transmitter doesn't offer patchInfo, then use nil value, which corresponds to Libre 1
                            var patchInfo: String?

                            // first off all see if the buffer contains patchInfo, and if yes send to delegate
                            if rxBuffer.count >= 369 {
                                
                                patchInfo = Data(rxBuffer[363...368]).hexEncodedString().uppercased()
                                
                                if let patchInfo = patchInfo {
                                    trace("    received patchInfo %{public}@", log: log, category: ConstantsLog.categoryCGMMiaoMiao, type: .info, patchInfo)
                                }
                                
                            }
                            
                            var dataIsDecryptedToLibre1Format = false

                            if let libreSensorType = LibreSensorType.type(patchInfo: patchInfo) {
                                // note that we should always have a libreSensorType
                                
                                self.libreSensorType = libreSensorType
                                
                                cGMMiaoMiaoTransmitterDelegate?.received(libreSensorType: libreSensorType, from: self)

                                // decrypt of libre2 or libreUS
                                dataIsDecryptedToLibre1Format = libreSensorType.decryptIfPossibleAndNeeded(rxBuffer: &rxBuffer, headerLength: miaoMiaoHeaderLength, log: log, patchInfo: patchInfo, uid: Array(rxBuffer[5..<13]))
                                
                                // now except libreProH, all libres' 344 data is libre1 format
                                // should crc check
                                guard libreSensorType.crcIsOk(rxBuffer: &self.rxBuffer, headerLength: miaoMiaoHeaderLength, log: log) else {

                                    let temp = resendPacketCounter
                                    resetRxBuffer()
                                    resendPacketCounter = temp + 1
                                    if resendPacketCounter < maxPacketResendRequests {
                                        trace("in peripheral didUpdateValueFor, crc error encountered. New attempt launched", log: log, category: ConstantsLog.categoryCGMMiaoMiao, type: .info)
                                        _ = sendStartReadingCommand()
                                    } else {
                                        trace("in peripheral didUpdateValueFor, crc error encountered. Maximum nr of attempts reached", log: log, category: ConstantsLog.categoryCGMMiaoMiao, type: .info)
                                        resendPacketCounter = 0
                                    }

                                    return
                                    
                                }

                            }
                                
                            //get MiaoMiao info from MiaoMiao header
                            let firmware = String(describing: rxBuffer[14...15].hexEncodedString())
                            let hardware = String(describing: rxBuffer[16...17].hexEncodedString())
                            let batteryPercentage = Int(rxBuffer[13])
                            
                            // send firmware, hardware, battery level to delegate
                            cGMMiaoMiaoTransmitterDelegate?.received(firmware: firmware, from: self)
                            cGMMiaoMiaoTransmitterDelegate?.received(hardware: hardware, from: self)
                            cGMMiaoMiaoTransmitterDelegate?.received(batteryLevel: batteryPercentage, from: self)
                            
                            // send batteryPercentage to delegate
                            cgmTransmitterDelegate?.cgmTransmitterInfoReceived(glucoseData: &emptyArray, transmitterBatteryInfo: TransmitterBatteryInfo.percentage(percentage: batteryPercentage), sensorAge: nil)

                            // get sensor serialNumber and if changed inform delegate
                            if let libreSensorSerialNumber = LibreSensorSerialNumber(withUID: Data(rxBuffer.subdata(in: 5..<13)), with: LibreSensorType.type(patchInfo: patchInfo)) {
                                
                                // (there will also be a seperate opcode form MiaoMiao because it's able to detect new sensor also)
                                if libreSensorSerialNumber.serialNumber != sensorSerialNumber {
                                    
                                    sensorSerialNumber = libreSensorSerialNumber.serialNumber
                                    
                                    trace("    new sensor detected :  %{public}@", log: log, category: ConstantsLog.categoryCGMMiaoMiao, type: .info, libreSensorSerialNumber.serialNumber)
                                    
                                    // inform delegate about new sensor detected
                                    // assign sensorStartDate, for this type of transmitter the sensorAge is passed in another call to cgmTransmitterDelegate
                                    cgmTransmitterDelegate?.newSensorDetected(sensorStartDate: nil)

                                    cGMMiaoMiaoTransmitterDelegate?.received(serialNumber: libreSensorSerialNumber.serialNumber, from: self)
                                    
                                }
                                
                            }
                            
                            libreDataParser.libreDataProcessor(libreSensorSerialNumber: LibreSensorSerialNumber(withUID: Data(rxBuffer.subdata(in: 5..<13)), with: LibreSensorType.type(patchInfo: patchInfo))?.serialNumber, patchInfo: patchInfo, webOOPEnabled: webOOPEnabled, libreData: (rxBuffer.subdata(in: miaoMiaoHeaderLength..<(344 + miaoMiaoHeaderLength))), cgmTransmitterDelegate: cgmTransmitterDelegate, dataIsDecryptedToLibre1Format: dataIsDecryptedToLibre1Format, testTimeStamp: nil, completionHandler: { (sensorState: LibreSensorState?, xDripError: XdripError?) in
                                
                                if let sensorState = sensorState {
                                    self.cGMMiaoMiaoTransmitterDelegate?.received(sensorStatus: sensorState, from: self)
                                }
                                
                            })
                            
                            //reset the buffer
                            resetRxBuffer()

                        }
                        
                    case .frequencyChangedResponse:
                        trace("in peripheral didUpdateValueFor, frequencyChangedResponse received, shound't happen ?", log: log, category: ConstantsLog.categoryCGMMiaoMiao, type: .error)
                        
                    case .newSensor:
                        trace("in peripheral didUpdateValueFor, new sensor detected", log: log, category: ConstantsLog.categoryCGMMiaoMiao, type: .info)
                        // assign sensorStartDate, for this type of transmitter the sensorAge is passed in another call to cgmTransmitterDelegate
                        cgmTransmitterDelegate?.newSensorDetected(sensorStartDate: nil)

                        // send 0xD3 and 0x01 to confirm sensor change as defined in MiaoMiao protocol documentation
                        // after that send start reading command, each with delay of 500 milliseconds
                        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + .milliseconds(500)) {
                            if self.writeDataToPeripheral(data: Data.init([0xD3, 0x01]), type: .withoutResponse) {
                                trace("in peripheralDidUpdateValueFor, successfully sent 0xD3 and 0x01, confirm sensor change to MiaoMiao", log: self.log, category: ConstantsLog.categoryCGMMiaoMiao, type: .info)
                                DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + .milliseconds(500)) {
                                    if !self.sendStartReadingCommand() {
                                        trace("in peripheralDidUpdateValueFor, sendStartReadingCommand failed", log: self.log, category: ConstantsLog.categoryCGMMiaoMiao, type: .error)
                                    } else {
                                        trace("in peripheralDidUpdateValueFor, successfully sent startReadingCommand to MiaoMiao", log: self.log, category: ConstantsLog.categoryCGMMiaoMiao, type: .info)
                                    }
                                }
                            } else {
                                trace("in peripheralDidUpdateValueFor, write D301 failed", log: self.log, category: ConstantsLog.categoryCGMMiaoMiao, type: .error)
                            }
                        }
                        
                    case .noSensor:
                        trace("in peripheral didUpdateValueFor, sensor not detected", log: log, category: ConstantsLog.categoryCGMMiaoMiao, type: .info)
                        // call to delegate
                        cgmTransmitterDelegate?.sensorNotDetected()
                        
                    }
                } else {
                    //rxbuffer doesn't start with a known miaomiaoresponse
                    //reset the buffer and send start reading command
                    trace("in peripheral didUpdateValueFor, rx buffer doesn't start with a known miaomiaoresponse, reset the buffer", log: log, category: ConstantsLog.categoryCGMMiaoMiao, type: .error)
                    resetRxBuffer()
                }
            }
        } else {
            trace("in peripheral didUpdateValueFor, value is nil, no further processing", log: log, category: ConstantsLog.categoryCGMMiaoMiao, type: .error)
        }
        
        
    }
    
    // MARK: CGMTransmitter protocol functions
    
    /// this transmitter supports oopWeb
    func setWebOOPEnabled(enabled: Bool) {
        webOOPEnabled = enabled
        
        // immediately request a new reading
        // there's no check here to see if peripheral, characteristic, connection, etc.. exists, but that's no issue. If anything's missing, write will simply fail,
        _ = sendStartReadingCommand()
    }
    
    func isWebOOPEnabled() -> Bool {
        return webOOPEnabled
    }
    
    func setNonFixedSlopeEnabled(enabled: Bool) {
        nonFixedSlopeEnabled = enabled
        
        // immediately request a new reading
        // there's no check here to see if peripheral, characteristic, connection, etc.. exists, but that's no issue. If anything's missing, write will simply fail,
       _ = sendStartReadingCommand()
    }
    
    func isNonFixedSlopeEnabled() -> Bool {
        return nonFixedSlopeEnabled
    }
    
    func requestNewReading() {
        _ = sendStartReadingCommand()
    }
    
    func cgmTransmitterType() -> CGMTransmitterType {
        return .miaomiao
    }
    
    func maxSensorAgeInDays() -> Double? {
        
        return libreSensorType?.maxSensorAgeInDays()
        
    }

    func getCBUUID_Service() -> String {
        return CBUUID_Service_MiaoMiao
    }
    
    func getCBUUID_Receive() -> String {
        return CBUUID_ReceiveCharacteristic_MiaoMiao
    }

    // MARK: - helpers
    
    /// reset rxBuffer, reset startDate, set resendPacketCounter to 0
    private func resetRxBuffer() {
        rxBuffer = Data()
        timestampLastPacketReception = Date()
        resendPacketCounter = 0
    }

    /// sample serial number in hex, as received from Libre, this is not the readable sensor number
    private static let sampleSerialNumberInHex = "3f38a50000a407e0"
    
    /// sample miaomiao header in hex
    //private let sampleMiaoMiaoHeader = "28016b455c2093690500a007e05c00071001"
    
    /// sample patchinfo in hex
    private static let samplePatchInfoInHex =   "9D083001FB30"
    
    /// sample encrypted libre data in hex
    private static var sampleLibreDataInHex:String = {

        // here example libre 2 encrypted data
        var sampleLibreDataInHex = "3244c69c763a7ec4290d1deb4db5cab2"
        sampleLibreDataInHex = sampleLibreDataInHex + "5711a23c3cd3e7e27950a87afe243567"
        sampleLibreDataInHex = sampleLibreDataInHex + "360a26adb3e6cf1754787603df0d6a57"
        sampleLibreDataInHex = sampleLibreDataInHex + "aff41ec028efd297b067da06878cd7a6"
        sampleLibreDataInHex = sampleLibreDataInHex + "6bff7a7121fe4072e74410be0d64b760"
        sampleLibreDataInHex = sampleLibreDataInHex + "4e7c1ded16a24d14307f740fff7417b5"
        sampleLibreDataInHex = sampleLibreDataInHex + "2fc31cfcf3976541c811cf4622f855a5"
        sampleLibreDataInHex = sampleLibreDataInHex + "3589133584bee671a9aac8572bc97dfc"
        sampleLibreDataInHex = sampleLibreDataInHex + "00966f04dc138780d26f301f8ed4ea10"
        sampleLibreDataInHex = sampleLibreDataInHex + "36d358ece134a4142470ab29d695afe1"
        sampleLibreDataInHex = sampleLibreDataInHex + "9be43c297f278039b8d483477d65b487"
        sampleLibreDataInHex = sampleLibreDataInHex + "1786be196d0e48252488e8764a790089"
        sampleLibreDataInHex = sampleLibreDataInHex + "78ad4e0466976eec5f06896673092de2"
        sampleLibreDataInHex = sampleLibreDataInHex + "29925d7fdb67453a3011437a931c0b67"
        sampleLibreDataInHex = sampleLibreDataInHex + "978157248da2fec758ff817aee394d84"
        sampleLibreDataInHex = sampleLibreDataInHex + "00f3e645bfd9ec271fec5581b9f0e976"
        sampleLibreDataInHex = sampleLibreDataInHex + "5d758d941fca99a3fa5c645e5c66bd7a"
        sampleLibreDataInHex = sampleLibreDataInHex + "537cfa0a46a9471a5f7e00876f7640ba"
        sampleLibreDataInHex = sampleLibreDataInHex + "32af681c01936f5bd511e0a672eb5fab"
        sampleLibreDataInHex = sampleLibreDataInHex + "a48967e9d4bd017fb4aebcb7fbca765e"
        sampleLibreDataInHex = sampleLibreDataInHex + "48d5e4e1a7a2665f200eff8b47b60d1a"
        sampleLibreDataInHex = sampleLibreDataInHex + "5870ccdc6cb29783"
        
        return sampleLibreDataInHex

    }()
    
    /// - to make tests, value should be full data packet, ie full rxbuffer
    /// - if value = nil then sample data defined here will be used
    /// - testTimeStamp : if set, then the most recent reading will get this timestamp
    public static func testPeripheralDidUpdateValue(libreDataAsHexString: String?, serialNumberAsHexString: String?, patchInfoAsHexString:String?, cGMTransmitterDelegate: CGMTransmitterDelegate?, libreDataParser: LibreDataParser, testTimeStamp: Date?) {
        
        let miaoMiaoHeaderLength = 18
        
        // using dummy value just to enforce a new sensor detected
        var previousSensorSerialNumber:String = "hello"
        
        var rxBuffer = Data()
        
        var libreDataAsHexStringToUse = ""
        if let libreDataAsHexString = libreDataAsHexString {
            libreDataAsHexStringToUse = libreDataAsHexString
        } else {
            libreDataAsHexStringToUse = sampleLibreDataInHex
        }
        
        var serialNumberAsHexStringToUse = ""
        if let serialNumberAsHexString = serialNumberAsHexString {
            serialNumberAsHexStringToUse = serialNumberAsHexString
        } else {
            serialNumberAsHexStringToUse = sampleSerialNumberInHex
        }
        
        var patchInfoAsHexStringToUse = ""
        if let patchInfoAsHexString = patchInfoAsHexString {
            patchInfoAsHexStringToUse = patchInfoAsHexString
        } else {
            patchInfoAsHexStringToUse = samplePatchInfoInHex
        }
        
        if rxBuffer.count == 0 {

            // mm response type + something + serial + something + libre data + patchinfo
            // 0 is mm response type, use 0x28
            // 1 to 4 use something dummy
            // serial number (not readable) = 5 to 12 (inclusive), length 8
            // 13 to 17 hare for battery, firmare , hardware, use something dummy
            // libre data in hex = 18 to 361 (incusive), length 344
            // 1 byte always 20 ?, length 1
            // patchinfo = 363 to 368 (inclusive), length 6
            rxBuffer =
                Data(hexadecimalString: "28")! // response type for data // 1

            rxBuffer = rxBuffer +
                Data(hexadecimalString: "00000000")! // dummy value // 4 + 1 = 5

            rxBuffer = rxBuffer +
                Data(hexadecimalString: serialNumberAsHexStringToUse)!  // 5 + 8 = 13

            rxBuffer = rxBuffer +
                Data(hexadecimalString: "0000000000")!  // dummy value, is normally batttery, firmware, hardware // 13 + 5 = 18

            rxBuffer = rxBuffer +
                Data(hexadecimalString: libreDataAsHexStringToUse)!  // 344 + 18 = 362

            rxBuffer = rxBuffer + Data(hexadecimalString: "20")! // 362 + 1 = 363

            rxBuffer = rxBuffer +
                Data(hexadecimalString: patchInfoAsHexStringToUse)! // 363 + 6 = 369

            
        }
        
        //check type of message and process according to type
        if let firstByte = rxBuffer.first {
            if let miaoMiaoResponseState = MiaoMiaoResponseType(rawValue: firstByte) {
                switch miaoMiaoResponseState {
                    
                case .dataPacket:
                    //if buffer complete, then start processing
                    if rxBuffer.count >= 363  {
                        
                        /// gives information about type of sensor (Libre1, Libre2, etc..) - if transmitter doesn't offer patchInfo, then use nil value, which corresponds to Libre 1
                        var patchInfo: String?
                        
                        // first off all see if the buffer contains patchInfo, and if yes send to delegate
                        if rxBuffer.count >= 369 {
                            
                            patchInfo = Data(rxBuffer[363...368]).hexEncodedString().uppercased()
                            
                        }
                        
                        var dataIsDecryptedToLibre1Format = false
                        
                        if let libreSensorType = LibreSensorType.type(patchInfo: patchInfo) {
                            // note that we should always have a libreSensorType
                            
                            // decrypt of libre2 or libreUS
                            dataIsDecryptedToLibre1Format = libreSensorType.decryptIfPossibleAndNeeded(rxBuffer: &rxBuffer, headerLength: miaoMiaoHeaderLength, log: nil, patchInfo: patchInfo, uid: Array(rxBuffer[5..<13]))
                            
                            // now except libreProH, all libres' 344 data is libre1 format
                            // should crc check
                            guard libreSensorType.crcIsOk(rxBuffer: &rxBuffer, headerLength: miaoMiaoHeaderLength, log: nil) else {
                                
                                debuglogging("crc is not ok")
                                
                                return
                                
                            }
                            
                        }
                        
                        //get MiaoMiao info from MiaoMiao header
                        //let firmware = String(describing: rxBuffer[14...15].hexEncodedString())
                        //let hardware = String(describing: rxBuffer[16...17].hexEncodedString())
                        //let batteryPercentage = Int(rxBuffer[13])
                        
                        // get sensor serialNumber and if changed inform delegate
                        if let libreSensorSerialNumber = LibreSensorSerialNumber(withUID: Data(rxBuffer.subdata(in: 5..<13)), with: LibreSensorType.type(patchInfo: patchInfo)) {
                            
                            // (there will also be a seperate opcode form MiaoMiao because it's able to detect new sensor also)
                            if libreSensorSerialNumber.serialNumber != previousSensorSerialNumber {
                                
                                previousSensorSerialNumber = libreSensorSerialNumber.serialNumber
                                
                            }
                            
                        }
                        
                        libreDataParser.libreDataProcessor(libreSensorSerialNumber: LibreSensorSerialNumber(withUID: Data(rxBuffer.subdata(in: 5..<13)), with: LibreSensorType.type(patchInfo: patchInfo))?.serialNumber, patchInfo: patchInfo, webOOPEnabled: true, libreData: (rxBuffer.subdata(in: miaoMiaoHeaderLength..<(344 + miaoMiaoHeaderLength))), cgmTransmitterDelegate: cGMTransmitterDelegate, dataIsDecryptedToLibre1Format: dataIsDecryptedToLibre1Format, testTimeStamp: testTimeStamp, completionHandler: { (sensorState: LibreSensorState?, xDripError: XdripError?) in
                            
                        })
                        
                        
                    }
                    
                case .frequencyChangedResponse:
                    break
                    
                case .newSensor:
                    break
                    
                case .noSensor:
                    break
                    
                }
            } else {
                //rxbuffer doesn't start with a known miaomiaoresponse
                //reset the buffer and send start reading command
                
            }
        }

    }
    
    public static func testRange(cGMTransmitterDelegate: CGMTransmitterDelegate?) {
        
        var testData = [String]()
        var patchInfoRange = [String]()
        var sampleLibreDataInHex = ""
        
        // the first element is taken from another range of tests
        sampleLibreDataInHex = "4cfb9faa1b977983833063becebdb941"
        sampleLibreDataInHex = sampleLibreDataInHex + "a8497d3f8b0817df5d38ac51fb6f221d"
        sampleLibreDataInHex = sampleLibreDataInHex + "03535dad0435f52bb3460836960466a7"
        sampleLibreDataInHex = sampleLibreDataInHex + "850c0d396b59b9eadfd107c97aaa91ed"
        sampleLibreDataInHex = sampleLibreDataInHex + "d990a0711b4a435b338dfdc29ec142cd"
        sampleLibreDataInHex = sampleLibreDataInHex + "445de8cac4acf02e0a872d2e2a9d80e2"
        sampleLibreDataInHex = sampleLibreDataInHex + "aeeb50d627ee1b08d655f838c4456a51"
        sampleLibreDataInHex = sampleLibreDataInHex + "36e6c9fdbe0abd570c3d0f9a92e8f162"
        sampleLibreDataInHex = sampleLibreDataInHex + "e7fb44fb2c6e20a441554edac1dd1be3"
        sampleLibreDataInHex = sampleLibreDataInHex + "c9b78aef42ec54e194f2a31f6c117bb2"
        sampleLibreDataInHex = sampleLibreDataInHex + "85b1eb380afdc60912c53f137060c784"
        sampleLibreDataInHex = sampleLibreDataInHex + "ab382d2208e18d63d2e16e2ee84662ab"
        sampleLibreDataInHex = sampleLibreDataInHex + "06fa15323e31698b1a918dde089c7674"
        sampleLibreDataInHex = sampleLibreDataInHex + "b46a50a456044b686a3197ab72e6f639"
        sampleLibreDataInHex = sampleLibreDataInHex + "877382cdc2ac209f2965251951898511"
        sampleLibreDataInHex = sampleLibreDataInHex + "7e2c7b729974ebac25895883d1c4c25f"
        sampleLibreDataInHex = sampleLibreDataInHex + "83c8d4c2b866e9e629b5b4abd368d6d7"
        sampleLibreDataInHex = sampleLibreDataInHex + "19657cad735c633cacbf6c5d9a392eff"
        sampleLibreDataInHex = sampleLibreDataInHex + "b407debec14587e8cb6d63507b17f943"
        sampleLibreDataInHex = sampleLibreDataInHex + "3da4d1d6a80e6c4760e718db29d7e20e"
        sampleLibreDataInHex = sampleLibreDataInHex + "1bf95ab8d51115608d0bbc572319e0f5"
        sampleLibreDataInHex = sampleLibreDataInHex + "a0102e563ccef9a2"
        testData.append(sampleLibreDataInHex)
        patchInfoRange.append("9D083001EE0F")
        
        sampleLibreDataInHex = "fb5721deb3441cef349cddca666edc2d"
        sampleLibreDataInHex = sampleLibreDataInHex + "1fe5c34b23db72b3d5ea172553bc4771"
        sampleLibreDataInHex = sampleLibreDataInHex + "b4ffe3d9ace6904704eab6423ed703cb"
        sampleLibreDataInHex = sampleLibreDataInHex + "4cd8ea65a62b5a801605e095b7d87287"
        sampleLibreDataInHex = sampleLibreDataInHex + "1044472dd638a031fa591a9e53b3a1a7"
        sampleLibreDataInHex = sampleLibreDataInHex + "8d890f9609de1344b45cca76e6ef7d87"
        sampleLibreDataInHex = sampleLibreDataInHex + "67ebb68af493f0e41e81066b09b3883b"
        sampleLibreDataInHex = sampleLibreDataInHex + "9645771117d9d83bbb91b1ee3a3b940e"
        sampleLibreDataInHex = sampleLibreDataInHex + "5057fa8f84bd45c8f6f9f0ae690e7e8f"
        sampleLibreDataInHex = sampleLibreDataInHex + "7e1b349bea3f318d235e1d6bc4c21ede"
        sampleLibreDataInHex = sampleLibreDataInHex + "321d554ca22ea365a5698167d8b3a2e8"
        sampleLibreDataInHex = sampleLibreDataInHex + "363f49b0588b026b4fe60abcb82ceda3"
        sampleLibreDataInHex = sampleLibreDataInHex + "9bfd71a06e5be6838796e94c58f6f97c"
        sampleLibreDataInHex = sampleLibreDataInHex + "296d3436066ec460f736f339228c7931"
        sampleLibreDataInHex = sampleLibreDataInHex + "1a74e65f92c6af97b462418b01e30a19"
        sampleLibreDataInHex = sampleLibreDataInHex + "0eef5e1e45c5bfe8554a7def0d75961b"
        sampleLibreDataInHex = sampleLibreDataInHex + "f30bf1ae64d7bda2597691c70fd98293"
        sampleLibreDataInHex = sampleLibreDataInHex + "69a659c1afed3778dc7c493146887abb"
        sampleLibreDataInHex = sampleLibreDataInHex + "c4c4fbd21df4d3acbbae463ca7a6ad07"
        sampleLibreDataInHex = sampleLibreDataInHex + "331fad92111ebe056e5c649f8bc7304c"
        sampleLibreDataInHex = sampleLibreDataInHex + "154226fc6c01c72283b0c0139a0932b7"
        sampleLibreDataInHex = sampleLibreDataInHex + "aeab521285de2be0"
        
        testData.append(sampleLibreDataInHex)
        patchInfoRange.append("9D083001A60E")
        
        sampleLibreDataInHex = "abc724035c529114640cd817897851d6"
        sampleLibreDataInHex = sampleLibreDataInHex + "95cbb0f4f58d9be98e946f9a8ae5ae6b"
        sampleLibreDataInHex = sampleLibreDataInHex + "e26fee0b43f01bbc3775b3e3d7c1ca3f"
        sampleLibreDataInHex = sampleLibreDataInHex + "6dd2c00952b2aec43767cff9434186c3"
        sampleLibreDataInHex = sampleLibreDataInHex + "40d442f0392e2dcaaac91f43bca52c5c"
        sampleLibreDataInHex = sampleLibreDataInHex + "07a77c29df88fa1e3e72b9c930b994dd"
        sampleLibreDataInHex = sampleLibreDataInHex + "377bb3571b857d1f4e1103b6e6a505c0"
        sampleLibreDataInHex = sampleLibreDataInHex + "c95f015586e1a076ece1c1aaab03e64c"
        sampleLibreDataInHex = sampleLibreDataInHex + "54147c9cf6b3a451f2ba76bd1b009f16"
        sampleLibreDataInHex = sampleLibreDataInHex + "a0e6c4eaa171b4b5fda3ed1a8f8c9be6"
        sampleLibreDataInHex = sampleLibreDataInHex + "365ed35fd02042fca12a0774aabd4371"
        sampleLibreDataInHex = sampleLibreDataInHex + "438ee512310a9a4d3a57a61ed1ad7585"
        sampleLibreDataInHex = sampleLibreDataInHex + "9fbef7b31c55071a83d56f5f2af818e5"
        sampleLibreDataInHex = sampleLibreDataInHex + "f790c4474d20415829cb034869c2fc09"
        sampleLibreDataInHex = sampleLibreDataInHex + "1e37604ce0c84e0eb021c79873edeb80"
        sampleLibreDataInHex = sampleLibreDataInHex + "969ab342a09ffc82cd3f90b3e82fd571"
        sampleLibreDataInHex = sampleLibreDataInHex + "64f46f6bffa30171ce890f0294ad3e40"
        sampleLibreDataInHex = sampleLibreDataInHex + "24e7b1660dd9ef0a913da196e4bca2c9"
        sampleLibreDataInHex = sampleLibreDataInHex + "533b651786806f7f2c51d8f93cd211d4"
        sampleLibreDataInHex = sampleLibreDataInHex + "d51219e691e57b698851d0eb0e3cf520"
        sampleLibreDataInHex = sampleLibreDataInHex + "82bdb839f7757bf1144f5ed6017d8e64"
        sampleLibreDataInHex = sampleLibreDataInHex + "e3eabab527eaf392"
        
        testData.append(sampleLibreDataInHex)
        patchInfoRange.append("9D083001740D")
        
        sampleLibreDataInHex = "e6b10aead9063b8fa6a121ca01bf1c22"
        sampleLibreDataInHex = sampleLibreDataInHex + "d8bd9e1d70d93172802be8df7c0c1c26"
        sampleLibreDataInHex = sampleLibreDataInHex + "7a2dc51981ca2a3f20ec4fc518681cd3"
        sampleLibreDataInHex = sampleLibreDataInHex + "f590eb1bb68797cdfc407fb2b518f28f"
        sampleLibreDataInHex = sampleLibreDataInHex + "bcd4356ddfdb265616d4b8b66ec2e792"
        sampleLibreDataInHex = sampleLibreDataInHex + "72a90be83f7dd683f355338dc6502690"
        sampleLibreDataInHex = sampleLibreDataInHex + "af399845d9bf4c9c5988ff90290cd32c"
        sampleLibreDataInHex = sampleLibreDataInHex + "511d2a4744db91f521c64bee5dea5401"
        sampleLibreDataInHex = sampleLibreDataInHex + "4db1d1bbeeff62a864c40cae0edfbe80"
        sampleLibreDataInHex = sampleLibreDataInHex + "b94369cdb93d724c49c403fffb6331b1"
        sampleLibreDataInHex = sampleLibreDataInHex + "d75c9cec901c6b65cff39ff3e7128d87"
        sampleLibreDataInHex = sampleLibreDataInHex + "a28caaa17136b3d48e3048fba542dfd2"
        sampleLibreDataInHex = sampleLibreDataInHex + "d5f0e4d37ea6339d4640ab0b4598cb0d"
        sampleLibreDataInHex = sampleLibreDataInHex + "bdded7272fd375df9dacedad1d2d565e"
        sampleLibreDataInHex = sampleLibreDataInHex + "ff352fffa0f46797def85f1f3e422576"
        sampleLibreDataInHex = sampleLibreDataInHex + "7798fcf1e0a3d51b79587e569cc07f26"
        sampleLibreDataInHex = sampleLibreDataInHex + "50c22523f8f1b3f07564927e6c606b5a"
        sampleLibreDataInHex = sampleLibreDataInHex + "10d1fb2e0a8b5d8b255a4f739053089e"
        sampleLibreDataInHex = sampleLibreDataInHex + "b2392aa4c6bc46e64288407e717ddf22"
        sampleLibreDataInHex = sampleLibreDataInHex + "34105655d1d952f03c363e0e75d35f77"
        sampleLibreDataInHex = sampleLibreDataInHex + "c8f3ab5995864f76d1da9a826e1d5d8c"
        sampleLibreDataInHex = sampleLibreDataInHex + "a9a4a9d54519c715"
        
        testData.append(sampleLibreDataInHex)
        patchInfoRange.append("9D083001090C")
        
        sampleLibreDataInHex = "6808a3afb162b9d0a7c35fbb64487912"
        sampleLibreDataInHex = sampleLibreDataInHex + "5604375818bdb32d29c9e23767d586af"
        sampleLibreDataInHex = sampleLibreDataInHex + "21a069a7aec03378f4ba344f3af1e2fb"
        sampleLibreDataInHex = sampleLibreDataInHex + "ae1d47a5998d8e8af2a8725aaec16806"
        sampleLibreDataInHex = sampleLibreDataInHex + "4c15c500d21e220f69ce9fef6e9404a4"
        sampleLibreDataInHex = sampleLibreDataInHex + "8268ca843aced4daf1bc3673db89c718"
        sampleLibreDataInHex = sampleLibreDataInHex + "f4a032fbcbb455df8bde6d1b0b9d2b04"
        sampleLibreDataInHex = sampleLibreDataInHex + "0a9086f96bd188b22f2e46064633ce88"
        sampleLibreDataInHex = sampleLibreDataInHex + "c30878fe869be0f765a672df6b28dbb0"
        sampleLibreDataInHex = sampleLibreDataInHex + "37fac088d159f0136abfe978ffa4df40"
        sampleLibreDataInHex = sampleLibreDataInHex + "a142d73da008065a36360316da9507d7"
        sampleLibreDataInHex = sampleLibreDataInHex + "d492e1704122deebad4ba27ca1853123"
        sampleLibreDataInHex = sampleLibreDataInHex + "08a2f3d16c7d43bc14c96b3d5ad05c43"
        sampleLibreDataInHex = sampleLibreDataInHex + "608cc0253d0805febed7072a19eab8af"
        sampleLibreDataInHex = sampleLibreDataInHex + "892b642e90e00aa8273dc3fa03c5af26"
        sampleLibreDataInHex = sampleLibreDataInHex + "0186b720d0b7b8245a2394d1980791d7"
        sampleLibreDataInHex = sampleLibreDataInHex + "de7b8c66909531af7406ec0f09970e6a"
        sampleLibreDataInHex = sampleLibreDataInHex + "9e68526b62efdfd42bb2429b8b8a9217"
        sampleLibreDataInHex = sampleLibreDataInHex + "e9b4861ae9b65fa196de3bf453e4210a"
        sampleLibreDataInHex = sampleLibreDataInHex + "6f9dfaebfed34bb732de33e66b0ac5fe"
        sampleLibreDataInHex = sampleLibreDataInHex + "38325b3498434b2faec0bddb6e4bbeba"
        sampleLibreDataInHex = sampleLibreDataInHex + "596559b848dcc34c"
        
        testData.append(sampleLibreDataInHex)
        patchInfoRange.append("9D083001040B")

        
        sampleLibreDataInHex = "f9c39d77e89d8478b9d3b6573024a3d5"
        sampleLibreDataInHex = sampleLibreDataInHex + "c7cf098041428e85714c71b913f838fd"
        sampleLibreDataInHex = sampleLibreDataInHex + "b26b577ef7670cd0eaaadda36e9d383c"
        sampleLibreDataInHex = sampleLibreDataInHex + "3fd6797dc072b3226f9284811cb9d592"
        sampleLibreDataInHex = sampleLibreDataInHex + "2f06ce5e767a014b85064385c763c08f"
        sampleLibreDataInHex = sampleLibreDataInHex + "e17bc1da9eaaf79ec7ca9c7b4b3e6792"
        sampleLibreDataInHex = sampleLibreDataInHex + "97b339a56fd0769b6716b171a26aef2f"
        sampleLibreDataInHex = sampleLibreDataInHex + "9182858dc9b549f7baeeb1ddf44b731c"
        sampleLibreDataInHex = sampleLibreDataInHex + "de632a88475e45b5f716f79da77e999d"
        sampleLibreDataInHex = sampleLibreDataInHex + "2a9192fe109c555122b11a580ab2f9cc"
        sampleLibreDataInHex = sampleLibreDataInHex + "bc29854b61cda318a486865416c345fa"
        sampleLibreDataInHex = sampleLibreDataInHex + "c9f9b30680e77ba9307154a713fd8cb7"
        sampleLibreDataInHex = sampleLibreDataInHex + "6bb1f88fc81960f8f801b757f3279868"
        sampleLibreDataInHex = sampleLibreDataInHex + "039fcb7b996c26ba88a1ad22895d1825"
        sampleLibreDataInHex = sampleLibreDataInHex + "ea386f70348429eccbf51f90aa326b0d"
        sampleLibreDataInHex = sampleLibreDataInHex + "6295bc7e74d39b60c719620a2a7f2c43"
        sampleLibreDataInHex = sampleLibreDataInHex + "ee83397f4e4ee095cb258e22dadf383f"
        sampleLibreDataInHex = sampleLibreDataInHex + "ae90e772bc340eee4e2f56d46182c0e3"
        sampleLibreDataInHex = sampleLibreDataInHex + "d94c3303376d8e9b29fd59d980ac175f"
        sampleLibreDataInHex = sampleLibreDataInHex + "5f654ff220089a8dafe4c53da472786a"
        sampleLibreDataInHex = sampleLibreDataInHex + "5b21506a3c27686b420861b1c7bc7a91"
        sampleLibreDataInHex = sampleLibreDataInHex + "3a7652e6ecb8e008"
        testData.append(sampleLibreDataInHex)
        patchInfoRange.append("9D083001BD2D")
        
        sampleLibreDataInHex = "72b202f0b92e3a8e10bbbd2600a796e2"
        sampleLibreDataInHex = sampleLibreDataInHex + "6ea702f171c1bbb281bc06a91a3b696b"
        sampleLibreDataInHex = sampleLibreDataInHex + "c1bd2a6dfea45d46cec0de105f1e9909"
        sampleLibreDataInHex = sampleLibreDataInHex + "9e8c730c06f38eff44d093c6caa246f7"
        sampleLibreDataInHex = sampleLibreDataInHex + "e144da68a1edd92fde167d720a7beb54"
        sampleLibreDataInHex = sampleLibreDataInHex + "bacbff2d53b2dc4546c4d4eebf6628e8"
        sampleLibreDataInHex = sampleLibreDataInHex + "16bd71309b8839e13ca68f866f72c4f4"
        sampleLibreDataInHex = sampleLibreDataInHex + "ca32bb7a04ad622c90aca59b22dc2178"
        sampleLibreDataInHex = sampleLibreDataInHex + "f4213ece91c917d1d2de90420fc73440"
        sampleLibreDataInHex = sampleLibreDataInHex + "0f59f521b825f88cddc70be59b4b30b0"
        sampleLibreDataInHex = sampleLibreDataInHex + "435f94f6f0346a64814ee18bbe7ae827"
        sampleLibreDataInHex = sampleLibreDataInHex + "ec31d4d9285ed6741a3340e1c56aded3"
        sampleLibreDataInHex = sampleLibreDataInHex + "41f3ecc91e8e329ca3b189a03e3fb3b3"
        sampleLibreDataInHex = sampleLibreDataInHex + "582ff58c54740d6109afe5b77d05575f"
        sampleLibreDataInHex = sampleLibreDataInHex + "6b3627e5c0dc669690452167672a40d6"
        sampleLibreDataInHex = sampleLibreDataInHex + "39258289b9cbb0bbed5b764cfce87e27"
        sampleLibreDataInHex = sampleLibreDataInHex + "c4c12d3998d9b2f118f1772d9306a8c0"
        sampleLibreDataInHex = sampleLibreDataInHex + "7d443172f5c19f114745d9b9111b34bd"
        sampleLibreDataInHex = sampleLibreDataInHex + "d026bc6e47f47ac5fa29a0d6c97587a0"
        sampleLibreDataInHex = sampleLibreDataInHex + "8cb1b6fd69d10a725e29a8c4879b6354"
        sampleLibreDataInHex = sampleLibreDataInHex + "aaec3d9314ce7355c23726f9f4da1810"
        sampleLibreDataInHex = sampleLibreDataInHex + "ba4915aedfde8289"
        
        testData.append(sampleLibreDataInHex)
        patchInfoRange.append("9D0830011B0D")
        
        sampleLibreDataInHex = "ed9b65c73e7adddaad8b4ee7e6c3fa77"
        sampleLibreDataInHex = sampleLibreDataInHex + "d397f13097a5d72764dd860ac51f615f"
        sampleLibreDataInHex = sampleLibreDataInHex + "a633afce2180557273f02dd1b97af59c"
        sampleLibreDataInHex = sampleLibreDataInHex + "23bc80cde097e26a88124ab6374953dd"
        sampleLibreDataInHex = sampleLibreDataInHex + "2d8603185c06cc0563268eb3581f8f1f"
        sampleLibreDataInHex = sampleLibreDataInHex + "c7faacecbd88b3d0854a511163428fdc"
        sampleLibreDataInHex = sampleLibreDataInHex + "71ef379294ac311142977c478916a861"
        sampleLibreDataInHex = sampleLibreDataInHex + "770248bbe2c90eb9221625c3ba96b254"
        sampleLibreDataInHex = sampleLibreDataInHex + "469bbe96098384fd6fee6383e9a358d5"
        sampleLibreDataInHex = sampleLibreDataInHex + "b26906e05e419419ba498e46446f3884"
        sampleLibreDataInHex = sampleLibreDataInHex + "24d111552f1062503c7e124a581e84b2"
        sampleLibreDataInHex = sampleLibreDataInHex + "51012718ce3abae1d6f199913881cbf9"
        sampleLibreDataInHex = sampleLibreDataInHex + "8d3135b9e36527b61e817a61d85bdf26"
        sampleLibreDataInHex = sampleLibreDataInHex + "e51f064db21061f46e216014a2215f6b"
        sampleLibreDataInHex = sampleLibreDataInHex + "0cb8a2461ff86ea22d75d2a6814e2c43"
        sampleLibreDataInHex = sampleLibreDataInHex + "841571485fafdc2e0b3275daf9ba8169"
        sampleLibreDataInHex = sampleLibreDataInHex + "22a82eaf9d8b4dbf070e99f2091a9515"
        sampleLibreDataInHex = sampleLibreDataInHex + "62bbdfad6fdda2c482044104b2476dc9"
        sampleLibreDataInHex = sampleLibreDataInHex + "156724d3e4a823b1e5d64e095369ba75"
        sampleLibreDataInHex = sampleLibreDataInHex + "934e5822f3cd37a730246caa0108273e"
        sampleLibreDataInHex = sampleLibreDataInHex + "c4e1f9fd955d373fddc8c8266ec625c5"
        sampleLibreDataInHex = sampleLibreDataInHex + "a5b6fb7145c2bf5c"
        
        testData.append(sampleLibreDataInHex)
        patchInfoRange.append("9D083001E50B")
        
        sampleLibreDataInHex = "0f527ae5a27a3b7840c8225c04ede36c"
        sampleLibreDataInHex = sampleLibreDataInHex + "3ed49d8b758bce3cb12793d327711c35"
        sampleLibreDataInHex = sampleLibreDataInHex + "91ce9f17fa0a28c89eb3416a5b54ec87"
        sampleLibreDataInHex = sampleLibreDataInHex + "ceffec7602b9fb7114a30cbccee83379"
        sampleLibreDataInHex = sampleLibreDataInHex + "b1374512a5a7aca18e65e208ba319604"
        sampleLibreDataInHex = sampleLibreDataInHex + "2ab9c0575fa6aacbb2b74bc8b82cf266"
        sampleLibreDataInHex = sampleLibreDataInHex + "46122d4b4fc24cabafd421fc637ab27a"
        sampleLibreDataInHex = sampleLibreDataInHex + "ba412c7e03e72ba2c08b39e1269654f6"
        sampleLibreDataInHex = sampleLibreDataInHex + "a452a1b49583625f111117eee2f71c84"
        sampleLibreDataInHex = sampleLibreDataInHex + "cc96728d5515d0481e088c49767b1874"
        sampleLibreDataInHex = sampleLibreDataInHex + "8090135a1d0442a042816627534ac0e3"
        sampleLibreDataInHex = sampleLibreDataInHex + "2ffe5375c56efeb0d9fcc74d285af617"
        sampleLibreDataInHex = sampleLibreDataInHex + "823c6b65f3be1a58607e0e0cd30f9b77"
        sampleLibreDataInHex = sampleLibreDataInHex + "9be07220b94425a5ca60621b90357f9b"
        sampleLibreDataInHex = sampleLibreDataInHex + "a8f9a0492dec4e52538aa6cb8a1a6812"
        sampleLibreDataInHex = sampleLibreDataInHex + "faea052554fb987f2e94f1e011d856e3"
        sampleLibreDataInHex = sampleLibreDataInHex + "070eaa9575e99a352d226e519f56bd26"
        sampleLibreDataInHex = sampleLibreDataInHex + "4897280ef9918af77296c0c51d4b215b"
        sampleLibreDataInHex = sampleLibreDataInHex + "e5f5a5124ba46f23cffab9aac5259246"
        sampleLibreDataInHex = sampleLibreDataInHex + "b962af8165811f946bfab1b891cb76b2"
        sampleLibreDataInHex = sampleLibreDataInHex + "9f3f24ef189e66b3f7e43f85f88a0df6"
        sampleLibreDataInHex = sampleLibreDataInHex + "8f9a0cd2d38e976f"
        
        testData.append(sampleLibreDataInHex)
        patchInfoRange.append("9D083001AB0A")
        
        sampleLibreDataInHex = "d55ce78cd2afef671a971b9807852fa5"
        sampleLibreDataInHex = sampleLibreDataInHex + "31ee05194230813bd32bd9741d59b45d"
        sampleLibreDataInHex = sampleLibreDataInHex + "9ef40785cdb167cf58ef78e65b3ca64d"
        sampleLibreDataInHex = sampleLibreDataInHex + "623b2a37e1cea9103d0e5bc9d663440e"
        sampleLibreDataInHex = sampleLibreDataInHex + "4a418197b2d3feb8d43adbccb9595acd"
        sampleLibreDataInHex = sampleLibreDataInHex + "258358c5681de5cc3256046e82045a0e"
        sampleLibreDataInHex = sampleLibreDataInHex + "4928b5d9787903acf58b183860127eb3"
        sampleLibreDataInHex = sampleLibreDataInHex + "604fb1177332ffbd955e73bc5bd06786"
        sampleLibreDataInHex = sampleLibreDataInHex + "7e5c3cdde556b640d8f236fc08e58d07"
        sampleLibreDataInHex = sampleLibreDataInHex + "5010f2c98bd4c2050d55db39a529ed56"
        sampleLibreDataInHex = sampleLibreDataInHex + "1c16931ec3c550ed8b624735b9585160"
        sampleLibreDataInHex = sampleLibreDataInHex + "18348fe23960f1e361edcceed9c71e2b"
        sampleLibreDataInHex = sampleLibreDataInHex + "b5f6b7f20fb0150ba99d2f1e391d0af4"
        sampleLibreDataInHex = sampleLibreDataInHex + "0766f264678537e8d93d356b43678ab9"
        sampleLibreDataInHex = sampleLibreDataInHex + "347f200df32d5c1f9a6987d96008f991"
        sampleLibreDataInHex = sampleLibreDataInHex + "45441e4a2c342c081ee13dbb648405fb"
        sampleLibreDataInHex = sampleLibreDataInHex + "b8a0b1fa0d262e4212ddd19394241187"
        sampleLibreDataInHex = sampleLibreDataInHex + "220d369ac630a598cad909312d79e95b"
        sampleLibreDataInHex = sampleLibreDataInHex + "8f6fbb867405404cf0050668ce573ee7"
        sampleLibreDataInHex = sampleLibreDataInHex + "78b4edc678ef2de525f724cb8a36a3ac"
        sampleLibreDataInHex = sampleLibreDataInHex + "5ee966a805f054c2c81b8047f3f8a157"
        sampleLibreDataInHex = sampleLibreDataInHex + "e5001246ec2fb800"
        
        testData.append(sampleLibreDataInHex)
        patchInfoRange.append("9D0830012609")
        
        sampleLibreDataInHex = "e77a9760f426a5a97dd4ca2215dfe6a5"
        sampleLibreDataInHex = sampleLibreDataInHex + "03c875f564b9cbf5b2be75ac364319fc"
        sampleLibreDataInHex = sampleLibreDataInHex + "acd27769eb382d0194e0f58f6ba97253"
        sampleLibreDataInHex = sampleLibreDataInHex + "501d5adbc747e3de80f3fc11fd79e9af"
        sampleLibreDataInHex = sampleLibreDataInHex + "7867f17b945a9176bb9fc877ae039b47"
        sampleLibreDataInHex = sampleLibreDataInHex + "d5a421294ee0ae0291aba3e2a81ee5af"
        sampleLibreDataInHex = sampleLibreDataInHex + "7bc604345ef04962495eb8cd8d74b541"
        sampleLibreDataInHex = sampleLibreDataInHex + "5ccbb54fede92c992601a0d0c89853cd"
        sampleLibreDataInHex = sampleLibreDataInHex + "42d838857b8d6564b11393f2a2eddded"
        sampleLibreDataInHex = sampleLibreDataInHex + "6c94f691150f1121be0a08553661d91d"
        sampleLibreDataInHex = sampleLibreDataInHex + "209297465d1e83c949cfbee8319f1c94"
        sampleLibreDataInHex = sampleLibreDataInHex + "24b08bbaa7bb22c7d2b21f824a8f2a60"
        sampleLibreDataInHex = sampleLibreDataInHex + "8972b3aa916bc62fc07c8a1093155a1e"
        sampleLibreDataInHex = sampleLibreDataInHex + "3be2f63cf95ee4cc6a62e607d02fbef2"
        sampleLibreDataInHex = sampleLibreDataInHex + "08fb24556df68f3b26bc272c8d6e3263"
        sampleLibreDataInHex = sampleLibreDataInHex + "8fdc84c2538fc20e5ba2700716ac0c92"
        sampleLibreDataInHex = sampleLibreDataInHex + "72382b72729dc0448d20ea4ddf4c7c4f"
        sampleLibreDataInHex = sampleLibreDataInHex + "e895ac12b98b4b9e8f9a448d5f51e032"
        sampleLibreDataInHex = sampleLibreDataInHex + "45f7210e0bbeae4ac4b46165a7f04e31"
        sampleLibreDataInHex = sampleLibreDataInHex + "b22c774e0754c3e360b46977fd1eaac5"
        sampleLibreDataInHex = sampleLibreDataInHex + "9471fc207a4bbac457e6bb99b890cc9f"
        sampleLibreDataInHex = sampleLibreDataInHex + "2f9888ce93945606"
        
        testData.append(sampleLibreDataInHex)
        patchInfoRange.append("9D083001B707")
        
        sampleLibreDataInHex = "595568d902428c9bc3fb359be3bbcf97"
        sampleLibreDataInHex = sampleLibreDataInHex + "bde78a4c92dde2c766b58715f82730b2"
        sampleLibreDataInHex = sampleLibreDataInHex + "d3fc88d01d5c04332acf0a369dcd5b61"
        sampleLibreDataInHex = sampleLibreDataInHex + "ee32a5623123caec3edc03a80b1dc09d"
        sampleLibreDataInHex = sampleLibreDataInHex + "c6480ec2623eb84405b037ce5867b275"
        sampleLibreDataInHex = sampleLibreDataInHex + "6b8bde90b88487302f845c5b5e7acc9d"
        sampleLibreDataInHex = sampleLibreDataInHex + "c5e9fb8de29468b66c01cf0e564868fb"
        sampleLibreDataInHex = sampleLibreDataInHex + "a095bdb0ffc6c623c24369121bb68f77"
        sampleLibreDataInHex = sampleLibreDataInHex + "a6863046a8a3b9de554d9b3171c30157"
        sampleLibreDataInHex = sampleLibreDataInHex + "88cafe52c621cd9b5a540096e54f05a7"
        sampleLibreDataInHex = sampleLibreDataInHex + "c4cc9f858e305f73ad91b62be2b1c02e"
        sampleLibreDataInHex = sampleLibreDataInHex + "c0ee83797495fe7d36ec174199a1f6da"
        sampleLibreDataInHex = sampleLibreDataInHex + "6d2cbb6942451a95242282d3403b86a4"
        sampleLibreDataInHex = sampleLibreDataInHex + "dfbcfeff2a7038768e3ceec403016248"
        sampleLibreDataInHex = sampleLibreDataInHex + "eca52c96bed85381c2e22fef5e40eed9"
        sampleLibreDataInHex = sampleLibreDataInHex + "6b828c0180a11eb4bffc78c4c582d028"
        sampleLibreDataInHex = sampleLibreDataInHex + "966623b1a1b31cfe697ee28e0c62a0f5"
        sampleLibreDataInHex = sampleLibreDataInHex + "0ccba4d16aa597246bc44c4e8c7f3c88"
        sampleLibreDataInHex = sampleLibreDataInHex + "a1a929cdd89072f020ea69a674de928b"
        sampleLibreDataInHex = sampleLibreDataInHex + "56727f8dd47a1f5984ea61b41130767f"
        sampleLibreDataInHex = sampleLibreDataInHex + "702ff4e3a965667eb3b8b35a6bbe1025"
        sampleLibreDataInHex = sampleLibreDataInHex + "cbc6800d40ba8abc"
        
        testData.append(sampleLibreDataInHex)
        patchInfoRange.append("9D0830017706")
        
        sampleLibreDataInHex = "0942404183a1c33793ec1d036258803b"
        sampleLibreDataInHex = sampleLibreDataInHex + "edf0a2d4133ead6be336a88a79c47f1e"
        sampleLibreDataInHex = sampleLibreDataInHex + "83eb8e4894e58a9e4ed82ae8dd2f26cd"
        sampleLibreDataInHex = sampleLibreDataInHex + "be8d8dfae4c085ac6ecb14308a0a4f30"
        sampleLibreDataInHex = sampleLibreDataInHex + "965f265ae3ddf7e855a71f56d984fdd9"
        sampleLibreDataInHex = sampleLibreDataInHex + "3b9cf6083967c89c7f9374c3df998331"
        sampleLibreDataInHex = sampleLibreDataInHex + "95fed3156377271a68c564584ab34b35"
        sampleLibreDataInHex = sampleLibreDataInHex + "a45116e6e33de5edc687c244074dacb9"
        sampleLibreDataInHex = sampleLibreDataInHex + "a2429b10b4589a10518930676d382299"
        sampleLibreDataInHex = sampleLibreDataInHex + "8c0e5504dadaee555e90abc0f9b42669"
        sampleLibreDataInHex = sampleLibreDataInHex + "c00834d392cb7cbda9551d7dfe4ae3e0"
        sampleLibreDataInHex = sampleLibreDataInHex + "c42a282f686eddb33228bc17855ad514"
        sampleLibreDataInHex = sampleLibreDataInHex + "69e8103f5ebe395b20e629855cc0a56a"
        sampleLibreDataInHex = sampleLibreDataInHex + "db7855a9368b1bb88af845921ffa4186"
        sampleLibreDataInHex = sampleLibreDataInHex + "e86187c0a223704febb563d65da5b96f"
        sampleLibreDataInHex = sampleLibreDataInHex + "42d5c0388344490296ab34fdc667879e"
        sampleLibreDataInHex = sampleLibreDataInHex + "bf316f88a2564b484029aeb70f87f743"
        sampleLibreDataInHex = sampleLibreDataInHex + "259ce8e86940c092429300778f9a863f"
        sampleLibreDataInHex = sampleLibreDataInHex + "88c6a7f5db75254609bd259f773bc53d"
        sampleLibreDataInHex = sampleLibreDataInHex + "7f2533b4d79f48efadbd2d8d17d521c9"
        sampleLibreDataInHex = sampleLibreDataInHex + "5978b8daaa8031c89aefff63685b4793"
        sampleLibreDataInHex = sampleLibreDataInHex + "e291cc34435fdd0a"
        
        testData.append(sampleLibreDataInHex)
        patchInfoRange.append("9D0830010705")
        
        sampleLibreDataInHex = "4c6d7f6ca53d25670c7d544c7d8402ca"
        sampleLibreDataInHex = sampleLibreDataInHex + "7261eb9b0ce22f9a65e8c6747d978450"
        sampleLibreDataInHex = sampleLibreDataInHex + "6d88edb690b671d0d14963a7c2f3a43c"
        sampleLibreDataInHex = sampleLibreDataInHex + "211cc4b5fb1c075d2be42b1dac96a960"
        sampleLibreDataInHex = sampleLibreDataInHex + "cc7011e90540e9b8c2b4961839587fa0"
        sampleLibreDataInHex = sampleLibreDataInHex + "640c5b47262f8a6c675a6b7943996593"
        sampleLibreDataInHex = sampleLibreDataInHex + "7737cc37ff77c1b8858608e3a89d522e"
        sampleLibreDataInHex = sampleLibreDataInHex + "49127a5d0113fcf6f17ad89ddc23d103"
        sampleLibreDataInHex = sampleLibreDataInHex + "95bf81c96f36e7aabcca5cdc8f163b82"
        sampleLibreDataInHex = sampleLibreDataInHex + "614d39bf38f4f74ec221edca001546cd"
        sampleLibreDataInHex = sampleLibreDataInHex + "5cb972d96b6a1c19441671c61c64fafb"
        sampleLibreDataInHex = sampleLibreDataInHex + "296944948a40c4a805d5a6ce5e34a8ae"
        sampleLibreDataInHex = sampleLibreDataInHex + "5e150ae685d044e1cda5453ebeeebc71"
        sampleLibreDataInHex = sampleLibreDataInHex + "363b3912d4a502a368315ab083faa724"
        sampleLibreDataInHex = sampleLibreDataInHex + "0aa898e23e2396ed2b65e802a095d40c"
        sampleLibreDataInHex = sampleLibreDataInHex + "82054bec7e7424618cc5c94b02178e5c"
        sampleLibreDataInHex = sampleLibreDataInHex + "a55f923e6626428a80f92563f2b79a20"
        sampleLibreDataInHex = sampleLibreDataInHex + "e54c633c9470adf1f3b1a112692592e3"
        sampleLibreDataInHex = sampleLibreDataInHex + "39e406903dca319ac96dae4b8a0ba85e"
        sampleLibreDataInHex = sampleLibreDataInHex + "bff5b8602aaf258cb7d3d03bd8a5280b"
        sampleLibreDataInHex = sampleLibreDataInHex + "4316456c6ef0380a5a3f74b7956b2af0"
        sampleLibreDataInHex = sampleLibreDataInHex + "224147e0be6fb069"
        
        testData.append(sampleLibreDataInHex)
        patchInfoRange.append("9D083001B103")
        
        sampleLibreDataInHex = "f93b9e5416eca2cb36f06240c3c66209"
        sampleLibreDataInHex = sampleLibreDataInHex + "1d897cc18673cc971339a7abe11af98d"
        sampleLibreDataInHex = sampleLibreDataInHex + "7392505d01a8eb62408809785e7ed9e1"
        sampleLibreDataInHex = sampleLibreDataInHex + "4ef453ef718de45011691d1112d4c9a3"
        sampleLibreDataInHex = sampleLibreDataInHex + "7926f0d1b6916e14f839a014871a1f63"
        sampleLibreDataInHex = sampleLibreDataInHex + "0be4cc1dacbe6961fa317d7a4747f7a2"
        sampleLibreDataInHex = sampleLibreDataInHex + "6dc90d00a93a4ed418eda6e0ac1bf21e"
        sampleLibreDataInHex = sampleLibreDataInHex + "84bb2fd8696e566994f62c0a808d5e52"
        sampleLibreDataInHex = sampleLibreDataInHex + "7fa8a26a3e0b8f94d906a84bd3b8b4d3"
        sampleLibreDataInHex = sampleLibreDataInHex + "51e46c7e5089fbd10ca1458e7e74d482"
        sampleLibreDataInHex = sampleLibreDataInHex + "1de20da9189869398a96d982620568b4"
        sampleLibreDataInHex = sampleLibreDataInHex + "19c01155e23dc83760195259029a27ff"
        sampleLibreDataInHex = sampleLibreDataInHex + "b4022945d4ed2cdfa869b1a9e2403320"
        sampleLibreDataInHex = sampleLibreDataInHex + "06926cd3bcd80e3cd8c9abdc983ab36d"
        sampleLibreDataInHex = sampleLibreDataInHex + "358bbeba287065cb9b9d196ebb55c045"
        sampleLibreDataInHex = sampleLibreDataInHex + "b2ac1e2d160928fee9093ddc5eb9010d"
        sampleLibreDataInHex = sampleLibreDataInHex + "4f48b19d371b2ab4e535d1f4ae191571"
        sampleLibreDataInHex = sampleLibreDataInHex + "d5e536fdfc0da16e3d310956174400ac"
        sampleLibreDataInHex = sampleLibreDataInHex + "78bf79e04e3844ba07ed060ff46a3a11"
        sampleLibreDataInHex = sampleLibreDataInHex + "8f5ceda142d22913d21f24ac990ba75a"
        sampleLibreDataInHex = sampleLibreDataInHex + "a90166cf3fcd50343ff38020c9c5a5a1"
        sampleLibreDataInHex = sampleLibreDataInHex + "12e81221d612bcf6"
        
        testData.append(sampleLibreDataInHex)
        patchInfoRange.append("9D0830015602")
        
        sampleLibreDataInHex = "e427273796b03676d5c526a655866864"
        sampleLibreDataInHex = sampleLibreDataInHex + "abd9997124e04534b95a9d2eef1a9f1f"
        sampleLibreDataInHex = sampleLibreDataInHex + "c5c26fedab71a2c006bd4ddec83e468c"
        sampleLibreDataInHex = sampleLibreDataInHex + "5baa2a8d42d170298caef8469fd3b571"
        sampleLibreDataInHex = sampleLibreDataInHex + "083b416cf9cc51a865a0b2da74fb9308"
        sampleLibreDataInHex = sampleLibreDataInHex + "c3cc70856b8c66c4bdc216d68de61f68"
        sampleLibreDataInHex = sampleLibreDataInHex + "a5e1b1986e08417185a0bb2e5ffa7e75"
        sampleLibreDataInHex = sampleLibreDataInHex + "b43471d4f62cb6ac2ba2a532125c59f8"
        sampleLibreDataInHex = sampleLibreDataInHex + "4f27fc66a1496f5117a00bc25ae6cac6"
        sampleLibreDataInHex = sampleLibreDataInHex + "ca276ea1ed04060a18b99065ce6ace36"
        sampleLibreDataInHex = sampleLibreDataInHex + "86210f76a51594e244307a0beb5b16a1"
        sampleLibreDataInHex = sampleLibreDataInHex + "294f4f597d7f28f2df4ddb61904b2055"
        sampleLibreDataInHex = sampleLibreDataInHex + "848d77494bafcc1a3524ac6711a1bf4b"
        sampleLibreDataInHex = sampleLibreDataInHex + "cebad04b7bea01999f3ac070529b5ba7"
        sampleLibreDataInHex = sampleLibreDataInHex + "fda30222ef426a6e06d004a048b44c2e"
        sampleLibreDataInHex = sampleLibreDataInHex + "afb0a74e9655bc437bce538bd37672df"
        sampleLibreDataInHex = sampleLibreDataInHex + "525408feb747be090600951238591f1c"
        sampleLibreDataInHex = sampleLibreDataInHex + "63b5d34d5e9e28cd04ba3bd2b8446e60"
        sampleLibreDataInHex = sampleLibreDataInHex + "ceef9c50e0aacd3d26d942e9622a307c"
        sampleLibreDataInHex = sampleLibreDataInHex + "924054c2c28ebdae40d84afb1cc4d488"
        sampleLibreDataInHex = sampleLibreDataInHex + "b41ddfacbf91c489a2be9dee3a2429ca"
        sampleLibreDataInHex = sampleLibreDataInHex + "dac0aeb91120b353"
        
        testData.append(sampleLibreDataInHex)
        patchInfoRange.append("9D083001831B")
        // CGMMiaoMiaoTransmitter.testPeripheralDidUpdateValue(libreDataAsHexString: testData[0], serialNumberAsHexString: nil, patchInfoAsHexString: patchInfoRange[0])
        
        let libreDataParser: LibreDataParser = LibreDataParser()

        var testTimeStamp = Date(timeIntervalSinceNow: -300.0 * Double(testData.count + 1))
        
        for (index, data) in testData.enumerated() {
         
            CGMMiaoMiaoTransmitter.testPeripheralDidUpdateValue(libreDataAsHexString: data, serialNumberAsHexString: nil, patchInfoAsHexString: patchInfoRange[index], cGMTransmitterDelegate: cGMTransmitterDelegate, libreDataParser: libreDataParser, testTimeStamp: nil)
            
            testTimeStamp = testTimeStamp.addingTimeInterval(300.0)
         
        }

    }
    
}



