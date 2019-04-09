import Foundation
import CoreData
import UIKit

public class BgReading: NSManagedObject {
    
    init(
        timeStamp:Date,
        sensor:Sensor?,
        calibration:Calibration?,
        rawData:Double,
        filteredData:Double,
        deviceName:String?,
        nsManagedObjectContext:NSManagedObjectContext
    ) {
        let entity = NSEntityDescription.entity(forEntityName: "BgReading", in: nsManagedObjectContext)!
        super.init(entity: entity, insertInto: nsManagedObjectContext)
        self.timeStamp = timeStamp
        self.sensor = sensor
        self.calibration = calibration
        self.rawData = rawData
        self.filteredData = filteredData
        self.deviceName = deviceName
        
        ageAdjustedRawValue = 0
        calibrationFlag = false
        calculatedValue = 0
        filteredCalculatedValue = 0
        calculatedValueSlope = 0
        a = 0
        b = 0
        c = 0
        ra = 0
        rb = 0
        rc = 0
        hideSlope = false
        id = UniqueId.createEventId()
    }
    
    private override init(entity: NSEntityDescription, insertInto context: NSManagedObjectContext?) {
        super.init(entity: entity, insertInto: context)
    }
    
    /// log the contents to a string
    public func log(_ indentation:String) -> String {
        var r:String = "bgreading = "
        r += "\n" + indentation + "timestamp = " + timeStamp.description + "\n"
        r += "\n" + indentation + "uniqueid = " + id
        r += "\n" + indentation + "a = " + a.description
        r += "\n" + indentation + "ageAdjustedRawValue = " + ageAdjustedRawValue.description
        r += "\n" + indentation + "b = " + b.description
        r += "\n" + indentation + "c = " + c.description
        r += "\n" + indentation + "calculatedValue = " + calculatedValue.description
        r += "\n" + indentation + "calculatedValueSlope = " + calculatedValueSlope.description
        if let calibration = calibration {
            r += "\n" + indentation + "calibration = " + calibration.log("      ")
        }
        r += "\n" + indentation + "calibrationFlag = " + calibrationFlag.description
        r += "\n" + indentation + "filteredCalculatedValue = " + filteredCalculatedValue.description
        r += "\n" + indentation + "filteredData = " + filteredData.description
        r += "\n" + indentation + "hideSlope = " + hideSlope.description
        r += "\n" + indentation + "ra = " + ra.description
        r += "\n" + indentation + "rawData = " + rawData.description
        r += "\n" + indentation + "rb = " + rb.description
        r += "\n" + indentation + "rc = " + rc.description
        if let sensor = sensor {
            r += "\n" + indentation + "sensor = " + sensor.log(indentation: "      ")
        }
        return r
    }
}
