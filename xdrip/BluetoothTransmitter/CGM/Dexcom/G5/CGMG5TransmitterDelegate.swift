import Foundation

protocol CGMG5TransmitterDelegate: AnyObject {
    
    /// received firmware from CGMG5Transmitter 
    func received(firmware: String, cGMG5Transmitter: CGMG5Transmitter)
    
    func received(transmitterBatteryInfo: TransmitterBatteryInfo, cGMG5Transmitter: CGMG5Transmitter)
    
    /// transmitter reset result
    func reset(for cGMG5Transmitter: CGMG5Transmitter, successful: Bool)
    
}

