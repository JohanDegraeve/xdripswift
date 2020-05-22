import Foundation

/// extends RawGlucoseData and adds property unsmoothedGlucose, because this is only used for Libre
class LibreRawGlucoseData: GlucoseData {
    
    var unsmoothedGlucose: Double

    init(timeStamp:Date, glucoseLevelRaw:Double, glucoseLevelFiltered:Double, unsmoothedGlucose: Double = 0.0) {
        self.unsmoothedGlucose = unsmoothedGlucose

        super.init(timeStamp: timeStamp, glucoseLevelRaw: glucoseLevelRaw, glucoseLevelFiltered: glucoseLevelFiltered)
    }
    
    convenience init(timeStamp:Date, glucoseLevelRaw:Double) {
        self.init(timeStamp: timeStamp, glucoseLevelRaw: glucoseLevelRaw, glucoseLevelFiltered: glucoseLevelRaw)
    }
    
    convenience init(timeStamp:Date, unsmoothedGlucose: Double) {
        self.init(timeStamp: timeStamp, glucoseLevelRaw: unsmoothedGlucose, glucoseLevelFiltered: unsmoothedGlucose, unsmoothedGlucose: unsmoothedGlucose)
    }

}

protocol LibreRawGlucoseWeb {
    var isError: Bool { get }
    var sensorTime: Int? { get }
    var canGetParameters: Bool { get }
    var sensorState: LibreSensorState { get }
    var valueError: Bool { get }
    func glucoseData(date: Date) ->(LibreRawGlucoseData?, [LibreRawGlucoseData])
}

public class LibreRawGlucoseOOPData: NSObject, Codable, LibreRawGlucoseWeb {
    var alarm : String?
    var esaMinutesToWait : Int?
    var historicGlucose : [HistoricGlucose]?
    var isActionable : Bool?
    var lsaDetected : Bool?
    var realTimeGlucose : HistoricGlucose?
    var trendArrow : String?
    var msg: String?
    var errcode: String?
    var endTime: Int?
    
    enum Error: String {
        typealias RawValue = String
        case RESULT_SENSOR_STORAGE_STATE
        case RESCAN_SENSOR_BAD_CRC
        case TERMINATE_SENSOR_NORMAL_TERMINATED_STATE
        case TERMINATE_SENSOR_ERROR_TERMINATED_STATE
        case TERMINATE_SENSOR_CORRUPT_PAYLOAD
        case FATAL_ERROR_BAD_ARGUMENTS
        case TYPE_SENSOR_NOT_STARTED
        case TYPE_SENSOR_STARTING
        case TYPE_SENSOR_Expired
        case TYPE_SENSOR_END
        case TYPE_SENSOR_ERROR
        case TYPE_SENSOR_OK
        case TYPE_SENSOR_DETERMINED
    }
    
    var isError: Bool {
        if let msg = msg {
            switch Error(rawValue: msg) {
            case .TERMINATE_SENSOR_CORRUPT_PAYLOAD,
                 .TERMINATE_SENSOR_NORMAL_TERMINATED_STATE,
                 .TERMINATE_SENSOR_ERROR_TERMINATED_STATE:
                return false
            default:
                break
            }
        }
        return historicGlucose?.isEmpty ?? true
    }
    
    var sensorTime: Int? {
        if let endTime = endTime, endTime != 0 {
            return 24 * 6 * 149
        }
        return realTimeGlucose?.id
    }
    
    var canGetParameters: Bool {
        if let dataQuality = realTimeGlucose?.dataQuality, let id = realTimeGlucose?.id {
            if dataQuality == 0 && id >= 60 {
                return true
            }
        }
        return false
    }
    
    var sensorState: LibreSensorState {
        if let dataQuality = realTimeGlucose?.dataQuality, let id = realTimeGlucose?.id {
            if dataQuality != 0 && id < 60 {
                return LibreSensorState.starting
            }
        }
        
        var state = LibreSensorState.ready
        if let msg = msg {
            switch Error(rawValue: msg) {
            case .TYPE_SENSOR_NOT_STARTED:
                state = .notYetStarted
                break;
            case .TYPE_SENSOR_STARTING:
                state = .starting
                break;
            case .TYPE_SENSOR_Expired,
                 .TERMINATE_SENSOR_CORRUPT_PAYLOAD,
                 .TERMINATE_SENSOR_NORMAL_TERMINATED_STATE,
                 .TERMINATE_SENSOR_ERROR_TERMINATED_STATE:
                state = .expired
                break;
            case .TYPE_SENSOR_END:
                state = .expired
                break;
            case .TYPE_SENSOR_ERROR:
                state = .failure
                break;
            case .TYPE_SENSOR_OK:
                state = .ready
            case .TYPE_SENSOR_DETERMINED:
                state = .unknown
                break
            default:
                break;
            }
        }
        if let endTime = endTime, endTime != 0 {
            state = .expired
        }
        return state
    }
    
