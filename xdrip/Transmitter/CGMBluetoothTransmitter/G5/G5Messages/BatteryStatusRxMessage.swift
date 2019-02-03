import Foundation


struct BatteryStatusRxMessage: TransmitterRxMessage {
    let status: UInt8
    let voltageA: Int
    let voltageB: Int
    let resist: Int
    
    init?(data: Data) {
        guard data.count >= 12 && data.isCRCValid else {
            return nil
        }
        
        guard data.starts(with: .batteryStatusRx) else {
            return nil
        }
        
        status = data[1]
        voltageA = data[2..<4].toInt()
        voltageB = data[4..<6].toInt()
        resist = data[6..<8].toInt()
    }
    
}
