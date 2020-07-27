import Foundation

protocol LibreRawGlucoseWeb {
    
    /// if the server value is error  return true
    var isError: Bool { get }
    
    /// sensor state
    var sensorState: LibreSensorState { get }
    
    /// - parameters:
    ///     - timeStampLastBgReading: this is of the timestamp of the latest reading we already received during previous session, optional
    /// - returns:
    ///     - array of libreRawGlucoseData, first is the most recent. Only returns recent readings, ie not the ones that are older than timeStampLastBgReading. 30 seconds are added here, meaning, new reading should be at least 30 seconds more recent than timeStampLastBgReading
    ///     - sensorState: status of the sensor
    ///     - sensorTimeInMinutes: age of sensor in minutes, optional
    func glucoseData(timeStampLastBgReading: Date?) -> (libreRawGlucoseData:[LibreRawGlucoseData], sensorState:LibreSensorState, sensorTimeInMinutes:Int?)
    
}

// to implement a var description
extension LibreRawGlucoseWeb {

    var description: String {
        
        var returnValue =  "   isError = " + isError.description + "\n"
        
        returnValue = returnValue + "   sensorState = " + sensorState.description + "\n"
        
        let libreGlucoseData = glucoseData(timeStampLastBgReading: nil)
        
        returnValue = returnValue + "\nSize of [LibreRawGlucoseData] = " + libreGlucoseData.libreRawGlucoseData.count.description + "\n"
        
        if libreGlucoseData.libreRawGlucoseData.count > 0 {
            returnValue = returnValue + "list = \n"
            
            for glucoseData in libreGlucoseData.libreRawGlucoseData {
                returnValue = returnValue + glucoseData.description + "\n"
            }
        }
        
        if let sensorTimeInMinutes = libreGlucoseData.sensorTimeInMinutes {

            returnValue = returnValue + "sensor time in minutes = " + sensorTimeInMinutes.description + "\n"

        } else {

            returnValue = returnValue + "sensor time in minutes is unknown\n"

        }
        
        return returnValue
        
    }
    
}
