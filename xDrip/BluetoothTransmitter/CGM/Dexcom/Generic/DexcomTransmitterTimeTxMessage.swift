import Foundation

struct DexcomTransmitterTimeTxMessage {
    typealias Response = DexcomTransmitterTimeRxMessage
    
    let opcode: DexcomTransmitterOpCode = .transmitterTimeTx
    var data: Data {
        return Data(for: .transmitterTimeTx).appendingCRC()
    }
}

