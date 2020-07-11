import Foundation

/// errors encountered whil processing libre data, complies to XdripError
enum LibreOOPWebError {
    
    /// didn't receive data from oop web server
    case receivedDataIsNil
    
    /// in case error is received after calling RLSession.shared.dataTask.resume
    case genericError(String)
    
    /// in case json parsing of oopweb server response failed
    case jsonParsingFailed
    
    /// in case web server returns err
    case jsonResponseHasError(msg: String?, errcode: Int?)
    
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
            
        case .jsonResponseHasError(let msg, let errcode):
            // for now always return HIGH
            // maybe letter we change change to MEDIUM or LOW depending on errcode value
            return .HIGH
            
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
            
        case .jsonResponseHasError(let msg, let errcode):
            
            var message:String = ""
            if let msg = msg {
                message = msg
            }
            
            var errcodeAsInt:Int = 0
            if let errcode = errcode {
                errcodeAsInt = errcode
            }
            
            return TextsLibreErrors.oOPWebServerError + " code = " + errcodeAsInt.description + ", message = " + message
            
        }
    }
    
}
