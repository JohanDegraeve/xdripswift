import Foundation

protocol CGMBubbleTransmitterDelegate: AnyObject {
    
    /// received firmware
    func received(firmware: String, from cGMBubbleTransmitter: CGMBubbleTransmitter)
    
    /// received hardware
    func received(hardware: String, from cGMBubbleTransmitter: CGMBubbleTransmitter)
    
    /// received sensor Serial Number
    func received(serialNumber: String, from cGMBubbleTransmitter: CGMBubbleTransmitter)
    
    /// Bubble is sending batteryLevel
    func received(batteryLevel: Int, from cGMBubbleTransmitter: CGMBubbleTransmitter)

    /// Bubble is sending type of transmitter
    func received(libreSensorType: LibreSensorType, from cGMBubbleTransmitter: CGMBubbleTransmitter)
    
    /// bubble is sending sensorStatus
    func received(sensorStatus: LibreSensorState, from cGMBubbleTransmitter: CGMBubbleTransmitter)
    
}

