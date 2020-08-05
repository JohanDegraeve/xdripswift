import Foundation

/// errors encountered whil processing libre data, complies to XdripError
enum DexcomError {
    
    /// this indicates low battery, error message needs to be shown in that case
    case receivedEnfilteredValue2096896
    
}

extension DexcomError: XdripError {
    
    var priority: XdripErrorPriority {
        
        switch self {
            
        case .receivedEnfilteredValue2096896:
            return .HIGH
        }
        
    }
    
    
    var errorDescription: String? {
        
        switch self {
            
        case .receivedEnfilteredValue2096896:
            return Texts_HomeView.dexcomBatteryTooLow
            
        }
    }
    
}
