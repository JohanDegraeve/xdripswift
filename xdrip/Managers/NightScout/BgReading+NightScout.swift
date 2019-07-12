import Foundation

extension BgReading {
    
    /// dictionary representation for upload to NightScout
    public var dictionaryRepresentationForNightScoutUpload: [String: Any] {
        
        return  [
            "_id": id,
            "device": deviceName ?? "",
            "date": timeStamp.toMillisecondsAsInt64(),
            "dateString": timeStamp.toNightScoutFormat(),
            "type": "sgv",
            "sgv": Int(calculatedValue.roundToDecimal(0)),
            "direction": slopeName,
            "filtered": round(ageAdjustedFiltered() * 1000),
            "unfiltered": round(ageAdjustedRawValue * 1000),
            "noise": 1,
            "sysTime": timeStamp.toNightScoutFormat()
        ]
        
    }

    /// same function as defined in Calibrator
    private func ageAdjustedFiltered() -> Double {
        let usedRaw = ageAdjustedRawValue
        
        if(usedRaw == rawData || rawData == 0) {
            return filteredData
        } else {
            // adjust the filtereddata the same factor as the age adjusted raw value
            return filteredData * usedRaw / rawData;
        }
    }
    
}

