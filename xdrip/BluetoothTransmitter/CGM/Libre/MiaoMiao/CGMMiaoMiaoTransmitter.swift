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
    
    /// oop website url to use in case oop web would be enabled
    private var oopWebSite: String
    
    /// oop token to use in case oop web would be enabled
    private var oopWebToken: String
        
    // current sensor serial number, if nil then it's not known yet
    private var sensorSerialNumber:String?

    /// used as parameter in call to cgmTransmitterDelegate.cgmTransmitterInfoReceived, when there's no glucosedata to send
    var emptyArray: [GlucoseData] = []

    // MARK: - Initialization
    /// - parameters:
    ///     - address: if already connected before, then give here the address that was received during previous connect, if not give nil
    ///     - name : if already connected before, then give here the name that was received during previous connect, if not give nil
    ///     - webOOPEnabled : enabled or not
    ///     - oopWebSite : oop web site url to use, only used in case webOOPEnabled = true
    ///     - oopWebToken : oop web token to use, only used in case webOOPEnabled = true
    ///     - bluetoothTransmitterDelegate : a BluetoothTransmitterDelegate
    ///     - cGMTransmitterDelegate : a CGMTransmitterDelegate
    ///     - cGMMiaoMiaoTransmitterDelegate : a CGMMiaoMiaoTransmitterDelegate
    init(address:String?, name: String?, bluetoothTransmitterDelegate: BluetoothTransmitterDelegate, cGMMiaoMiaoTransmitterDelegate : CGMMiaoMiaoTransmitterDelegate, cGMTransmitterDelegate:CGMTransmitterDelegate, sensorSerialNumber:String?, webOOPEnabled: Bool?, oopWebSite: String?, oopWebToken: String?, nonFixedSlopeEnabled: Bool?) {
        
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
        
        // initialize oopWebToken and oopWebSite
        self.oopWebToken = oopWebToken ?? ConstantsLibre.token
        self.oopWebSite = oopWebSite ?? ConstantsLibre.site
        
        // initialize nonFixedSlopeEnabled
        self.nonFixedSlopeEnabled = nonFixedSlopeEnabled ?? false

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
                                
                                cGMMiaoMiaoTransmitterDelegate?.received(libreSensorType: libreSensorType, from: self)

                                // decrypt of libre2 or libreUS
                                dataIsDecryptedToLibre1Format = libreSensorType.decryptIfPossibleAndNeeded(rxBuffer: &rxBuffer, headerLength: miaoMiaoHeaderLength, log: log, patchInfo: patchInfo, uid: rxBuffer[5..<13].bytes)
                                
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
                            cgmTransmitterDelegate?.cgmTransmitterInfoReceived(glucoseData: &emptyArray, transmitterBatteryInfo: TransmitterBatteryInfo.percentage(percentage: batteryPercentage), sensorTimeInMinutes: nil)

                            // get sensor serialNumber and if changed inform delegate
                            if let libreSensorSerialNumber = LibreSensorSerialNumber(withUID: Data(rxBuffer.subdata(in: 5..<13))) {
                                
                                // (there will also be a seperate opcode form MiaoMiao because it's able to detect new sensor also)
                                if libreSensorSerialNumber.serialNumber != sensorSerialNumber {
                                    
                                    sensorSerialNumber = libreSensorSerialNumber.serialNumber
                                    
                                    trace("    new sensor detected :  %{public}@", log: log, category: ConstantsLog.categoryCGMMiaoMiao, type: .info, libreSensorSerialNumber.serialNumber)
                                    
                                    // inform delegate about new sensor detected
                                    cgmTransmitterDelegate?.newSensorDetected()
                                    
                                    cGMMiaoMiaoTransmitterDelegate?.received(serialNumber: libreSensorSerialNumber.serialNumber, from: self)
                                    
                                }
                                
                            }
                            
                            LibreDataParser.libreDataProcessor(libreSensorSerialNumber: LibreSensorSerialNumber(withUID: Data(rxBuffer.subdata(in: 5..<13))), patchInfo: patchInfo, webOOPEnabled: webOOPEnabled, oopWebSite: oopWebSite, oopWebToken: oopWebToken, libreData: (rxBuffer.subdata(in: miaoMiaoHeaderLength..<(344 + miaoMiaoHeaderLength))), cgmTransmitterDelegate: cgmTransmitterDelegate, dataIsDecryptedToLibre1Format: dataIsDecryptedToLibre1Format, completionHandler: { (sensorState: LibreSensorState?, xDripError: XdripError?) in
                                
                                if let sensorState = sensorState {
                                    self.cGMMiaoMiaoTransmitterDelegate?.received(sensorStatus: sensorState, from: self)
                                }
                                
                                // TODO : xDripError could be used to show latest errors in bluetoothPeripheralView
                                
                            })
                            
                            //reset the buffer
                            resetRxBuffer()

                        }
                        
                    case .frequencyChangedResponse:
                        trace("in peripheral didUpdateValueFor, frequencyChangedResponse received, shound't happen ?", log: log, category: ConstantsLog.categoryCGMMiaoMiao, type: .error)
                        
                    case .newSensor:
                        trace("in peripheral didUpdateValueFor, new sensor detected", log: log, category: ConstantsLog.categoryCGMMiaoMiao, type: .info)
                        cgmTransmitterDelegate?.newSensorDetected()
                        
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
    
    func setWebOOPSite(oopWebSite: String) {
        self.oopWebSite = oopWebSite
    }
    
    func setWebOOPToken(oopWebToken: String) {
        self.oopWebToken = oopWebToken
    }
    
    func requestNewReading() {
        _ = sendStartReadingCommand()
    }
    
    func cgmTransmitterType() -> CGMTransmitterType {
        return .miaomiao
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
    public static func testPeripheralDidUpdateValue(libreDataAsHexString: String?, serialNumberAsHexString: String?, patchInfoAsHexString:String?) {
        
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
                            dataIsDecryptedToLibre1Format = libreSensorType.decryptIfPossibleAndNeeded(rxBuffer: &rxBuffer, headerLength: miaoMiaoHeaderLength, log: nil, patchInfo: patchInfo, uid: rxBuffer[5..<13].bytes)
                            
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
                        if let libreSensorSerialNumber = LibreSensorSerialNumber(withUID: Data(rxBuffer.subdata(in: 5..<13))) {
                            
                            // (there will also be a seperate opcode form MiaoMiao because it's able to detect new sensor also)
                            if libreSensorSerialNumber.serialNumber != previousSensorSerialNumber {
                                
                                previousSensorSerialNumber = libreSensorSerialNumber.serialNumber
                                
                            }
                            
                        }
                        
                        LibreDataParser.libreDataProcessor(libreSensorSerialNumber: LibreSensorSerialNumber(withUID: Data(rxBuffer.subdata(in: 5..<13))), patchInfo: patchInfo, webOOPEnabled: true, oopWebSite: ConstantsLibre.site, oopWebToken: ConstantsLibre.token, libreData: (rxBuffer.subdata(in: miaoMiaoHeaderLength..<(344 + miaoMiaoHeaderLength))), cgmTransmitterDelegate: nil, dataIsDecryptedToLibre1Format: dataIsDecryptedToLibre1Format, completionHandler: { (sensorState: LibreSensorState?, xDripError: XdripError?) in
                            
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
    
    public static func testRange() {
        
        var testData = [String]()
        var patchInfoRange = [String]()
        var sampleLibreDataInHex = ""
        
        // the first element is taken from another range of tests
        sampleLibreDataInHex = "431d9ea2310d6903d9b3c3e0d0f42a0f"
        sampleLibreDataInHex = sampleLibreDataInHex + "a7af7c37a192075f5f1c7c6b9565dddc"
        sampleLibreDataInHex = sampleLibreDataInHex + "0ab505a62e7fe3ab4d8af42bac82c2f4"
        sampleLibreDataInHex = sampleLibreDataInHex + "f4ce50197f612ff02794f7de30e8e604"
        sampleLibreDataInHex = sampleLibreDataInHex + "f60df8a5527110d117fec2b5492557dd"
        sampleLibreDataInHex = sampleLibreDataInHex + "72c30ce68b2f61a811c1a2966e351608"
        sampleLibreDataInHex = sampleLibreDataInHex + "dfd9cef7aed685a40c0932d9e7bd9679"
        sampleLibreDataInHex = sampleLibreDataInHex + "d8902fca8d8e63aca1ab38c949f97215"
        sampleLibreDataInHex = sampleLibreDataInHex + "088ffd9a1916885dc743094b0c8b01d4"
        sampleLibreDataInHex = sampleLibreDataInHex + "ebfea1892e683021f45d1c4f543e3524"
        sampleLibreDataInHex = sampleLibreDataInHex + "efc40505f2787af1ce0526f138f93dcc"
        sampleLibreDataInHex = sampleLibreDataInHex + "a0e637a2cd3201ff3fe58dbd28e8965e"
        sampleLibreDataInHex = sampleLibreDataInHex + "0ef02eb36b0ae7f3402ac70cf1227b26"
        sampleLibreDataInHex = sampleLibreDataInHex + "49b06cfd9c399effedb0bc1f17419708"
        sampleLibreDataInHex = sampleLibreDataInHex + "88ad0a43070fae0354e2bd4de8094d52"
        sampleLibreDataInHex = sampleLibreDataInHex + "084219db30e5e3badcf49b127ca96daa"
        sampleLibreDataInHex = sampleLibreDataInHex + "7060b11711fa1a720a0e7054f72a5d47"
        sampleLibreDataInHex = sampleLibreDataInHex + "69c34305db4c6ea671c3de9c3836b404"
        sampleLibreDataInHex = sampleLibreDataInHex + "c2757c1630d48f8a45e29f7ecdad6e09"
        sampleLibreDataInHex = sampleLibreDataInHex + "ab7be5156b33c2dcef483e6f2f568bfd"
        sampleLibreDataInHex = sampleLibreDataInHex + "13276639182c9bfcd0b02180daf7eda7"
        sampleLibreDataInHex = sampleLibreDataInHex + "a8ce12d7f1f3773e"
        testData.append(sampleLibreDataInHex)
        patchInfoRange.append("9D083001D718")
        
        sampleLibreDataInHex = "4fc0096be8c74510005a51d24e509d04"
        sampleLibreDataInHex = sampleLibreDataInHex + "7e46ee053f36b054f378ee4448c162d5"
        sampleLibreDataInHex = sampleLibreDataInHex + "1f5ddb94b00798a17a2f3a0adce8d5e1"
        sampleLibreDataInHex = sampleLibreDataInHex + "869352f9000a85119930fe3f84598010"
        sampleLibreDataInHex = sampleLibreDataInHex + "42a83648221b17c4ce135c870e81e0d6"
        sampleLibreDataInHex = sampleLibreDataInHex + "672b51d415471aa219283836fc914003"
        sampleLibreDataInHex = sampleLibreDataInHex + "069450c5067232f3e146797f21190213"
        sampleLibreDataInHex = sampleLibreDataInHex + "dbde5f08875b68c780f9846e282c2a4a"
        sampleLibreDataInHex = sampleLibreDataInHex + "29c1233ddff6d03689ea59d270c30a4e"
        sampleLibreDataInHex = sampleLibreDataInHex + "6d3e3c211f2368487ff5c2e4288263bd"
        sampleLibreDataInHex = sampleLibreDataInHex + "c06155e481304c65e351ea8a837278db"
        sampleLibreDataInHex = sampleLibreDataInHex + "4c03d7d4931984797f0d81bbb46eccd5"
        sampleLibreDataInHex = sampleLibreDataInHex + "232827c99880a2b00483e0ab8d1ee1be"
        sampleLibreDataInHex = sampleLibreDataInHex + "721734b2257089666b942ab76d0bc73b"
        sampleLibreDataInHex = sampleLibreDataInHex + "cc043ee973b5329b037ae8b7102e81d8"
        sampleLibreDataInHex = sampleLibreDataInHex + "5b768f8841ce207b44693c4c47e7252a"
        sampleLibreDataInHex = sampleLibreDataInHex + "06f0e459e1dd55ff8c4aeafcbd6f055e"
        sampleLibreDataInHex = sampleLibreDataInHex + "256a74a8a7a0ff3e29688e258e7ff89e"
        sampleLibreDataInHex = sampleLibreDataInHex + "44b9e6bee09ad77fa3076e0493e2e78f"
        sampleLibreDataInHex = sampleLibreDataInHex + "d29fe94b35b4b95bc2b83215e0c4ce7a"
        sampleLibreDataInHex = sampleLibreDataInHex + "3ec36a4346abde7b56187129a6bfb53e"
        sampleLibreDataInHex = sampleLibreDataInHex + "2e66427e8dbb2fa7"
        
        testData.append(sampleLibreDataInHex)
        patchInfoRange.append("9D083001AB33")
        
        sampleLibreDataInHex = "f1eff6d21ea36c22be75ae6bb834b436"
        sampleLibreDataInHex = sampleLibreDataInHex + "c06911bcc95299663daa1cfa0ba54be3"
        sampleLibreDataInHex = sampleLibreDataInHex + "a172242d4663b193c400c5b32a8cfcd3"
        sampleLibreDataInHex = sampleLibreDataInHex + "38bcad40f66eac23271f0186723da922"
        sampleLibreDataInHex = sampleLibreDataInHex + "fc87c9f1d47f3ef6703ca33ef8e5c9e4"
        sampleLibreDataInHex = sampleLibreDataInHex + "d904ae6de3233390a707c78f0af56931"
        sampleLibreDataInHex = sampleLibreDataInHex + "b8bbaf7c06161bc55f697cc6d7792b21"
        sampleLibreDataInHex = sampleLibreDataInHex + "a2f1a0b5713f98f53ed27bd7de480378"
        sampleLibreDataInHex = sampleLibreDataInHex + "97eedc842992f90411c40051e64df8f6"
        sampleLibreDataInHex = sampleLibreDataInHex + "f57868a289adb6f2e7db9b67be0cbd07"
        sampleLibreDataInHex = sampleLibreDataInHex + "584f0c6717be92df7b7fb30915fca661"
        sampleLibreDataInHex = sampleLibreDataInHex + "d42d8e5705975ac3e723d83822e0126f"
        sampleLibreDataInHex = sampleLibreDataInHex + "bb067e4a0e0e7c0a9cadb9281b903f04"
        sampleLibreDataInHex = sampleLibreDataInHex + "ea396d31b3fe57dcf3ba7334fb851981"
        sampleLibreDataInHex = sampleLibreDataInHex + "542a676ae53bec219b54b13486a05f62"
        sampleLibreDataInHex = sampleLibreDataInHex + "c358d60bd740fec1dc4765cfd169fb90"
        sampleLibreDataInHex = sampleLibreDataInHex + "9edebdda77538b451464b37f2be1dbe4"
        sampleLibreDataInHex = sampleLibreDataInHex + "bd442d2b312e2184b146d7a618f12624"
        sampleLibreDataInHex = sampleLibreDataInHex + "dc97bf3d761409c53b293787056c3935"
        sampleLibreDataInHex = sampleLibreDataInHex + "4ab1b0c8a33a67e15a966b968b4d10c0"
        sampleLibreDataInHex = sampleLibreDataInHex + "a6ed33c0d02500c1ce3628aa30316b84"
        sampleLibreDataInHex = sampleLibreDataInHex + "b6481bfd1b35f11d"
        
        testData.append(sampleLibreDataInHex)
        patchInfoRange.append("9D0830016B32")
        
        sampleLibreDataInHex = "3244c69c763a7ec4290d1deb4db5cab2"
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
        
        testData.append(sampleLibreDataInHex)
        patchInfoRange.append("9D083001FB30")
        
        sampleLibreDataInHex = "4497d9548b50d2cfde3984166aa991c3"
        sampleLibreDataInHex = sampleLibreDataInHex + "a0253bc11bcfbc938a5f3c87d9386e16"
        sampleLibreDataInHex = sampleLibreDataInHex + "c13ebf5094fa94665beb0d6aa061de46"
        sampleLibreDataInHex = sampleLibreDataInHex + "a06765a957836686bff4a16ff8e063b7"
        sampleLibreDataInHex = sampleLibreDataInHex + "e86b01285e927e6443af3704e8c01e5b"
        sampleLibreDataInHex = sampleLibreDataInHex + "eaa3e0504b29e41b2fa7538162d6beba"
        sampleLibreDataInHex = sampleLibreDataInHex + "8b1c3b46ae34cc4ec782b42f5d94e1b4"
        sampleLibreDataInHex = sampleLibreDataInHex + "3a1a685cfbd25260a639b33e54a5c9ed"
        sampleLibreDataInHex = sampleLibreDataInHex + "0f05146da37f339108c84e8db6d6c519"
        sampleLibreDataInHex = sampleLibreDataInHex + "ec74267ed9368b1dfed7d5bbee9780e8"
        sampleLibreDataInHex = sampleLibreDataInHex + "414342bb4725af30b747f82e02090096"
        sampleLibreDataInHex = sampleLibreDataInHex + "1815c5701262fc342b1b931f3515b498"
        sampleLibreDataInHex = sampleLibreDataInHex + "773e356d19fbdafdfbd9aedc2eaa84ed"
        sampleLibreDataInHex = sampleLibreDataInHex + "8d4d7ac586c4ec3594ce64c0cebfa268"
        sampleLibreDataInHex = sampleLibreDataInHex + "335e709ed00157c8576cfa139155f995"
        sampleLibreDataInHex = sampleLibreDataInHex + "0f609d2cc0b55836107f2ee8c69c5d67"
        sampleLibreDataInHex = sampleLibreDataInHex + "52e6f6fd60a62db20d68fda37b7ae60b"
        sampleLibreDataInHex = sampleLibreDataInHex + "a44863f761b51c6ba84a997a486a1bcb"
        sampleLibreDataInHex = sampleLibreDataInHex + "c59bf1e1268f342af9b30814aacb0628"
        sampleLibreDataInHex = sampleLibreDataInHex + "882b8f5b0c9d58fc980c54052eea2fdd"
        sampleLibreDataInHex = sampleLibreDataInHex + "64770c537f823fdca7e04beabd594987"
        sampleLibreDataInHex = sampleLibreDataInHex + "df9e78bd965dd31e"
        
        testData.append(sampleLibreDataInHex)
        patchInfoRange.append("9D0830019F2F")
        
        sampleLibreDataInHex = "803312dd230e2cdc4ff8eec9f624ec1e"
        sampleLibreDataInHex = sampleLibreDataInHex + "be3f862a8ad1262167fa5d5945b513cb"
        sampleLibreDataInHex = sampleLibreDataInHex + "059a74d93ca46a75328d8521649c4cfb"
        sampleLibreDataInHex = sampleLibreDataInHex + "46da3ad69eed1354d69229243c1df10a"
        sampleLibreDataInHex = sampleLibreDataInHex + "7f2474e68c7372098185e39c0ef291f8"
        sampleLibreDataInHex = sampleLibreDataInHex + "a752e3fca0888cd7ed8d871984e47019"
        sampleLibreDataInHex = sampleLibreDataInHex + "1c7b4e8870d5c00faee42c6499597309"
        sampleLibreDataInHex = sampleLibreDataInHex + "f5a7371332bceeb2cf6f3b7590585b50"
        sampleLibreDataInHex = sampleLibreDataInHex + "b2e1bb458927d598e04940f3a85da0de"
        sampleLibreDataInHex = sampleLibreDataInHex + "8b2eff34ff2b09751b56dbc5f01ce52f"
        sampleLibreDataInHex = sampleLibreDataInHex + "fca7ed936d7d49398af2f3ab5becfe49"
        sampleLibreDataInHex = sampleLibreDataInHex + "aa7b19c14614e58416ae989a6cf04a47"
        sampleLibreDataInHex = sampleLibreDataInHex + "b4a2c36d5602baf26d20f98a5580672c"
        sampleLibreDataInHex = sampleLibreDataInHex + "946ffaa7f07de89b02373396b59541a9"
        sampleLibreDataInHex = sampleLibreDataInHex + "f0c2869e9ff837c76ad9f196c8b0074a"
        sampleLibreDataInHex = sampleLibreDataInHex + "bd0e419d94c341862dca256d9f79a3b8"
        sampleLibreDataInHex = sampleLibreDataInHex + "ef0259d54afecbbbe5e9f3dd65f183cc"
        sampleLibreDataInHex = sampleLibreDataInHex + "c312babd72ad9ec340cb970456e17e0c"
        sampleLibreDataInHex = sampleLibreDataInHex + "787f5ec90cd7d223caa477254b7c611d"
        sampleLibreDataInHex = sampleLibreDataInHex + "34e7275ee0b9d8a6ab1b2b34d45d48e8"
        sampleLibreDataInHex = sampleLibreDataInHex + "a9498ee78829c6393fbb68087e2133ac"
        sampleLibreDataInHex = sampleLibreDataInHex + "c81e8c6b58b64e5a"
        
        testData.append(sampleLibreDataInHex)
        patchInfoRange.append("9D083001742E")
        
        sampleLibreDataInHex = "b046de8656527fc4ab0f05f16dddcbb2"
        sampleLibreDataInHex = sampleLibreDataInHex + "d513ba261cbbe6e23a80b3619d4c3457"
        sampleLibreDataInHex = sampleLibreDataInHex + "b40872b793bece17267a6e1dff658857"
        sampleLibreDataInHex = sampleLibreDataInHex + "2dee06da2487d38f3265c21ca7e4d6a6"
        sampleLibreDataInHex = sampleLibreDataInHex + "65fa625b0196cb75657208a4950bb654"
        sampleLibreDataInHex = sampleLibreDataInHex + "cc7edff036e24c14097a6c211f1d57b5"
        sampleLibreDataInHex = sampleLibreDataInHex + "ade904e6dfff646d4a13c75c02a054a5"
        sampleLibreDataInHex = sampleLibreDataInHex + "9e8b0b1fa4d62e712b98d04d0ba17cfc"
        sampleLibreDataInHex = sampleLibreDataInHex + "8294771efc7b8680506d2805aebceb10"
        sampleLibreDataInHex = sampleLibreDataInHex + "b4d140f6f459a5d4ab72b333f6fdaee1"
        sampleLibreDataInHex = sampleLibreDataInHex + "19e624335f4f81393ad69b5d5d0db587"
        sampleLibreDataInHex = sampleLibreDataInHex + "9584a6034d664925a68af06c6a110189"
        sampleLibreDataInHex = sampleLibreDataInHex + "faaf561e46ff6fecdd04917c53612ce2"
        sampleLibreDataInHex = sampleLibreDataInHex + "ab904565fb0f443ab2135b60b3740a67"
        sampleLibreDataInHex = sampleLibreDataInHex + "15834f3eadcaffc7dafd9960ce514c84"
        sampleLibreDataInHex = sampleLibreDataInHex + "82f1fe5f9fb1ed279dee4d9b9998e876"
        sampleLibreDataInHex = sampleLibreDataInHex + "df77958e3fa298a3785e7c447c0ebc7a"
        sampleLibreDataInHex = sampleLibreDataInHex + "d17ee21066c1461add7c189d4f1e41ba"
        sampleLibreDataInHex = sampleLibreDataInHex + "b0ad700621fb6e5b5713f8bc52835eab"
        sampleLibreDataInHex = sampleLibreDataInHex + "268b7ff3f4d5007f36aca4adc8a2775e"
        sampleLibreDataInHex = sampleLibreDataInHex + "cad7fcfb87ca675fa20ce79167de0c1a"
        sampleLibreDataInHex = sampleLibreDataInHex + "da72d4c64cda9683"
        
        testData.append(sampleLibreDataInHex)
        patchInfoRange.append("9D083001FB2C")
        
        CGMMiaoMiaoTransmitter.testPeripheralDidUpdateValue(libreDataAsHexString: testData[0], serialNumberAsHexString: nil, patchInfoAsHexString: patchInfoRange[0])
        
        /*for (index, data) in testData.enumerated() {
         
         CGMMiaoMiaoTransmitter.testPeripheralDidUpdateValue(libreDataAsHexString: data, serialNumberAsHexString: nil, patchInfoAsHexString: patchInfoRange[index])
         
        }*/

    }
    
}



