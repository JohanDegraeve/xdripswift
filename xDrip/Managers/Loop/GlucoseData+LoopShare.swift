import Foundation

// will not be used to upload to dexcomshare, but in loopshare
extension GlucoseData {
    
    /// dictionary representation
   public var dictionaryRepresentationForLoopShare: [String: Any] {
    
    // date in same format as Dexcom share, that's how Loop expects it
    let date = "/Date(" + Int64(floor(timeStamp.toMillisecondsAsDouble() / 1000) * 1000).description + ")/"
    
    let newReading: [String : Any] = [
        "Trend" : slopeOrdinal ?? 0,
        "ST" : date,
        "DT" : date,
        "Value" : round(glucoseLevelRaw),
        "direction" : slopeName ?? "NONE"
        ]
    
    return newReading
    
    }
     
}
