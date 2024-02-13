import Foundation

protocol CGMG7TransmitterDelegate: AnyObject {
    
    /// sensor start time as received from transmitter
    /// - sensorStartDate = nil for sensorStop
    func received(sensorStartDate: Date?, cGMG7Transmitter: CGMG7Transmitter)
   
    /// sensor status as received from the transmitter
    /// - sensorStatus if not known
    func received(sensorStatus: String?, cGMG7Transmitter: CGMG7Transmitter)
    
}

