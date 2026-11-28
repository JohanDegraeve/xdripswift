import Foundation

extension BgReading {
    
    /// dictionary representation for upload to Dexcom Share
   public func dictionaryRepresentationForDexcomShareUpload(trend: Int, direction: String) -> [String: Any] {
    
    // date as expected by Dexcom Share
    let date = "/Date(" + Int64(floor(timeStamp.toMillisecondsAsDouble() / 1000) * 1000).description + ")/"
    
    let newReading: [String : Any] = [
        "Trend" : trend,
        "ST" : date,
        "DT" : date,
        "Value" : round(historicalValue),
        "direction" : direction
        ]
    
    return newReading
    
    }
     
}
