import UIKit

class GNSEntryBluetoothPeripheralViewModel {
    
    // MARK: - private properties
    
    /// settings specific for GNSEntry
    private enum Settings:Int, CaseIterable {
        
        /// bootLoader
        case bootLoader = 0
        
        /// firmware version
        case firmWareVersion = 1
        
        /// hardware version
        case serialNumber = 2
        
    }
    
    /// GNSEntry settings willb be in section 0 + numberOfGeneralSections
    private let sectionNumberForGNSEntrySpecificSettings = 0
    
    /// reference to bluetoothPeripheralManager
    private weak var bluetoothPeripheralManager: BluetoothPeripheralManaging?
    
    /// reference to the tableView
    private weak var tableView: UITableView?
    
    /// reference to BluetoothPeripheralViewController that will own this GNSEntryBluetoothPeripheralViewModel - needed to present stuff etc
    private weak var bluetoothPeripheralViewController: BluetoothPeripheralViewController?
    
    /// temporary reference to bluetoothPerpipheral, will be set in configure function.
    private var bluetoothPeripheral: BluetoothPeripheral?
    
    /// it's the bluetoothPeripheral as GNSentry
    private var GNSEntry: GNSEntry? {
        get {
            return bluetoothPeripheral as? GNSEntry
        }
    }
    
    // MARK: - deinit
    
    deinit {

        // when closing the viewModel, and if there's still a bluetoothTransmitter existing, then reset the specific delegate to BluetoothPeripheralManager
        
        guard let bluetoothPeripheralManager = bluetoothPeripheralManager else {return}
        
        guard let GNSEntry = GNSEntry else {return}
        
        guard let blueToothTransmitter = bluetoothPeripheralManager.getBluetoothTransmitter(for: GNSEntry, createANewOneIfNecesssary: false) else {return}
        
        guard let cGMGNSEntryBluetoothTransmitter = blueToothTransmitter as? CGMGNSEntryTransmitter else {return}
        
        cGMGNSEntryBluetoothTransmitter.cGMGNSEntryTransmitterDelegate = bluetoothPeripheralManager as! BluetoothPeripheralManager

    }
    
}

// MARK: - conform to BluetoothPeripheralViewModel

extension GNSEntryBluetoothPeripheralViewModel: BluetoothPeripheralViewModel {

    func configure(bluetoothPeripheral: BluetoothPeripheral?, bluetoothPeripheralManager: BluetoothPeripheralManaging, tableView: UITableView, bluetoothPeripheralViewController: BluetoothPeripheralViewController) {
        
        self.bluetoothPeripheralManager = bluetoothPeripheralManager
        
        self.tableView = tableView
        
        self.bluetoothPeripheralViewController = bluetoothPeripheralViewController
        
        self.bluetoothPeripheral = bluetoothPeripheral
        
        if let bluetoothPeripheral = bluetoothPeripheral {
            
            if let gNSEntry = bluetoothPeripheral as? GNSEntry {
                
                if let blueToothTransmitter = bluetoothPeripheralManager.getBluetoothTransmitter(for: gNSEntry, createANewOneIfNecesssary: false), let cGMGNSEntryTransmitter = blueToothTransmitter as? CGMGNSEntryTransmitter {
                    
                    // set CGMGNSEntryTransmitter delegate to self.
                    cGMGNSEntryTransmitter.cGMGNSEntryTransmitterDelegate = self
                    
                }
                
            } else {
                fatalError("in GNSEntryBluetoothPeripheralViewModel, configure. bluetoothPeripheral is not GNSEntry")
            }
        }

    }
    
    func screenTitle() -> String {
        return BluetoothPeripheralType.GNSentryType.rawValue
    }
    
    func sectionTitle(forSection section: Int) -> String {
        return BluetoothPeripheralType.GNSentryType.rawValue
    }
    
