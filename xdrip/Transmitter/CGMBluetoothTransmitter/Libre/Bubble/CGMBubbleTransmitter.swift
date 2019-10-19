import Foundation
import CoreBluetooth
import os

class CGMBubbleTransmitter:BluetoothTransmitter, BluetoothTransmitterDelegate, CGMTransmitter {
    
    // MARK: - properties
    
    /// service to be discovered
    let CBUUID_Service_Bubble: String = "6E400001-B5A3-F393-E0A9-E50E24DCCA9E"
    /// receive characteristic
    let CBUUID_ReceiveCharacteristic_Bubble: String = "6E400003-B5A3-F393-E0A9-E50E24DCCA9E"
    /// write characteristic
    let CBUUID_WriteCharacteristic_Bubble: String = "6E400002-B5A3-F393-E0A9-E50E24DCCA9E"
    
    /// expected device name
    let expectedDeviceNameBubble:String = "Bubble"
    
    /// will be used to pass back bluetooth and cgm related events
    private(set) weak var cgmTransmitterDelegate: CGMTransmitterDelegate?
    
    /// for trace
    private let log = OSLog(subsystem: ConstantsLog.subSystem, category: ConstantsLog.categoryCGMBubble)
    
    // used in parsing packet
    private var timeStampLastBgReading:Date
    
    // counts number of times resend was requested due to crc error
    private var resendPacketCounter:Int = 0
    
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
    
    /// used as parameter in call to cgmTransmitterDelegate.cgmTransmitterInfoReceived, when there's no glucosedata to send
    var emptyArray: [GlucoseData] = []
    
    // current sensor serial number, if nil then it's not known yet
    private var sensorSerialNumber:String?
    
    /// oop website url to use in case oop web would be enabled
    private var oopWebSite: String
    
    /// oop token to use in case oop web would be enabled
    private var oopWebToken: String
    
    // MARK: - Initialization
    
    /// - parameters:
    ///     - address: if already connected before, then give here the address that was received during previous connect, if not give nil
    ///     - name : if already connected before, then give here the name that was received during previous connect, if not give nil
    ///     - delegate : CGMTransmitterDelegate intance
    ///     - timeStampLastBgReading : timestamp of last bgReading
    ///     - webOOPEnabled : enabled or not
    ///     - oopWebSite : oop web site url to use, only used in case webOOPEnabled = true
    ///     - oopWebToken : oop web token to use, only used in case webOOPEnabled = true
    init(address:String?, name: String?, delegate:CGMTransmitterDelegate, timeStampLastBgReading:Date, sensorSerialNumber:String?, webOOPEnabled: Bool, oopWebSite: String, oopWebToken: String) {
        
        // assign addressname and name or expected devicename
        var newAddressAndName:BluetoothTransmitter.DeviceAddressAndName = BluetoothTransmitter.DeviceAddressAndName.notYetConnected(expectedName: expectedDeviceNameBubble)
        if let address = address {
            newAddressAndName = BluetoothTransmitter.DeviceAddressAndName.alreadyConnectedBefore(address: address, name: name)
        }
        
        // initialize sensorSerialNumber
        self.sensorSerialNumber = sensorSerialNumber

        // assign CGMTransmitterDelegate
        cgmTransmitterDelegate = delegate
        
        // initialize rxbuffer
        rxBuffer = Data()
        startDate = Date()
        
        //initialize timeStampLastBgReading
        self.timeStampLastBgReading = timeStampLastBgReading
        
        // initialize webOOPEnabled
        self.webOOPEnabled = webOOPEnabled
        
        // initialize oopWebToken and oopWebSite
        self.oopWebToken = oopWebToken
        self.oopWebSite = oopWebSite
        
        super.init(addressAndName: newAddressAndName, CBUUID_Advertisement: nil, servicesCBUUIDs: [CBUUID(string: CBUUID_Service_Bubble)], CBUUID_ReceiveCharacteristic: CBUUID_ReceiveCharacteristic_Bubble, CBUUID_WriteCharacteristic: CBUUID_WriteCharacteristic_Bubble, startScanningAfterInit: CGMTransmitterType.Bubble.startScanningAfterInit())
        
        // set self as delegate for BluetoothTransmitterDelegate - this parameter is defined in the parent class BluetoothTransmitter
        bluetoothTransmitterDelegate = self
    }
    
    // MARK: - public functions
    
    func sendStartReadingCommmand() -> Bool {
        if writeDataToPeripheral(data: Data([0x00, 0x00, 0x05]), type: .withoutResponse) {
            return true
        } else {
            trace("in sendStartReadingCommmand, write failed", log: log, type: .error)
            return false
        }
    }
    
    // MARK: - BluetoothTransmitterDelegate functions
    
    func centralManagerDidConnect(address:String?, name:String?) {
        cgmTransmitterDelegate?.cgmTransmitterDidConnect(address: address, name: name)
    }
    
    func centralManagerDidFailToConnect(error: Error?) {
        trace("in centralManagerDidFailToConnect", log: log, type: .error)
    }
    
    func centralManagerDidUpdateState(state: CBManagerState) {
        cgmTransmitterDelegate?.deviceDidUpdateBluetoothState(state: state)
    }
    
    func centralManagerDidDisconnectPeripheral(error: Error?) {
        cgmTransmitterDelegate?.cgmTransmitterDidDisconnect()
    }
    
    func peripheralDidUpdateNotificationStateFor(characteristic: CBCharacteristic, error: Error?) {
        if error == nil && characteristic.isNotifying {
            _ = sendStartReadingCommmand()
        }
    }
    
