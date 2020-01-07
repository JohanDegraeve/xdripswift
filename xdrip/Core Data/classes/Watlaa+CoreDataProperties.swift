import Foundation
import CoreData


extension Watlaa {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Watlaa> {
        return NSFetchRequest<Watlaa>(entityName: "Watlaa")
    }

    @NSManaged public var address: String
    @NSManaged public var name: String
    @NSManaged public var shouldconnect: Bool
    @NSManaged public var alias: String?

}
