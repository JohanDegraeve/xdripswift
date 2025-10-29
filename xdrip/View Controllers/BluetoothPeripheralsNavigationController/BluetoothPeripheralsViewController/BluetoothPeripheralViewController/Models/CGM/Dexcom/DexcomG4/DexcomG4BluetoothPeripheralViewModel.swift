import UIKit

class DexcomG4BluetoothPeripheralViewModel {
    
    // MARK: - private properties
    
    /// settings specific for DexcomG4
    private enum Settings:Int, CaseIterable {
        
        /// battery level
        case batteryLevel = 0
        
    }
    
    /// DexcomG4 settings willb be in section 0 + numberOfGeneralSections
    private let sectionNumberForDexcomG4SpecificSettings = 0
    
    /// reference to bluetoothPeripheralManager
    private weak var bluetoothPeripheralManager: BluetoothPeripheralManaging?
    
    /// reference to the tableView
    private weak var tableView: UITableView?
    
    /// reference to BluetoothPeripheralViewController that will own this DexcomG4BluetoothPeripheralViewModel - needed to present stuff etc
    private weak var bluetoothPeripheralViewController: BluetoothPeripheralViewController?
    
    /// temporary reference to bluetoothPerpipheral, will be set in configure function.
    private var bluetoothPeripheral: BluetoothPeripheral?
    
    /// it's the bluetoothPeripheral as M5Stack
    private var DexcomG4: DexcomG4? {
        get {
            return bluetoothPeripheral as? DexcomG4
        }
    }
    
    // MARK: - deinit
    
    deinit {
        
        // when closing the viewModel, and if there's still a bluetoothTransmitter existing, then reset the specific delegate to BluetoothPeripheralManager
        
        guard let bluetoothPeripheralManager = bluetoothPeripheralManager else {return}
        
        guard let DexcomG4 = DexcomG4 else {return}
        
        guard let blueToothTransmitter = bluetoothPeripheralManager.getBluetoothTransmitter(for: DexcomG4, createANewOneIfNecesssary: false) else {return}
        
        guard let cGMG4xDripTransmitter = blueToothTransmitter as? CGMG4xDripTransmitter else {return}
        
        cGMG4xDripTransmitter.cGMDexcomG4TransmitterDelegate = bluetoothPeripheralManager as! BluetoothPeripheralManager
        
    }
    
}

// MARK: - conform to BluetoothPeripheralViewModel

extension DexcomG4BluetoothPeripheralViewModel: BluetoothPeripheralViewModel {
    
    func configure(bluetoothPeripheral: BluetoothPeripheral?, bluetoothPeripheralManager: BluetoothPeripheralManaging, tableView: UITableView, bluetoothPeripheralViewController: BluetoothPeripheralViewController) {
        
        self.bluetoothPeripheralManager = bluetoothPeripheralManager
        
        self.tableView = tableView
        
        self.bluetoothPeripheralViewController = bluetoothPeripheralViewController
        
        self.bluetoothPeripheral = bluetoothPeripheral
        
        if let bluetoothPeripheral = bluetoothPeripheral {
            
            if let dexcomG4 = bluetoothPeripheral as? DexcomG4 {
                
                if let blueToothTransmitter = bluetoothPeripheralManager.getBluetoothTransmitter(for: dexcomG4, createANewOneIfNecesssary: false), let cGMG4xDripTransmitter = blueToothTransmitter as? CGMG4xDripTransmitter {
                    
                    // set CGMDexcomG4Transmitter delegate to self.
                    cGMG4xDripTransmitter.cGMDexcomG4TransmitterDelegate = self
                    
                }
                
            } else {
                fatalError("in DexcomG4BluetoothPeripheralViewModel, configure. bluetoothPeripheral is not DexcomG4")
            }
        }
        
    }
    
    func screenTitle() -> String {
        return BluetoothPeripheralType.DexcomG4Type.rawValue
    }
    
    func sectionTitle(forSection section: Int) -> String {
        return BluetoothPeripheralType.DexcomG4Type.rawValue
    }
    
    func update(cell: UITableViewCell, forRow rawValue: Int, forSection section: Int, for bluetoothPeripheral: BluetoothPeripheral) {
        
        // verify that bluetoothPeripheral is a DexcomG4
        guard let DexcomG4 = bluetoothPeripheral as? DexcomG4 else {
            fatalError("DexcomG4BluetoothPeripheralViewModel update, bluetoothPeripheral is not DexcomG4")
        }
        
        // default value for accessoryView is nil
        cell.accessoryView = nil
        
        guard let setting = Settings(rawValue: rawValue) else { fatalError("DexcomG4BluetoothPeripheralViewModel update, unexpected setting") }
        
        switch setting {
            
        case .batteryLevel:
            
            cell.textLabel?.text = Texts_BluetoothPeripheralsView.batteryLevel
            if DexcomG4.batteryLevel > 0 {
                cell.detailTextLabel?.text = DexcomG4.batteryLevel.description + " %"
            } else {
                cell.detailTextLabel?.text = ""
            }
            cell.accessoryType = .none
            
        }
        
    }
    
    func userDidSelectRow(withSettingRawValue rawValue: Int, forSection section: Int, for bluetoothPeripheral: BluetoothPeripheral, bluetoothPeripheralManager: BluetoothPeripheralManaging) -> SettingsSelectedRowAction {
        
        guard let setting = Settings(rawValue: rawValue) else { fatalError("DexcomG4BluetoothPeripheralViewModel userDidSelectRow, unexpected setting") }
        
        switch setting {
            
        case .batteryLevel:
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
    
}

// MARK: - conform to CGMDexcomG4TransmitterDelegate

extension DexcomG4BluetoothPeripheralViewModel: CGMDexcomG4TransmitterDelegate {
    
    func received(batteryLevel: Int, from cGMG4xDripTransmitter: CGMG4xDripTransmitter) {
        
        // inform also bluetoothPeripheralManager
        (bluetoothPeripheralManager as? CGMDexcomG4TransmitterDelegate)?.received(batteryLevel: batteryLevel, from: cGMG4xDripTransmitter)
        
        // here's the trigger to update the table
        reloadRow(row: Settings.batteryLevel.rawValue)
        
    }
    
    private func reloadRow(row: Int) {
        DispatchQueue.main.async {
            guard let tableView = self.tableView,
                  let bluetoothPeripheralViewController = self.bluetoothPeripheralViewController else { return }

            // Always reload the general section (0) first, because its row count may have changed.
            tableView.reloadSections(IndexSet(integer: 0), with: .none)
            
            let totalSections = tableView.numberOfSections
            let section = bluetoothPeripheralViewController.numberOfGeneralSections() + self.sectionNumberForDexcomG4SpecificSettings
            
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

