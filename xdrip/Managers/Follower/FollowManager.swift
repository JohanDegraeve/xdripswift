import Foundation

/// instance of this class will do the follower functionality. Just make an instance, it will listen to the settings, do the regular download if needed - it could be deallocated when isMaster setting in Userdefaults changes, but that's not necessary to do
class FollowManager {
    
    // MARK: - public properties
    
    // MARK: - private properties
    
    // when to do next download
    private var nextFollowDownloadTimeStamp:Date
    
    // reference to coredatamanager
    private var coreDataManager:CoreDataManager
    
    // reference to BgReadingsAccessor
    private var bgReadingsAccessor:BgReadingsAccessor
    
    // MARK: - initializer
    
    /// init is private, to avoid creation
    private init(coreDataManager:CoreDataManager) {
        
        // initialize nextFollowDownloadTimeStamp to now, which is at moment FollowManager is instantiated
        nextFollowDownloadTimeStamp = Date()
        
        // initial non optional private properties
        self.coreDataManager = coreDataManager
        self.bgReadingsAccessor = BgReadingsAccessor(coreDataManager: coreDataManager)
    }
    
    // MARK: - private functions
    
    private func download() {
        
        // maximum timeStamp to download initially set to 1 day back
        var timeStampOfFirstBgReadingToDowload = Date(timeIntervalSinceNow: TimeInterval(-Constants.Follower.maxiumDaysOfReadingsToDownload * 24 * 3600))
        
        // check timestamp of lastest stored bgreading with calculated value, if more recent then use this as timestamp
        let latestBgReadings = bgReadingsAccessor.getLatestBgReadings(limit: nil, howOld: 1, forSensor: nil, ignoreRawData: true, ignoreCalculatedValue: false)
        if latestBgReadings.count > 0 {
            timeStampOfFirstBgReadingToDowload = max(latestBgReadings[0].timeStamp, timeStampOfFirstBgReadingToDowload)
        }
        
        // calculate count, which is a parameter in the nightscout api - divide by 60, worst case NightScout has a reading every minute, this can be the case for MiaoMiao
        let count = -timeStampOfFirstBgReadingToDowload.timeIntervalSinceNow / 60 + 1
        
        
    }
}
