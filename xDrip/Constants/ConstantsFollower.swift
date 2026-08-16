import Foundation

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

    /// number of seconds without a successful follower connection before a warning is shown when in Medtrum EasyView follower mode
    static let secondsUntilFollowerDisconnectWarningMedtrumEasyView: Int = 70

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

/// CareLink-specific follower timing.
///
/// These values follow xDrip+'s CareLink Follow scheduling strategy: anticipate the next
/// five-minute sample, allow a 30-second upload grace period, retry missing data once per minute,
/// and keep at least 20 seconds between requests. xDrip4iOS initially reused Nightscout's fixed
/// 15-second polling cadence, but initial live testing produced a repeatable pattern consistent
/// with CareLink server throttling, so CareLink now uses its source-specific reference strategy.
/// Reference: NightscoutFoundation/xDrip, `cgm/carelinkfollow/CareLinkFollowService.java`.
enum ConstantsCareLink {
    static let samplePeriod: TimeInterval = 5 * 60
    static let pollingGracePeriod: TimeInterval = 30
    static let missedDataPollingInterval: TimeInterval = 60
    static let minimumPollingInterval: TimeInterval = 20
    /// A local deadline check only; CareLink is contacted only when `nextPollAt` is due.
    static let schedulerCheckInterval = minimumPollingInterval
    static let staleReadingAge: TimeInterval = 20 * 60
    static let initialRetryBackoff: TimeInterval = 15
    static let maximumRetryBackoff: TimeInterval = 5 * 60
}
