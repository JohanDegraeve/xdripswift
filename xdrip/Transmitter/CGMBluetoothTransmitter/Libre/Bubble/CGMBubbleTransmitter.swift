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
    
    /// for OS_log
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
    private let BubbleHeaderLength = 8
    
    /// used as parameter in call to cgmTransmitterDelegate.cgmTransmitterInfoReceived, when there's no glucosedata to send
    var emptyArray: [RawGlucoseData] = []
    
    // MARK: - Initialization
    /// - parameters:
    ///     - address: if already connected before, then give here the address that was received during previous connect, if not give nil
    init(address:String?, delegate:CGMTransmitterDelegate, timeStampLastBgReading:Date) {
        
        // assign addressname and name or expected devicename
        var newAddressAndName:BluetoothTransmitter.DeviceAddressAndName = BluetoothTransmitter.DeviceAddressAndName.notYetConnected(expectedName: expectedDeviceNameBubble)
        if let address = address {
            newAddressAndName = BluetoothTransmitter.DeviceAddressAndName.alreadyConnectedBefore(address: address)
        }
        
        // assign CGMTransmitterDelegate
        cgmTransmitterDelegate = delegate
        
        // initialize rxbuffer
        rxBuffer = Data()
        startDate = Date()
        
        //initialize timeStampLastBgReading
        self.timeStampLastBgReading = timeStampLastBgReading
        
        super.init(addressAndName: newAddressAndName, CBUUID_Advertisement: nil, servicesCBUUIDs: [CBUUID(string: CBUUID_Service_Bubble)], CBUUID_ReceiveCharacteristic: CBUUID_ReceiveCharacteristic_Bubble, CBUUID_WriteCharacteristic: CBUUID_WriteCharacteristic_Bubble, startScanningAfterInit: CGMTransmitterType.Bubble.startScanningAfterInit())
        
        // set self as delegate for BluetoothTransmitterDelegate - this parameter is defined in the parent class BluetoothTransmitter
        bluetoothTransmitterDelegate = self
    }
    
    // MARK: - public functions
    
    func sendStartReadingCommmand() -> Bool {
        if writeDataToPeripheral(data: Data([0x00, 0x00, 0x5]), type: .withoutResponse) {
            return true
        } else {
            os_log("in sendStartReadingCommmand, write failed", log: log, type: .error)
            return false
        }
    }
    
    // MARK: - BluetoothTransmitterDelegate functions
    
    func centralManagerDidConnect(address:String?, name:String?) {
        cgmTransmitterDelegate?.cgmTransmitterDidConnect(address: address, name: name)
    }
    
    func centralManagerDidFailToConnect(error: Error?) {
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
                os_log("in peripheral didUpdateValueFor, more than %{public}d seconds since last update - or first update since app launch, resetting buffer", log: log, type: .info, CGMBubbleTransmitter.maxWaitForpacketInSeconds)
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
                        
                    case .dataPacket:
                        rxBuffer.append(value.suffix(from: 4))
                        if rxBuffer.count >= 352 {
                            if (Crc.LibreCrc(data: &rxBuffer, headerOffset: BubbleHeaderLength)) {
                                //get readings from buffer and send to delegate
                                var result = parseLibreData(data: &rxBuffer, timeStampLastBgReadingStoredInDatabase: timeStampLastBgReading, headerOffset: BubbleHeaderLength)
                                //TODO: sort glucosedata before calling newReadingsReceived
                                cgmTransmitterDelegate?.cgmTransmitterInfoReceived(glucoseData: &result.glucoseData, transmitterBatteryInfo: nil, sensorState: result.sensorState, sensorTimeInMinutes: result.sensorTimeInMinutes, firmware: nil, hardware: nil, hardwareSerialNumber: nil, bootloader: nil, sensorSerialNumber: nil)
                                
                                //set timeStampLastBgReading to timestamp of latest reading in the response so that next time we parse only the more recent readings
                                if result.glucoseData.count > 0 {
                                    timeStampLastBgReading = result.glucoseData[0].timeStamp
                                }
                                
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
            os_log("in peripheral didUpdateValueFor, value is nil, no further processing", log: log, type: .error)
        }
    }
    
    // MARK: CGMTransmitter protocol functions
    
    /// to ask pairing - empty function because G4 doesn't need pairing
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
}

fileprivate enum BubbleResponseType: UInt8 {
    case dataPacket = 130
    case dataInfo = 128
    case noSensor = 191
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
        }
    }
}
