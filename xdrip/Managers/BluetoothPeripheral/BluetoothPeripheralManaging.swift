import Foundation

/// used by BluetoothPeripheral UI view controllers - it's the glue between BluetoothPeripheralManager and UIViewControllers - defines functions to scan for devices, connect/disconnect, delete a BluetoothPeripheral, change the username, etc.
protocol BluetoothPeripheralManaging: AnyObject {
    
    /// to scan for a new BluetoothPeripheral - callback will be called when a new BluetoothPeripheral is found and connected
    func startScanningForNewDevice(callback: @escaping (BluetoothPeripheral) -> Void)
    
    /// will stop scanning, this is again for the case where scanning for a new BluetoothPeripheral has started
    func stopScanningForNewDevice()
    
    /// try to connect to the BluetoothPeripheral
    func connect(toBluetoothPeripheral bluetoothPeripheral: BluetoothPeripheral)
    
    /// returns the BluetoothTransmitter for the specified bluetoothPeripheral
    /// - parameters:
    ///     - forM5Stack : the object that conforms to bluetoothPeripheral, for which bluetoothTransmitter should be returned (remember bluetoothPeripheral is a protocol, every BluetoothTransmitter conforms to this protocol)
    ///     - createANewOneIfNecesssary : if there's no instance yet,  then should one be created ?
    func bluetoothTransmitter(forBluetoothPeripheral bluetoothPeripheral: BluetoothPeripheral, createANewOneIfNecesssary: Bool) -> BluetoothTransmitter?

    /// deletes the BluetoothPeripheral in coredata, and also the corresponding BluetoothTransmitter if there is one will be deleted
    func deleteBluetoothPeripheral(bluetoothPeripheral: BluetoothPeripheral)
    
    /// - returns: the BluetoothPeripheral's managed by this BluetoothPeripheralManager
    func getBluetoothPeripherals() -> [BluetoothPeripheral]
    
    /// bluetoothtransmitter for this bluetoothperiheral will be deleted, as a result this will also disconnect the bluetoothtransmitter
    func setBluetoothTransmitterToNil(forBluetoothPeripheral bluetoothPeripheral: BluetoothPeripheral)
    
}
