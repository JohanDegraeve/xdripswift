import Foundation
import UIKit
import CoreBluetooth

class DexcomG6BluetoothPeripheralViewModel: DexcomG5BluetoothPeripheralViewModel {
    
    // MARK: - overriden functions
    
    override public func dexcomScreenTitle() -> String {
        return BluetoothPeripheralType.DexcomG6Type.rawValue
    }
    
}
