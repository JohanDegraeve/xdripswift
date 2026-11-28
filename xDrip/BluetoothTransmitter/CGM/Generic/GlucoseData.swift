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
    var watchNightscoutOwned = false
    var watchDexcomShareOwned = false

    init(timeStamp:Date, glucoseLevelRaw:Double, backfilledAt: Date? = nil) {
        
        self.timeStamp = timeStamp
        
        self.glucoseLevelRaw = glucoseLevelRaw

        self.backfilledAt = backfilledAt
        self.isHistoricalCollection = backfilledAt != nil
        
    }
    
    var description: String {
        
        return "timeStamp = " + timeStamp.description(with: .current) + ", glucoseLevelRaw = " + glucoseLevelRaw.description
        
    }
    
}
