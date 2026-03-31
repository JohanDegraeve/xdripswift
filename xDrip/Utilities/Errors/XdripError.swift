import Foundation

/// for
protocol XdripError {
    
    var errorDescription: String? { get }
    
    var priority: XdripErrorPriority { get }
    
}

/// priority gives indication if user attention is required or not
enum XdripErrorPriority: String {
    
    /// LOW doesn't need user attention, just to keep track of it somewhere
    case LOW = "LOW"
    
    /// is between LOW and HIGH
    case MEDIUM = "MEDIUM"
    
    /// HIGH would be something that requires immediate attention from the user, either by notification , alarm, ...
    case HIGH = "HIGH"
    
}
