import Foundation
import CoreBluetooth
import os

class CGMBubbleTransmitter:BluetoothTransmitter, CGMTransmitter {
    
    // MARK: - properties
    
    /// service to be discovered
    let CBUUID_Service_Bubble: String = "6E400001-B5A3-F393-E0A9-E50E24DCCA9E"
    /// receive characteristic
    let CBUUID_ReceiveCharacteristic_Bubble: String = "6E400003-B5A3-F393-E0A9-E50E24DCCA9E"
    /// write characteristic
    let CBUUID_WriteCharacteristic_Bubble: String = "6E400002-B5A3-F393-E0A9-E50E24DCCA9E"
    
    /// expected device name
    let expectedDeviceNameBubble:String = "Bubble"
    
    /// CGMBubbleTransmitterDelegate
    public weak var cGMBubbleTransmitterDelegate: CGMBubbleTransmitterDelegate?

    /// will be used to pass back bluetooth and cgm related events
    private(set) weak var cgmTransmitterDelegate: CGMTransmitterDelegate?
    
    /// for trace
    private let log = OSLog(subsystem: ConstantsLog.subSystem, category: ConstantsLog.categoryCGMBubble)
    
    /// timestamp of last received reading. When a new packet is received, then only the more recent readings will be treated
    private var timeStampLastBgReading:Date
    
    /// used when processing Bubble data packet
    private var startDate:Date
    // receive buffer for bubble packets
    private var rxBuffer:Data
    // how long to wait for next packet before sending startreadingcommand
    private static let maxWaitForpacketInSeconds = 60.0
    // length of header added by Bubble in front of data dat is received from Libre sensor
    private let bubbleHeaderLength = 8
   
    /// is the transmitter oop web enabled or not
    private var webOOPEnabled: Bool

    /// is nonFixed enabled for the transmitter or not
    private var nonFixedSlopeEnabled: Bool
    
    /// used as parameter in call to cgmTransmitterDelegate.cgmTransmitterInfoReceived, when there's no glucosedata to send
    var emptyArray: [GlucoseData] = []
    
    /// current sensor serial number, if nil then it's not known yet
    private var sensorSerialNumber:String?
    
    /// - sensor serial number stored in type LibreSensorSerialNumber
    /// - this is for temporary storage, when receiving .serialNumber from transmitter
    private var libreSensorSerialNumber:LibreSensorSerialNumber?
    
    /// gives information about type of sensor (Libre1, Libre2, etc..)
    private var patchInfo: String?
    
    /// oop website url to use in case oop web would be enabled
    private var oopWebSite: String
    
    /// oop token to use in case oop web would be enabled
    private var oopWebToken: String
    
    /// hold libre pro/h data and handle the data
    private var librePro: LibrePro?
    
    /// bubble firmware version
    private var firmware: String?
    
    // MARK: - Initialization
    
