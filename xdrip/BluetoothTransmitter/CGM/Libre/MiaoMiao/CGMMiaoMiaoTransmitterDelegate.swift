import Foundation

protocol CGMMiaoMiaoTransmitterDelegate: AnyObject {
    
    /// received firmware
    func received(firmware: String, from cGMMiaoMiaoTransmitter: CGMMiaoMiaoTransmitter)
    
    /// received hardware
    func received(hardware: String, from cGMMiaoMiaoTransmitter: CGMMiaoMiaoTransmitter)
    
    /// received sensor Serial Number
    func received(serialNumber: String, from cGMMiaoMiaoTransmitter: CGMMiaoMiaoTransmitter)
    
    /// MiaoMiao is sending batteryLevel
    func received(batteryLevel: Int, from cGMMiaoMiaoTransmitter: CGMMiaoMiaoTransmitter)

    /// miaomiao is sending type of transmitter
    func received(libreSensorType: LibreSensorType, from cGMMiaoMiaoTransmitter: CGMMiaoMiaoTransmitter)
    
    /// miaomiao is sending sensorStatus
    func received(sensorStatus: LibreSensorState, from cGMMiaoMiaoTransmitter: CGMMiaoMiaoTransmitter)

}

