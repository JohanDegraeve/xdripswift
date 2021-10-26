import Foundation

protocol CGMG6FireflyTransmitterDelegate: AnyObject {
    
    /// received firmware from CGMG6FireflyTransmitter
    func received(firmware: String, cGMG6FireflyTransmitter: CGMG6FireflyTransmitter)
    
    func received(transmitterBatteryInfo: TransmitterBatteryInfo, cGMG6FireflyTransmitter: CGMG6FireflyTransmitter)
    
    /// transmitter reset result
    func reset(for cGMG6FireflyTransmitter: CGMG6FireflyTransmitter, successful: Bool)
    
}