    /// - parameters:
    ///     - address: if already connected before, then give here the address that was received during previous connect, if not give nil
    ///     - name : if already connected before, then give here the name that was received during previous connect, if not give nil
    ///     - delegate : CGMTransmitterDelegate intance
    ///     - timeStampLastBgReading : timestamp of last bgReading, if nil then 1 1 1970 is used
    ///     - webOOPEnabled : enabled or not, if nil then default false
    ///     - oopWebSite : oop web site url to use, only used in case webOOPEnabled = true, if nil then default value is used (see Constants)
    ///     - oopWebToken : oop web token to use, only used in case webOOPEnabled = true, if nil then default value is used (see Constants)
    ///     - bluetoothTransmitterDelegate : a BluetoothTransmitterDelegate
    ///     - cGMTransmitterDelegate : a CGMTransmitterDelegate
    ///     - cGMBubbleTransmitterDelegate : a CGMBubbleTransmitterDelegate
    init(address:String?, name: String?, bluetoothTransmitterDelegate: BluetoothTransmitterDelegate, cGMBubbleTransmitterDelegate: CGMBubbleTransmitterDelegate, cGMTransmitterDelegate:CGMTransmitterDelegate, timeStampLastBgReading:Date?, sensorSerialNumber:String?, webOOPEnabled: Bool?, oopWebSite: String?, oopWebToken: String?, nonFixedSlopeEnabled: Bool?) {
        
        // assign addressname and name or expected devicename
        var newAddressAndName:BluetoothTransmitter.DeviceAddressAndName = BluetoothTransmitter.DeviceAddressAndName.notYetConnected(expectedName: expectedDeviceNameBubble)
        if let address = address {
            newAddressAndName = BluetoothTransmitter.DeviceAddressAndName.alreadyConnectedBefore(address: address, name: name)
        }
        
        // initialize sensorSerialNumber
        self.sensorSerialNumber = sensorSerialNumber
        
        // assign CGMTransmitterDelegate
        self.cgmTransmitterDelegate = cGMTransmitterDelegate
        
        // assign CGMBubbleTransmitterDelegate
        self.cGMBubbleTransmitterDelegate = cGMBubbleTransmitterDelegate
        
        // initialize rxbuffer
        rxBuffer = Data()
        startDate = Date()
        
        // initialize timeStampLastBgReading
        self.timeStampLastBgReading = timeStampLastBgReading ?? Date(timeIntervalSince1970: 0)
        
        // initialize nonFixedSlopeEnabled
        self.nonFixedSlopeEnabled = nonFixedSlopeEnabled ?? false
        
        // initialize webOOPEnabled
        self.webOOPEnabled = webOOPEnabled ?? false
        
        // initialize oopWebToken and oopWebSite
        self.oopWebToken = oopWebToken ?? ConstantsLibre.token
        self.oopWebSite = oopWebSite ?? ConstantsLibre.site
        
        super.init(addressAndName: newAddressAndName, CBUUID_Advertisement: nil, servicesCBUUIDs: [CBUUID(string: CBUUID_Service_Bubble)], CBUUID_ReceiveCharacteristic: CBUUID_ReceiveCharacteristic_Bubble, CBUUID_WriteCharacteristic: CBUUID_WriteCharacteristic_Bubble, bluetoothTransmitterDelegate: bluetoothTransmitterDelegate)
        
    }
    
    // MARK: - public functions
    
    func sendStartReadingCommmand() -> Bool {
        if writeDataToPeripheral(data: Data([0x00, 0x00, 0x05]), type: .withoutResponse) {
            return true
        } else {
            trace("in sendStartReadingCommmand, write failed", log: log, category: ConstantsLog.categoryCGMBubble, type: .error)
            return false
        }
    }
    
    // MARK: - overriden  BluetoothTransmitter functions
    
    override func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        
        super.peripheral(peripheral, didUpdateNotificationStateFor: characteristic, error: error)
        
