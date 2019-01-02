import Foundation

/// raw glucose as received from transmitter
struct RawGlucoseData {
    var timeStamp:Date
    var glucoseLevelRaw:Int
    
    init(timeStamp:Date, glucoseLevelRaw:Int) {
        self.timeStamp = timeStamp
        self.glucoseLevelRaw = glucoseLevelRaw
    }}
