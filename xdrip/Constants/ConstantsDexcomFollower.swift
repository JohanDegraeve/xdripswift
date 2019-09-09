/// constants for follower mode
enum ConstantsFollower {
    
    /// maximum days of readings to download
    static let maxiumDaysOfReadingsToDownload = 1
    
    /// maximum age in seconds, of reading in alert flow. If age of latest reading is more than this number, then no alert check will be done
    static let maximumBgReadingAgeForAlertsInSeconds = 1200.0
}
