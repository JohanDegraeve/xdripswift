import Foundation


struct BatteryStatusRxMessage: TransmitterRxMessage {
    let status: UInt8
    let voltageA: Int
    let voltageB: Int
    let resist: Int
    let runtime: Int
    let temperature:Int
    
    init?(data: Data) {
        guard data.count >= 12 && data.isCRCValid else {
            return nil
        }
        
        guard data.starts(with: .batteryStatusRx) else {
            return nil
        }
        
        status = data[1]
        voltageA = Int(data.uint16(position: 2))
        voltageB = Int(data.uint16(position: 4))
        resist = Int(data.uint16(position: 6))
        runtime = Int(data.uint16(position: 8))
        temperature = Int(data.uint8(position: 10))
    }
    
}
