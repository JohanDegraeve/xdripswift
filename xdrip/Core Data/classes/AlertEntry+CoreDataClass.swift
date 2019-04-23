import Foundation
import CoreData

@objc(AlertEntry)
public class AlertEntry: NSManagedObject {

    init(
        value:Int,
        alertKind:AlertKind,
        start:Int,
        alertType:AlertType,
        nsManagedObjectContext:NSManagedObjectContext
        ) {
        let entity = NSEntityDescription.entity(forEntityName: "AlertEntry", in: nsManagedObjectContext)!
        super.init(entity: entity, insertInto: nsManagedObjectContext)
        
        self.value = Int16(value)
        self.alertkind = Int16(alertKind.rawValue)
        self.start = Int16(start)
        self.alertType = alertType
    }
    
    private override init(entity: NSEntityDescription, insertInto context: NSManagedObjectContext?) {
        super.init(entity: entity, insertInto: context)
    }
}
