import Foundation

/// used by BluetoothPeripheral UI view controllers - it's the glue between BluetoothPeripheralManager and UIViewControllers - defines functions to scan for devices, connect/disconnect, delete a BluetoothPeripheral, change the username, etc.
protocol BluetoothPeripheralManaging: AnyObject {
    
    /// to scan for a new BluetoothPeripheral - callback will be called when a new BluetoothPeripheral is found and connected
    func startScanningForNewDevice(callback: @escaping (BluetoothPeripheral) -> Void, type: BluetoothPeripheralType)
    
    /// will stop scanning, this is again for the case where scanning for a new BluetoothPeripheral has started
    func stopScanningForNewDevice()
    
    /// try to connect to the BluetoothPeripheral
    func connect(to bluetoothPeripheral: BluetoothPeripheral)
    
    /// returns the BluetoothTransmitter for the specified bluetoothPeripheral
    /// - parameters:
    ///     - for : the bluetoothPeripheral, for which bluetoothTransmitter should be returned
    ///     - createANewOneIfNecesssary : if there's no instance yet,  then should one be created ?
    func getBluetoothTransmitter(for bluetoothPeripheral: BluetoothPeripheral, createANewOneIfNecesssary: Bool) -> BluetoothTransmitter?

    /// returns the BluetoothPeripheral for the specified BluetoothTransmitter
    /// - parameters:
    ///     - for : the bluetoothTransmitter, for which BluetoothPeripheral should be returned
    func getBluetoothPeripheral(for bluetoothTransmitter: BluetoothTransmitter) -> BluetoothPeripheral
    
    /// deletes the BluetoothPeripheral in coredata, and also the corresponding BluetoothTransmitter if there is one will be deleted
    func deleteBluetoothPeripheral(bluetoothPeripheral: BluetoothPeripheral)
    
    /// - returns: the BluetoothPeripheral's managed by this BluetoothPeripheralManager
    func getBluetoothPeripherals() -> [BluetoothPeripheral]
    
    /// bluetoothtransmitter for this bluetoothperiheral will be deleted, as a result this will also disconnect the bluetoothtransmitter
    func setBluetoothTransmitterToNil(forBluetoothPeripheral bluetoothPeripheral: BluetoothPeripheral)
    
}
