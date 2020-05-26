import Foundation

// sourcre https://github.com/gui-dos/DiaBLE

public enum LibreSensorType: String {
    
    // TODO: can this be improved ? raw type UInt8 iso String ? in which case all patchInfo variables would need to become of type LibreSensorType in stead of a String. In the bluetooth transmitters, then when assigning a value, immediately set to LibreSensorType iso patchInfo
    
    // Libre 1
    case libre1    = "DF"
    
    case libre1A2 =  "A2"
    
    case libre2    = "9D"
    
    case libreUS   = "E5"
    
    case libreProH = "70"
    
    var description: String {
        
        switch self {
            
        case .libre1:
            return "Libre 1"
            
        case .libre1A2:
            return "Libre 1"
            
        case .libre2:
            return "Libre 2"
            
        case .libreUS:
            return "Libre US"
            
        case .libreProH:
            return "Libre PRO H"

        }
        
    }
    
    /// some of the Libre types can not work without webOOP. In case returnvalue is true, then user can not change the value
    func needsWebOOP() -> Bool {
        
        switch self {
            
        case .libre1:
            return false
            
        case .libre1A2, .libre2, .libreUS, .libreProH :
            return true
            
        }
        
    }
    
    /// - reads the first byte in patchInfo and dependent on that value, returns type of sensor
    /// - if patchInfo = nil, then returnvalue is Libre1
    /// - if first byte is unknown, then returns nil
    static func type(patchInfo: String?) -> LibreSensorType? {
        
        guard let patchInfo = patchInfo else {return .libre1}
        
        guard patchInfo.count > 1 else {return nil}
        
        let firstTwoChars = patchInfo[0..<2]
        
        switch firstTwoChars {
            
        case "DF":
            return .libre1
            
        case "A2":
            return .libre1A2
            
        case "9D":
            return .libre2
            
        case "E5":
            return .libreUS
            
        case "70":
            return .libreProH
            
        default:
            return nil
            
        }
            
    }
    
}


