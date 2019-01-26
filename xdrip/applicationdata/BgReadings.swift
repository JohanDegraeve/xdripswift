import Foundation
import CoreData


class BgReadings {
    
    /// the latest 24 hours (or more ?) of readings.
    /// the latest element is the youngest
    static var bgReadings = [BgReading]()

    private init() {
    }
    
    /// Gives readings for which calculatedValue != 0, rawdata != 0, matching sensorid if sensorid not nil,
    ///
    /// - parameters:
    ///     - howMany : maximum amount of readings to return
    ///     - forSensor : if not nil, then only readings for the given sensor will be returned - if nil, then sensor is ignored
    ///     - if ignoreRawData = true, then value of rawdata will be ignored
    ///     - if ignoreCalculatedValue = true, then value of calculatedValue will be ignored
    /// - returns: an array with readings, can be empty array.
    ///     Order by timestamp, descending meaning the reading at index 0 is the youngest
    static func getLatestBgReadings(howMany amount:Int, forSensor sensor:Sensor?, ignoreRawData:Bool, ignoreCalculatedValue:Bool) -> Array<BgReading> {
        
        var returnValue:Array<BgReading> = []
        
        let ignoreSensorId = sensor == nil ? true:false
        
        loop: for (_,bgReading) in bgReadings.enumerated().reversed() {
            //TODO: delete this --- let tocheck:BgReading = bgReading
            //TODO: delete this --- debuglogging(index.description + " calculatedvalue = " + bgReading.calculatedValue.description)
            if ignoreSensorId {
                if (bgReading.calculatedValue != 0.0 || ignoreCalculatedValue) && (bgReading.rawData != 0.0 || ignoreRawData) {
                    returnValue.append(bgReading)
                }
            } else {
                if let readingsensor = bgReading.sensor {
                    if readingsensor.id == sensor!.id {
                        if (bgReading.calculatedValue != 0.0 || ignoreCalculatedValue) && (bgReading.rawData != 0.0 || ignoreRawData) {
                            returnValue.append(bgReading)
                        }
                    }
                }
            }
            if returnValue.count == amount {
                break loop
            }
        }

        return returnValue
    }
    
    static func addBgReading(newReading:BgReading) {
        bgReadings.append(newReading)
    }
}
