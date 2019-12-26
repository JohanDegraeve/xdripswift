import Foundation


struct SensorDataRxMessage: TransmitterRxMessage {
    let status: UInt8
    let timestamp: Date
    let unfiltered: Double
    let filtered: Double

    init?(data: Data) {
        guard data.count >= 14 && data.isCRCValid else {
            return nil
        }

        guard data.starts(with: .sensorDataRx) else {
            return nil
        }

        status = data[1]
        timestamp = Date()
        let filteredAsUint32:UInt32 = data.uint32(position: 6)
        filtered = Double(filteredAsUint32)
        let unfilteredAsUint32:UInt32 = data.uint32(position: 10)
        unfiltered = Double(unfilteredAsUint32)
    }
}