    func peripheralDidUpdateValueFor(characteristic: CBCharacteristic, error: Error?) {
        
        if let value = characteristic.value {
            
            //check if buffer needs to be reset
            if (Date() > startDate.addingTimeInterval(CGMBubbleTransmitter.maxWaitForpacketInSeconds - 1)) {
                trace("in peripheral didUpdateValueFor, more than %{public}d seconds since last update - or first update since app launch, resetting buffer", log: log, type: .info, CGMBubbleTransmitter.maxWaitForpacketInSeconds)
                resetRxBuffer()
            }
            
            if let firstByte = value.first {
                if let bubbleResponseState = BubbleResponseType(rawValue: firstByte) {
                    switch bubbleResponseState {
                    case .dataInfo:
                        
                        // get hardware, firmware and batteryPercentage
                        let hardware = value[2].description + ".0"
                        let firmware = value[1].description + ".0"
                        let batteryPercentage = Int(value[4])

                        // send hardware, firmware and batteryPercentage to delegate
                        cgmTransmitterDelegate?.cgmTransmitterInfoReceived(glucoseData: &emptyArray, transmitterBatteryInfo: TransmitterBatteryInfo.percentage(percentage: batteryPercentage), sensorState: nil, sensorTimeInMinutes: nil, firmware: firmware, hardware: hardware, hardwareSerialNumber: nil, bootloader: nil, sensorSerialNumber: nil)

                        // confirm receipt
                        _ = writeDataToPeripheral(data: Data([0x02, 0x00, 0x00, 0x00, 0x00, 0x2B]), type: .withoutResponse)
                        
                    case .serialNumber:
                        
                        rxBuffer.append(value.subdata(in: 2..<10))
                        
                    case .dataPacket:
                        
                        rxBuffer.append(value.suffix(from: 4))
                        if rxBuffer.count >= 352 {
                            if (Crc.LibreCrc(data: &rxBuffer, headerOffset: bubbleHeaderLength)) {
                                
                                if let libreSensorSerialNumber = LibreSensorSerialNumber(withUID: Data(rxBuffer.subdata(in: 0..<8))) {

                                    
                                    // verify serial number and if changed inform delegate
                                    if libreSensorSerialNumber.serialNumber != sensorSerialNumber {
                                        
                                        sensorSerialNumber = libreSensorSerialNumber.serialNumber
                                        
                                        trace("    new sensor detected :  %{public}@", log: log, type: .info, libreSensorSerialNumber.serialNumber)
                                        
                                        // inform delegate about new sensor detected
                                        cgmTransmitterDelegate?.newSensorDetected()
                                        
                                        // also reset timestamp last reading, to be sure that if new sensor is started, we get historic data
                                        timeStampLastBgReading = Date(timeIntervalSince1970: 0)
                                        
                                        // inform delegate about new sensorSerialNumber
                                        cgmTransmitterDelegate?.cgmTransmitterInfoReceived(glucoseData: &emptyArray, transmitterBatteryInfo: nil, sensorState: nil, sensorTimeInMinutes: nil, firmware: nil, hardware: nil, hardwareSerialNumber: nil, bootloader: nil, sensorSerialNumber: sensorSerialNumber)

                                    }

                                }
                                
                                LibreDataParser.libreDataProcessor(sensorSerialNumber: sensorSerialNumber, webOOPEnabled: webOOPEnabled, oopWebSite: oopWebSite, oopWebToken: oopWebToken, libreData: (rxBuffer.subdata(in: bubbleHeaderLength..<(344 + bubbleHeaderLength))), cgmTransmitterDelegate: cgmTransmitterDelegate, transmitterBatteryInfo: nil, firmware: nil, hardware: nil, hardwareSerialNumber: nil, bootloader: nil, timeStampLastBgReading: timeStampLastBgReading, completionHandler: {(timeStampLastBgReading:Date) in
                                    self.timeStampLastBgReading = timeStampLastBgReading
                                    
                                })

                                //reset the buffer
                                resetRxBuffer()
                                
                            }
                        }
                    case .noSensor:
                        cgmTransmitterDelegate?.sensorNotDetected()
                    }
                }
            }
        } else {
            trace("in peripheral didUpdateValueFor, value is nil, no further processing", log: log, type: .error)
        }
    }
    
    // MARK: CGMTransmitter protocol functions
    
    /// to ask pairing - empty function because Bubble doesn't need pairing
    ///
    /// this function is not implemented in BluetoothTransmitter.swift, otherwise it might be forgotten to look at in future CGMTransmitter developments
    func initiatePairing() {}
    
    /// to ask transmitter reset - empty function because Bubble doesn't support reset
    ///
    /// this function is not implemented in BluetoothTransmitter.swift, otherwise it might be forgotten to look at in future CGMTransmitter developments
    func reset(requested:Bool) {}
    
    // MARK: - helpers
    
    /// reset rxBuffer, reset startDate, stop packetRxMonitorTimer, set resendPacketCounter to 0
    private func resetRxBuffer() {
        rxBuffer = Data()
        startDate = Date()
        resendPacketCounter = 0
    }
    
    /// this transmitter supports oopWeb
    func setWebOOPEnabled(enabled: Bool) {
        webOOPEnabled = enabled
    }
    

    func setWebOOPSiteAndToken(oopWebSite: String, oopWebToken: String) {
        self.oopWebToken = oopWebToken
        self.oopWebSite = oopWebSite
    }

}

fileprivate enum BubbleResponseType: UInt8 {
    case dataPacket = 130
    case dataInfo = 128
    case noSensor = 191
    case serialNumber = 192
}

extension BubbleResponseType: CustomStringConvertible {
    public var description: String {
        switch self {
        case .dataPacket:
            return "Data packet received"
        case .noSensor:
            return "No sensor detected"
        case .dataInfo:
            return "Data info received"
        case .serialNumber:
            return "serial number received"
        }
    }
}
