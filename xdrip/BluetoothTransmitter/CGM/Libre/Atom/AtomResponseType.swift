import Foundation

enum AtomResponseType: UInt8 {
    case transmitterInfo = 0x80
    case sensorUID = 0xC0
    case patchInfo = 0xC1
    case dataPacket = 0x82
    case sensorNotDetected = 0xBF
}

extension AtomResponseType: CustomStringConvertible {
    public var description: String {
        switch self {
        case .transmitterInfo:
            return "Transmitter Info received"
        case .sensorUID:
            return "Sensor UID received"
        case .patchInfo:
            return "patchInfo detected"
        case .dataPacket:
            return "dataPacket received"
        case .sensorNotDetected:
            return "Sensor not detected"
        }
    }
}
