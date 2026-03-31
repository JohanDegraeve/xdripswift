import Foundation

enum DexcomSessionStartResponse: UInt8 {
    
    
    case manualCalibrationSessionStarted = 0x01
    
    case manualCalibrationSessionInProgress = 0x02
    
    case staleStartComand = 0x03
    
    case error = 0x04
    
    case transmitterEndOfLife = 0x05
    
    case autoCalibrationSessionInProgress = 0x06
    
    public var description: String {
        
        switch self {
            
        case .manualCalibrationSessionStarted:
            return "manual calibration session started"
            
        case .manualCalibrationSessionInProgress:
            return "manual calibration session in progress"
            
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
