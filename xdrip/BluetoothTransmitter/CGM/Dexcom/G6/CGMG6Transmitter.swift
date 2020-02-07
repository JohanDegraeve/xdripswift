import Foundation

class CGMG6Transmitter: CGMG5Transmitter {
    
    /// scaling factor for G6 firmware version 1
    private let G6v1ScalingFactor = 34.0
    
    /// - parameters:
    ///     - address: if already connected before, then give here the address that was received during previous connect, if not give nil
    ///     - transmitterID: expected transmitterID, 6 characters
    override init(address:String?, name: String?, transmitterID:String, cGMTransmitterDelegate delegate:CGMTransmitterDelegate) {
        
        // call super.init
        super.init(address: address, name: name, transmitterID: transmitterID, cGMTransmitterDelegate: delegate)
        
    }
    
    override func scaleRawValue(firmwareVersion: String?, rawValue: Double) -> Double {
        
        return rawValue * G6v1ScalingFactor;
                
    }
    
    override func cgmTransmitterType() -> CGMTransmitterType? {
        return .dexcomG6
    }
    
}
