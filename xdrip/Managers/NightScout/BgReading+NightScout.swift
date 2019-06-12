import Foundation

extension BgReading {
    /// dictionary representation for upload to NightScout
    public var dictionaryRepresentation: [String: Any] {
        debuglogging("timestamp = " + timeStamp.description(with: .current))
        return  [
            "_id": id,
            "device": deviceName ?? "",
            "date": timeStamp.toMillisecondsAsInt64(),
            "dateString": TimeFormat.timestampNightScoutFormatFromDate(timeStamp),
            "type": "sgv",
            "sgv": Int(calculatedValue.roundToDecimal(0)),
            "direction": slopeName,
            "filtered": round(ageAdjustedFiltered() * 1000),
            "unfiltered": round(ageAdjustedRawValue * 1000),
            "noise": 1,
            "sysTime": TimeFormat.timestampNightScoutFormatFromDate(timeStamp)
        ]
    }
    
    /// slopeName for upload to NightScout
    private var slopeName:String {
        let slope_by_minute:Double = calculatedValueSlope * 60000
        var arrow = "NONE"
        if (slope_by_minute <= (-3.5)) {
            arrow = "DoubleDown"
        } else if (slope_by_minute <= (-2)) {
            arrow = "SingleDown"
        } else if (slope_by_minute <= (-1)) {
            arrow = "FortyFiveDown"
        } else if (slope_by_minute <= (1)) {
            arrow = "Flat"
        } else if (slope_by_minute <= (2)) {
            arrow = "FortyFiveUp"
        } else if (slope_by_minute <= (3.5)) {
            arrow = "SingleUp"
        } else if (slope_by_minute <= (40)) {
            arrow = "DoubleUp"
        }
        
        if(hideSlope) {
            arrow = "NOT COMPUTABLE"
        }
        return arrow
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

