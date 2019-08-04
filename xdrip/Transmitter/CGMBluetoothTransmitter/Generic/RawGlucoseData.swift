import Foundation

/// raw glucose as received from transmitter
public struct RawGlucoseData {
    //TODO: move this class to other location ?
    var timeStamp:Date
    var glucoseLevelRaw:Double
    var glucoseLevelFiltered:Double
    var unsmoothedGlucose: Double
    
    init(timeStamp:Date, glucoseLevelRaw:Double, glucoseLevelFiltered:Double, unsmoothedGlucose: Double = 0.0) {
        self.timeStamp = timeStamp
        self.glucoseLevelRaw = glucoseLevelRaw
        self.glucoseLevelFiltered = glucoseLevelFiltered
        self.unsmoothedGlucose = unsmoothedGlucose
    }

    init(timeStamp:Date, glucoseLevelRaw:Double) {
        self.init(timeStamp: timeStamp, glucoseLevelRaw: glucoseLevelRaw, glucoseLevelFiltered: glucoseLevelRaw)
    }
    
    init(timeStamp:Date, unsmoothedGlucose: Double) {
        self.init(timeStamp: timeStamp, glucoseLevelRaw: 0.0, glucoseLevelFiltered: 0.0, unsmoothedGlucose: unsmoothedGlucose)
    }
}

