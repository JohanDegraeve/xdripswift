import Foundation

class CGMG6Transmitter: CGMG5Transmitter {
    
    /// - parameters:
    ///     - address: if already connected before, then give here the address that was received during previous connect, if not give nil
    ///     - transmitterID: expected transmitterID, 6 characters
    ///     - bluetoothTransmitterDelegate : a BluetoothTransmitterDelegate
    ///     - cGMTransmitterDelegate : a CGMTransmitterDelegate
    init(address:String?, name: String?, transmitterID:String, bluetoothTransmitterDelegate: BluetoothTransmitterDelegate, cGMG6TransmitterDelegate: CGMG6TransmitterDelegate, cGMTransmitterDelegate:CGMTransmitterDelegate, transmitterStartDate: Date?, firmware: String?) {
        
        // call super.init
        super.init(address: address, name: name, transmitterID: transmitterID, bluetoothTransmitterDelegate: bluetoothTransmitterDelegate, cGMG5TransmitterDelegate: cGMG6TransmitterDelegate, cGMTransmitterDelegate: cGMTransmitterDelegate, transmitterStartDate: transmitterStartDate, firmware: firmware)
        
    }
    
    override func scaleRawValue(firmwareVersion: String?, rawValue: Double) -> Double {
        
        guard let firmwareVersion = firmwareVersion else { return rawValue }
        
        if firmwareVersion.starts(with: "1.") {
            
            return rawValue * 34.0
            
        } else if firmwareVersion.starts(with: "2.") {
            
            return (rawValue - 1151500000.0) / 110.0
            
        }
        
        return rawValue
        
    }
    
    override func cgmTransmitterType() -> CGMTransmitterType {
        return .dexcomG6
    }
    
}
