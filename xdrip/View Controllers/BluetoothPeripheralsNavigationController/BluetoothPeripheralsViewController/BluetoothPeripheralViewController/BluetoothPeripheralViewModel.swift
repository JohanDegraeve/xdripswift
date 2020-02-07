import Foundation
import UIKit

protocol BluetoothPeripheralViewModel {
    
    /// to be called before opening the actual viewcontroller or after discovering a new bluetoothperipheral
    /// - parameters :
    ///    - bluetoothTransmitterDelegate : usually the uiViewController
    ///    - bluetoothPeripheral : if nil then the viewcontroller is opened to scan for a new peripheral
    ///    - bluetoothPeripheralManager : reference to bluetoothPeripheralManaging object
    ///    - tableView : needed to intiate refresh of row
    ///    - bluetoothPeripheralViewController : BluetoothPeripheralViewController
    func configure(bluetoothPeripheral: BluetoothPeripheral?, bluetoothPeripheralManager: BluetoothPeripheralManaging, tableView: UITableView, bluetoothPeripheralViewController: BluetoothPeripheralViewController, bluetoothTransmitterDelegate: BluetoothTransmitterDelegate)
    
    /// screen title for uiviewcontroller
    func screenTitle() -> String
    
    func sectionTitle(forSection section: Int) -> String
    
    /// updates the contents of a cell, for setting with rawValue withSettingRawValue
    func update(cell: UITableViewCell, forRow rawValue: Int, forSection section: Int, for bluetoothPeripheral: BluetoothPeripheral, doneButtonOutlet: UIBarButtonItem)
    
    /// user clicked a row, this function returns an instance of SettingsSelectedRowAction, can be run with SettingsViewUtilities.runSelectedRowAction
    func userDidSelectRow(withSettingRawValue rawValue: Int, forSection section: Int, for bluetoothPeripheral: BluetoothPeripheral, bluetoothPeripheralManager: BluetoothPeripheralManaging, doneButtonOutlet: UIBarButtonItem) -> SettingsSelectedRowAction
    
    /// - get number of settings in the viewmodel, in specified section number
    /// - this is the same as the number of rows in the section
    /// - section counting starts at 1, which is actually the section with index 1 in the uiviewcontroller
    func numberOfSettings(inSection section:Int) -> Int
    
    /// how many sections does this viewmodel define, in addition to the section already defined in BluetoothPeripheralViewController
    func numberOfSections() -> Int
    
    /// used when new peripheral is discovered and connected, to temporary store values in model (eg in case of M5Stack, store the rotation value which would be a default value)
    func storeTempValues(from bluetoothPeripheral: BluetoothPeripheral)
    
    /// used when user clicks done button in uiviewcontroller
    func writeTempValues(to bluetoothPeripheral: BluetoothPeripheral)
    
}
