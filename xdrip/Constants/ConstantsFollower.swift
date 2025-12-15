/// constants for follower mode
enum ConstantsFollower {
    
    /// maximum days of readings to download
    static let maxiumDaysOfReadingsToDownload = 1
    
    /// maximum age in seconds, of reading in alert flow. If age of latest reading is more than this number, then no alert check will be done
    static let maximumBgReadingAgeForAlertsInSeconds = 240.0
    
    /// how often the followerConnectionTimer should run to check for the last connection timestamp and update the UI
    static let secondsUsedByFollowerConnectionTimer: Double = 5
    
    /// number of seconds without a successful follower connection before a warning is shown when in Nightscout follower mode
    static let secondsUntilFollowerDisconnectWarningNightscout: Int = 310
    
    /// number of seconds without a successful follower connection before a warning is shown when in LibreLinkUp follower mode
    static let secondsUntilFollowerDisconnectWarningLibreLinkUp: Int = 70
    
    /// number of seconds without a successful follower connection before a warning is shown when in Dexcom Share follower mode
    static let secondsUntilFollowerDisconnectWarningDexcomShare: Int = 310
    
    
    // Server URLs for different services
    /// base url for Abbott server statuspage
    static let followerStatusAbbottBaseUrl = "https://status.freestyle.abbott"
    /// base url for Dexcom server statuspage
    static let followerStatusDexcomBaseUrl = "https://status.dexcom.com"
    
    // Server paths for status API
    /// status endpoint for Abbott, Dexcom
    static let followerStatusAtlassianApiPath = "/api/v2/summary.json"
    /// status endpoint for Nightscout
    static let followerStatusNightscoutApiPath = "/api/v1/status.json"    
}
