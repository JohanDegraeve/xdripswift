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
    /// if the server value is error  return true
    var isError: Bool { get }
    /// sensor time
    var sensorTime: Int? { get }
    /// if `false`, it means current 344 bytes can not get the parameters from server
    var canGetParameters: Bool { get }
    /// sensor state
    var sensorState: LibreSensorState { get }
    /// when sensor return error 344 bytes, server will return wrong glucose data
    var valueError: Bool { get }
    /// get glucoses from server data
    func glucoseData(date: Date) ->(LibreRawGlucoseData?, [LibreRawGlucoseData])
}

public class LibreRawGlucoseOOPData: NSObject, Codable, LibreRawGlucoseWeb {
    /// histories by server
    var historicGlucose : [LibreRawGlucoseOOPGlucose]?
    /// current glucose
    var realTimeGlucose : LibreRawGlucoseOOPGlucose?
    /// trend arrow by server
    var trendArrow : String?
    /// sensor message
    var msg: String?
    var errcode: String?
    /// if endTime != 0, the sensor expired
    var endTime: Int?
    
    enum Error: String {
        typealias RawValue = String
        case RESCAN_SENSOR_BAD_CRC // crc failed
        // sensor terminate
        case TERMINATE_SENSOR_NORMAL_TERMINATED_STATE
        case TERMINATE_SENSOR_ERROR_TERMINATED_STATE
        case TERMINATE_SENSOR_CORRUPT_PAYLOAD
        // http request bad arguments
        case FATAL_ERROR_BAD_ARGUMENTS
        // the follow messages is sensor state
        case TYPE_SENSOR_NOT_STARTED
        case TYPE_SENSOR_STARTING
        case TYPE_SENSOR_Expired
        case TYPE_SENSOR_END
        case TYPE_SENSOR_ERROR
        case TYPE_SENSOR_OK
        case TYPE_SENSOR_DETERMINED
    }
    /// if the server value is error  return true
    var isError: Bool {
        if let msg = msg {
            switch Error(rawValue: msg) { // sensor terminate
            case .TERMINATE_SENSOR_CORRUPT_PAYLOAD,
                 .TERMINATE_SENSOR_NORMAL_TERMINATED_STATE,
                 .TERMINATE_SENSOR_ERROR_TERMINATED_STATE:
                return false
            default:
                break
            }
        }
        // if parse the 344 failed, historicGlucose will be nil, return is error
        return historicGlucose?.isEmpty ?? true
    }
    
    /// sensor time
    var sensorTime: Int? {
        // if endTime != 0, the sensor expired
        if let endTime = endTime, endTime != 0 {
            return 24 * 6 * 149
        }
        return realTimeGlucose?.id
    }
    /// if `false`, it means current 344 bytes can not get the parameters from server
    var canGetParameters: Bool {
        if let dataQuality = realTimeGlucose?.dataQuality, let id = realTimeGlucose?.id {
            if dataQuality == 0 && id >= 60 {
                return true
            }
        }
        return false
    }
    
    var sensorState: LibreSensorState {
        /// if sensor time < 60, sensor state is starting
        if let dataQuality = realTimeGlucose?.dataQuality, let id = realTimeGlucose?.id {
            if dataQuality != 0 && id < 60 {
                return LibreSensorState.starting
            }
        }
        
        var state = LibreSensorState.ready
        // parse the sensor state from msg
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
        
        // if endTime != 0, the sensor expired
        if let endTime = endTime, endTime != 0 {
            state = .expired
        }
        return state
    }
    
    /// get glucoses from server data
    /// - Parameter date: timestamp of last reading
    /// - Returns: return current glucose and histories
    func glucoseData(date: Date) ->(LibreRawGlucoseData?, [LibreRawGlucoseData]) {
        if endTime != 0 {
            return (nil, [])
        }
        var current: LibreRawGlucoseData?
        guard let g = realTimeGlucose, g.dataQuality == 0 else { return(nil, []) }
        current = LibreRawGlucoseData.init(timeStamp: date, glucoseLevelRaw: g.value ?? 0)
        var array = [LibreRawGlucoseData]()
        // every 15 minutes apart
        let gap: TimeInterval = 60 * 15
        var date = date
        if var history = historicGlucose {
            if (history.first?.id ?? 0) < (history.last?.id ?? 0) {
                history = history.reversed()
            }
            
            for g in history {
                date = date.addingTimeInterval(-gap)
                // if dataQuality != 0, the value is error
                if g.dataQuality != 0 { continue }
                let glucose = LibreRawGlucoseData.init(timeStamp: date, glucoseLevelRaw: g.value ?? 0)
                array.insert(glucose, at: 0)
            }
        }
        return (current ,array)
    }
    
