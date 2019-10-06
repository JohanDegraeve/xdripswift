import Foundation
import CoreData

/// M5Stack
///
/// M5Stack has
/// - an address (received form M5Stack),
/// - a name (also received from M5Stack),
/// - shouldConnect with default value true, if true then xdrip will automatically try to connect at app launch
/// - blePassword : optional, if this value is set, then it means this M5Stack does have an internally stored password created during M5Stack launch. If it is not set, then the password in the userdefaults will be used. If that is also nil, then the xdrip app can not authenticate towards the M5Stack
/// - M5StackName : optional. A reference to a userdefined name
public class M5Stack: NSManagedObject {

    /// create M5Stack, shouldconnect default value = true
    init(address: String, name: String, textColor: M5StackTextColor, nsManagedObjectContext:NSManagedObjectContext) {
       
        let entity = NSEntityDescription.entity(forEntityName: "M5Stack", in: nsManagedObjectContext)!
        
        super.init(entity: entity, insertInto: nsManagedObjectContext)
        
        self.address = address
        self.name = name
        self.shouldconnect = true
        self.textcolor = Int32(textColor.rawValue)
        
    }
    
    private override init(entity: NSEntityDescription, insertInto context: NSManagedObjectContext?) {
        super.init(entity: entity, insertInto: context)
    }
    
}
