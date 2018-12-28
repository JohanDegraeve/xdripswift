import Foundation
import CoreBluetooth

/// protocol for bluetooth transmitter.
/// For new transmitters, extend BluetoothTransmitter and implement the protocol BluetoothTransmitterDelegate
///
/// the protocol BluetoothTransmitterDelegate handles events that need to be treated differently dependent on device type, eg data that is received from the transmitter
///
/// class BluetoothTransmitter implements the protocols CBCentralManagerDelegate, CBPeripheralDelegate
///
/// some of those functions might still need override/re-implementation in the deriving specific class
///
protocol BluetoothTransmitterDelegate {
    
    /// it's the same function as defined in CBPeripheralDelegate. It's defined in this protocol to make sure the deriving class implements it because for some of the devices it needs specific coding. Check the objective-c code and actionscript code in Spike : G5BleManager.m, FQBleManager.m, BluetoothService.peripheral_characteristic_subscribeHandler
    func peripheralD(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?)
    
    /// it's the same function as defined in CBPeripheralDelegate. It's defined in this protocol to make sure the deriving class implements it because for some of the devices it needs specific coding. Check the objective-c code and actionscript code in Spike : G5BleManager.m, FQBleManager.m, BluetoothService.peripheral_characteristic_updatedHandler
    func peripheralD(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?)
    
    /// it's the same function as defined in CBPeripheralDelegate. It's defined in this protocol to make sure the deriving class implements it because for some of the devices it needs specific coding. 
    func centralManagerDidUpdateStateD(_ central: CBCentralManager)
    
    /// it's the same function as defined in CBPeripheralDelegate. It's defined in this protocol to make sure the deriving class implements it because for some of the devices it needs specific coding.
    func centralManagerD(_ central: CBCentralManager, didConnect peripheral: CBPeripheral)

    /// it's the same function as defined in CBPeripheralDelegate. It's defined in this protocol to make sure the deriving class implements it because for some of the devices it needs specific coding.
    func peripheralD(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?)
    
}

