import UIKit

class WatlaaBluetoothPeripheralViewModel {
    
    // MARK: - private properties
    
    /// settings specific for Watlaa
    private enum Settings:Int, CaseIterable {
        
        /// battery level
        case watlaaBatteryLevel = 0
        
        /// transmitter battery level
        case transmitterBatteryLevel = 1
        
    }
    
    /// Watlaa settings willb be in section 0 + numberOfGeneralSections
    private let sectionNumberForWatlaaSpecificSettings = 0
    
    /// reference to bluetoothPeripheralManager
    private weak var bluetoothPeripheralManager: BluetoothPeripheralManaging?
    
    /// reference to the tableView
    private weak var tableView: UITableView?
    
    /// reference to BluetoothPeripheralViewController that will own this WatlaaBluetoothPeripheralViewModel - needed to present stuff etc
    private weak var bluetoothPeripheralViewController: BluetoothPeripheralViewController?
    
    /// temporary reference to bluetoothPerpipheral, will be set in configure function.
    private var bluetoothPeripheral: BluetoothPeripheral?
    
    /// it's the bluetoothPeripheral as Waatla
    private var Watlaa: Watlaa? {
        get {
            return bluetoothPeripheral as? Watlaa
        }
    }
    
    // MARK: - deinit
    
    deinit {
        
        // when closing the viewModel, and if there's still a bluetoothTransmitter existing, then reset the specific delegate to BluetoothPeripheralManager
        
        guard let bluetoothPeripheralManager = bluetoothPeripheralManager else {return}
        
        guard let Watlaa = Watlaa else {return}
        
        guard let blueToothTransmitter = bluetoothPeripheralManager.getBluetoothTransmitter(for: Watlaa, createANewOneIfNecesssary: false) else {return}
        
        guard let cGMWatlaaBluetoothTransmitter = blueToothTransmitter as? WatlaaBluetoothTransmitter else {return}
        
        cGMWatlaaBluetoothTransmitter.watlaaBluetoothTransmitterDelegate = bluetoothPeripheralManager as! BluetoothPeripheralManager
        
    }
    
}

// MARK: - conform to BluetoothPeripheralViewModel

extension WatlaaBluetoothPeripheralViewModel: BluetoothPeripheralViewModel {
    
    func configure(bluetoothPeripheral: BluetoothPeripheral?, bluetoothPeripheralManager: BluetoothPeripheralManaging, tableView: UITableView, bluetoothPeripheralViewController: BluetoothPeripheralViewController) {
        
        self.bluetoothPeripheralManager = bluetoothPeripheralManager
        
        self.tableView = tableView
        
        self.bluetoothPeripheralViewController = bluetoothPeripheralViewController
        
        self.bluetoothPeripheral = bluetoothPeripheral
        
        if let bluetoothPeripheral = bluetoothPeripheral {
            
            if let watlaa = bluetoothPeripheral as? Watlaa {
                
                if let blueToothTransmitter = bluetoothPeripheralManager.getBluetoothTransmitter(for: watlaa, createANewOneIfNecesssary: false), let cGMWatlaaTransmitter = blueToothTransmitter as? WatlaaBluetoothTransmitter {
                    
                    // set WatlaaBluetoothTransmitterMaster delegate to self.
                    cGMWatlaaTransmitter.watlaaBluetoothTransmitterDelegate = self
                    
                }
                
            } else {
                fatalError("in WatlaaBluetoothPeripheralViewModel, configure. bluetoothPeripheral is not Watlaa")
            }
        }
        
    }
    
    func screenTitle() -> String {
        return BluetoothPeripheralType.WatlaaType.rawValue
    }
    
    func sectionTitle(forSection section: Int) -> String {
        return BluetoothPeripheralType.WatlaaType.rawValue
    }
    