        if error == nil && characteristic.isNotifying {
            _ = sendStartReadingCommmand()
        }
        
    }

    override func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        
        super.peripheral(peripheral, didUpdateValueFor: characteristic, error: error)
        
        if let value = characteristic.value {
            
            //check if buffer needs to be reset
            if (Date() > startDate.addingTimeInterval(CGMBubbleTransmitter.maxWaitForpacketInSeconds - 1)) {
                trace("in peripheral didUpdateValueFor, more than %{public}@ seconds since last update - or first update since app launch, resetting buffer", log: log, category: ConstantsLog.categoryCGMBubble, type: .info, CGMBubbleTransmitter.maxWaitForpacketInSeconds.description)
                resetRxBuffer()
            }
            
            if let firstByte = value.first {
                if let bubbleResponseState = BubbleResponseType(rawValue: firstByte) {
                    switch bubbleResponseState {
                        
                    case .dataInfo:
                        
                        // get hardware, firmware and batteryPercentage
                        let hardware = value[value.count-2].description + "." + value[value.count-1].description
                        let firmware = value[2].description + "." + value[3].description
                        let batteryPercentage = Int(value[4])
                        
                        // send firmware, hardware and battery to delegeate
                        cGMBubbleTransmitterDelegate?.received(firmware: firmware, from: self)
                        cGMBubbleTransmitterDelegate?.received(hardware: hardware, from: self)
                        cGMBubbleTransmitterDelegate?.received(batteryLevel: batteryPercentage, from: self)
                        
                        // send batteryPercentage to delegate
                        cgmTransmitterDelegate?.cgmTransmitterInfoReceived(glucoseData: &emptyArray, transmitterBatteryInfo: TransmitterBatteryInfo.percentage(percentage: batteryPercentage), sensorTimeInMinutes: nil)
                        
                        self.firmware = firmware
                        // confirm receipt
                        // if firmware >= 2.6, write [0x08, 0x01, 0x00, 0x00, 0x00, 0x2B]
                        // bubble will decrypt the libre2 data and return it
                        if firmware.toDouble() ?? 0 >= 2.6 {
                            _ = writeDataToPeripheral(data: Data([0x08, 0x01, 0x00, 0x00, 0x00, 0x2B]), type: .withoutResponse)
                        } else {
                            _ = writeDataToPeripheral(data: Data([0x02, 0x00, 0x00, 0x00, 0x00, 0x2B]), type: .withoutResponse)
                        }
                        
                    case .serialNumber:
                        
                        guard value.count >= 10 else { return }
                        
                        // as serialNumber is always the first packet being sent, resetRxBuffer (just in case it wasn't done yet
                        resetRxBuffer()
                        
                        // this is actually the sensor serial number, adding it to rxBuffer (we could also not add it and set bubbleHeaderLength to 0 - this is historuc
                        rxBuffer.append(value.subdata(in: 2..<10))
                        
                        // get libreSensorSerialNumber, if this fails, then self.libreSensorSerialNumber will keep it's current value
                        guard let libreSensorSerialNumber = LibreSensorSerialNumber(withUID: Data(rxBuffer.subdata(in: 0..<8))) else {
                            trace("    could not create libreSensorSerialNumber", log: self.log, category: ConstantsLog.categoryCGMBubble, type: .info)
                            return
                        }
                        
                        // assign self.libreSensorSerialNumber to received libreSensorSerialNumber
                        self.libreSensorSerialNumber = libreSensorSerialNumber

                        
                    case .dataPacket, .decryptedDataPacket:
                        // decryptedDataPacket for bubble firmware >= 2.6
                        // write [0x08, 0x01, 0x00, 0x00, 0x00, 0x2B] callback
                        
                        // sensor libre pro/h histories
                        if (value[1] == 0x04) {
                            rxBuffer.append(value.suffix(from: 4))
                            if rxBuffer.count >= 200 + 352 {
                                handleDataPackages()
                            }
                            return
                        }
                        
                        
                        rxBuffer.append(value.suffix(from: 4))
                        
                        if rxBuffer.count >= 352 {
                            
                            // crc check only for Libre 1
                            guard crcIsOk(rxBuffer: &self.rxBuffer, patchInfo: patchInfo, bubbleHeaderLength: bubbleHeaderLength, log: log) else {
                                return
                            }
                            
                            // did we receive a serialNumber ?
                            if let libreSensorSerialNumber = libreSensorSerialNumber {

                                // verify serial number and if changed inform delegate
                                if libreSensorSerialNumber.serialNumber != sensorSerialNumber {

                                    // store self.sensorSerialNumber
                                    sensorSerialNumber = libreSensorSerialNumber.serialNumber
                                    
                                    trace("    new sensor detected :  %{public}@", log: log, category: ConstantsLog.categoryCGMBubble, type: .info, libreSensorSerialNumber.serialNumber)
                                    
                                    // inform cgmTransmitterDelegate about new sensor detected
                                    cgmTransmitterDelegate?.newSensorDetected()
                                    
                                    // inform cGMBubbleTransmitterDelegate about new sensor detected
                                    cGMBubbleTransmitterDelegate?.received(serialNumber: libreSensorSerialNumber.serialNumber, from: self)
                                    
                                    // also reset timestamp last reading, to be sure that if new sensor is started, we get historic data
                                    timeStampLastBgReading = Date(timeIntervalSince1970: 0)
                                    
                                }

                            }
                            
                            if let libreSensorType = LibreSensorType.type(patchInfo: patchInfo) {
                                // handle libreProH data
                                if libreSensorType == .libreProH {
                                    let time = CLongLong(Date().timeIntervalSince1970 * 1000)
                                    let pro = LibrePro(j: time, j2: time, bArr: rxBuffer.subdata(in: bubbleHeaderLength..<(344 + bubbleHeaderLength)).bytes)
                                    // proStart != nil means can read pro histories
                                    if let proStart = pro.proStart() {
                                        let starts = proStart.toByteArray()
                                        let bytes = (LibrePro.max + 1).toByteArray()
                                        _ = writeDataToPeripheral(data: Data([0x02, 0x04, starts[1], starts[0], bytes[1], bytes[0]]), type: .withoutResponse)
                                        return
                                    }
                                }
                                
                                // if firmware < 2.6, libre2 and libreUS will decrypt fram local
                                // after decryptFRAM, the libre2 and libreUS 344 will be libre1 344 data format
                                if libreSensorType == .libre2 || libreSensorType == .libreUS {
                                    if let firmware = firmware?.toDouble(), firmware < 2.6 {
                                        var libreData = rxBuffer.subdata(in: bubbleHeaderLength..<rxBuffer.count)
                                        let uid = rxBuffer[0..<bubbleHeaderLength].bytes
                                        if let info = patchInfo?.hexadecimal?.bytes {
                                            libreData = Data(PreLibre2.decryptFRAM(uid, info, libreData.bytes))
                                        }
                                    }
                                }
                            }
                            
                            handleDataPackages()
                            
                            //reset the buffer
                            resetRxBuffer()
                            
                        }
                        
                    case .noSensor:
                        cgmTransmitterDelegate?.sensorNotDetected()
                        
                    case .patchInfo:
                        if value.count >= 10 {
                            patchInfo = value.subdata(in: 5 ..< 11).hexEncodedString().uppercased()
                        }
                        
                        // send libreSensorType to delegate
                        if let libreSensorType = LibreSensorType.type(patchInfo: patchInfo) {
                            cGMBubbleTransmitterDelegate?.received(libreSensorType: libreSensorType, from: self)
                        }
                        
                    }
                }
            }
        } else {
            trace("in peripheral didUpdateValueFor, value is nil, no further processing", log: log, category: ConstantsLog.categoryCGMBubble, type: .error)
        }
        
    }
    
    func handleDataPackages() {
        LibreDataParser.libreDataProcessor(libreSensorSerialNumber: libreSensorSerialNumber, patchInfo: patchInfo, webOOPEnabled: webOOPEnabled, oopWebSite: oopWebSite, oopWebToken: oopWebToken, libreData: (rxBuffer.subdata(in: bubbleHeaderLength..<rxBuffer.count)), cgmTransmitterDelegate: cgmTransmitterDelegate, timeStampLastBgReading: timeStampLastBgReading) { (timeStampLastBgReading: Date?, sensorState: LibreSensorState?, xDripError: XdripError?) in
            
            if let timeStampLastBgReading = timeStampLastBgReading {
                self.timeStampLastBgReading = timeStampLastBgReading
            }
            
            if let sensorState = sensorState {
                self.cGMBubbleTransmitterDelegate?.received(sensorStatus: sensorState, from: self)
            }
        }
    }
        
    // MARK: CGMTransmitter protocol functions
    
    func setNonFixedSlopeEnabled(enabled: Bool) {
        
        if nonFixedSlopeEnabled != enabled {
            
            nonFixedSlopeEnabled = enabled
            
            // nonFixed value changed, reset timeStampLastBgReading so that all glucose values will be sent to delegate. This is simply to ensure at least one reading will be sent to the delegate immediately.
            timeStampLastBgReading = Date(timeIntervalSince1970: 0)
          
        }
    }
    
    /// set webOOPEnabled value
    func setWebOOPEnabled(enabled: Bool) {
        
        if webOOPEnabled != enabled {
            
            webOOPEnabled = enabled
            
            // weboop value changed, reset timeStampLastBgReading so that all glucose values will be sent to delegate. This is simply to ensure at least one reading will be sent to the delegate immediately.
            timeStampLastBgReading = Date(timeIntervalSince1970: 0)
            
        }
        
    }
    
    func setWebOOPSite(oopWebSite: String) {
        self.oopWebSite = oopWebSite
    }
    
    func setWebOOPToken(oopWebToken: String) {
        self.oopWebToken = oopWebToken
    }
    
    func cgmTransmitterType() -> CGMTransmitterType {
        return .Bubble
    }

    func isNonFixedSlopeEnabled() -> Bool {
        return nonFixedSlopeEnabled
    }

    func isWebOOPEnabled() -> Bool {
        return webOOPEnabled
    }

    func requestNewReading() {
        
        _ = sendStartReadingCommmand()
        
    }

    // MARK: - helpers
    
    /// reset rxBuffer, reset startDate, stop packetRxMonitorTimer, set resendPacketCounter to 0
    private func resetRxBuffer() {
        rxBuffer = Data()
        startDate = Date()
    }
    
}

