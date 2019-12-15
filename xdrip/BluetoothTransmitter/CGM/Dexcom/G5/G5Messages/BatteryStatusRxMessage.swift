import Foundation


struct BatteryStatusRxMessage: TransmitterRxMessage {
    let status: UInt8
    let voltageA: Int
    let voltageB: Int
    let resist: Int
    let runtime: Int
    let temperature:Int
    
    init?(data: Data) {
        guard data.count >= 10 && data.isCRCValid else {
            return nil
        }
        
        guard data.starts(with: .batteryStatusRx) else {
            return nil
        }
        
        status = data[1]
        voltageA = Int(data.uint16(position: 2))
        voltageB = Int(data.uint16(position: 4))
        resist = Int(data.uint16(position: 6))
        if data.count == 10 {// see https://github.com/NightscoutFoundation/xDrip/commit/b1fb0835a765a89ccc1bb8b216b0d6b2d21d66bb#diff-564e59f90a64b2928799ea4e30d81920
            runtime = -1
        } else {
            runtime = Int(data[8])
        }
        temperature = Int(data.uint8(position: 9))
    }
    
}
