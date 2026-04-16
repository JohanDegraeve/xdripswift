import Foundation

/// errors encountered whil processing libre data, complies to XdripError
enum LibreError {
    
    /// sensor not in status ready and not expired (expired is between 14 and 14.5 days, still usable)
    case sensorNotReady
    
}

extension LibreError: XdripError {
    
    var priority: XdripErrorPriority {
        
        switch self {
            
        case .sensorNotReady:
            return .HIGH
        
        }
        
    }
    
    
    var errorDescription: String? {
        
        switch self {
            
        case .sensorNotReady:
            return TextsLibreErrors.libreSensorNotReady
    
        }
    }
    
}
