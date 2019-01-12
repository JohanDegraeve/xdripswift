import Foundation
import CoreData


public class Calibration: NSManagedObject {
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
        
        checkIn = false
        estimateBgAtTimeOfCalibration = 0
        firstDecay = 0
        firstIntercept = 0
        firstScale = 0
        firstSlope = 0
        possibleBad = false
        secondDecay = 0
        secondIntercept = 0
        secondScale = 0
        secondSlope = 0
        id = UniqueId.createEventId()
    }
    
    var sensorAgeAtTimeOfEstimation:Double {
        get {
            return timeStamp.toMillisecondsAsDouble() - sensor.startDate.toMillisecondsAsDouble()
        }
    }
    
    private override init(entity: NSEntityDescription, insertInto context: NSManagedObjectContext?) {
        super.init(entity: entity, insertInto: context)
    }

    /// for logging only
    public func log(_ indentation:String) -> String {
        var r:String = "calibration = "
        r += "\n" + indentation + "uniqueid = " + id
        r += "\n" + indentation + "adjustedRawValue = " + adjustedRawValue.description
        r += "\n" + indentation + "bg = " + bg.description
        r += "\n" + indentation + "checkIn = " + checkIn.description
        r += "\n" + indentation + "distanceFromEstimate = " + distanceFromEstimate.description
        r += "\n" + indentation + "estimateBgAtTimeOfCalibration = " + estimateBgAtTimeOfCalibration.description
        r += "\n" + indentation + "estimateRawAtTimeOfCalibration = " + estimateRawAtTimeOfCalibration.description
        r += "\n" + indentation + "firstDecay = " + firstDecay.description
        r += "\n" + indentation + "firstIntercept = " + firstIntercept.description
        r += "\n" + indentation + "firstScale = " + firstScale.description
        r += "\n" + indentation + "firstSlope = " + firstSlope.description
        r += "\n" + indentation + "intercept = " + intercept.description
        r += "\n" + indentation + "possibleBad = " + possibleBad.description
        if let rawTimeStamp = rawTimeStamp {
            r += "\n" + indentation + "rawTimestamp = " + rawTimeStamp.description
        }
        r += "\n" + indentation + "rawValue = " + rawValue.description
        r += "\n" + indentation + "secondDecay = " + secondDecay.description
        r += "\n" + indentation + "secondIntercept = " + secondIntercept.description
        r += "\n" + indentation + "secondScale = " + secondScale.description
        r += "\n" + indentation + "secondSlope = " + secondSlope.description
        r += "\n" + indentation + "sensor = " + sensor.log(indentation: "         ")
        r += "\n" + indentation + "sensorAgeAtTimeOfEstimation = " + sensorAgeAtTimeOfEstimation.description
        r += "\n" + indentation + "sensorConfidence = " + sensorConfidence.description
        r += "\n" + indentation + "slope = " + slope.description
        r += "\n" + indentation + "slopeConfidence = " + slopeConfidence.description
        r += "\n" + indentation + "timestamp = " + timeStamp.description + "\n"
        return r
    }

}
