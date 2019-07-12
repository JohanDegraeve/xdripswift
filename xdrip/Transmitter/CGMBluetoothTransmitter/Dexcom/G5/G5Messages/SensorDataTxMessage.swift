import Foundation


struct SensorDataTxMessage: RespondableMessage {
    typealias Response = SensorDataRxMessage

    var data: Data {
        return Data(for: .sensorDataTx).appendingCRC()
    }
}


