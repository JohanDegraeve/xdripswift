import Foundation

/// to be implemented for anyone who needs to receive information from a follower manager
protocol NightScoutFollowerDelegate:AnyObject {
    
    /// to pass back follower data
    /// - parameters:
    ///     - followGlucoseDataArray : array of FollowGlucoseData, can be empty array, first entry is the youngest
    func nightScoutFollowerInfoReceived(followGlucoseDataArray:inout [NightScoutBgReading])

}