fileprivate enum BubbleResponseType: UInt8 {
    case dataPacket = 130 //0x82
    case dataInfo = 128 //0x80
    case noSensor = 191 //0xBF
    case serialNumber = 192 //0xC0
    case patchInfo = 193 //0xC1
    /// bubble firmware 2.6 support decrypt libre2 344 to libre1 344
    /// if firmware >= 2.6, write [0x08, 0x01, 0x00, 0x00, 0x00, 0x2B]
    /// bubble will decrypt the libre2 data and return it
    case decryptedDataPacket = 136 // 0x88
}

fileprivate func crcIsOk(rxBuffer:inout Data, patchInfo: String?, bubbleHeaderLength: Int, log: OSLog) -> Bool {
    
    // get sensortype, and dependent on sensortype get crc
    if let libreSensorType = LibreSensorType.type(patchInfo: patchInfo) {// should always return a value
        
        // crc check only for Libre 1 (is this the right thing to do ?)
        if libreSensorType == .libre1 {
            
            guard Crc.LibreCrc(data: &rxBuffer, headerOffset: bubbleHeaderLength) else {
                trace("    Libre 1 sensor, CRC check failed, no further processing", log: log, category: ConstantsLog.categoryCGMBubble, type: .info)
                return false
            }
            
        }
        
        // do this for tracing only, not processing will continue if crc check fails
        if libreSensorType == .libreProH {
            
            if !Crc.LibreCrc(data: &rxBuffer, headerOffset: bubbleHeaderLength) {
                trace("    libreProH sensor, CRC check failed - will continue processing anyway", log: log, category: ConstantsLog.categoryCGMBubble, type: .info)
            }
            
        }
        
    }

    return true

}

extension BubbleResponseType: CustomStringConvertible {
    public var description: String {
        switch self {
        case .dataPacket, .decryptedDataPacket:
            return "Data packet received"
        case .noSensor:
            return "No sensor detected"
        case .dataInfo:
            return "Data info received"
        case .serialNumber:
            return "Serial number received"
        case .patchInfo:
            return "Patch info received"
        }
    }
}
