import Foundation

/// raw glucose as received from transmitter
public class RawGlucoseData {
    
    var timeStamp:Date
    var glucoseLevelRaw:Double
    var glucoseLevelFiltered:Double
    
    init(timeStamp:Date, glucoseLevelRaw:Double, glucoseLevelFiltered:Double) {
        self.timeStamp = timeStamp
        self.glucoseLevelRaw = glucoseLevelRaw
        self.glucoseLevelFiltered = glucoseLevelFiltered
    }

    convenience init(timeStamp:Date, glucoseLevelRaw:Double) {
        self.init(timeStamp: timeStamp, glucoseLevelRaw: glucoseLevelRaw, glucoseLevelFiltered: glucoseLevelRaw)
    }
    
    convenience init(timeStamp:Date) {
        self.init(timeStamp: timeStamp, glucoseLevelRaw: 0.0, glucoseLevelFiltered: 0.0)
    }
}

