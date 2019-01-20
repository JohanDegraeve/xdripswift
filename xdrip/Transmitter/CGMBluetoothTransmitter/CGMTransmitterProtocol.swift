import Foundation

protocol CGMTransmitterProtocol {
    /// example MiaoMiao can detect new sensor, implementation should return true, Dexcom transmitter's can't
    func canDetectNewSensor() -> Bool
}
