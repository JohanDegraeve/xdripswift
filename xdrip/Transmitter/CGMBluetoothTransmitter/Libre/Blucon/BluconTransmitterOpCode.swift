import Foundation

enum BluconTransmitterOpCode: String, CaseIterable {
    
    case wakeUp = "cb010000"
    
    case getPatchInfoRequest = "010d0900"
    
    case getPatchInfoResponse = "8bd9"
    
    case error14 = "8b1a020014"
    
    case sensorNotDetected = "8b1a02000f"
    
    /// iterates through all cases, and as soon as one is found that starts with valueReceived, then initializes with that case. If none found then returns nil
    public init?(withOpCodeValue: String) {
        for opCode in BluconTransmitterOpCode.allCases {
            if withOpCodeValue.startsWith(opCode.rawValue) {
                self = opCode
                return
            }
        }
        
        return nil
    }
    
    
    public var description:String {
        
        switch self {
            
        case .wakeUp:
            return "wakeUp"
            
        case .getPatchInfoRequest:
            return "getPatchInfo"
            
        case .error14:
            return "error14"
            
        case .sensorNotDetected:
            return "sensorNotDetected"
            
        case .getPatchInfoResponse:
            return "getPatchInfoResponse"
        }
    }
}
