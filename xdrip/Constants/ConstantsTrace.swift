import Foundation

enum ConstantsTrace {

    /// email address to which to send trace file
    static let traceFileDestinationAddress = "xdrip@proximus.be"

    /// will be used as filename to store traces on disk, and attachment file name when sending trace via e-mail
    static let traceFileName = "xdriptrace.txt"
    
    /// will be used as filename to app info (configured transmitters etc ...)
    static let appInfoFileName = "appinfo.txt"
    
}
