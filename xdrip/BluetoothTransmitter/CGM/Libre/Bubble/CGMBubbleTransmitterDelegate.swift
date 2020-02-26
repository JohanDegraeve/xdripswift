import Foundation

protocol CGMBubbleTransmitterDelegate: AnyObject {
    
    /// received firmware
    func received(firmware: String, from cGMBubbleTransmitter: CGMBubbleTransmitter)
    
    /// received hardware
    func received(hardware: String, from cGMBubbleTransmitter: CGMBubbleTransmitter)
    
    /// received sensor Serial Number
    func received(serialNumber: String, from cGMBubbleTransmitter: CGMBubbleTransmitter)
    
    /// M5Stack is sending batteryLevel
    func received(batteryLevel: Int, from cGMBubbleTransmitter: CGMBubbleTransmitter)

}

