import Foundation

protocol CGMMiaoMiaoTransmitterDelegate: AnyObject {
    
    /// received firmware
    func received(firmware: String, from cGMMiaoMiaoTransmitter: CGMMiaoMiaoTransmitter)
    
    /// received hardware
    func received(hardware: String, from cGMMiaoMiaoTransmitter: CGMMiaoMiaoTransmitter)
    
    /// received sensor Serial Number
    func received(serialNumber: String, from cGMMiaoMiaoTransmitter: CGMMiaoMiaoTransmitter)
    
    /// M5Stack is sending batteryLevel
    func received(batteryLevel: Int, from cGMMiaoMiaoTransmitter: CGMMiaoMiaoTransmitter)

}

