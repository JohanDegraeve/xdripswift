import Foundation
import CoreData


extension Sensor {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Sensor> {
        return NSFetchRequest<Sensor>(entityName: "Sensor")
    }

    @NSManaged public var endDate: Date?
    @NSManaged public var startDate: Date
    @NSManaged public var id: String

}
