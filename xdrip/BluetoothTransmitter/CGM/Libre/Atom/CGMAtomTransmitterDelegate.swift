import Foundation

protocol CGMAtomTransmitterDelegate: AnyObject {
    
    /// received firmware
    func received(firmware: String, from cGMAtomTransmitter: CGMAtomTransmitter)
    
    /// received hardware
    func received(hardware: String, from cGMAtomTransmitter: CGMAtomTransmitter)
    
    /// received sensor Serial Number
    func received(serialNumber: String, from cGMAtomTransmitter: CGMAtomTransmitter)
    
    /// Atom is sending batteryLevel
    func received(batteryLevel: Int, from cGMAtomTransmitter: CGMAtomTransmitter)
    
    /// miaomiao is sending type of transmitter
    func received(libreSensorType: LibreSensorType, from cGMAtomTransmitter: CGMAtomTransmitter)
    
    /// miaomiao is sending sensorStatus
    func received(sensorStatus: LibreSensorState, from cGMAtomTransmitter: CGMAtomTransmitter)
    
}

