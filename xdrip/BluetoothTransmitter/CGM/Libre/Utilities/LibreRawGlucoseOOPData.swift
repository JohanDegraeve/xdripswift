// https://github.com/JohanDegraeve/xdripswift/blob/bd5b3060f3a7d4c68dce767b5c86306239d06d14/xdrip/BluetoothTransmitter/CGM/Libre/Utilities/LibreRawGlucoseData.swift#L208

import Foundation

public class LibreRawGlucoseOOPData: NSObject, LibreRawGlucoseWeb, LibreOOPWebServerResponseData {
    
    /// histories by server
    var historicGlucose : [LibreRawGlucoseOOPGlucose]?
    
    /// current glucose
    var realTimeGlucose : LibreRawGlucoseOOPGlucose?
    
    /// trend arrow by server
    var trendArrow : String?
    
    /// sensor message
    var msg: String?
    
    var errcode: Int?
    
    /// if endTime != 0, the sensor expired
    var endTime: Int?
    
    /// - time when instance of LibreRawGlucoseOOPData was created
    /// - this can be created to calculate the timestamp of realTimeGlucose
    let creationTimeStamp = Date()
    
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
    
    func glucoseData(timeStampLastBgReading: Date?) -> (libreRawGlucoseData:[LibreRawGlucoseData], sensorState:LibreSensorState, sensorTimeInMinutes:Int?) {

        // initialize returnvalue, empty glucoseData array, sensorState, and nil as sensorTimeInMinutes
        var returnValue: ([LibreRawGlucoseData], LibreSensorState, Int?) = ([LibreRawGlucoseData](), sensorState, nil)

        // if isError function returns true, then return empty array
        guard !isError else { return returnValue }

        // if sensorState is not .ready, then return empty array
        if sensorState != .ready { return returnValue  }

        // realTimeGlucose must be non-nil and realTimeGlucose.dataQuality must be 0, id (sensor time) must be non nil, otherwise return empty array
        guard let realTimeGlucose = realTimeGlucose, realTimeGlucose.dataQuality == 0, let value = realTimeGlucose.value, let sensorTimeInMinutes = realTimeGlucose.id else { return returnValue }
        
        // set senorTimeInMinutes in returnValue
        returnValue.2 = sensorTimeInMinutes
        
        // get realtimeLibreRawGlucoseData which is the first element to add, with timestamp the time this instance of LibreRawGlucoseOOPData was created
        let realtimeLibreRawGlucoseData = LibreRawGlucoseData(timeStamp: creationTimeStamp, glucoseLevelRaw: value)
        
        // add first element to returnValue
        returnValue.0.append(realtimeLibreRawGlucoseData)

        // if historicGlucose is nil then return currentLibreRawGlucoseData and an empty array
        guard var history = historicGlucose else {return returnValue}

        // check the order, first should be the highest value, time is sensor time in minutes, means first should be the most recent or the highest sensor time
        // if not, reverse it
        if (history.first?.id ?? 0) < (history.last?.id ?? 0) {
            history = history.reversed()
        }

        // go through history
        for realTimeGlucose in history {
            
            // if dataQuality != 0, the value is error, don't add it
            if realTimeGlucose.dataQuality != 0 { continue }
            
            // if id is nil, (which is sensorTimeInMinutes at the moment this reading was created), then we can't calculate the timestamp, don't add it
            if realTimeGlucose.id == nil {continue}
            

            // create timestamp of the reading
            let readingTimeStamp = creationTimeStamp.addingTimeInterval(-60 * Double(sensorTimeInMinutes - realTimeGlucose.id!))
            

            // only add the new reading if at least 30 seconds older than timeStampLastBgReading (if not nil) - when nil then 0.0 is used, readingTimeStamp will never be < 0.0
            // as soon as a reading is found which is too old to process then break the loop
            if readingTimeStamp.toMillisecondsAsDouble() < (timeStampLastBgReading != nil ? (timeStampLastBgReading!.toMillisecondsAsDouble() + 30000) : 0.0) {break}
            
            //  only add readings that are at least 5 minutes away from each other, same approach as in LibreDataParser.parse
            if let lastElement = returnValue.0.last {
                if lastElement.timeStamp.toMillisecondsAsDouble() - readingTimeStamp.toMillisecondsAsDouble() < (5 * 60 * 1000 - 10000) {continue}
            }

            // realTimeGlucose.value should be non nil and not 0
            if realTimeGlucose.value == nil {continue}
            if realTimeGlucose.value! == 0.0 {continue}
            
            let libreRawGlucoseData = LibreRawGlucoseData(timeStamp: readingTimeStamp, glucoseLevelRaw: realTimeGlucose.value!)
            
            returnValue.0.append(libreRawGlucoseData)
            
        }

        return (returnValue)
        
    }
    
    public override var description: String {
        
        var returnValue = "LibreRawGlucoseWeb =\n"
        
        // a description created by LibreRawGlucoseWeb
        returnValue = returnValue + (self as LibreRawGlucoseWeb).description
        
        if let errcode = errcode {
            returnValue = returnValue + "   errcode = " + errcode.description + "\n"
        }
        
        return returnValue

    }
    
}

