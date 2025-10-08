import UIKit

class AtomBluetoothPeripheralViewModel {
    
    // MARK: - private properties
    
    /// settings specific for Atom
    private enum Settings:Int, CaseIterable {
        
        /// Libre sensor type
        case sensorType = 0
        
        /// Sensor serial number
        case sensorSerialNumber = 1
        
        /// sensor State
        case sensorState = 2
        
        /// battery level
        case batteryLevel = 3
        
        /// firmware version
        case firmWare = 4
        
        /// hardware version
        case hardWare = 5
        
    }
    
    /// Atom settings willb be in section 0 + numberOfGeneralSections
    private let sectionNumberForAtomSpecificSettings = 0
    
    /// reference to bluetoothPeripheralManager
    private weak var bluetoothPeripheralManager: BluetoothPeripheralManaging?
    
    /// reference to the tableView
    private weak var tableView: UITableView?
    
    /// reference to BluetoothPeripheralViewController that will own this AtomBluetoothPeripheralViewModel - needed to present stuff etc
    private weak var bluetoothPeripheralViewController: BluetoothPeripheralViewController?
    
    /// temporary reference to bluetoothPerpipheral, will be set in configure function.
    private var bluetoothPeripheral: BluetoothPeripheral?
    
    /// it's the bluetoothPeripheral as M5Stack
    private var atom: Atom? {
        get {
            return bluetoothPeripheral as? Atom
        }
    }
    
    // MARK: - deinit
    
    deinit {
        
        // when closing the viewModel, and if there's still a bluetoothTransmitter existing, then reset the specific delegate to BluetoothPeripheralManager
        
        guard let bluetoothPeripheralManager = bluetoothPeripheralManager else {return}
        
        guard let Atom = atom else {return}
        
        guard let blueToothTransmitter = bluetoothPeripheralManager.getBluetoothTransmitter(for: Atom, createANewOneIfNecesssary: false) else {return}
        
        guard let cGMAtomBluetoothTransmitter = blueToothTransmitter as? CGMAtomTransmitter else {return}
        
        cGMAtomBluetoothTransmitter.cGMAtomTransmitterDelegate = bluetoothPeripheralManager as! BluetoothPeripheralManager
        
    }
    
}

// MARK: - conform to BluetoothPeripheralViewModel

extension AtomBluetoothPeripheralViewModel: BluetoothPeripheralViewModel {
    
    func configure(bluetoothPeripheral: BluetoothPeripheral?, bluetoothPeripheralManager: BluetoothPeripheralManaging, tableView: UITableView, bluetoothPeripheralViewController: BluetoothPeripheralViewController) {
        
        self.bluetoothPeripheralManager = bluetoothPeripheralManager
        
        self.tableView = tableView
        
        self.bluetoothPeripheralViewController = bluetoothPeripheralViewController
        
        self.bluetoothPeripheral = bluetoothPeripheral
        
        if let bluetoothPeripheral = bluetoothPeripheral {
            
            if let atom = bluetoothPeripheral as? Atom {
                
                if let blueToothTransmitter = bluetoothPeripheralManager.getBluetoothTransmitter(for: atom, createANewOneIfNecesssary: false), let cGMAtomTransmitter = blueToothTransmitter as? CGMAtomTransmitter {
                    
                    // set CGMAtomTransmitter delegate to self.
                    cGMAtomTransmitter.cGMAtomTransmitterDelegate = self
                    
                }
                
            } else {
                fatalError("in AtomBluetoothPeripheralViewModel, configure. bluetoothPeripheral is not Atom")
            }
        }
        
    }
    
    func screenTitle() -> String {
        return BluetoothPeripheralType.AtomType.rawValue
    }
    
    func sectionTitle(forSection section: Int) -> String {
        return BluetoothPeripheralType.AtomType.rawValue
    }
    
    func update(cell: UITableViewCell, forRow rawValue: Int, forSection section: Int, for bluetoothPeripheral: BluetoothPeripheral) {
        
        // verify that bluetoothPeripheral is a Atom
        guard let atom = bluetoothPeripheral as? Atom else {
            fatalError("AtomBluetoothPeripheralViewModel update, bluetoothPeripheral is not Atom")
        }
        
        // default value for accessoryView is nil
        cell.accessoryView = nil
        
        // create disclosureIndicator in color ConstantsUI.disclosureIndicatorColor
        // will be used whenever accessoryType is to be set to disclosureIndicator
        let  disclosureAccessoryView = DTCustomColoredAccessory(color: ConstantsUI.disclosureIndicatorColor)
        
        guard let setting = Settings(rawValue: rawValue) else { fatalError("AtomBluetoothPeripheralViewModel update, unexpected setting") }
        
        switch setting {
        
        case .sensorType:
            
            cell.accessoryType = .none
            
            cell.textLabel?.text = Texts_BluetoothPeripheralView.sensorType
            
            if let libreSensorType = atom.blePeripheral.libreSensorType {
                
                cell.detailTextLabel?.text = libreSensorType.description
                
            } else {
                
                cell.detailTextLabel?.text = nil
            }
            
        case .sensorState:
            
            cell.accessoryType = .none
            
            cell.textLabel?.text = Texts_Common.sensorStatus
            
            cell.detailTextLabel?.text = atom.sensorState.translatedDescription
            
        case .batteryLevel:
            
            cell.textLabel?.text = Texts_BluetoothPeripheralsView.batteryLevel
            if atom.batteryLevel > 0 {
                cell.detailTextLabel?.text = atom.batteryLevel.description + " %"
            } else {
                cell.detailTextLabel?.text = ""
            }
            cell.accessoryType = .none
            
        case .firmWare:
            
            cell.textLabel?.text = Texts_Common.firmware
            cell.detailTextLabel?.text = atom.firmware
            cell.accessoryType = .disclosureIndicator
            cell.accessoryView =  disclosureAccessoryView
            
        case .hardWare:
            
            cell.textLabel?.text = Texts_Common.hardware
            cell.detailTextLabel?.text = atom.hardware
            cell.accessoryType = .disclosureIndicator
            cell.accessoryView =  disclosureAccessoryView
            
        case .sensorSerialNumber:
            
            cell.textLabel?.text = Texts_BluetoothPeripheralView.sensorSerialNumber
            cell.detailTextLabel?.text = atom.blePeripheral.sensorSerialNumber
            cell.accessoryType = .disclosureIndicator
            cell.accessoryView =  disclosureAccessoryView
            
        }
        
    }
    
