import Foundation

/// class for bluetoothdevice
/// defines also device types in enum
/// it's in datamodel but there's probably not going to be a database storage, it's only a few attributes, only one instance will be created, looks better to store them via settings
class BluetoothDevice {
    
    enum deviceTypes {
        case none
        case DexcomxDripG4
        case DexcomG5
        case DexcomG6
        case Blucon
        case MiaoMiao
    }
    
    var deviceType = deviceTypes.none
    
    init () {}
    
    func isTypeLimitter() -> Bool {
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
