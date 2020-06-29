/// constants related to Libre OOP
enum ConstantsLibre {

    /// is web oop enabled by default yes or no
    static let defaultWebOOPEnabled = false
    
    /// site for libreOOP client
    static let site = "http://www.glucose.space"
    
    /// token to use to access site
    static let token = "bubble-201907"
    
    /// calibration parameters will be stored locally on disk, this is the path
    static let filePathForParameterStorage = "/Documents/LibreSensorParameters"
    
    /// maximum age Libre 1
    ///
    /// taking one hour spare. To avoid that there's a wrong value used eg in case the user manually starts the sensor and doesn't set the time correctly
    static let maximumAgeLibre1InMinutes: Double = 20880.0 - 60.0
    
}
