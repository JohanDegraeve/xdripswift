import Foundation
import CoreData


public class Sensor: NSManagedObject {

    private override init(entity: NSEntityDescription, insertInto context: NSManagedObjectContext?) {
        super.init(entity: entity, insertInto: context)
    }

}
