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

    /// temporary reference to bluetoothPerpipheral, will be set in configure function.
    private var bluetoothPeripheral: BluetoothPeripheral?
    
    /// it's the bluetoothPeripheral as Watlaa
    private var watlaa: Watlaa? {
        get {
            return bluetoothPeripheral as? Watlaa
        }
    }
    
    // MARK: - deinit
    
    deinit {
        
        // when closing the viewModel, and if there's still a bluetoothTransmitter existing, then reset the specific delegate to BluetoothPeripheralManager
        
        guard let bluetoothPeripheralManager = bluetoothPeripheralManager else {return}
        
        guard let watlaa = watlaa else {return}
        
        guard let blueToothTransmitter = bluetoothPeripheralManager.getBluetoothTransmitter(for: watlaa, createANewOneIfNecesssary: false) else {return}
        
        guard let watlaaBluetoothTransmitterMaster = blueToothTransmitter as? WatlaaBluetoothTransmitterMaster else {return}
        
        watlaaBluetoothTransmitterMaster.watlaaBluetoothTransmitterDelegate = bluetoothPeripheralManager as! BluetoothPeripheralManager
        
    }

}

// MARK: - conform to BluetoothPeripheralViewModel

extension WatlaaMasterBluetoothPeripheralViewModel: BluetoothPeripheralViewModel {
    
    func canWebOOP() -> Bool {
        return CGMTransmitterType.watlaa.canWebOOP()
    }

    func configure(bluetoothPeripheral: BluetoothPeripheral?, bluetoothPeripheralManager: BluetoothPeripheralManaging, tableView: UITableView, bluetoothPeripheralViewController: BluetoothPeripheralViewController) {
        
        self.bluetoothPeripheralManager = bluetoothPeripheralManager
        
        self.tableView = tableView
        
        self.bluetoothPeripheralViewController = bluetoothPeripheralViewController
        
        if let bluetoothPeripheral = bluetoothPeripheral {

            if let watlaa = bluetoothPeripheral as? Watlaa  {
                
                // request batteryLevel, this may have been updated
                if let blueToothTransmitter = bluetoothPeripheralManager.getBluetoothTransmitter(for: watlaa, createANewOneIfNecesssary: false), let watlaaBluetoothTransmitter = blueToothTransmitter as? WatlaaBluetoothTransmitterMaster {
                    
                    // set CGMBubbleTransmitter delegate to self.
                    watlaaBluetoothTransmitter.watlaaBluetoothTransmitterDelegate = self
                    
                    _ = watlaaBluetoothTransmitter.readBatteryLevel()
                    
                }
                
            } else {
                fatalError("in WatlaaMasterBluetoothPeripheralViewModel, configure. bluetoothPeripheral is not Watlaa")
            }

        }
        
    }
    
    func screenTitle() -> String {
        return TextsWatlaaView.watlaaViewscreenTitle
    }
    
    func sectionTitle(forSection section: Int) -> String {
        return "section title tbc"
    }
    
    func update(cell: UITableViewCell, forRow rawValue: Int, forSection section: Int, for bluetoothPeripheral: BluetoothPeripheral) {
        
        // unwrap watlaa
        guard let watlaa = watlaa else {return}
        
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
    
    func userDidSelectRow(withSettingRawValue rawValue: Int, forSection section: Int, for bluetoothPeripheral: BluetoothPeripheral, bluetoothPeripheralManager: BluetoothPeripheralManaging) -> SettingsSelectedRowAction {
        
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
