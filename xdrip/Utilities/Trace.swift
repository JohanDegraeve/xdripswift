import Foundation
import os

fileprivate var log:OSLog = {
    let log:OSLog = OSLog(subsystem: ConstantsLog.subSystem, category: ConstantsLog.debuglogging)
    return log
}()


/// will only be used during development
func debuglogging(_ logtext:String) {
    os_log("%{public}@", log: log, type: .debug, logtext)
}

/// function to be used for logging, takes same parameters as os_log but in a next phase also NSLog can be added, or writing to disk to send later via e-mail ..
/// - message : the text, same format as in os_log with %{private}@ and %{public}@ to either keep variables private or public , string formatting parameters can be used as defined here https://developer.apple.com/library/archive/documentation/CoreFoundation/Conceptual/CFStrings/formatSpecifiers.html#//apple_ref/doc/uid/TP40004265
/// - log : as in os_log
/// - args : optional list of parameters that will be used. MAXIMUM 10 !
func trace(_ message: StaticString, log:OSLog, type:OSLogType, _ args: CVarArg...) {
    
    /*let message1 = message.description.replacingOccurrences(of: "{public}", with: "%").replacingOccurrences(of: "{private}", with: "%")
    let toprint = String(format: message1, "test")
    debuglogging("toprint = " + toprint)*/
    
    switch args.count {
        
    case 0:
        os_log(message, log: log, type: type)
    case 1:
        os_log(message, log: log, type: type, args[0])
    case 2:
        os_log(message, log: log, type: type, args[0], args[1])
    case 3:
        os_log(message, log: log, type: type, args[0], args[1], args[2])
    case 4:
        os_log(message, log: log, type: type, args[0], args[1], args[2], args[3])
    case 5:
        os_log(message, log: log, type: type, args[0], args[1], args[2], args[3], args[4])
    case 6:
        os_log(message, log: log, type: type, args[0], args[1], args[2], args[3], args[4], args[5])
    case 7:
        os_log(message, log: log, type: type, args[0], args[1], args[2], args[3], args[4], args[5], args[6])
    case 8:
        os_log(message, log: log, type: type, args[0], args[1], args[2], args[3], args[4], args[5], args[6], args[7])
    case 9:
        os_log(message, log: log, type: type, args[0], args[1], args[2], args[3], args[4], args[5], args[6], args[7], args[8])
    case 10:
        os_log(message, log: log, type: type, args[0], args[1], args[2], args[3], args[4], args[5], args[6], args[7], args[8], args[9])
    default:
        os_log(message, log: log, type: type)
        
    }
}

