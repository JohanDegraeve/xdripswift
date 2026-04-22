import Foundation

enum MiaoMiaoResponseType: UInt8 {
    case dataPacket = 0x28
    case newSensor = 0x32
    case noSensor = 0x34
    case frequencyChangedResponse = 0xD1
}

extension MiaoMiaoResponseType: CustomStringConvertible {
    public var description: String {
        switch self {
        case .dataPacket:
            return "Data packet received"
        case .newSensor:
            return "New sensor detected"
        case .noSensor:
            return "No sensor detected"
        case .frequencyChangedResponse:
            return "Reading interval changed"
        }
    }
}
