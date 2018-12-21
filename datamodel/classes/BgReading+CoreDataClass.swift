import Foundation
import CoreData
import UIKit


public class BgReading: NSManagedObject {
    
    var moc:NSManagedObjectContext!
    
    init(
        timeStamp:Date,
        sensor:Sensor?,
        calibration:Calibration?,
        rawData:Double,
        filteredData:Double,
        nsManagedObjectContext:NSManagedObjectContext
    ) {
        let entity = NSEntityDescription.entity(forEntityName: "BgReading", in: nsManagedObjectContext)!
        super.init(entity: entity, insertInto: nsManagedObjectContext)
        self.timeStamp = timeStamp
        self.sensor = sensor
        self.calibration = calibration
        self.rawData = rawData
        self.filteredData = filteredData
        
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
        rawCalculated  = 0
        hideSlope = false
        id = UniqueId.createEventId()
    }
    
    private override init(entity: NSEntityDescription, insertInto context: NSManagedObjectContext?) {
        super.init(entity: entity, insertInto: context)
    }
    
}
