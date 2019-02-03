import Foundation

struct BatteryStatusTxMessage {
    typealias Response = BatteryStatusRxMessage
    
    let opcode: Opcode = .batteryStatusTx
    var data: Data {
        return Data(for: .batteryStatusTx).appendingCRC()
    }
}
