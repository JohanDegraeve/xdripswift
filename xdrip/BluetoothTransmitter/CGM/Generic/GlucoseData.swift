import Foundation

/// glucose,
public class GlucoseData {
    
    var timeStamp:Date

    var glucoseLevelRaw:Double

    /// used when needed
    var slopeOrdinal: Int?
    
    /// used when needed
    var slopeName: String?
    
    init(timeStamp:Date, glucoseLevelRaw:Double) {
        
        self.timeStamp = timeStamp
        
        self.glucoseLevelRaw = glucoseLevelRaw
        
    }
    
    init(timeStamp:Date, glucoseLevelRaw:Double, slopeOrdinal: Int, slopeName: String) {
        
        self.timeStamp = timeStamp
        
        self.glucoseLevelRaw = glucoseLevelRaw
        
        self.slopeOrdinal = slopeOrdinal
        
        self.slopeName = slopeName
        
    }

    var description: String {
        
        return "timeStamp = " + timeStamp.description(with: .current) + ", glucoseLevelRaw = " + glucoseLevelRaw.description
        
    }
    
}

