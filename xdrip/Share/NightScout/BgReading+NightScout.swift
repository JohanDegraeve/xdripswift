import Foundation

extension BgReading {
    public var dictionaryRepresentation: [String: Any] {
        var representation: [String: Any] = [
            "device": device,
            "date": timestamp.timeIntervalSince1970 * 1000,
            "dateString": TimeFormat.timestampStrFromDate(timestamp)
        ]
        
        switch glucoseType {
        case .Meter:
            representation["type"] = "mbg"
            representation["mbg"] = glucose
        case .Sensor:
            representation["type"] = "sgv"
            representation["sgv"] = glucose
        }
        
        if let direction = direction {
            representation["direction"] = direction
        }
        
        if let previousSGV = previousSGV {
            representation["previousSGV"] = previousSGV
        }
        
        if let previousSGVNotActive = previousSGVNotActive {
            representation["previousSGVNotActive"] = previousSGVNotActive
        }
        
        return representation
    }
}
