import Foundation

/// raw glucose as received from transmitter
//TODO: move this class to other location ?
struct RawGlucoseData {
    var timeStamp:Date
    var glucoseLevelRaw:Double
    var glucoseLevelFiltered:Double
    
    init(timeStamp:Date, glucoseLevelRaw:Double, glucoseLevelFiltered:Double) {
        self.timeStamp = timeStamp
        self.glucoseLevelRaw = glucoseLevelRaw
        self.glucoseLevelFiltered = glucoseLevelFiltered
    }

    init(timeStamp:Date, glucoseLevelRaw:Double) {
        self.init(timeStamp: timeStamp, glucoseLevelRaw: glucoseLevelRaw, glucoseLevelFiltered: glucoseLevelRaw)
    }

}

