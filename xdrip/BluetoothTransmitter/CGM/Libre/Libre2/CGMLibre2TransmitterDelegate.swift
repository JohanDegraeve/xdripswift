import Foundation

protocol CGMLibre2TransmitterDelegate: AnyObject {
    
    /// received sensor Serial Number
    func received(serialNumber: String, from cGMLibre2Transmitter: CGMLibre2Transmitter)

}
