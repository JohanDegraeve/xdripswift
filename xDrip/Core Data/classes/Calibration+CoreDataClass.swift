import Foundation
import CoreData


public class Calibration: NSManagedObject {
    
    /// creates Calibration with given parameters.
    ///
    /// property possibleBad gets value false. id gets new value
    init(
        timeStamp: Date,
        sensor: Sensor,
        bg: Double,
        rawValue: Double,
        adjustedRawValue: Double,
        sensorConfidence: Double,
        rawTimeStamp: Date,
        slope: Double,
        intercept: Double,
        distanceFromEstimate: Double,
        estimateRawAtTimeOfCalibration: Double,
        slopeConfidence: Double,
        deviceName:String?,
        nsManagedObjectContext:NSManagedObjectContext
        ) {
        
        let entity = NSEntityDescription.entity(forEntityName: "Calibration", in: nsManagedObjectContext)!
        super.init(entity: entity, insertInto: nsManagedObjectContext)
        
        self.timeStamp = timeStamp
        self.sensor = sensor
        self.bg = bg
        self.rawValue = rawValue
        self.adjustedRawValue = adjustedRawValue
        self.sensorConfidence = sensorConfidence
        self.rawTimeStamp = rawTimeStamp
        self.slope = slope
        self.intercept = intercept
        self.distanceFromEstimate = distanceFromEstimate
        self.estimateRawAtTimeOfCalibration = estimateRawAtTimeOfCalibration
        self.slopeConfidence = slopeConfidence
        self.deviceName = deviceName
        
        possibleBad = false
        id = UniqueId.createEventId()
        sentToTransmitter = false
            
    }
    
    var sensorAgeAtTimeOfEstimation:Double {
        get {
            return timeStamp.toMillisecondsAsDouble() - sensor.startDate.toMillisecondsAsDouble()
        }
    }
    
    private override init(entity: NSEntityDescription, insertInto context: NSManagedObjectContext?) {
        super.init(entity: entity, insertInto: context)
    }

    /// log the contents to a string
    public func log(_ indentation:String) -> String {
        var r:String = "calibration = "
        r += "\n" + indentation + "uniqueid = " + id
        r += "\n" + indentation + "adjustedRawValue = " + adjustedRawValue.description
        r += "\n" + indentation + "bg = " + bg.description
        r += "\n" + indentation + "distanceFromEstimate = " + distanceFromEstimate.description
        r += "\n" + indentation + "estimateRawAtTimeOfCalibration = " + estimateRawAtTimeOfCalibration.description
        r += "\n" + indentation + "intercept = " + intercept.description
        r += "\n" + indentation + "possibleBad = " + possibleBad.description
        if let rawTimeStamp = rawTimeStamp {
            r += "\n" + indentation + "rawTimestamp = " + rawTimeStamp.description
        }
        r += "\n" + indentation + "rawValue = " + rawValue.description
        r += "\n" + indentation + "sensor = " + sensor.log(indentation: "         ")
        r += "\n" + indentation + "sensorAgeAtTimeOfEstimation = " + sensorAgeAtTimeOfEstimation.description
        r += "\n" + indentation + "sensorConfidence = " + sensorConfidence.description
        r += "\n" + indentation + "slope = " + slope.description
        r += "\n" + indentation + "slopeConfidence = " + slopeConfidence.description
        r += "\n" + indentation + "timestamp = " + timeStamp.description + "\n"
        r += "\n" + indentation + "sentToTransmitter = " + sentToTransmitter.description + "\n"
        r += "\n" + indentation + "acceptedByTransmitter = " + acceptedByTransmitter.description + "\n"
        return r
    }
}
