import Foundation

struct BatteryStatusTxMessage {
    typealias Response = BatteryStatusRxMessage
    
    let opcode: DexcomTransmitterOpCode = .batteryStatusTx
    var data: Data {
        return Data(for: .batteryStatusTx).appendingCRC()
    }
}
