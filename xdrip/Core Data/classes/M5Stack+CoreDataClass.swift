import Foundation
import CoreData


public class M5Stack: NSManagedObject {

    /// create M5Stack
    init(address: String, name: String, nsManagedObjectContext:NSManagedObjectContext) {
       
        super.init(entity: entity, insertInto: nsManagedObjectContext)
        
        self.address = address
        self.name = name
        
    }
    
    private override init(entity: NSEntityDescription, insertInto context: NSManagedObjectContext?) {
        super.init(entity: entity, insertInto: context)
    }
    
}
