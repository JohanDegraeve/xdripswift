import CoreData
import Foundation

/// Per kind of alert, a list of AlertEntry can be defined. It can define per minute of the day which value and alertype is applicable
///
/// properties :
///
/// - isDisabled: flag if the alert kind has been disabled. We use isDisabled instead of isEnabled because the default value in coredata for Boolean is false so it's easier to manage
/// - value : meaning depends on the kind of alert, example for low or high alert, value is the glucose value in mgdl, for missed raeding alert, it is the time since last reading in minutes, for calibration alert, it is the time since last calibration in hours
/// - start : at which minute of the day (local time) does the alertentry apply
/// - alertType : which alerttype is applicable
public class AlertEntry: NSManagedObject {
    init(
        isDisabled: Bool,
        value: Int,
        triggerValue: Int,
        alertKind: AlertKind,
        start: Int,
        alertType: AlertType,
        nsManagedObjectContext: NSManagedObjectContext
    ) {
        let entity = NSEntityDescription.entity(forEntityName: "AlertEntry", in: nsManagedObjectContext)!
        super.init(entity: entity, insertInto: nsManagedObjectContext)

        self.isDisabled = Bool(isDisabled)
        self.value = Int16(value)
        self.triggerValue = Int16(triggerValue)
        self.alertkind = Int16(alertKind.rawValue)
        self.start = Int16(start)
        self.alertType = alertType
    }

    override private init(entity: NSEntityDescription, insertInto context: NSManagedObjectContext?) {
        super.init(entity: entity, insertInto: context)
    }
}
