/// constants typically for master mode
enum ConstantsMaster {
    
    /// maximum age in seconds, of reading in alert flow. If age of latest reading is more than this number, then no alert check will be done
    static let maximumBgReadingAgeForAlertsInSeconds = 60.0 * 5
}
