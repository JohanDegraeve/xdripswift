import Foundation

/// raw glucose as received from transmitter
struct RawGlucoseData {
    var timeStamp:Date
    var glucoseLevelRaw:Double
    
    init(timeStamp:Date, glucoseLevelRaw:Double) {
        self.timeStamp = timeStamp
        self.glucoseLevelRaw = glucoseLevelRaw
    }}
