enum ConstantsNightScout {
    
    /// - default nightscout url
    /// - used in settings, when setting first time nightscout url
    static let defaultNightScoutUrl = "https://yoursitename.herokuapp.com"
    
    /// maximum number of days to upload
    static let maxBgReadingsDaysToUpload = TimeInterval(days: 7)
    
    /// there's al imit of 102400 bytes to upload to NightScout, this corresponds on average to 400 readings. Setting a lower maximum value to avoid to bypass this limit.
    static let maxReadingsToUpload = 300
    
    /// if the time between the last and last but one reading is less than minimiumTimeBetweenTwoReadingsInMinutes, then the last reading will not be uploaded - except if there's been a disconnect in between these two readings
    static let minimiumTimeBetweenTwoReadingsInMinutes = 4.75
    
    /// maximum amount of treatments to sync with Nightscout
    static let maxTreatmentsToSync = 50

}
