import Foundation

/// extends RawGlucoseData and adds property unsmoothedGlucose, because this is only used for Libre
class LibreRawGlucoseData: GlucoseData {
    
    var unsmoothedGlucose: Double

    init(timeStamp:Date, glucoseLevelRaw:Double, glucoseLevelFiltered:Double, unsmoothedGlucose: Double = 0.0) {
        self.unsmoothedGlucose = unsmoothedGlucose

        super.init(timeStamp: timeStamp, glucoseLevelRaw: glucoseLevelRaw, glucoseLevelFiltered: glucoseLevelFiltered)
    }
    
    convenience init(timeStamp:Date, glucoseLevelRaw:Double) {
        debuglogging("creating LibreRawGlucoseData with timestamp " + timeStamp.description(with: .current) + " and glucoseLevelRaw = " + glucoseLevelRaw.description)
        self.init(timeStamp: timeStamp, glucoseLevelRaw: glucoseLevelRaw, glucoseLevelFiltered: glucoseLevelRaw)
    }
    
    convenience init(timeStamp:Date, unsmoothedGlucose: Double) {
        self.init(timeStamp: timeStamp, glucoseLevelRaw: unsmoothedGlucose, glucoseLevelFiltered: unsmoothedGlucose, unsmoothedGlucose: unsmoothedGlucose)
    }

    /// description
    override var description: String {
        
        return "\nLibreRawGlucoseData\nunsmoothedGlucose = " + unsmoothedGlucose.description + "\n" + "GlucoseData = \n" + super.description
        
    }
    
}