    /// when sensor return error 344 bytes, server will return wrong glucose data
    var valueError: Bool {
        // sensor time < 60, the sensor is starting
        if let id = realTimeGlucose?.id, id < 60 {
            return false
        }
        
        // current glucose is error, this parse failed, can not be use
        if let g = realTimeGlucose, let value = g.dataQuality {
            return value != 0
        }
        return false
    }
}


/// glucose value
class LibreRawGlucoseOOPGlucose: NSObject, Codable {
    /// if dataQuality != 0, it means the value is error
    let dataQuality : Int?
    /// the value's sensor time
    let id: Int?
    /// glucose value
    let value : Double?
}


public class LibreRawGlucoseOOPA2Data: NSObject, Codable, LibreRawGlucoseWeb {
    var errcode: Int?
    var list: [LibreRawGlucoseOOPA2List]?
    
    /// server parse value
    var content: LibreRawGlucoseOOPA2Cotent? {
        return list?.first?.content
    }
    /// if the server value is error return true
    var isError: Bool {
        if content?.currentBg ?? 0 <= 10 {
            return true
        }
        return list?.first?.content?.historicBg?.isEmpty ?? true
    }
    /// sensor time
    var sensorTime: Int? {
        return content?.currentTime
    }
    /// if `false`, it means current 344 bytes can not get the parameters from server
    var canGetParameters: Bool {
        if let id = content?.currentTime {
            if id >= 60 {
                return true
            }
        }
        return false
    }
    /// sensor state
    var sensorState: LibreSensorState {
        if let id = content?.currentTime {
            if id < 60 { // if sensor time < 60, the sensor is starting
                return LibreSensorState.starting
            } else if id >= 20880 { // if sensor time >= 20880, the sensor expired
                return LibreSensorState.expired
            }
        }
        
        let state = LibreSensorState.ready
        return state
    }
    
    /// get glucoses from server data
    /// - Parameter date: timestamp of last reading
    /// - Returns: return current glucose and histories
    func glucoseData(date: Date) ->(LibreRawGlucoseData?, [LibreRawGlucoseData]) {
        var current: LibreRawGlucoseData?
        guard !isError else { return(nil, []) }
        current = LibreRawGlucoseData.init(timeStamp: date, glucoseLevelRaw: content?.currentBg ?? 0)
        var array = [LibreRawGlucoseData]()
        // every 15 minutes apart
        let gap: TimeInterval = 60 * 15
        var date = date
        if var history = content?.historicBg {
            if (history.first?.time ?? 0) < (history.last?.time ?? 0) {
                history = history.reversed()
            }
            
            for g in history {
                date = date.addingTimeInterval(-gap)
                // if dataQuality != 0, the value is error
                if g.quality != 0 { continue }
                let glucose = LibreRawGlucoseData.init(timeStamp: date, glucoseLevelRaw: g.bg ?? 0)
                array.insert(glucose, at: 0)
            }
        }
        return (current ,array)
    }
    
    /// when sensor return error 344 bytes, server will return wrong glucose data
    var valueError: Bool {
        // sensor time < 60, the sensor is starting
        if let id = content?.currentTime, id < 60 {
            return false
        }
        
        // current glucose is error
        if content?.currentBg ?? 0 <= 10 {
            return true
        }
        return false
    }
}

class LibreRawGlucoseOOPA2List: NSObject, Codable {
    var content: LibreRawGlucoseOOPA2Cotent?
}

class LibreRawGlucoseOOPA2Cotent: NSObject, Codable {
    /// current sensor time
    var currentTime: Int?
    /// histories
    var historicBg: [HistoricGlucoseA2]?
    /// current glucose value
    var currentBg: Double?
}

class HistoricGlucoseA2: NSObject, Codable {
    /// if quality != 0, it means the value is error
    let quality : Int?
    /// the value's sensor time
    let time: Int?
    /// glucose value
    let bg : Double?
}
