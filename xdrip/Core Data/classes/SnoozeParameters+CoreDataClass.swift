import Foundation
import CoreData

/// maps to SnoozeParameters
public class SnoozeParameters: NSManagedObject {
    
    init(
        alertKind:AlertKind,
        snoozePeriodInMinutes: Int16,
        snoozeTimeStamp: Date?,
        nsManagedObjectContext:NSManagedObjectContext
    ) {
        let entity = NSEntityDescription.entity(forEntityName: "SnoozeParameters", in: nsManagedObjectContext)!
        super.init(entity: entity, insertInto: nsManagedObjectContext)
        
        self.snoozePeriodInMinutes = snoozePeriodInMinutes
        self.alertKind = Int16(alertKind.rawValue)
        self.snoozeTimeStamp = snoozeTimeStamp

    }
    
    private override init(entity: NSEntityDescription, insertInto context: NSManagedObjectContext?) {
        super.init(entity: entity, insertInto: context)
    }
}
