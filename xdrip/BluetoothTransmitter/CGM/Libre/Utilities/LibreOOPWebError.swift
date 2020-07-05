import Foundation

/// errors encountered whil processing libre data, complies to XdripError
enum LibreOOPWebError {
    
    /// didn't receive data from oop web server
    case receivedDataIsNil
    
    /// in case error is received after calling RLSession.shared.dataTask.resume
    case genericError(String)
    
    /// in case json parsing of oopweb server response failed
    case jsonParsingFailed
    
}

extension LibreOOPWebError: XdripError {

    var priority: XdripErrorPriority {
        
        switch self {
            
        case .receivedDataIsNil:
            return .HIGH
            
        case .genericError:
            return .HIGH
            
        case .jsonParsingFailed:
            return .LOW
            
        }
        
    }
    
    
    var errorDescription: String? {
        
        switch self {
            
        case .receivedDataIsNil:
            return TextsLibreErrors.oOPWebServerError + TextsLibreErrors.receivedDataIsNil
            
        case .genericError(let description):
            return TextsLibreErrors.oOPWebServerError + description
            
        case .jsonParsingFailed:
            return TextsLibreErrors.oOPWebServerError + "json parsing failed"
            
        }
    }
    
}
