import Foundation
import CoreData


public class Sensor: NSManagedObject {

    init(startDate:Date, nsManagedObjectContext:NSManagedObjectContext) {
        let entity = NSEntityDescription.entity(forEntityName: "Sensor", in: nsManagedObjectContext)!
        
        super.init(entity: entity, insertInto: nsManagedObjectContext)

        self.startDate = startDate
        id = UniqueId.createEventId()
    }
    
    private override init(entity: NSEntityDescription, insertInto context: NSManagedObjectContext?) {
        super.init(entity: entity, insertInto: context)
        
    }

    /// for logging only
    public func log(indentation:String) -> String {
        var r:String = "sensor = ";
        r += "\n" + indentation + "uniqueid = " + id;
        r += "\n" + indentation + "startedAt = " + startDate.description
        if let endDate = endDate {
            r += "\n" + indentation + "stoppedAt = " + endDate.description
        }
        r += "\n"
        return r;
    }

}
