import Foundation
import os
import CoreBluetooth

class WatlaaBluetoothTransmitterMaster: BluetoothTransmitter {
    
    // MARK: UUID's
    
    /// Glucose Data Service UUID
    let CBUUID_Data_Service = "00001010-1212-EFDE-0137-875F45AC0113"
    
    /// Battery Service UUID
    let CBUUID_Battery_Service = "0000180F-0000-1000-8000-00805F9B34FB"
    
    /// Current Time Service UUID
    let CBUUID_CurrentTime_Service = "00002A2B-0000-1000-8000-00805F9B34FB"
    
    /// characteristic uuids (created them in an enum as there's a lot of them, it's easy to switch through the list)
    private enum CBUUID_Characteristic_UUID:String, CustomStringConvertible {
        
        /// Raw data characteristic
        case CBUUID_RawData_Characteristic = "00001011-1212-EFDE-0137-875F45AC0113"
        
        /// Bridge connection status characteristic
        case CBUUID_BridgeConnectionStatus_Characteristic = "00001012-1212-EFDE-0137-875F45AC0113"
        
        /// Last BG raw value characteristic
        case CBUUID_LastBGRawValue_Characteristic = "00001013-1212-EFDE-0137-875F45AC0113"
        
        /// Calibration characteristic
        case CBUUID_Calibration_Characteristic = "00001014-1212-EFDE-0137-875F45AC0113"
        
        /// Glucose unit characteristic
        case CBUUID_GlucoseUnit_Characteristic = "00001015-1212-EFDE-0137-875F45AC0113"
        
        /// Alerts settings characteristic
        case CBUUID_AlertSettings_Characteristic = "00001016-1212-EFDE-0137-875F45AC0113"
        
        /// Battery level characteristic
        case CBUUID_BatteryLevel_Characteristic = "00002A19-0000-1000-8000-00805F9B34FB"
        
        /// Current time characteristic
        case CBUUID_CurrentTime_Characteristic = "00002A2B-0000-1000-8000-00805F9B34FB"
        
        /// for logging, returns a readable name for the characteristic
        var description: String {
            switch self {
                
            case .CBUUID_RawData_Characteristic:
                return "RawData"
            case .CBUUID_BridgeConnectionStatus_Characteristic:
                return "BridgeConnectionStatus"
            case .CBUUID_LastBGRawValue_Characteristic:
                return "LastBGRawValue"
            case .CBUUID_Calibration_Characteristic:
                return "Calibration"
            case .CBUUID_GlucoseUnit_Characteristic:
                return "GlucoseUnit"
            case .CBUUID_AlertSettings_Characteristic:
                return "AlertSettings"
            case .CBUUID_BatteryLevel_Characteristic:
                return "BatteryLevel"
            case .CBUUID_CurrentTime_Characteristic:
                return "CurrentTime"

            }
        }

    }
    
    // MARK: Other private properties
    
    /// for trace
    private let log = OSLog(subsystem: ConstantsLog.subSystem, category: ConstantsLog.categoryWatlaa)
    
    /// will be used to pass back bluetooth and cgm related events
    private weak var cgmTransmitterDelegate:CGMTransmitterDelegate?
    
    // MARK: - public functions
    
