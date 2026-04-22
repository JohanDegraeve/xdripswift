import Foundation

enum ConstantsTrace {

    /// email address to which to send trace file
    static let traceFileDestinationAddress = "xdrip@proximus.be"

    /// - will be used as filename to store traces on disk, and attachment file name when sending trace via e-mail
    /// - filename will be extended with digit, eg xdriptrace.0.log, or xdriptrace.1.log - the actual trace file is always xdriptrace.0.log
    static let traceFileName = "xdriptrace"
    
    /// maximum size of one trace file, in MB. If size is larger, files will rotate, ie all trace files will be renamed, from xdriptrace.2.log to xdriptrace.3.log, from xdriptrace.1.log to xdriptrace.2.log, from xdriptrace.0.log to xdriptrace.1.log, 
    static let maximumFileSizeInMB: UInt64 = 3
    
    /// maximum amount of trace files to hold. When rotating, and if value is 3, then tracefile xdriptrace.2.log will be deleted
    static let maximumAmountOfTraceFiles = 3
    
    /// will be used as filename to app info (configured transmitters etc ...)
    static let appInfoFileName = "appinfo.txt"
    
}
