import Foundation
import CoreData

/// M5Stack
///
/// M5Stack has
/// - an address (received form M5Stack),
/// - a name (also received from M5Stack),
/// - shouldConnect with default value true, if true then xdrip will automatically try to connect at app launch
/// - blePassword : optional, if this value is set, then it means this M5Stack does have an internally stored password created during M5Stack launch. If it is not set, then the password in the userdefaults will be used. If that is also nil, then the xdrip app can not authenticate towards the M5Stack
/// - textColor : color to use, see M5StackColor
/// - backGroundColor : color to use, see M5StackColor
/// - m5StackName : optional. A reference to a user defined name
/// - rotation : screen rotation to apply, between 0 and 360
/// - brightness : value between 0 and 100
public class M5Stack: NSManagedObject {

    /// this property is not stored in coreData. It is used to keep track of parameter updates sent to the M5Stack. If value is true, then xdrip needs to send an update off all parameters to this M5Stack as soon as possible (ie when connected)
    public var parameterUpdateNeeded = true
    
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
