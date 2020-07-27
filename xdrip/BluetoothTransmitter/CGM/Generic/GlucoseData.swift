import Foundation

/// glucose,
public class GlucoseData {
    
    // TODO: is there ever a difference between raw and filtered ? why not remove one ?
    
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

    var description: String {
        
        return "timeStamp = " + timeStamp.description(with: .current) + ", glucoseLevelRaw = " + glucoseLevelRaw.description + ", glucoseLevelFiltered = " + glucoseLevelFiltered.description
        
    }
    
}

