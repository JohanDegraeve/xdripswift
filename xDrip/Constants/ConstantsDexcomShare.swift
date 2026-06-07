/// constants for Dexcom Share
enum ConstantsDexcomShare {
    // Application IDs
    /// applicationId to use in Dexcom Share protocol
    static let applicationId = "d89443d2-327c-4a6f-89e5-496bbb0317db"
    /// applicationId to use in Dexcom Share protocol for Japan
    static let applicationIdJapan = "d8665ade-9673-4e27-9ff6-92db4ce13d13"
        
    // Server URLs for different regions
    /// us share base url
    static let usBaseShareUrl = "https://share2.dexcom.com/ShareWebServices/Services"
    /// non-us/global share base url
    static let globalBaseShareUrl = "https://shareous1.dexcom.com/ShareWebServices/Services"
    /// japan share base url
    static let japanBaseShareUrl = "https://share.dexcom.jp/ShareWebServices/Services"
    
    // Server paths for dexcom share upload services
    /// endpoint for authorization to login with account name
    static let dexcomShareUploadLoginPath = "/General/LoginPublisherAccountByName"
    /// endpoint to upload EGV records
    static let dexcomShareUploadPostReceiverEgvRecordsPath = "Publisher/PostReceiverEgvRecords"
    /// endpoint to start remote monitoring session
    static let dexcomShareUploadStartRemoteMonitoringSessionPath = "Publisher/StartRemoteMonitoringSession"
    
    // Server paths for dexcom share follow mode services
    /// endpoint for authorization to get accountId
    static let dexcomShareFollowAuthPath = "/General/AuthenticatePublisherAccount"
    /// endpoint for login to get sessionId
    static let dexcomShareFollowLoginPath = "/General/LoginPublisherAccountById"
    /// endpoint to pull latest glucose values
    static let dexcomShareFollowLatestGlucoseValuesPath = "/Publisher/ReadPublisherLatestGlucoseValues"
    
    /// dummy/failed session ID - used in both upload and follower classes
    static let failedSessionId = "00000000-0000-0000-0000-000000000000"
    
    /// if the time between the last and last but one reading is less than minimiumTimeBetweenTwoReadingsInMinutes, then the last reading will not be uploaded - except if there's been a disconnect in between these two readings
    static let minimiumTimeBetweenTwoReadingsInMinutes = 4.75
}
