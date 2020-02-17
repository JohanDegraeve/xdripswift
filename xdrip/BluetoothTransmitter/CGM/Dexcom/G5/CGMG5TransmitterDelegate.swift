import Foundation

protocol CGMG5TransmitterDelegate: AnyObject {
    
    /// received firmware from CGMG5Transmitter 
    func received(firmware: String, cGMG5Transmitter: CGMG5Transmitter)
    
}

