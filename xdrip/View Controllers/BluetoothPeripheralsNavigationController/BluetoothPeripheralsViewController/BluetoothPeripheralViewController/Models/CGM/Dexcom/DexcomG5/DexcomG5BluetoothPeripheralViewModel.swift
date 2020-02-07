import Foundation
import UIKit
import CoreBluetooth

class DexcomG5BluetoothPeripheralViewModel {
    // 't is hier dat de transmitter id die gekozen werd door gebruiker, moet toegevoegd worden
    
    // MARK: - private properties
    
    /// settings specific for Dexcom G5
    private enum Settings:Int, CaseIterable {
        
        /// firmware version
        case firmWareVersion = 1
        
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

extension DexcomG5BluetoothPeripheralViewModel: BluetoothPeripheralViewModel {
    
    func configure(bluetoothPeripheral: BluetoothPeripheral?, bluetoothPeripheralManager: BluetoothPeripheralManaging, tableView: UITableView, bluetoothPeripheralViewController: BluetoothPeripheralViewController, bluetoothTransmitterDelegate: BluetoothTransmitterDelegate) {
        
        self.bluetoothPeripheralManager = bluetoothPeripheralManager
        
        self.tableView = tableView
        
        self.bluetoothPeripheralViewController = bluetoothPeripheralViewController
        
        self.bluetoothTransmitterDelegate = bluetoothTransmitterDelegate
        
        if let dexcomG5 = bluetoothPeripheral as? DexcomG5  {
            
            storeTempValues(from: dexcomG5)
            
        }

    }
    
    func screenTitle() -> String {
        return BluetoothPeripheralType.DexcomG5Type.rawValue
    }
    
    func sectionTitle(forSection section: Int) -> String {
        // not shown ?
        return ""
    }
    
    func update(cell: UITableViewCell, forRow rawValue: Int, forSection section: Int, for bluetoothPeripheral: BluetoothPeripheral, doneButtonOutlet: UIBarButtonItem) {
        
        // verify that bluetoothPeripheral is a DexcomG5
        guard let dexcomG5 = bluetoothPeripheral as? DexcomG5 else {
            fatalError("DexcomG5BluetoothPeripheralViewModel update, bluetoothPeripheral is not DexcomG5")
        }
        
        // default value for accessoryView is nil
        cell.accessoryView = nil

        guard let setting = Settings(rawValue: rawValue) else { fatalError("DexcomG5BluetoothPeripheralViewModel update, unexpected setting") }
        
        switch setting {
            
        case .firmWareVersion:
            
            cell.textLabel?.text = Texts_Common.firmware
            cell.detailTextLabel?.text = dexcomG5.firmwareVersion
            cell.accessoryType = .none

        }
        
    }
    
    func userDidSelectRow(withSettingRawValue rawValue: Int, forSection section: Int, for bluetoothPeripheral: BluetoothPeripheral, bluetoothPeripheralManager: BluetoothPeripheralManaging, doneButtonOutlet: UIBarButtonItem) -> SettingsSelectedRowAction {
        
        // verify that bluetoothPeripheral is a DexcomG5
        /*guard let dexcomG5 = bluetoothPeripheral as? DexcomG5 else {
            fatalError("DexcomG5BluetoothPeripheralViewModel userDidSelectRow, bluetoothPeripheral is not DexcomG5")
        }*/
        
        guard let setting = Settings(rawValue: rawValue) else { fatalError("DexcomG5BluetoothPeripheralViewModel userDidSelectRow, unexpected setting") }
        
        switch setting {
            
        case .firmWareVersion:
            return .nothing
            
        }

    }
    
    func numberOfSettings(inSection section: Int) -> Int {
        return Settings.allCases.count
    }
    
    func numberOfSections() -> Int {
        // for the moment only one specific section for DexcomG5
        return 1
    }
    
    func storeTempValues(from bluetoothPeripheral: BluetoothPeripheral) {
        
        //guard let dexcomG5 = bluetoothPeripheral as? DexcomG5 else {return}
        
        // creating enum to make sure we don't forget new cases
        for setting in Settings.allCases {
           
            switch setting {
                
            case .firmWareVersion:
                // user doesn't change the firmware version
                break

            }
        }
    }
    
    func writeTempValues(to bluetoothPeripheral: BluetoothPeripheral) {
        
        //guard let dexcomG5 = bluetoothPeripheral as? DexcomG5 else {return}
        
        // creating enum to make sure we don't forget new cases
        for setting in Settings.allCases {
            
            switch setting {
                
            case .firmWareVersion:
                // user doesn't change the firmware version
                break
                
            }
            
        }
        
    }
    
}
