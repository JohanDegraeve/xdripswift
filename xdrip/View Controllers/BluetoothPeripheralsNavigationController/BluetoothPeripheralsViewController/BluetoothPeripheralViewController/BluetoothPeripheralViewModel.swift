import Foundation
import UIKit

protocol BluetoothPeripheralViewModel: BluetoothTransmitterDelegate {
    
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
    
    /// updates the contents of a cell, for setting with rawValue withSettingRawValue
    func update(cell: UITableViewCell, withSettingRawValue rawValue: Int, for bluetoothPeripheral: BluetoothPeripheral, doneButtonOutlet: UIBarButtonItem)
    
    /// user clicked a row, this function does the necessary
    func userDidSelectRow(withSettingRawValue rawValue: Int, for bluetoothPeripheral: BluetoothPeripheral, bluetoothPeripheralManager: BluetoothPeripheralManaging, doneButtonOutlet: UIBarButtonItem)
    
    /// get number of settings in the viewmodel
    func numberOfSettings() -> Int
    
    /// used when new peripheral is discovered and connected, to temporary store values in model (eg in case of M5Stack, store the rotation value which would be a default value)
    func storeTempValues(from bluetoothPeripheral: BluetoothPeripheral)
    
    /// used when user clicks done button in uiviewcontroller
    func writeTempValues(to bluetoothPeripheral: BluetoothPeripheral)
    
}
