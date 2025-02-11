import Foundation

protocol CGMG5TransmitterDelegate: AnyObject {
    
    /// received firmware from CGMG5Transmitter 
    func received(firmware: String, cGMG5Transmitter: CGMG5Transmitter)

    /// received transmitterBatteryInfo
    func received(transmitterBatteryInfo: TransmitterBatteryInfo, cGMG5Transmitter: CGMG5Transmitter)
    
    /// received transmitterStartDate
    func received(transmitterStartDate: Date, cGMG5Transmitter: CGMG5Transmitter)
    
    /// transmitter reset result
    func reset(for cGMG5Transmitter: CGMG5Transmitter, successful: Bool)
    
    /// sensor start time as received from transmitter
    /// - sensorStartDate = nil for sensorStop
    func received(sensorStartDate: Date?, cGMG5Transmitter: CGMG5Transmitter)
   
    /// sensor status as received from the transmitter
    /// - sensorStatus if not known
    func received(sensorStatus: String?, cGMG5Transmitter: CGMG5Transmitter)
    
    /// isAnubis flag as decoded from the transmitterVersionRxMessage received from the transmitter
    func received(isAnubis: Bool, cGMG5Transmitter: CGMG5Transmitter)
    
}

