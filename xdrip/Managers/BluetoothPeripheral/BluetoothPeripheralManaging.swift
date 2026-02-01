import Foundation

/// used by BluetoothPeripheral UI view controllers - it's the glue between BluetoothPeripheralManager and UIViewControllers
protocol BluetoothPeripheralManaging: BluetoothTransmitterDelegate {
    
    /// to scan for a new BluetoothPeripheral - callback will be called when a new BluetoothPeripheral is found and connected
    /// - parameters:
    ///     - transmitterId : only for devices that need a transmitterID (currently only Dexcom)
    ///     - callBackForScanningResult : to be called with result of startScanning
    ///     - bluetoothTransmitterDelegate : optional
    func startScanningForNewDevice(type: BluetoothPeripheralType, transmitterId: String?, bluetoothTransmitterDelegate: BluetoothTransmitterDelegate?, callBackForScanningResult: ((BluetoothTransmitter.startScanningResult) -> Void)?, callback: @escaping (BluetoothPeripheral) -> Void)
    
    /// stops scanning for new device
    func stopScanningForNewDevice()
    
    /// to know if bluetoothperipheralmanager is currently scanning for a new device
    func isScanning() -> Bool
    
    /// try to connect to the M5Stack
    func connect(to bluetoothPeripheral: BluetoothPeripheral)
    
    /// returns the BluetoothTransmitter for the specified bluetoothPeripheral
    /// - parameters:
    ///     - for : the bluetoothPeripheral, for which bluetoothTransmitter should be returned
    ///     - createANewOneIfNecesssary : if there's no instance yet,  then should one be created ?
    func getBluetoothTransmitter(for bluetoothPeripheral: BluetoothPeripheral, createANewOneIfNecesssary: Bool) -> BluetoothTransmitter?

    /// returns the BluetoothPeripheral for the specified BluetoothTransmitter
    /// - parameters:
    ///     - for : the bluetoothTransmitter, for which BluetoothPeripheral should be returned
    /// - returns:
    ///     - bluetoothPeripheral for the transmitter, can be nil (example if called while scanning)
    func getBluetoothPeripheral(for bluetoothTransmitter: BluetoothTransmitter) -> BluetoothPeripheral?
    
    /// deletes the BluetoothPeripheral in coredata, and also the corresponding BluetoothTransmitter if there is one will be deleted
    func deleteBluetoothPeripheral(bluetoothPeripheral: BluetoothPeripheral)
    
    /// - returns: the BluetoothPeripheral's managed by this BluetoothPeripheralManager
    func getBluetoothPeripherals() -> [BluetoothPeripheral]
    
    /// - returns: the BluetoothTransmittersl's managed by this BluetoothPeripheralManager
    func getBluetoothTransmitters() -> [BluetoothTransmitter]
    
    /// bluetoothtransmitter for this bluetoothperiheral will be deleted, as a result this will also disconnect the bluetoothtransmitter
    func setBluetoothTransmitterToNil(forBluetoothPeripheral bluetoothPeripheral: BluetoothPeripheral)
    
    /// bluetoothtransmitter may need pairing, but app is in background. Notification will be sent to user, user will open the app, at that moment initiatePairing will be called
    func initiatePairing()
    
    /// to pass new value off nonFixedSlopeEnabled
    ///
    /// when user changes the nonFixed value in BluetoothPeripheralViewController, this function will be called
    func receivedNewValue(nonFixedSlopeEnabled: Bool, for bluetoothPeripheral: BluetoothPeripheral)

    /// to pass new value off webOOPEnabled
    ///
    /// when user changes webOOP values in BluetoothPeripheralViewController, this function will be called
    func receivedNewValue(webOOPEnabled: Bool, for bluetoothPeripheral: BluetoothPeripheral)
    
    /// - returns the currently in use CGMTransmitter, nil if non in use.
    /// - in use means : created, and shouldconnect = true
    func getCGMTransmitter() -> CGMTransmitter?
    
    /// only applicable for Libre transmitters. To request a new reading.
    func requestNewReading()
    
}
