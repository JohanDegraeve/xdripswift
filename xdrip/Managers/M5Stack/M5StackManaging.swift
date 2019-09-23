import Foundation

/// used by M5Stack UI view controllers - it's the glue between M5StackManager and UIViewControllers - defines functions to scan for devices, connect/disconnect, delete an M5 stack, change the username, etc. 
protocol M5StackManaging: AnyObject {
    
    /// to scan for a new M5SStack - callback will be called when a new M5Stack is found and connected
    func startScanningForNewDevice(callback: @escaping (M5Stack) -> Void)
    
    /// will stop scanning, this is again for the case where scanning for a new M5Stack has started
    func stopScanningForNewDevice()
    
    /// will call coreDataManager.saveChanges
    func save()
    
    /// try to connect to the M5Stack
    func connect(toM5Stack m5Stack: M5Stack)
    
    /// disconnect from M5Stack
    func disconnect(fromM5stack m5Stack: M5Stack)
    
    /// returns the M5StackBluetoothTransmitter for the m5stack
    /// - parameters:
    ///     - forM5Stack : the m5Stack for which bluetoothTransmitter should be returned
    ///     - createANewOneIfNecesssary : if bluetoothTransmitter is nil, then should one be created ?
    func m5StackBluetoothTransmitter(forM5stack m5Stack: M5Stack, createANewOneIfNecesssary: Bool) -> M5StackBluetoothTransmitter?

    /// deletes the M5Stack in coredata, and also the corresponding M5StackBluetoothTransmitter if there is one will be deleted
    func deleteM5Stack(m5Stack: M5Stack)
    
    /// - returns: the M5Stack's managed by this M5StackManager
    func m5Stacks() -> [M5Stack]
}
