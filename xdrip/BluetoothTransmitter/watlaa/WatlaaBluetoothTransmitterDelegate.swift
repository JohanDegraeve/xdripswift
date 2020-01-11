import Foundation

protocol WatlaaBluetoothTransmitterDelegate: BluetoothTransmitterDelegate {
    
    /// will be called if WatlaaBluetoothTransmitter is connected and ready to receive data, as soon as this is received, xdrip can request for example battery level
    func isReadyToReceiveData(watlaaBluetoothTransmitter: WatlaaBluetoothTransmitterMaster)

    /// Watlaa is sending batteryLevel
    func receivedBattery(level: Int, watlaaBluetoothTransmitter: WatlaaBluetoothTransmitterMaster)
    
}
