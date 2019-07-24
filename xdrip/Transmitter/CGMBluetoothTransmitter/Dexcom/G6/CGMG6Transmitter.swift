import Foundation

class CGMG6Transmitter: CGMG5Transmitter {
    
    /// scaling factor for G6 firmware version 1
    private let G6v1ScalingFactor = 34.0
    
    /// - parameters:
    ///     - address: if already connected before, then give here the address that was received during previous connect, if not give nil
    ///     - transmitterID: expected transmitterID, 6 characters
    override init?(address:String?, transmitterID:String, delegate:CGMTransmitterDelegate) {
        
        // call super.init
        super.init(address: address, transmitterID: transmitterID, delegate: delegate)
        
    }
    
    override func scaleRawValue(firmwareVersion: String?, rawValue: Double) -> Double {
        
        if let firmwareVersion = firmwareVersion {
            if firmwareVersion.startsWith("1") {
                
                // G6-v1
                return rawValue * G6v1ScalingFactor;
                
            } else {
                
                // G6-v2
                return (rawValue - 1151395987) / 113432;
            }
        } else {
            
            // assumed G6-v1, although firmwareVersion will normally not be nil
            return rawValue * G6v1ScalingFactor;
            
        }
        
    }
    
}
