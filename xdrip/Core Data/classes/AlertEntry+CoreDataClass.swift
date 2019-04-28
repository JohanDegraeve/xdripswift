import Foundation
import CoreData

/// Per kind of alert, a list of AlertEntry can be defined. It can define per minute of the day which value and alertype is applicable
///
/// properties :
///
/// - value : meaning depends on the kind of alert, example for low or high alert, value is the glucose value in mgdl, for missed raeding alert, it is the time since last reading in minutes, for calibration alert, it is the time since last calibration in hours
/// - start : at which minute of the day (local time) does the alertentry apply
/// - alertType : which alerttype is applicable
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
