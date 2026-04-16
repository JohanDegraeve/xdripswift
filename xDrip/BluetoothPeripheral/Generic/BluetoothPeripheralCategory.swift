import Foundation

/// categories are M5Stack, CGM, ...
enum BluetoothPeripheralCategory: String, CaseIterable {
    
    /// for Dexcom, bubble, MiaoMiao ...
    case CGM = "CGM"
    
    /// this is the category for M5Stack ad M5StickC
    case M5Stack = "M5Stack"
    
    /// for using a a bluetooth device as heartbeat : whenever the device sends someting over a read characteristic, then xDrip4iOS will wake up
    /// Heartbeat also works for connect and disconnect
    case HeartBeat = "Follower HeartBeat ♥"
    
    /// returns index in list of BluetoothPeripheralCategory's
    func index() -> Int {
        
        for (index, type) in BluetoothPeripheralCategory.allCases.enumerated() {
            
            if type == self {
                return index
            }
            
        }
        
        return 0
        
    }
    
    /// gets list of  categories in array of strings, user will see those strings when selecting a category
    static func listOfCategories() -> [String] {
        
        var list = [String]()
        for category in BluetoothPeripheralCategory.allCases{
            list.append(category.rawValue)
        }
        return list
        
    }
    
    /// - returns list of bluetooth peripheral type's rawValue,  that have a bluetoothperipheral category, that has withCategory as rawValue
    /// - so it gives a list of bluetoothperipheral types for a specific bluetoothperipheral category
    static func listOfBluetoothPeripheralTypes(withCategory rawValueOfTheCategory: String) -> [String] {
        
        var list = [String]()
        for bluetoothPeripheralType in BluetoothPeripheralType.allCases {
            if bluetoothPeripheralType.category().rawValue == rawValueOfTheCategory {
                list.append(bluetoothPeripheralType.rawValue)
            }
        }
        return list
        
    }
    
}
