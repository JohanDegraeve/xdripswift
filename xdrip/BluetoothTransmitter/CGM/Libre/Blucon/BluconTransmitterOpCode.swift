import Foundation

enum BluconTransmitterOpCode: String, CaseIterable {
    
    case wakeUpRequest = "cb010000"
    
    case wakeUpResponse = "810a00"
    
    case getPatchInfoRequest = "010d0900"
    
    case getPatchInfoResponse = "8bd9"
    
    case error14 = "8b1a020014"
    
    case sensorNotDetected = "8b1a02000f"
    
    case sleep = "010c0e00"
    
    case bluconAckResponse = "8b0a00"
    
    case unknown1Command = "010d0b00"
    
    case unknown1CommandResponse = "8bdb"
    
    case unknown2Command = "010d0a00"
    
    case unknown2CommandResponse = "8bda"
    
    case getHistoricDataAllBlocksCommand = "010d0f02002b"
    
    case multipleBlockResponseIndex = "8bdf"
    
    case getNowDataIndex = "010d0e0103"
    
    case singleBlockInfoResponsePrefix = "8bde"
    
    case singleBlockInfoPrefix = "010d0e010"
    
    case bluconBatteryLowIndication1 = "cb020000"

    case bluconBatteryLowIndication2 = "cbdb0000"

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
            
        case .wakeUpRequest:
            return "wakeUp"
            
        case .wakeUpResponse:
            return "wakeUpResponse"
            
        case .getPatchInfoRequest:
            return "getPatchInfo"
            
        case .error14:
            return "error14"
            
        case .sensorNotDetected:
            return "sensorNotDetected"
            
        case .getPatchInfoResponse:
            return "getPatchInfoResponse"
            
        case .sleep:
            return "sleep"
            
        case .bluconAckResponse:
            return "bluconAckResponse"
            
        case .unknown1Command:
            return "unknown1Command"
            
        case .unknown1CommandResponse:
            return "unknown1CommandResponse"
            
        case .unknown2Command:
            return "unknown2Command"
            
        case .unknown2CommandResponse:
            return "unknown2CommandResponse"
            
        case .getHistoricDataAllBlocksCommand:
            return "getHistoricDataAllBlocksCommand"
            
        case .multipleBlockResponseIndex:
            return "multipleBlockResponseIndex"
            
        case .getNowDataIndex:
            return "getNowDataIndex"
            
        case .singleBlockInfoResponsePrefix:
            return "singleBlockInfoResponsePrefixResponse"
            
        case .singleBlockInfoPrefix:
            return "singleBlockInfoPrefix"
            
        case .bluconBatteryLowIndication1:
            return "bluconBatteryLowIndication1"
        
        case .bluconBatteryLowIndication2:
            return "bluconBatteryLowIndication2"
            
        }
    }
}
