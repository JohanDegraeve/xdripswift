import Foundation

protocol CGMLibre2TransmitterDelegate: AnyObject {
    
    /// received sensor Serial Number
    func received(serialNumber: String, from cGMLibre2Transmitter: CGMLibre2Transmitter)

    /// Libre 2 is sending sensorStatus
    func received(sensorStatus: LibreSensorState, from cGMLibre2Transmitter: CGMLibre2Transmitter)
    
}
