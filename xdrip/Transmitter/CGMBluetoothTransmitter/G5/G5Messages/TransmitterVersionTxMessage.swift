import Foundation


struct TransmitterVersionTxMessage {
    typealias Response = TransmitterVersionRxMessage

    let opcode: DexcomTransmitterOpCode = .transmitterVersionTx
    var data: Data {
        return Data(for: .transmitterVersionTx).appendingCRC()
    }
}
