import Foundation

protocol CGMDropletTransmitterDelegate: AnyObject {
    
    /// Droplet1 is sending batteryLevel
    func received(batteryLevel: Int, from cGMDroplet1Transmitter: CGMDroplet1Transmitter)

}
