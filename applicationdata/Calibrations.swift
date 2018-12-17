import Foundation

class Calibrations {
    
    //don't know yet how many calibrations will be stored here
    //the last element is the youngest, meaning small to large
    static private var calibrations:Array<Calibration> = []
    
    private init() {}
    
    /// Returns calibrations for which, sensorConfidence != 0, slopeConfidence != 0,
    /// sensor == active sensor,
    /// timestamp within last days days
    /// - parameters:
    ///     - inLastDays : calibrations with timestamp in last days
    ///     - withActivesensor
    /// - returns:
    ///     - array of calibrations, can have size 0 if there's no calibration matching
    ///     - ordered by timestamp, large to small (descending) ie the last is the youngest
    public static func allForSensor(inLastDays lastdays:Int, withActivesensor sensor:Sensor) -> Array<Calibration> {
        
        let fourdaysago = Date.nowInMilliSecondsAsDouble() - (Double)(lastdays * 24 * 3600 * 1000)
        
        var returnValue:Array<Calibration> = []
        
        loop: for calibration in calibrations.reversed() {
            if calibration.timeStamp.toMillisecondsAsDouble() > fourdaysago {
                if calibration.sensor.id == sensor.id
                    &&
                    calibration.sensorConfidence != 0
                    &&
                    calibration.slopeConfidence != 0
                {
                    returnValue.insert(calibration, at: 0)
                }
            } else {
                break loop
            }
        }
        return returnValue
    }

    /// get first calibration (ie oldest) for currently active sensor and with sensorconfidence and slopeconfidence != 0
    /// - parameters:
    ///     - withActivesensor : should be currently active sensor
    /// - returns:
    ///     - the first, can be nil
    public static func firstCalibrationForActiveSensor(withActivesensor sensor:Sensor) -> Calibration? {
        
        loop: for calibration in calibrations {
            if calibration.sensor.id == sensor.id
                &&
                calibration.sensorConfidence != 0
                &&
                calibration.slopeConfidence != 0
            {
                return calibration
            }
        }
        return nil
    }

    /// get last calibration (ie youngest) for currently active sensor and with sensorconfidence and slopeconfidence != 0
    /// - parameters:
    ///     - withActivesensor : should be currently active sensor
    /// - returns:
    ///     - the first, can be nil
    public static func lastCalibrationForActiveSensor(withActivesensor sensor:Sensor) -> Calibration? {
        
        loop: for calibration in calibrations.reversed() {
            if calibration.sensor.id == sensor.id
                &&
                calibration.sensorConfidence != 0
                &&
                calibration.slopeConfidence != 0
            {
                return calibration
            }
        }
        return nil
    }
}
