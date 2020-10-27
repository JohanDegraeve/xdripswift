import Foundation

/// extends RawGlucoseData and adds property unsmoothedGlucose, because this is only used for Libre
class LibreRawGlucoseData: GlucoseData {
    
    var unsmoothedGlucose: Double

    init(timeStamp:Date, glucoseLevelRaw:Double, unsmoothedGlucose: Double = 0.0) {
        self.unsmoothedGlucose = unsmoothedGlucose

        super.init(timeStamp: timeStamp, glucoseLevelRaw: glucoseLevelRaw)
    }
    
    convenience init(timeStamp:Date, unsmoothedGlucose: Double) {
        self.init(timeStamp: timeStamp, glucoseLevelRaw: unsmoothedGlucose, unsmoothedGlucose: unsmoothedGlucose)
    }

    /// description
    override var description: String {
        
        return "\nLibreRawGlucoseData\nunsmoothedGlucose = " + unsmoothedGlucose.description + "\n" + "GlucoseData = \n" + super.description
        
    }
    
}