    func userDidSelectRow(withSettingRawValue rawValue: Int, forSection section: Int, for bluetoothPeripheral: BluetoothPeripheral, bluetoothPeripheralManager: BluetoothPeripheralManaging) -> SettingsSelectedRowAction {
        
        // verify that bluetoothPeripheral is a Atom
        guard let atom = bluetoothPeripheral as? Atom else {
            fatalError("AtomBluetoothPeripheralViewModel userDidSelectRow, bluetoothPeripheral is not Atom")
        }
        
        guard let setting = Settings(rawValue: rawValue) else { fatalError("AtomBluetoothPeripheralViewModel userDidSelectRow, unexpected setting") }
        
        switch setting {
        
        case .batteryLevel, .sensorType, .sensorState:
            return .nothing
            
        case .firmWare:
            
            // firmware text could be longer than screen width, clicking the row allos to see it in pop up with more text place
            if let firmware = atom.firmware {
                return .showInfoText(title: Texts_HomeView.info, message: Texts_Common.firmware + ": " + firmware)
            }
            
        case .hardWare:
            
            // hardware text could be longer than screen width, clicking the row allows to see it in pop up with more text place
            if let hardware = atom.hardware {
                return .showInfoText(title: Texts_HomeView.info, message: Texts_Common.hardware + ": " + hardware)
            }
            
        case .sensorSerialNumber:
            
            // serial text could be longer than screen width, clicking the row allows to see it in a pop up with more text place
            if let serialNumber = atom.blePeripheral.sensorSerialNumber {
                return .showInfoText(title: Texts_HomeView.info, message: Texts_BluetoothPeripheralView.sensorSerialNumber + " " + serialNumber)
            }
            
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

// MARK: - conform to CGMAtomTransmitterDelegate

extension AtomBluetoothPeripheralViewModel: CGMAtomTransmitterDelegate {
    
    func received(libreSensorType: LibreSensorType, from cGMAtomTransmitter: CGMAtomTransmitter) {
        
        // inform bluetoothPeripheralManager, bluetoothPeripheralManager will store the libreSensorType in the atom object
        (bluetoothPeripheralManager as? CGMAtomTransmitterDelegate)?.received(libreSensorType: libreSensorType, from: cGMAtomTransmitter)
        
        // here's the trigger to update the table row for sensorType
        reloadRow(row: Settings.sensorType.rawValue)
        
    }
    
    func received(serialNumber: String, from cGMAtomTransmitter: CGMAtomTransmitter) {
        
        // inform also bluetoothPeripheralManager
        (bluetoothPeripheralManager as? CGMAtomTransmitterDelegate)?.received(serialNumber: serialNumber, from: cGMAtomTransmitter)
        
        // here's the trigger to update the table
        reloadRow(row: Settings.sensorSerialNumber.rawValue)
        
    }
    
    func received(batteryLevel: Int, from cGMAtomTransmitter: CGMAtomTransmitter) {
        
        // inform also bluetoothPeripheralManager
        (bluetoothPeripheralManager as? CGMAtomTransmitterDelegate)?.received(batteryLevel: batteryLevel, from: cGMAtomTransmitter)
        
        // here's the trigger to update the table
        reloadRow(row: Settings.batteryLevel.rawValue)
        
    }
    
    func received(sensorStatus: LibreSensorState, from cGMAtomTransmitter: CGMAtomTransmitter) {
        
        // inform also bluetoothPeripheralManager
        (bluetoothPeripheralManager as? CGMAtomTransmitterDelegate)?.received(sensorStatus: sensorStatus, from: cGMAtomTransmitter)
        
        // here's the trigger to update the table
        reloadRow(row: Settings.sensorState.rawValue)
        
    }
    
    func received(firmware: String, from cGMAtomTransmitter: CGMAtomTransmitter) {
        
        // inform also bluetoothPeripheralManager
        (bluetoothPeripheralManager as? CGMAtomTransmitterDelegate)?.received(firmware: firmware, from: cGMAtomTransmitter)
        
        // here's the trigger to update the table
        reloadRow(row: Settings.firmWare.rawValue)
        
    }
    
    func received(hardware: String, from cGMAtomTransmitter: CGMAtomTransmitter) {
        
        // inform also bluetoothPeripheralManager
        (bluetoothPeripheralManager as? CGMAtomTransmitterDelegate)?.received(hardware: hardware, from: cGMAtomTransmitter)
        
        // here's the trigger to update the table
        reloadRow(row: Settings.hardWare.rawValue)
        
    }
    
    private func reloadRow(row: Int) {
        DispatchQueue.main.async {
            guard let tableView = self.tableView,
                  let bluetoothPeripheralViewController = self.bluetoothPeripheralViewController else { return }

            // Always reload the general section (0) first, because its row count may have changed.
            tableView.reloadSections(IndexSet(integer: 0), with: .none)
            
            let totalSections = tableView.numberOfSections
            let section = bluetoothPeripheralViewController.numberOfGeneralSections() + self.sectionNumberForAtomSpecificSettings
            
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
