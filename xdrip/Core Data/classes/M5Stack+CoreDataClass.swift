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
/// - alias : optional. Name defined by user, to easier recognize the peripheral
/// - rotation : screen rotation to apply, between 0 and 360
/// - brightness : value between 0 and 100 (doesn't work for M5Stick)
public class M5Stack: NSManagedObject {

    /// explanation, see function parameterUpdateNotNeededAtNextConnect in protocol BluetoothPeripheral
    public var parameterUpdateNeeded: Bool = false
    
    /// batterylevel, not stored in coreData, will only be available after having received it from the M5Stack
    public var batteryLevel: Int = 0
    
    /// create M5Stack, shouldconnect default value = true
    /// - parameters:
    ///     - rotation is internally stored as Int32, actual value should always be between 0 and 360 so UInt16 as parameter is sufficient.
    init(address: String, name: String, textColor: M5StackColor, backGroundColor: M5StackColor, rotation: UInt16, brightness: Int, alias: String?, nsManagedObjectContext:NSManagedObjectContext) {
       
        let entity = NSEntityDescription.entity(forEntityName: "M5Stack", in: nsManagedObjectContext)!
        
        super.init(entity: entity, insertInto: nsManagedObjectContext)
        
        blePeripheral = BLEPeripheral(address: address, name: name, alias: nil, bluetoothPeripheralType: .M5StackType, nsManagedObjectContext: nsManagedObjectContext)

        self.textcolor = Int32(textColor.rawValue)
        self.backGroundColor = Int32(backGroundColor.rawValue)
        self.rotation = Int32(rotation)
        self.brightness = Int16(brightness)
        
        // this is creation of an M5Stack, not M5Stick, set isM5StickC to false
        self.isM5StickC = false
        
        // by default, don't connect to WiFi
        self.connectToWiFi = false
        
    }
    
    private override init(entity: NSEntityDescription, insertInto context: NSManagedObjectContext?) {
        super.init(entity: entity, insertInto: context)
    }
    
}
