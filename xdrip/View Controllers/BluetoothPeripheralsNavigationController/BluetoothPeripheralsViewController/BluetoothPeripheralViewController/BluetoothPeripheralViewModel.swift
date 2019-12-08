import Foundation
import UIKit

protocol BluetoothPeripheralViewModel {
    
    /// to be called before opening the actual viewcontroller or after discovering a new bluetoothperipheral
    /// - parameters :
    ///     - bluetoothPeripheral : the bluetoothPeripheral that will be shown
    ///     - bluetoothPeripheralManager : reference to bluetoothPeripheralManager
    ///     - tableView: reference to tableView
    ///     - bluetoothPeripheralViewController : reference to bluetoothPeripheralViewController
    func configure(bluetoothPeripheral: BluetoothPeripheral?, bluetoothPeripheralManager: BluetoothPeripheralManager, tableView: UITableView, bluetoothPeripheralViewController: BluetoothPeripheralViewController)
    
    /// screen title for uiviewcontroller
    func screenTitle() -> String
    
    /// user clicked done button in uiviewcontroller
    /// - parameters:
    ///     - bluetoothPeripheral : the bluetoothPeripheral being shown
    func doneButtonHandler(bluetoothPeripheral: BluetoothPeripheral?)
    
    /// updates the contents of a cell, for setting with rawValue withSettingRawValue
    func update(cell: UITableViewCell, withSettingRawValue rawValue: Int, for bluetoothPeripheral: BluetoothPeripheral)
    
    /// user clicked a row, this function does the necessary
    func userDidSelectRow(withSettingRawValue rawValue: Int, rowOffset: Int, for bluetoothPeripheral: BluetoothPeripheral, bluetoothPeripheralManager: BluetoothPeripheralManager, doneButtonOutlet: UIBarButtonItem)
    
    func numberOfSettings() -> Int
}
