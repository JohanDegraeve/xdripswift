/// constants related to Libre OOP
enum ConstantsLibre {

    /// is nonFixed enabled by default yes or no
    static let defaultNonFixedSlopeEnabled = false
    
    /// is web oop enabled by default yes or no
    static let defaultWebOOPEnabled = true
    
    /// calibration parameters will be stored locally on disk, this is the path
    static let filePathForParameterStorage = "/Documents/LibreSensorParameters"
    
    /// how many times should the app repeat the NFC scan whilst trying to get a tag response and systemInfo/patchInfo
    static let retryAttemptsForLibre2NFCScans = 10
    
}
