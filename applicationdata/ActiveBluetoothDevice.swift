import Foundation

class ActiveBluetoothDevice {
    
    enum deviceTypes {
        case none
        case DexcomxDripG4
        case DexcomG5
        case DexcomG6
        case Blucon
        case MiaoMiao
    }
    
    static var deviceType = deviceTypes.none

    private init() {
    }

    static func isTypeLimitter() -> Bool {
        switch deviceType {
        case .DexcomxDripG4,.DexcomG5,.DexcomG6 :
            return false
        case .Blucon,.MiaoMiao :
            return true
        default :
            return false
        }
    }

}
