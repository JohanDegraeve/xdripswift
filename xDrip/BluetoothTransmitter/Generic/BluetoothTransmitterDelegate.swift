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
    
    /// transmitter needs bluetooth pairing, this to allow to notify the user about the fact that pairing is needed
    func transmitterNeedsPairing(bluetoothTransmitter: BluetoothTransmitter)
    
    /// transmitter successfully paired
    func successfullyPaired()
    
    /// transmitter pairing failed
    func pairingFailed()
    
    /// to pass some text error message, delegate can decide to show to user, log, ...
    func error(message: String)

    /// peripheral used as heartbeat, this is the heartbeat
    func heartBeat()

    /// A Bluetooth transmitter received a valid battery percentage that can be presented by the UI.
    ///
    /// This is primarily used by generic heartbeat hardware such as EmaLink and OrangeLink. Those
    /// devices may expose the standard BLE Battery Service, but battery reporting must remain
    /// optional because most heartbeat devices do not provide it.
    func didUpdateBatteryLevel(_ batteryLevel: Int, bluetoothTransmitter: BluetoothTransmitter)
    
}

extension BluetoothTransmitterDelegate {
    /// Keep battery reporting optional so transmitters without EmaLink/OrangeLink-style battery
    /// support do not need special handling and retain their existing behaviour.
    func didUpdateBatteryLevel(_: Int, bluetoothTransmitter _: BluetoothTransmitter) {}
}