    func update(cell: UITableViewCell, forRow rawValue: Int, forSection section: Int, for bluetoothPeripheral: BluetoothPeripheral) {
        
        // verify that bluetoothPeripheral is a GNSEntry
        guard let gNSEntry = bluetoothPeripheral as? GNSEntry else {
            fatalError("GNSEntryBluetoothPeripheralViewModel update, bluetoothPeripheral is not GNSEntry")
        }
        
        // default value for accessoryView is nil
        cell.accessoryView = nil
        
        // create disclosureIndicator in color ConstantsUI.disclosureIndicatorColor
        // will be used whenever accessoryType is to be set to disclosureIndicator
        let  disclosureAccessoryView = DTCustomColoredAccessory(color: ConstantsUI.disclosureIndicatorColor)

        guard let setting = Settings(rawValue: rawValue) else { fatalError("GNSEntryBluetoothPeripheralViewModel update, unexpected setting") }
        
        switch setting {
            
        case .bootLoader:
            cell.textLabel?.text = Texts_BluetoothPeripheralView.bootLoader
            cell.detailTextLabel?.text = gNSEntry.bootLoader
            cell.accessoryType = .none
            
        case .firmWareVersion:
            
            cell.textLabel?.text = Texts_Common.firmware
            cell.detailTextLabel?.text = gNSEntry.firmwareVersion
            cell.accessoryType = .disclosureIndicator
            cell.accessoryView =  disclosureAccessoryView
            
        case .serialNumber:
            
            cell.textLabel?.text = Texts_BluetoothPeripheralView.serialNumber
            cell.detailTextLabel?.text = gNSEntry.serialNumber
            cell.accessoryType = .disclosureIndicator
            cell.accessoryView =  disclosureAccessoryView

        }

    }
    
    func userDidSelectRow(withSettingRawValue rawValue: Int, forSection section: Int, for bluetoothPeripheral: BluetoothPeripheral, bluetoothPeripheralManager: BluetoothPeripheralManaging) -> SettingsSelectedRowAction {
        
        // verify that bluetoothPeripheral is a GNSEntry
        guard let gNSEntry = bluetoothPeripheral as? GNSEntry else {
            fatalError("GNSEntryBluetoothPeripheralViewModel userDidSelectRow, bluetoothPeripheral is not GNSEntry")
        }
        
        guard let setting = Settings(rawValue: rawValue) else { fatalError("GNSEntryBluetoothPeripheralViewModel userDidSelectRow, unexpected setting") }
        
        switch setting {
            
        case .bootLoader:
            
            return .nothing
            
        case .firmWareVersion:
            
            // firmware text could be longer than screen width, clicking the row allos to see it in pop up with more text place
            if let firmWareVersion = gNSEntry.firmwareVersion {
                return .showInfoText(title: Texts_HomeView.info, message: Texts_Common.firmware + ": " + firmWareVersion)
            }

        case .serialNumber:

            return .nothing
            
        }
        
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

// MARK: - conform to CGMGNSEntryTransmitterDelegate

extension GNSEntryBluetoothPeripheralViewModel: CGMGNSEntryTransmitterDelegate {
    
    func received(bootLoader: String, from cGMGNSEntryTransmitter: CGMGNSEntryTransmitter) {

        // inform also bluetoothPeripheralManager
        (bluetoothPeripheralManager as? CGMGNSEntryTransmitterDelegate)?.received(bootLoader: bootLoader, from: cGMGNSEntryTransmitter)
        
        // here's the trigger to update the table
        reloadRow(row: Settings.bootLoader.rawValue)

    }
    
    func received(firmwareVersion: String, from cGMGNSEntryTransmitter: CGMGNSEntryTransmitter) {
        
        // inform also bluetoothPeripheralManager
        (bluetoothPeripheralManager as? CGMGNSEntryTransmitterDelegate)?.received(firmwareVersion: firmwareVersion, from: cGMGNSEntryTransmitter)
        
        // here's the trigger to update the table
        reloadRow(row: Settings.firmWareVersion.rawValue)

    }
    
    func received(serialNumber: String, from cGMGNSEntryTransmitter: CGMGNSEntryTransmitter) {
        
        // inform also bluetoothPeripheralManager
        (bluetoothPeripheralManager as? CGMGNSEntryTransmitterDelegate)?.received(serialNumber: serialNumber, from: cGMGNSEntryTransmitter)
        
        // here's the trigger to update the table
        reloadRow(row: Settings.serialNumber.rawValue)

    }
    
    private func reloadRow(row: Int) {
        DispatchQueue.main.async {
            guard let tableView = self.tableView,
                  let bluetoothPeripheralViewController = self.bluetoothPeripheralViewController else { return }

            // Always reload the general section (0) first, because its row count may have changed.
            tableView.reloadSections(IndexSet(integer: 0), with: .none)
            
            let totalSections = tableView.numberOfSections
            let section = bluetoothPeripheralViewController.numberOfGeneralSections() + self.sectionNumberForGNSEntrySpecificSettings
            
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
