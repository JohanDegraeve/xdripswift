import Foundation

protocol LibreRawGlucoseWeb {
    
    /// if the server value is error  return true
    var isError: Bool { get }
    
    /// sensor state
    var sensorState: LibreSensorState { get }
    
    /// - returns:
    ///     - array of libreRawGlucoseData, first is the most recent.
    ///     - sensorState: status of the sensor
    ///     - sensorTimeInMinutes: age of sensor in minutes, optional
    func glucoseData() -> (libreRawGlucoseData:[GlucoseData], sensorState:LibreSensorState, sensorTimeInMinutes:Int?)
    
}

// to implement a var description
extension LibreRawGlucoseWeb {

    var description: String {
        
        var returnValue =  "   isError = " + isError.description + "\n"
        
        returnValue = returnValue + "   sensorState = " + sensorState.description + "\n"
        
        let libreGlucoseData = glucoseData()
        
        returnValue = returnValue + "\nSize of [LibreRawGlucoseData] = " + libreGlucoseData.libreRawGlucoseData.count.description + "\n"
        
        if libreGlucoseData.libreRawGlucoseData.count > 0 {
            returnValue = returnValue + "latest reading = \n"

            returnValue = returnValue + libreGlucoseData.libreRawGlucoseData[0].description + "\n"
            
        }
        
        if let sensorTimeInMinutes = libreGlucoseData.sensorTimeInMinutes {

            returnValue = returnValue + "sensor time in minutes = " + sensorTimeInMinutes.description + "\n"

        } else {

            returnValue = returnValue + "sensor time in minutes is unknown\n"

        }
        
        return returnValue
        
    }
    
}
