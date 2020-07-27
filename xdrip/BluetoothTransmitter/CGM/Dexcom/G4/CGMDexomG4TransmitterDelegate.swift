import Foundation

protocol CGMDexcomG4TransmitterDelegate: AnyObject {
    
    /// DexcomG4 is sending batteryLevel
    func received(batteryLevel: Int, from cGMG4xDripTransmitter: CGMG4xDripTransmitter)
    
}
