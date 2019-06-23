import Foundation

extension BgReading {
    
    /// dictionary representation for upload to Dexcom Share
   public var dictionaryRepresentationForDexcomShareUpload: [String: Any] {
    
    // date as expected by Dexcom Share
    let date = "/Date(" + Int64(floor(timeStamp.toMillisecondsAsDouble() / 1000) * 1000).description + ")/"
    
    let newReading: [String : Any] = [
        "Trend" : slopeOrdinal(),
        "ST" : date,
        "DT" : date,
        "Value" : round(calculatedValue),
        "direction" : slopeName
        ]
    
    return newReading
    
    }
     
}
