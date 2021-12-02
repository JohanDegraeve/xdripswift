import Foundation
import UIKit
import CoreBluetooth

class DexcomG6FireflyBluetoothPeripheralViewModel: DexcomG5BluetoothPeripheralViewModel {
    
    // MARK: - overriden functions
    
    override public func dexcomScreenTitle() -> String {
        return BluetoothPeripheralType.DexcomG6FireflyType.rawValue
    }

    /// just a helper, can be overloaded, eg for firefly
    public override func numberOfSectionsForThisTransmitter() -> Int {
        
        return DexcomSection.allCases.count - 1
        
    }

}


