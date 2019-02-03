import Foundation


struct TransmitterVersionTxMessage {
    typealias Response = TransmitterVersionRxMessage

    let opcode: Opcode = .transmitterVersionTx
    var data: Data {
        return Data(for: .transmitterVersionTx).appendingCRC()
    }
}
