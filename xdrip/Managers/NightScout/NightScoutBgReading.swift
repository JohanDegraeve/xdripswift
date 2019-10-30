import Foundation

/// structure for bg reading data downloaded from NightScout
struct NightScoutBgReading {
    
    var timeStamp:Date
    var sgv:Double
    
    init(timeStamp:Date, sgv:Double) {

        self.timeStamp = timeStamp
        self.sgv = sgv
        
    }
    
    /// creates an instance with parameter a json array as received from NightScout
    init?(json:[String:Any]) {
        
        guard let sgv = json["sgv"] as? Double, let date = json["date"] as? Double else {return nil}
        
        self.sgv = sgv
        self.timeStamp = Date(timeIntervalSince1970: date/1000)
        
    }

}
