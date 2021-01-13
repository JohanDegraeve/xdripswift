import Foundation

protocol CGMLibre2TransmitterDelegate: AnyObject {
    
    /// received sensor Serial Number
    func received(serialNumber: String, from cGMLibre2Transmitter: CGMLibre2Transmitter)

    /// received sensor time in minutes
    func received(sensorTimeInMinutes: Int, from cGMLibre2Transmitter: CGMLibre2Transmitter)
}
