import Foundation

extension BgReading {
    
    /// dictionary representation for upload to NightScout
    public var dictionaryRepresentationForNightScoutUpload: [String: Any] {
        
        return  [
            "_id": id,
            "device": deviceName ?? "",
            "date": timeStamp.toMillisecondsAsInt64(),
            "dateString": timeStamp.ISOStringFromDate(),
            "type": "sgv",
            "sgv": Int(calculatedValue.round(toDecimalPlaces: 0)),
            "direction": slopeName,
            "filtered": round(ageAdjustedRawValue * 1000),
            "unfiltered": round(ageAdjustedRawValue * 1000),
            "noise": 1,
            "sysTime": timeStamp.ISOStringFromDate()
        ]
        
    }
    
}

