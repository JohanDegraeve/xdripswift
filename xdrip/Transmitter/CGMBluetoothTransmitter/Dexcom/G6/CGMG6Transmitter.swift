import Foundation

class CGMG6Transmitter: CGMG5Transmitter {
    
    /// scaling factor for G6 firmware version 1
    private let G6v1ScalingFactor = 34.0
    
    /// scaling factor 1 for G6 firmware version 2
    static let G6v2DefaultScalingFactor1 = 1151500000.0
    
    static let G6v2DefaultScalingFactor2 = 110000.0
    
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

                var scalingFactor1 = CGMG6Transmitter.G6v2DefaultScalingFactor1
                if let factor = UserDefaults.standard.G6v2ScalingFactor1, let factorAsDouble = factor.toDouble() {
                    scalingFactor1 = factorAsDouble
                }

                var scalingFactor2 = CGMG6Transmitter.G6v2DefaultScalingFactor2
                if let factor = UserDefaults.standard.G6v2ScalingFactor2, let factorAsDouble = factor.toDouble() {
                    scalingFactor2 = factorAsDouble
                }

                // G6-v2
                return (rawValue - scalingFactor1) / scalingFactor2
            }
        } else {
            
            // assumed G6-v1, although firmwareVersion will normally not be nil
            return rawValue * G6v1ScalingFactor;
            
        }
        
    }
    
}
