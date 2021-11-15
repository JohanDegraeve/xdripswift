import Foundation

enum DexcomSessionStopResponse: UInt8 {
    
    // 0x01 = Stop Session Successful | 0x02 = No Session In Progress | 0x03 Stale Stop Command
    
    case stopSessionSuccessful = 0x01
    
    case noSessionInProgress = 0x02
    
    case staleStopCommand = 0x03
    
    public var description: String {
        
        switch self {
            
        case .stopSessionSuccessful:
            return "stopSessionSuccessful"
            
        case .noSessionInProgress:
            return "noSessionInProgress"
            
        case .staleStopCommand:
            return "staleStopCommand"
            
        }
        
    }
    
}
