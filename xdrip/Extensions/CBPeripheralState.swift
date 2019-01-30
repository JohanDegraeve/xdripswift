import CoreBluetooth
import Foundation

extension CBPeripheralState {
    func description() -> String {
        switch self {
        case .connected:
            return "connected"
        case .connecting:
            return "connecting"
        case .disconnected:
            return "disconnected"
        case .disconnecting:
            return "disconnecting"
        default:
            return "unknown"
        }
    }
}
