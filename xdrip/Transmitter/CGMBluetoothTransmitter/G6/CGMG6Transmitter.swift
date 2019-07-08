import Foundation

class CGMG6Transmitter: CGMG5Transmitter {
    
    /// - parameters:
    ///     - address: if already connected before, then give here the address that was received during previous connect, if not give nil
    ///     - transmitterID: expected transmitterID, 6 characters
    override init?(address:String?, transmitterID:String, delegate:CGMTransmitterDelegate) {
        
        // call super.init
        super.init(address: address, transmitterID: transmitterID, delegate: delegate)
        
        scalingFactor = 34.0
    }
    
}
