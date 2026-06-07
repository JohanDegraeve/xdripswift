import Foundation

/// errors encountered whil processing libre data, complies to XdripError
enum LibreOOPWebError {
    
    /// user tries Libre US which is not suppored
    case libreUSNotSupported
    
}

extension LibreOOPWebError: XdripError {

    var priority: XdripErrorPriority {
        
        switch self {
            
        case .libreUSNotSupported:
            return .HIGH
            
        }
        
    }
    
    
    var errorDescription: String? {
        
        switch self {
            
        case .libreUSNotSupported:
            return TextsLibreErrors.oOPWebServerError + " " + TextsLibreErrors.libreUSNotSupported
 
        }
    }
    
}
