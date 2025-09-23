import Foundation
import CoreData

/// Protocol to allow any controller to provide the current active Sensor.
/// Used so that child view controllers (e.g. BluetoothPeripheralViewController)
/// can query the active sensor without holding a direct reference to RootViewController.
protocol ActiveSensorProviding: AnyObject {
    var activeSensor: Sensor? { get }
}

public class Sensor: NSManagedObject {

    /// creates Sensor.
    ///
    /// id gets new value - all other optional values will get value nil
    init(startDate:Date, nsManagedObjectContext:NSManagedObjectContext) {
        let entity = NSEntityDescription.entity(forEntityName: "Sensor", in: nsManagedObjectContext)!
        
        super.init(entity: entity, insertInto: nsManagedObjectContext)

        self.startDate = startDate
        id = UniqueId.createEventId()
    }
    
    private override init(entity: NSEntityDescription, insertInto context: NSManagedObjectContext?) {
        super.init(entity: entity, insertInto: context)
        
    }

    /// log the contents to a string
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
