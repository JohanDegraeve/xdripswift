import Foundation

/// raw glucose as received from transmitter
//TODO: move this class to other location ?
struct RawGlucoseData {
    var timeStamp:Date
    var glucoseLevelRaw:Double
    
    init(timeStamp:Date, glucoseLevelRaw:Double) {
        self.timeStamp = timeStamp
        self.glucoseLevelRaw = glucoseLevelRaw
    }}
