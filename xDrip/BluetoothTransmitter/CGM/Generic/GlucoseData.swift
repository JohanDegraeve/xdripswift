import Foundation

/// glucose,
public class GlucoseData {
    
    var timeStamp:Date

    var glucoseLevelRaw:Double

    var backfilledAt: Date?
    // Capture the collection path before batching or phone/Watch delivery can delay it.
    // Backfill may merge with a live value, but does not confirm a second live collector.
    var isHistoricalCollection: Bool
    var valueIsFromWatch = false
    var watchReceivedAt: Date?
    var watchCollectedAt: Date?

    /// used when needed
    var slopeOrdinal: Int?
    
    /// used when needed
    var slopeName: String?
    
    init(timeStamp:Date, glucoseLevelRaw:Double, backfilledAt: Date? = nil) {
        
        self.timeStamp = timeStamp
        
        self.glucoseLevelRaw = glucoseLevelRaw

        self.backfilledAt = backfilledAt
        self.isHistoricalCollection = backfilledAt != nil
        
    }
    
    init(timeStamp:Date, glucoseLevelRaw:Double, backfilledAt: Date? = nil, slopeOrdinal: Int, slopeName: String) {
        
        self.timeStamp = timeStamp
        
        self.glucoseLevelRaw = glucoseLevelRaw

        self.backfilledAt = backfilledAt
        self.isHistoricalCollection = backfilledAt != nil
        
        self.slopeOrdinal = slopeOrdinal
        
        self.slopeName = slopeName
        
    }

    var description: String {
        
        return "timeStamp = " + timeStamp.description(with: .current) + ", glucoseLevelRaw = " + glucoseLevelRaw.description
        
    }
    
}
