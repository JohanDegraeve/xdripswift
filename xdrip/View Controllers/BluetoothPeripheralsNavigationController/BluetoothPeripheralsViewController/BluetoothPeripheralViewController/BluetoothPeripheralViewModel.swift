import Foundation
import UIKit

protocol BluetoothPeripheralViewModel {
    
    /// to be called before opening the actual viewcontroller or after discovering a new bluetoothperipheral
    /// - parameters :
    ///    - bluetoothPeripheral : if nil then the viewcontroller is opened to scan for a new peripheral
    ///    - bluetoothPeripheralManager : reference to bluetoothPeripheralManaging object
    ///    - tableView : needed to intiate refresh of row
    ///    - bluetoothPeripheralViewController : BluetoothPeripheralViewController
    func configure(bluetoothPeripheral: BluetoothPeripheral?, bluetoothPeripheralManager: BluetoothPeripheralManaging, tableView: UITableView, bluetoothPeripheralViewController: BluetoothPeripheralViewController)
    
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
    
    /// used in BluetoothPeripheralViewController which is unaware of types of transmitters (M5Stack, Watlaa, ...). This to handle that there can be multiple delegates listening for example M5StackBluetoothTransmitter changes. The function assignBluetoothTransmitterDelegate will temporary store the value of the existing delegate (example M5StackBluetoothTransmitterDelegate) and assign itself (ie the viewmodel) as delegate. It should also handle the calling of the functions in the stored delegate (look at an example to understand :) )
    func assignBluetoothTransmitterDelegate(to bluetoothTransmitter: BluetoothTransmitter)

    /// see explanation assignBluetoothTransmitterDelegate
    func reAssignBluetoothTransmitterDelegateToOriginal(for bluetoothTransmitter: BluetoothTransmitter)

}
