import Foundation
import CoreData

/// M5Stack
///
/// M5Stack has
/// - an address (received from the real device),
/// - a name (also received from the real device),
/// - shouldConnect with default value true, if true then xdrip will automatically try to connect at app launch
/// - blePassword : optional, if this value is set, then it means this M5Stack does have an internally stored password created during M5Stack launch. If it is not set, then the password in the userdefaults will be used. If that is also nil, then the xdrip app can not authenticate towards the M5Stack
/// - textColor : color to use, see M5StackColor
/// - backGroundColor : color to use, see M5StackColor
/// - m5StackName : optional. A reference to a user defined name
/// - rotation : screen rotation to apply, between 0 and 360
/// - brightness : value between 0 and 100
public class M5Stack: NSManagedObject {

    /// create M5Stack, shouldconnect default value = true
    /// - parameters:
    ///     - rotation is internally stored as Int32, actual value should always be between 0 and 360 so UInt16 as parameter is sufficient.
    init(address: String, name: String, textColor: M5StackColor, backGroundColor: M5StackColor, rotation: UInt16, brightness: Int, nsManagedObjectContext:NSManagedObjectContext) {
       
        let entity = NSEntityDescription.entity(forEntityName: "M5Stack", in: nsManagedObjectContext)!
        
        super.init(entity: entity, insertInto: nsManagedObjectContext)
        
        self.address = address
        self.name = name
        self.shouldconnect = true
        self.textcolor = Int32(textColor.rawValue)
        self.backGroundColor = Int32(backGroundColor.rawValue)
        self.rotation = Int32(rotation)
        self.brightness = Int16(brightness)
        
    }
    
    private override init(entity: NSEntityDescription, insertInto context: NSManagedObjectContext?) {
        super.init(entity: entity, insertInto: context)
    }
    
}
