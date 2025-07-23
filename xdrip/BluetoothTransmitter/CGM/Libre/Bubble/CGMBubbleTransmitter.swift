import Foundation
import CoreBluetooth
import os

class CGMBubbleTransmitter:BluetoothTransmitter, CGMTransmitter {
    let appId:UInt8=0xA0;
    var lastDataTime:Double=0;
    // MARK: - properties
    
    private var lastGlucoseDate: Date? {
        get {
            UserDefaults.standard.object(forKey: "CGMBubbleTransmitterLastGlucoseDate") as? Date
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "CGMBubbleTransmitterLastGlucoseDate")
        }
    }

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
    
    /// bubble firmware version
    private var firmware: String?
    
    /// instance of libreDataParser
    private let libreDataParser: LibreDataParser
    
    /// sensor type
    private var libreSensorType: LibreSensorType?

    // MARK: - Initialization
    
    /// - parameters:
    ///     - address: if already connected before, then give here the address that was received during previous connect, if not give nil
    ///     - name : if already connected before, then give here the name that was received during previous connect, if not give nil
    ///     - delegate : CGMTransmitterDelegate intance
    ///     - webOOPEnabled : enabled or not, if nil then default false
    ///     - bluetoothTransmitterDelegate : a BluetoothTransmitterDelegate
    ///     - cGMTransmitterDelegate : a CGMTransmitterDelegate
    ///     - cGMBubbleTransmitterDelegate : a CGMBubbleTransmitterDelegate
    init(address:String?, name: String?, bluetoothTransmitterDelegate: BluetoothTransmitterDelegate, cGMBubbleTransmitterDelegate: CGMBubbleTransmitterDelegate, cGMTransmitterDelegate:CGMTransmitterDelegate, sensorSerialNumber:String?, webOOPEnabled: Bool?, nonFixedSlopeEnabled: Bool?) {
        
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
        
        // initialize nonFixedSlopeEnabled
        self.nonFixedSlopeEnabled = nonFixedSlopeEnabled ?? false
        
        // initialize webOOPEnabled
        self.webOOPEnabled = webOOPEnabled ?? false
        
        // initiliaze LibreDataParser
        self.libreDataParser = LibreDataParser()

        super.init(addressAndName: newAddressAndName, CBUUID_Advertisement: nil, servicesCBUUIDs: [CBUUID(string: CBUUID_Service_Bubble)], CBUUID_ReceiveCharacteristic: CBUUID_ReceiveCharacteristic_Bubble, CBUUID_WriteCharacteristic: CBUUID_WriteCharacteristic_Bubble, bluetoothTransmitterDelegate: bluetoothTransmitterDelegate)
        
    }
    
    func nextReadTimeinterval() -> UInt8 {
        
        guard let last = lastGlucoseDate else {
            return 0x05
        }
        
        let interval = Date().timeIntervalSince(last) / 60.0
        
        if interval > 5.0 || interval < 1.0 {
            return 0x05
        }

        return UInt8(interval)
    }

    // MARK: - public functions
    private var readTimeInterval: UInt8 = 0x05
    func sendStartReadingCommmand() -> Bool {
        readTimeInterval = nextReadTimeinterval()
        if writeDataToPeripheral(data: Data([0x00, appId, readTimeInterval]), type: .withoutResponse) {
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
                        cgmTransmitterDelegate?.cgmTransmitterInfoReceived(glucoseData: &emptyArray, transmitterBatteryInfo: TransmitterBatteryInfo.percentage(percentage: batteryPercentage), sensorAge: nil)
                        
                        // store received firmware local
                        self.firmware = firmware
                        lastDataTime=0
                        
                        if let last = lastGlucoseDate {
                            if Date().timeIntervalSince(last) < 4 * 60 {
                                return
                            }
                        }

                        //deviceName
                        if(deviceName!=="Bubble Nano"){
                            _ = writeDataToPeripheral(data: Data([0x08, appId, 0x00, 0x00, 0x00, 0x2B]), type: .withoutResponse)
                        } else {
                            if firmware.toDouble() ?? 0 >= 8.1 && libreSensorType == .libre1 {
                                _ = writeDataToPeripheral(data: Data([0x0C, appId, 0x00, 0x00, 0x00, 0x2B]), type: .withoutResponse)
                            } else if firmware.toDouble() ?? 0 >= 2.6 {
                                _ = writeDataToPeripheral(data: Data([0x08, appId, 0x00, 0x00, 0x00, 0x2B]), type: .withoutResponse)
                            } else {
                                _ = writeDataToPeripheral(data: Data([0x02, appId, 0x00, 0x00, 0x00, 0x2B]), type: .withoutResponse)
                            }
                        }
                        // confirm receipt
                        // if firmware >= 2.6, write [0x08, 0x01, 0x00, 0x00, 0x00, 0x2B]
                        // bubble will decrypt the libre2 data and return it
                  
                        
                    case .serialNumber:
                        
                        guard value.count >= 10 else { return }
                        
                        // as serialNumber is always the first packet being sent, resetRxBuffer (just in case it wasn't done yet
                        resetRxBuffer()
                        
                        // this is actually the sensor serial number, adding it to rxBuffer (we could also not add it and set bubbleHeaderLength to 0 - this is historic
                        rxBuffer.append(value.subdata(in: 2..<10))
                        
                        // get libreSensorSerialNumber, if this fails, then self.libreSensorSerialNumber will keep it's current value
                        // Bubble sends the patchInfo only in a second step, which means patchInfo is nil here, as a result, the sensorSerialNumber will maybe not be correct (eg for Libre 2), because the function LibreSensorType.type uses the patchInfo
                        // libreSensorSerialNumber will be recalculated when receiving the patchInfo
                        guard let libreSensorSerialNumber = LibreSensorSerialNumber(withUID: Data(rxBuffer.subdata(in: 0..<8)), with: LibreSensorType.type(patchInfo: patchInfo)) else {
                            trace("    could not create libreSensorSerialNumber", log: self.log, category: ConstantsLog.categoryCGMBubble, type: .info)
                            return
                        }
                        
                        // assign self.libreSensorSerialNumber to received libreSensorSerialNumber
                        self.libreSensorSerialNumber = libreSensorSerialNumber

                        
                    case .dataPacket, .dataPacket2, .decryptedDataPacket:

                        //no different processing for decryptedDataPacket, we look at the firmware version of the bubble and sensortype to determine if data is decrypted or not
                        
                        rxBuffer.append(value.suffix(from: 4))
                        
                        if rxBuffer.count >= 352 {
                            
                            var dataIsDecryptedToLibre1Format = false
                            
                            // for libre2 and libreUS we will do decryption
                            if let libreSensorType = LibreSensorType.type(patchInfo: patchInfo) {

                                self.libreSensorType = libreSensorType
                                
                                // if firmware < 2.6, libre2 and libreUS will decrypt fram local
                                // after decryptFRAM, the libre2 and libreUS 344 will be libre1 344 data format
                                // firmware >= 2.6, then bubble already decrypted the data, no need for decryption we already have the 344 bytes
                                if libreSensorType == .libre2 || libreSensorType == .libre2C5 || libreSensorType == .libre2C6 || libreSensorType == .libre27F || libreSensorType == .libreUS || libreSensorType == .libreUSE6 {
                                    
                                    if let firmware = firmware?.toDouble(), firmware < 2.6 {
                                        
                                        dataIsDecryptedToLibre1Format = libreSensorType.decryptIfPossibleAndNeeded(rxBuffer: &rxBuffer, headerLength: bubbleHeaderLength, log: log, patchInfo: patchInfo, uid: Array(rxBuffer[0..<bubbleHeaderLength]))
                                        
                                    } else {
                                        
                                        trace("    firmware version >= 2.6, libre data should be decrypted already", log: log, category: ConstantsLog.categoryCGMBubble, type: .info)

                                    }
                                    
                                    dataIsDecryptedToLibre1Format = true
                                    
                                }
                                
                                // now except libreProH, all libres' 344 data is libre1 format
                                // should crc check
                                guard libreSensorType.crcIsOk(rxBuffer: &self.rxBuffer, headerLength: bubbleHeaderLength, log: log) else {
                                    return
                                }

                            }
                            
                            // did we receive a serialNumber ?
                            if let libreSensorSerialNumber = libreSensorSerialNumber {

                                // verify serial number and if changed inform delegate
                                if libreSensorSerialNumber.serialNumber != sensorSerialNumber {

                                    // store self.sensorSerialNumber
                                    sensorSerialNumber = libreSensorSerialNumber.serialNumber
                                    
                                    trace("    new sensor detected :  %{public}@", log: log, category: ConstantsLog.categoryCGMBubble, type: .info, libreSensorSerialNumber.serialNumber)
                                    
                                    // inform cgmTransmitterDelegate about new sensor detected
                                    // assign sensorStartDate, for this type of transmitter the sensorAge is passed in another call to cgmTransmitterDelegate
                                    cgmTransmitterDelegate?.newSensorDetected(sensorStartDate: nil)

                                    // inform cGMBubbleTransmitterDelegate about new sensor detected
                                    cGMBubbleTransmitterDelegate?.received(serialNumber: libreSensorSerialNumber.serialNumber, from: self)
                                    
                                }

                            }

                            libreDataParser.libreDataProcessor(libreSensorSerialNumber: libreSensorSerialNumber?.serialNumber, patchInfo: patchInfo, webOOPEnabled: webOOPEnabled, libreData:  (rxBuffer.subdata(in: bubbleHeaderLength..<(344 + bubbleHeaderLength))), cgmTransmitterDelegate: cgmTransmitterDelegate, dataIsDecryptedToLibre1Format: dataIsDecryptedToLibre1Format, testTimeStamp: nil) { (sensorState: LibreSensorState?, xDripError: XdripError?) in
                                
                                self.lastGlucoseDate = Date()

                                if let sensorState = sensorState {
                                    self.cGMBubbleTransmitterDelegate?.received(sensorStatus: sensorState, from: self)
                                }
                            }
                            lastDataTime=Date().timeIntervalSince1970
                            //reset the buffer
                            resetRxBuffer()
                            
                        }
                        
                    case .noSensor:
                        if(Date().timeIntervalSince1970-lastDataTime>10000){
                            cgmTransmitterDelegate?.sensorNotDetected()
                        }
                      
                        
                    case .patchInfo:
                        if value.count >= 10 {
                            
                            patchInfo = value.subdata(in: 5 ..< 11).hexEncodedString().uppercased()

                            if let patchInfo = patchInfo {
                                trace("    received patchInfo %{public}@ ", log: log, category: ConstantsLog.categoryCGMBubble, type: .info, patchInfo)
                            }

                            // send libreSensorType to delegate
                            if let libreSensorType = LibreSensorType.type(patchInfo: patchInfo) {
                                cGMBubbleTransmitterDelegate?.received(libreSensorType: libreSensorType, from: self)
                            }
                            
                            // we have the patchInfo now, so recalculate the sensorSerialNumber
                            guard let libreSensorSerialNumber = LibreSensorSerialNumber(withUID: Data(rxBuffer.subdata(in: 0..<8)), with: LibreSensorType.type(patchInfo: patchInfo)) else {
                                trace("    could not create libreSensorSerialNumber", log: self.log, category: ConstantsLog.categoryCGMBubble, type: .info)
                                return
                            }
                            
                            // assign self.libreSensorSerialNumber to received libreSensorSerialNumber
                            self.libreSensorSerialNumber = libreSensorSerialNumber

                        }
                        
                    }
                }
            }
        } else {
            trace("in peripheral didUpdateValueFor, value is nil, no further processing", log: log, category: ConstantsLog.categoryCGMBubble, type: .error)
        }
        
    }
    
    // MARK: CGMTransmitter protocol functions
    
    func setNonFixedSlopeEnabled(enabled: Bool) {
        
        if nonFixedSlopeEnabled != enabled {
            
            nonFixedSlopeEnabled = enabled
            
        }
    }
    
    /// set webOOPEnabled value
    func setWebOOPEnabled(enabled: Bool) {
        
        if webOOPEnabled != enabled {
            
            webOOPEnabled = enabled
            
        }
        
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
    
    func maxSensorAgeInDays() -> Double? {
        
        return libreSensorType?.maxSensorAgeInDays()
        
    }

    func getCBUUID_Service() -> String {
        return CBUUID_Service_Bubble
    }
    
    func getCBUUID_Receive() -> String {
        return CBUUID_ReceiveCharacteristic_Bubble
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
    case dataPacket2 = 0x8C
    case dataInfo = 128 //0x80
    case noSensor = 191 //0xBF
    case serialNumber = 192 //0xC0
    case patchInfo = 193 //0xC1
    /// bubble firmware 2.6 support decrypt libre2 344 to libre1 344
    /// if firmware >= 2.6, write [0x08, 0x01, 0x00, 0x00, 0x00, 0x2B]
    /// bubble will decrypt the libre2 data and return it
    case decryptedDataPacket = 136 // 0x88
}

extension BubbleResponseType: CustomStringConvertible {
    public var description: String {
        switch self {
        case .dataPacket, .dataPacket2, .decryptedDataPacket:
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
