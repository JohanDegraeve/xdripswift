import Foundation
import CoreData

/// AlertType defines alert properties :
///
/// properties :
///
/// - enabled : if false then no alert will be generated
/// - name : the name of the alerttype as shown in the UI, should be unique
/// - overrideMute : should alert make sound if the alert is muted
/// - snooze : can the alert be snoozed from the home screen notification
/// - vibrate : should the phone vibrate when the alert fires
/// - soundname : the name of the sound as shown in the UI. ConstantsSounds defines available sounds. Per case there a string which is the soundname as shown in the UI and the filename of the sound in the Resources folder, seperated by backslash. Some special cases : an empty string means no sound needed. A nil value means default iOS sound. Any other value should be in the list defined in ConstantsSounds, otherwise the default xDrip sound will be used (see AlertManager.swift)
/// - alertEntries : the alertEntries in which this AlertType is used, optional
public class AlertType: NSManagedObject {
    init(
        enabled:Bool,
        name:String,
        overrideMute:Bool,
        snooze:Bool,
        snoozePeriod:Int,
        vibrate:Bool,
        soundName:String?,
        alertEntries:[AlertEntry]?,
        nsManagedObjectContext:NSManagedObjectContext
        ) {
        let entity = NSEntityDescription.entity(forEntityName: "AlertType", in: nsManagedObjectContext)!
        super.init(entity: entity, insertInto: nsManagedObjectContext)
        
        self.enabled = enabled
        self.name = name
        self.overridemute = overrideMute
        self.snooze = snooze
        self.snoozeperiod = Int16(snoozePeriod)
        self.vibrate = vibrate
        self.soundname = soundName
        if let alertEntries = alertEntries {
            for alertEntry in alertEntries {
                addToAlertEntries(alertEntry)
            }
        }
    }
    
    private override init(entity: NSEntityDescription, insertInto context: NSManagedObjectContext?) {
        super.init(entity: entity, insertInto: context)
    }
    
    public override var description: String {
        return name
    }
    
}
