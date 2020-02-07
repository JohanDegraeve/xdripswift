import UIKit
import CoreBluetooth

class WatlaaMasterBluetoothPeripheralViewModel {
 
    // MARK: - private properties

    /// settings correspond to watlaa specific rows in viewcontroller
    private enum WatlaaSetting: Int, CaseIterable {
        
        /// batteryLevel
        case batteryLevel
        
    }

    /// reference to bluetoothPeripheralManager
    private weak var bluetoothPeripheralManager: BluetoothPeripheralManaging?
    
    /// reference to the tableView
    private weak var tableView: UITableView?
    
    /// reference to BluetoothPeripheralViewController that will own this WatlaaMasterBluetoothPeripheralViewModel - needed to present stuff etc
    private weak var bluetoothPeripheralViewController: BluetoothPeripheralViewController?

    private weak var bluetoothTransmitterDelegate: BluetoothTransmitterDelegate?
    

}

// MARK: - conform to BluetoothPeripheralViewModel

extension WatlaaMasterBluetoothPeripheralViewModel: BluetoothPeripheralViewModel {
    
    func configure(bluetoothPeripheral: BluetoothPeripheral?, bluetoothPeripheralManager: BluetoothPeripheralManaging, tableView: UITableView, bluetoothPeripheralViewController: BluetoothPeripheralViewController, bluetoothTransmitterDelegate: BluetoothTransmitterDelegate) {
        
        self.bluetoothPeripheralManager = bluetoothPeripheralManager
        
        self.tableView = tableView
        
        self.bluetoothPeripheralViewController = bluetoothPeripheralViewController
        
        self.bluetoothTransmitterDelegate = bluetoothTransmitterDelegate

        if let watlaaPeripheral = bluetoothPeripheral as? Watlaa  {
            
            storeTempValues(from: watlaaPeripheral)
            
            // also request batteryLevel, this may have been updated
            if let blueToothTransmitter = bluetoothPeripheralManager.getBluetoothTransmitter(for: watlaaPeripheral, createANewOneIfNecesssary: false), let watlaaBluetoothTransmitter = blueToothTransmitter as? WatlaaBluetoothTransmitterMaster {
                
                _ = watlaaBluetoothTransmitter.readBatteryLevel()
                
            }

        }
        
    }
    
    func screenTitle() -> String {
        return TextsWatlaaView.watlaaViewscreenTitle
    }
    
    func sectionTitle(forSection section: Int) -> String {
        return "section title tbc"
    }
    
    func update(cell: UITableViewCell, forRow rawValue: Int, forSection section: Int, for bluetoothPeripheral: BluetoothPeripheral, doneButtonOutlet: UIBarButtonItem) {
        
        // verify that bluetoothPeripheral is an M5Stack
        guard let watlaa = bluetoothPeripheral as? Watlaa else {
            fatalError("WatlaaMasterBluetoothPeripheralViewModel update, bluetoothPeripheral is not Watlaa")
        }
        
        // default value for accessoryView is nil
        cell.accessoryView = nil
        
        switch section {
            
        case 1:
            
            guard let setting = WatlaaSetting(rawValue: rawValue) else { fatalError("WatlaaMasterBluetoothPeripheralViewModel update, unexpected setting") }
            
            switch setting {
                
            case .batteryLevel:

                cell.textLabel?.text = Texts_BluetoothPeripheralsView.batteryLevel
                cell.detailTextLabel?.text = watlaa.batteryLevel?.description
                cell.accessoryType = .none

            }
            
        default:
            fatalError("in WatlaaMasterBluetoothPeripheralViewModel update, unhandled section number")
            
        }
        
    }
    
    func userDidSelectRow(withSettingRawValue rawValue: Int, forSection section: Int, for bluetoothPeripheral: BluetoothPeripheral, bluetoothPeripheralManager: BluetoothPeripheralManaging, doneButtonOutlet: UIBarButtonItem) -> SettingsSelectedRowAction {
        
        switch section {
            
        case 1:
            
            guard let setting = WatlaaSetting(rawValue: rawValue) else { fatalError("WatlaaMasterBluetoothPeripheralViewModel userDidSelectRow, unexpected setting") }

            switch setting {
                
            case .batteryLevel:
                // user can't do anything by clicking on battery row
                return .nothing

            }
            
        default:
            fatalError("in WatlaaMasterBluetoothPeripheralViewModel update, unhandled section number")

        }
    }
    
    func numberOfSettings(inSection section: Int) -> Int {
        return WatlaaSetting.allCases.count
    }
    
    func numberOfSections() -> Int {
        // for the moment only one specific section for watlaa
        return 1
    }
    
    func storeTempValues(from bluetoothPeripheral: BluetoothPeripheral) {
    }
    
    func writeTempValues(to bluetoothPeripheral: BluetoothPeripheral) {
    }
    
    
}

// MARK: - conform to WatlaaBluetoothTransmitterDelegate

extension WatlaaMasterBluetoothPeripheralViewModel: WatlaaBluetoothTransmitterDelegate {
    
    func isReadyToReceiveData(watlaaBluetoothTransmitter: WatlaaBluetoothTransmitterMaster) {
        // viewcontroller doesn't use this
    }
    
    func receivedBattery(level: Int, watlaaBluetoothTransmitter: WatlaaBluetoothTransmitterMaster) {
        
        // batteryLevel should get updated in Watlaa object by bluetoothPeripheralManager, here's the trigger to update the table
        tableView?.reloadRows(at: [IndexPath(row: WatlaaSetting.batteryLevel.rawValue, section: 1)], with: .none)

    }
    
}