    /// - parameters:
    ///     - address: if already connected before, then give here the address that was received during previous connect, if not give nil
    ///     - name : if already connected before, then give here the name that was received during previous connect, if not give nil
    init(address:String?, name: String?, cgmTransmitterDelegate:CGMTransmitterDelegate?, bluetoothTransmitterDelegate: M5StackBluetoothTransmitterDelegate, bluetoothPeripheralType: BluetoothPeripheralType) {
        
        // assign addressname and name or expected devicename
        var newAddressAndName:BluetoothTransmitter.DeviceAddressAndName = BluetoothTransmitter.DeviceAddressAndName.notYetConnected(expectedName: "watlaa")
        if let address = address {
            newAddressAndName = BluetoothTransmitter.DeviceAddressAndName.alreadyConnectedBefore(address: address, name: name)
        }
        
        // initialize - CBUUID_Receive_Authentication.rawValue and CBUUID_Write_Control.rawValue will not be used in the superclass
        super.init(addressAndName: newAddressAndName, CBUUID_Advertisement: nil, servicesCBUUIDs: [CBUUID(string: CBUUID_Data_Service), CBUUID(string: CBUUID_Battery_Service), CBUUID(string: CBUUID_CurrentTime_Service)], CBUUID_ReceiveCharacteristic: CBUUID_Characteristic_UUID.CBUUID_RawData_Characteristic.rawValue, CBUUID_WriteCharacteristic: CBUUID_Characteristic_UUID.CBUUID_Calibration_Characteristic.rawValue, startScanningAfterInit: false, bluetoothTransmitterDelegate: bluetoothTransmitterDelegate)
        
        //assign CGMTransmitterDelegate
        self.cgmTransmitterDelegate = cgmTransmitterDelegate
        
    }
    
    // MARK: - private functions

    private func handleUpdateValueFor_RawData_Characteristic(value: Data) {
        
        
        
    }
    
    private func handleUpdateValueFor_BridgeConnectionStatus_Characteristic(value: Data) {
        
    }
    
    private func handleUpdateValueFor_LastBGRawValue_Characteristic(value: Data) {
        
    }
    
    private func handleUpdateValueFor_Calibration_Characteristic(value: Data) {
        
    }
    
    private func handleUpdateValueFor_GlucoseUnit_Characteristic(value: Data) {
        
    }
    
    private func handleUpdateValueFor_AlertSettings_Characteristic(value: Data) {
        
    }
    
    private func handleUpdateValueFor_BatteryLevel_Characteristic(value: Data) {
        
    }
    
    private func handleUpdateValueFor_CurrentTime_Characteristic(value: Data) {
        
    }
    
    // MARK: - BluetoothTransmitter overriden functions
    
    override func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
    
        super.peripheral(peripheral, didUpdateValueFor: characteristic, error: error)
        
        // find the CBUUID_Characteristic_UUID
        guard let characteristic_UUID = CBUUID_Characteristic_UUID(rawValue: characteristic.uuid.uuidString) else {
            trace("in peripheralDidUpdateValueFor, unknown characteristic received with uuid = %{public}@", log: log, type: .error, characteristic.uuid.uuidString)
            return
        }
        
        trace("in peripheralDidUpdateValueFor, characteristic uuid = %{public}@", log: log, type: .info, characteristic_UUID.description)
        
        guard let value = characteristic.value else {return}
        
        debuglogging("Received value from Watlaa : " + value.hexEncodedString())
        
        switch characteristic_UUID {
            
        case .CBUUID_RawData_Characteristic:
            handleUpdateValueFor_RawData_Characteristic(value: value)
            
        case .CBUUID_BridgeConnectionStatus_Characteristic:
            handleUpdateValueFor_BridgeConnectionStatus_Characteristic(value: value)
            
        case .CBUUID_LastBGRawValue_Characteristic:
            handleUpdateValueFor_LastBGRawValue_Characteristic(value: value)
            
        case .CBUUID_Calibration_Characteristic:
            handleUpdateValueFor_Calibration_Characteristic(value: value)
            
        case .CBUUID_GlucoseUnit_Characteristic:
            handleUpdateValueFor_GlucoseUnit_Characteristic(value: value)
            
        case .CBUUID_AlertSettings_Characteristic:
            handleUpdateValueFor_AlertSettings_Characteristic(value: value)
            
        case .CBUUID_BatteryLevel_Characteristic:
            handleUpdateValueFor_BatteryLevel_Characteristic(value: value)
            
        case .CBUUID_CurrentTime_Characteristic:
            handleUpdateValueFor_CurrentTime_Characteristic(value: value)

        }
        
    }
    
}
