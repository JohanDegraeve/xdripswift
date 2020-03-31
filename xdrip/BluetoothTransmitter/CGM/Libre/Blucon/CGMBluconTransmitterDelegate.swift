import Foundation

protocol CGMBluconTransmitterDelegate: AnyObject {
    
    /// received sensor Serial Number
    func received(serialNumber: String?, from cGMBluconTransmitter: CGMBluconTransmitter)
    
    /// M5Stack is sending batteryLevel
    func received(batteryLevel: Int, from cGMBluconTransmitter: CGMBluconTransmitter)

}

