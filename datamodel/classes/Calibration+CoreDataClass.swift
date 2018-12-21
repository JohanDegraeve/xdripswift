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
        
        let entity = NSEntityDescription.entity(forEntityName: "BgReading", in: nsManagedObjectContext)!
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

}
