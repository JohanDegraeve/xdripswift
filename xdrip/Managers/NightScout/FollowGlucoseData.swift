import Foundation

/// structure for bg reading data downloaded from NightScout
struct FollowGlucoseData {
    //TODO: move this class to other location ?
    var timeStamp:Date
    var unfiltered:Double
    var filtered:Double
    var sgv:Double
    
    init(timeStamp:Date, unfiltered:Double, filtered:Double, sgv:Double) {

        self.timeStamp = timeStamp
        self.unfiltered = unfiltered
        self.filtered = filtered
        self.sgv = sgv
        
    }
    
    /// creates an instance with parameter a json array as received from NightScout
    init?(json:[String:Any]) {
        guard let sgv = json["sgv"] as? Double, let date = json["date"] as? Double, let filtered = json["filtered"] as? Double, let unfiltered = json["unfiltered"] as? Double else {return nil}
        
        self.unfiltered = unfiltered
        self.filtered = filtered
        self.sgv = sgv
        self.timeStamp = Date(timeIntervalSince1970: date/1000)
        
    }

}
