import Foundation

protocol WatlaaBluetoothTransmitterDelegate: AnyObject {
    
    /// will be called if WatlaaBluetoothTransmitter is connected and ready to receive data, as soon as this is received, xdrip can request for example battery level
    func isReadyToReceiveData(watlaaBluetoothTransmitter: WatlaaBluetoothTransmitter)
    
    /// Watlaa is sending watlaa battery Level
    func received(watlaaBatteryLevel: Int, watlaaBluetoothTransmitter: WatlaaBluetoothTransmitter)
    
    /// Watlaa is sending transmitter battery Level
    func received(transmitterBatteryLevel: Int, watlaaBluetoothTransmitter: WatlaaBluetoothTransmitter)
    
    /// received sensor Serial Number
    func received(serialNumber: String, from watlaaBluetoothTransmitter: WatlaaBluetoothTransmitter)

}