    func glucoseData(date: Date) ->(LibreRawGlucoseData?, [LibreRawGlucoseData]) {
        if endTime != 0 {
            return (nil, [])
        }
        var current: LibreRawGlucoseData?
        guard let g = realTimeGlucose, g.dataQuality == 0 else { return(nil, []) }
        current = LibreRawGlucoseData.init(timeStamp: date, glucoseLevelRaw: g.value ?? 0)
        var array = [LibreRawGlucoseData]()
        let gap: TimeInterval = 60 * 15
        var date = date
        if var history = historicGlucose {
            if (history.first?.id ?? 0) < (history.last?.id ?? 0) {
                history = history.reversed()
            }
            
            for g in history {
                date = date.addingTimeInterval(-gap)
                if g.dataQuality != 0 { continue }
                let glucose = LibreRawGlucoseData.init(timeStamp: date, glucoseLevelRaw: g.value ?? 0)
                array.insert(glucose, at: 0)
            }
        }
        return (current ,array)
    }
    
    var valueError: Bool {
        if let id = realTimeGlucose?.id, id < 60 {
            return false
        }
        
        if let g = realTimeGlucose, let value = g.dataQuality {
            return value != 0
        }
        return false
    }
}

class HistoricGlucose: NSObject, Codable {
    let dataQuality : Int?
    let id: Int?
    let value : Double?
}


public class LibreRawGlucoseOOPA2Data: NSObject, Codable, LibreRawGlucoseWeb {
    var errcode: Int?
    var list: [LibreRawGlucoseOOPA2List]?
    
    var content: LibreRawGlucoseOOPA2Cotent? {
        return list?.first?.content
    }
    
    var isError: Bool {
        if content?.currentBg ?? 0 <= 10 {
            return true
        }
        return list?.first?.content?.historicBg?.isEmpty ?? true
    }
    
    var sensorTime: Int? {
        return content?.currentTime
    }
    
    var canGetParameters: Bool {
        if let id = content?.currentTime {
            if id >= 60 {
                return true
            }
        }
        return false
    }
    
    var sensorState: LibreSensorState {
        if let id = content?.currentTime {
            if id < 60 {
                return LibreSensorState.starting
            } else if id >= 20880 {
                return LibreSensorState.expired
            }
        }
        
        let state = LibreSensorState.ready
        return state
    }
    
    func glucoseData(date: Date) ->(LibreRawGlucoseData?, [LibreRawGlucoseData]) {
        var current: LibreRawGlucoseData?
        guard !isError else { return(nil, []) }
        current = LibreRawGlucoseData.init(timeStamp: date, glucoseLevelRaw: content?.currentBg ?? 0)
        var array = [LibreRawGlucoseData]()
        let gap: TimeInterval = 60 * 15
        var date = date
        if var history = content?.historicBg {
            if (history.first?.time ?? 0) < (history.last?.time ?? 0) {
                history = history.reversed()
            }
            
            for g in history {
                date = date.addingTimeInterval(-gap)
                if g.quality != 0 { continue }
                let glucose = LibreRawGlucoseData.init(timeStamp: date, glucoseLevelRaw: g.bg ?? 0)
                array.insert(glucose, at: 0)
            }
        }
        return (current ,array)
    }
    
    var valueError: Bool {
        if let id = content?.currentTime, id < 60 {
            return false
        }
        
        if content?.currentBg ?? 0 <= 10 {
            return true
        }
        return false
    }
}

class LibreRawGlucoseOOPA2List: NSObject, Codable {
    var content: LibreRawGlucoseOOPA2Cotent?
    var timestamp: Int?
}

class LibreRawGlucoseOOPA2Cotent: NSObject, Codable {
    var currentTime: Int?
    var currenTrend: Int?
    var serialNumber: String?
    var historicBg: [HistoricGlucoseA2]?
    var currentBg: Double?
    var timestamp: Int?
}

class HistoricGlucoseA2: NSObject, Codable {
    let quality : Int?
    let time: Int?
    let bg : Double?
}
