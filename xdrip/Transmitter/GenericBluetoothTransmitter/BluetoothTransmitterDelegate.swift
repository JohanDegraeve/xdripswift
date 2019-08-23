import Foundation
import CoreBluetooth

/// Defines functions similar as CBCentralManagerDelegate, CBPeripheralDelegate, with a different name and signature
///
/// Goal is that delegates that conform to this protocol have a way to receive information about bluetooth activities. Example centralManager didDisconnectPeripheral is handled in class BluetoothTransmitter, however a delegate may be interested that a disconnect occurred for showing info to the user. The implementation of centralManager didDisconnectPeripheral in BluetoothTransmitter class would first do own stuff (eg try to reconnect) and at the end call the corresponding delegate function. For some methods, the implementation in the class BluetoothTransmitter will do nothing but calling the corresponding method in the protocol BluetoothTransmitterDelegate, example centralManager didUpdateValueFor characteristic.
///
/// If a Delegate is not interested in information, then it just needs to implement an empty closure
///
/// Most delegates will only implement just a very fiew of the methods
protocol BluetoothTransmitterDelegate:AnyObject {
    /// didDiscover peripheral
    func centralManagerDidDiscover(peripheral: BluetoothPeripheral)
    
    /// called when centralManager didConnect was called in BlueToothTransmitter class
    /// the BlueToothTransmitter class handles the reconnect but the delegate class can for instance show the connection status to the user
    /// - parameters:
    ///     - address: the address that was received from the transmitter during connection phase
    ///     - name: the name that was received from the transmitter during connection phase
    func centralManagerDidConnect(address:String?, name:String?)
    
    /// called when centralManager didFailToConnect was called in BlueToothTransmitter class
    /// the BlueToothTransmitter class handles will try to reconnect but the delegate class can for instance show the connection status to the user
    func centralManagerDidFailToConnect(error: Error?)
    
    /// called when centralManagerDidUpdateState was called in BlueToothTransmitter class
    /// if an address is already stored (ie device already connected before) then the BlueToothTransmitter class will try to reconnect and/or scan
    func centralManagerDidUpdateState(state: CBManagerState)
    
    /// if an address is already stored (ie device already connected before) then the BlueToothTransmitter class will try to reconnect and/or scan
    ///
    /// the BlueToothTransmitter will also log the error if there is one
    func centralManagerDidDisconnectPeripheral(error: Error?)
    
    /// called when peripheral didUpdateNotificationStateFor was called in BlueToothTransmitter class
    ///
    /// the BlueToothTransmitter class will log the error if any and call the delegate function
    func peripheralDidUpdateNotificationStateFor(characteristic: CBCharacteristic, error: Error?)
    
    /// called when peripheral didUpdateValueFor was called in BlueToothTransmitter class
    /// the BlueToothTransmitter class will not do anything just call the delegate function
    func peripheralDidUpdateValueFor(characteristic: CBCharacteristic, error: Error?)
}

extension BluetoothTransmitterDelegate {
    func centralManagerDidDiscover(peripheral: BluetoothPeripheral) {
        
    }
}
