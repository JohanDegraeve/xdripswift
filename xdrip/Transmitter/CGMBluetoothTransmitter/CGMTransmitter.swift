import Foundation

protocol CGMTransmitter {
    /// example MiaoMiao can detect new sensor, implementation should return true, Dexcom transmitter's can't
    func canDetectNewSensor() -> Bool
    
    /// get device address, cgmtransmitters should also derive from BlueToothTransmitter, hence no need to implement this function
    func address() -> String?
    
    /// get device name, cgmtransmitters should also derive from BlueToothTransmitter, hence no need to implement this function
    func name() -> String?
    
    /// start scanning, cgmtransmitters should also derive from BlueToothTransmitter, hence no need to implement this function
    /// - returns:
    ///     the scanning result
    func startScanning() -> BluetoothTransmitter.startScanningResult
}
