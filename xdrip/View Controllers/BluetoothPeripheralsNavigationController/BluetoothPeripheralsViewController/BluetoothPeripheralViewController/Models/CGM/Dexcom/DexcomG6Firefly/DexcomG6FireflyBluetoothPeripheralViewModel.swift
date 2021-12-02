import Foundation
import UIKit
import CoreBluetooth

class DexcomG6FireflyBluetoothPeripheralViewModel: DexcomG5BluetoothPeripheralViewModel {
    
    // MARK: - overriden functions
    
    override public func dexcomScreenTitle() -> String {
        return BluetoothPeripheralType.DexcomG6FireflyType.rawValue
    }

    /// - just a helper, can be overloaded, eg for firefly
    /// - returns:
    ///  - 1 less than DexcomSection.allCases.count because we don't want to show the reset section for firefly transmitters
    public override func numberOfSectionsForThisTransmitter() -> Int {
        
        return DexcomSection.allCases.count - 1
        
    }

    public override func numberOfCommonDexcomSettings() -> Int {
        
        return Settings.allCases.count
        
    }
    
}


