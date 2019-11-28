import Foundation
import CoreBluetooth

/// delegate used for any type of BluetoothTransmitter
protocol BluetoothTransmitterDelegate: AnyObject {
 
    // MARK: - Generic functions that can be used for any type of BluetoothTransmitter
    
    /// did connect to
    /// - parameters:
    ///     - bluetoothTransmitter : the bluetoothTransmitter to which the connection is made
    func didConnectTo(bluetoothTransmitter: BluetoothTransmitter)
    
    /// did disconnect from bluetoothTransmitter
    func didDisconnectFrom(bluetoothTransmitter: BluetoothTransmitter)
    
    /// the ios device did change bluetooth status
    func deviceDidUpdateBluetoothState(state: CBManagerState, bluetoothTransmitter: BluetoothTransmitter)
    
}
