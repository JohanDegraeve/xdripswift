import Foundation
import os
import AVFoundation

class LoopFollowManager: NSObject {
    
    // MARK: - private properties
    
    /// for logging
    private var log = OSLog(subsystem: ConstantsLog.subSystem, category: ConstantsLog.categoryLoopFollowManager)
    
    /// delegate to pass back glucosedata
    private(set) weak var followerDelegate:FollowerDelegate?
    
    // MARK: - initializer
        
    /// initializer
    public init(coreDataManager: CoreDataManager, followerDelegate: FollowerDelegate) {
        
        // initialize non optional private properties
        self.followerDelegate  = followerDelegate
        
        // call super.init
        super.init()
    }
    
    // MARK: - public functions
    
    /// get reading from shared user defaults
    public func getReading() {
        
        // check that app is in follower mode
        guard !UserDefaults.standard.isMaster else {return}
        
        // use the app group suite name that is chosen in the settings (i.e. Loop/iAPS or Trio)
        guard let sharedUserDefaults = UserDefaults(suiteName: UserDefaults.standard.loopShareType.sharedUserDefaultsSuiteName) else {return}
        
        guard let encodedLatestReadings = sharedUserDefaults.data(forKey: "latestReadingsFromLoop") else {return}

        let decodedLatestReadings = try? JSONSerialization.jsonObject(with: encodedLatestReadings, options: [])
        
        guard let latestReadings = decodedLatestReadings as? Array<AnyObject> else {return}
        
        var followGlucoseDataArray = [FollowerBgReading]()
        
        for reading in latestReadings {
            
            guard let date = reading["date"] as? Double, let sgv = reading["sgv"] as? Double else {return}
            
            followGlucoseDataArray.append(FollowerBgReading(timeStamp: Date(timeIntervalSince1970: date/1000), sgv: sgv))
            
        }

        self.followerDelegate?.followerInfoReceived(followGlucoseDataArray: &followGlucoseDataArray)

    }

}
