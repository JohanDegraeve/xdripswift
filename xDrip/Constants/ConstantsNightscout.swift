enum ConstantsNightscout {
    
    /// - default nightscout url
    /// - used in settings, when setting first time nightscout url
    static let defaultNightscoutUrl = "https://"
    
    /// maximum number of days to upload
    static let maxBgReadingsDaysToUpload = TimeInterval(days: 7)
    
    /// there's al imit of 102400 bytes to upload to Nightscout, this corresponds on average to 400 readings. Setting a lower maximum value to avoid to bypass this limit.
    static let maxReadingsToUpload = 300
    
    /// if the time between the last and last but one reading is less than minimiumTimeBetweenTwoReadingsInMinutes, then the last reading will not be uploaded - except if there's been a disconnect in between these two readings
    static let minimiumTimeBetweenTwoReadingsInMinutes = 4.75
    
    /// use a modified time between readings if the user has enabled this option in developer settings. This will allow uploads of 60-second CGM values to Nightscout
    static let minimiumTimeBetweenTwoReadingsInMinutesFrequentUploads = 0.75
    
    /// maximum amount of treatments to upload to Nightscout (inclusive updated treatments and treatments marked as deleted)
    static let maxTreatmentsToUpload = 50
    
    /// download treatments from nightscout, how manyhours
    static let maxHoursTreatmentsToDownload = 24.0
    
    /// the text used by Nightscout for the "unit" json attribute for BG Checks stored in mg/dl
    static let mgDlNightscoutUnitString = "mg/dl"
    
    /// the text used by Nightscout for the "unit" json attribute for BG Checks stored in mmol/l
    static let mmolNightscoutUnitString = "mmol"
    
    /// how many seconds should we force the app to wait between treatment sync attempts
    static let minimiumTimeBetweenTwoTreatmentSyncsInSeconds: Double = 10
    
    static let omniPodReservoirFlagNumber: Double = 9999
}
