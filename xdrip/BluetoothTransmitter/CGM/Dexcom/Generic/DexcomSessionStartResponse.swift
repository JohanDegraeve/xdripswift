import Foundation

enum DexcomSessionStartResponse: UInt8 {
    
    
    case manualCalibrationSessionStarted = 0x01
    
    case staleStartComand = 0x02
    
    case error = 0x03
    
    case transmitterEndOfLife = 0x04
    
    case autoCalibrationSessionInProgress = 0x05
    
    public var description: String {
        
        switch self {
            
        case .manualCalibrationSessionStarted:
            return "manual calibration session started"
            
        case .staleStartComand:
            return "stale start comand"
            
        case .error:
            return "error"
            
        case .transmitterEndOfLife:
            return "transmitter end of life"
            
        case .autoCalibrationSessionInProgress:
            return "Auto calibration session in progress"
            
        }
        
    }
    
}