    func update(cell: UITableViewCell, forRow rawValue: Int, forSection section: Int, for bluetoothPeripheral: BluetoothPeripheral) {
        
        // verify that bluetoothPeripheral is a Watlaa
        guard let watlaa = bluetoothPeripheral as? Watlaa else {
            fatalError("WatlaaBluetoothPeripheralViewModel update, bluetoothPeripheral is not Watlaa")
        }
        
        // default value for accessoryView is nil
        cell.accessoryView = nil
        
        guard let setting = Settings(rawValue: rawValue) else { fatalError("WatlaaBluetoothPeripheralViewModel update, unexpected setting") }
        
        switch setting {
            
        case .watlaaBatteryLevel:
            
            cell.textLabel?.text = "Watlaa " + Texts_BluetoothPeripheralsView.batteryLevel
            if watlaa.watlaaBatteryLevel > 0 {
                cell.detailTextLabel?.text = watlaa.watlaaBatteryLevel.description + " %"
            } else {
                cell.detailTextLabel?.text = ""
            }
            cell.accessoryType = .none
            
        case .transmitterBatteryLevel:
            cell.textLabel?.text = Texts_SettingsView.sectionTitleTransmitter + " " + Texts_BluetoothPeripheralsView.batteryLevel
            if watlaa.transmitterBatteryLevel > 0 {
                cell.detailTextLabel?.text = watlaa.transmitterBatteryLevel.description + " %"
            } else {
                cell.detailTextLabel?.text = ""
            }
            cell.accessoryType = .none
            
        }
        
    }
    
    func userDidSelectRow(withSettingRawValue rawValue: Int, forSection section: Int, for bluetoothPeripheral: BluetoothPeripheral, bluetoothPeripheralManager: BluetoothPeripheralManaging) -> SettingsSelectedRowAction {

        // for the moment none of the watlaa settings rows react on clicking
        return .nothing
        
    }
    
    func numberOfSettings(inSection section: Int) -> Int {
        return Settings.allCases.count
    }
    
    func numberOfSections() -> Int {
        // for the moment only one specific section for DexcomG5
        return 1
    }
    
}

// MARK: - conform to WatlaaBluetoothTransmitterDelegate

extension WatlaaBluetoothPeripheralViewModel: WatlaaBluetoothTransmitterDelegate {
    
    func isReadyToReceiveData(watlaaBluetoothTransmitter: WatlaaBluetoothTransmitter) {
        // viewcontroller doesn't use this
    }
    
    func received(transmitterBatteryLevel: Int, watlaaBluetoothTransmitter: WatlaaBluetoothTransmitter) {
        
        // inform also bluetoothPeripheralManager
        (bluetoothPeripheralManager as? WatlaaBluetoothTransmitterDelegate)?.received(transmitterBatteryLevel: transmitterBatteryLevel, watlaaBluetoothTransmitter: watlaaBluetoothTransmitter)
        
        // here's the trigger to update the table
        reloadRow(row: Settings.transmitterBatteryLevel.rawValue)
        
    }
    
    func received(watlaaBatteryLevel: Int, watlaaBluetoothTransmitter: WatlaaBluetoothTransmitter) {
        
        // inform also bluetoothPeripheralManager
        (bluetoothPeripheralManager as? WatlaaBluetoothTransmitterDelegate)?.received(watlaaBatteryLevel: watlaaBatteryLevel, watlaaBluetoothTransmitter: watlaaBluetoothTransmitter)
        
        // here's the trigger to update the table
        reloadRow(row: Settings.watlaaBatteryLevel.rawValue)

    }
    
    
    func received(serialNumber: String, from cGMWatlaaTransmitter: WatlaaBluetoothTransmitter) {
        
        // inform also bluetoothPeripheralManager
        (bluetoothPeripheralManager as? WatlaaBluetoothTransmitterDelegate)?.received(serialNumber: serialNumber, from: cGMWatlaaTransmitter)
        
        // here's the trigger to update the table
        //reloadRow(row: Settings.sensorSerialNumber.rawValue)
        
    }
    
    private func reloadRow(row: Int) {
        DispatchQueue.main.async {
            guard let tableView = self.tableView,
                  let bluetoothPeripheralViewController = self.bluetoothPeripheralViewController else { return }

            // Always reload the general section (0) first, because its row count may have changed.
            tableView.reloadSections(IndexSet(integer: 0), with: .none)
            
            let totalSections = tableView.numberOfSections
            let section = bluetoothPeripheralViewController.numberOfGeneralSections() + self.sectionNumberForWatlaaSpecificSettings
            
            // Guard against invalid section index. A mismatch between calculated section and the current
            // table structure can occur during updates, which previously caused a crash in
            // -[UITableViewRowData numberOfRowsInSection:]. If the section is gone/shifted, fall back to a full reload.
            guard section < totalSections else {
                tableView.reloadData()
                return
            }

            // Then safely refresh the target section: reload the row if it still exists; otherwise reload the whole section.
            if row < tableView.numberOfRows(inSection: section) {
                tableView.reloadRows(at: [IndexPath(row: row, section: section)], with: .none)
            } else {
                tableView.reloadSections(IndexSet(integer: section), with: .none)
            }
        }
    }
    
}
