import Foundation

/// categories are M5Stack, CGM, watlaa, ...
enum BluetoothPeripheralCategory: String, CaseIterable {
    
    /// for Dexcom, bubble, MiaoMiao ...
    case CGM = "CGM"
    
    /// this is the category for M5Stack ad M5StickC
    case M5Stack = "M5Stack"
    
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
