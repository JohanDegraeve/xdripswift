import UIKit

class MiaoMiaoBluetoothPeripheralViewModel {
    
    // MARK: - private properties
    
    /// settings specific for MiaoMiao
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
    
    /// MiaoMiao settings willb be in section 0 + numberOfGeneralSections
    private let sectionNumberForMiaoMiaoSpecificSettings = 0
    
    /// reference to bluetoothPeripheralManager
    private weak var bluetoothPeripheralManager: BluetoothPeripheralManaging?
    
    /// reference to the tableView
    private weak var tableView: UITableView?
    
    /// reference to BluetoothPeripheralViewController that will own this MiaoMiaoBluetoothPeripheralViewModel - needed to present stuff etc
    private weak var bluetoothPeripheralViewController: BluetoothPeripheralViewController?
    
    /// temporary reference to bluetoothPerpipheral, will be set in configure function.
    private var bluetoothPeripheral: BluetoothPeripheral?
    
    /// it's the bluetoothPeripheral as MiaoMiao
    private var MiaoMiao: MiaoMiao? {
        get {
            return bluetoothPeripheral as? MiaoMiao
        }
    }
    
    // MARK: - deinit
    
    deinit {

        // when closing the viewModel, and if there's still a bluetoothTransmitter existing, then reset the specific delegate to BluetoothPeripheralManager
        
        guard let bluetoothPeripheralManager = bluetoothPeripheralManager else {return}
        
        guard let MiaoMiao = MiaoMiao else {return}
        
        guard let blueToothTransmitter = bluetoothPeripheralManager.getBluetoothTransmitter(for: MiaoMiao, createANewOneIfNecesssary: false) else {return}
        
        guard let cGMMiaoMiaoBluetoothTransmitter = blueToothTransmitter as? CGMMiaoMiaoTransmitter else {return}
        
        cGMMiaoMiaoBluetoothTransmitter.cGMMiaoMiaoTransmitterDelegate = bluetoothPeripheralManager as! BluetoothPeripheralManager

    }
    
}

// MARK: - conform to BluetoothPeripheralViewModel

extension MiaoMiaoBluetoothPeripheralViewModel: BluetoothPeripheralViewModel {

    func configure(bluetoothPeripheral: BluetoothPeripheral?, bluetoothPeripheralManager: BluetoothPeripheralManaging, tableView: UITableView, bluetoothPeripheralViewController: BluetoothPeripheralViewController) {
        
        self.bluetoothPeripheralManager = bluetoothPeripheralManager
        
        self.tableView = tableView
        
        self.bluetoothPeripheralViewController = bluetoothPeripheralViewController
        
        self.bluetoothPeripheral = bluetoothPeripheral
        
        if let bluetoothPeripheral = bluetoothPeripheral {
            
            if let miaoMiao = bluetoothPeripheral as? MiaoMiao {
                
                if let blueToothTransmitter = bluetoothPeripheralManager.getBluetoothTransmitter(for: miaoMiao, createANewOneIfNecesssary: false), let cGMMiaoMiaoTransmitter = blueToothTransmitter as? CGMMiaoMiaoTransmitter {
                    
                    // set CGMMiaoMiaoTransmitter delegate to self.
                    cGMMiaoMiaoTransmitter.cGMMiaoMiaoTransmitterDelegate = self
                    
                }
                
            } else {
                fatalError("in MiaoMiaoBluetoothPeripheralViewModel, configure. bluetoothPeripheral is not MiaoMiao")
            }
        }

    }
    
    func screenTitle() -> String {
        return BluetoothPeripheralType.MiaoMiaoType.rawValue
    }
    
    func sectionTitle(forSection section: Int) -> String {
        return BluetoothPeripheralType.MiaoMiaoType.rawValue
    }
    
    func update(cell: UITableViewCell, forRow rawValue: Int, forSection section: Int, for bluetoothPeripheral: BluetoothPeripheral) {
        
        // verify that bluetoothPeripheral is a MiaoMiao
        guard let miaoMiao = bluetoothPeripheral as? MiaoMiao else {
            fatalError("MiaoMiaoBluetoothPeripheralViewModel update, bluetoothPeripheral is not MiaoMiao")
        }
        
        // default value for accessoryView is nil
        cell.accessoryView = nil
        
        // create disclosureIndicator in color ConstantsUI.disclosureIndicatorColor
        // will be used whenever accessoryType is to be set to disclosureIndicator
        let  disclosureAccessoryView = DTCustomColoredAccessory(color: ConstantsUI.disclosureIndicatorColor)

        guard let setting = Settings(rawValue: rawValue) else { fatalError("MiaoMiaoBluetoothPeripheralViewModel update, unexpected setting") }
        
        switch setting {
          
        case .sensorType:
            
            cell.accessoryType = .none
            
            cell.textLabel?.text = Texts_BluetoothPeripheralView.sensorType
            
            if let libreSensorType = miaoMiao.blePeripheral.libreSensorType {
                
                cell.detailTextLabel?.text = libreSensorType.description
                
            } else {
                
                cell.detailTextLabel?.text = nil
            }

        case .sensorState:
            
            cell.accessoryType = .none
            
            cell.textLabel?.text = Texts_Common.sensorStatus
            
            cell.detailTextLabel?.text = miaoMiao.sensorState.translatedDescription
            
        case .batteryLevel:
            
            cell.textLabel?.text = Texts_BluetoothPeripheralsView.batteryLevel
            if miaoMiao.batteryLevel > 0 {
                cell.detailTextLabel?.text = miaoMiao.batteryLevel.description + " %"
            } else {
                cell.detailTextLabel?.text = ""
            }
            cell.accessoryType = .none
            
        case .firmWare:
            
            cell.textLabel?.text = Texts_Common.firmware
            cell.detailTextLabel?.text = miaoMiao.firmware
            cell.accessoryType = .disclosureIndicator
            cell.accessoryView =  disclosureAccessoryView
            
        case .hardWare:
            
            cell.textLabel?.text = Texts_Common.hardware
            cell.detailTextLabel?.text = miaoMiao.hardware
            cell.accessoryType = .disclosureIndicator
            cell.accessoryView =  disclosureAccessoryView
            
        case .sensorSerialNumber:
            
            cell.textLabel?.text = Texts_BluetoothPeripheralView.sensorSerialNumber
            cell.detailTextLabel?.text = miaoMiao.blePeripheral.sensorSerialNumber
            cell.accessoryType = .disclosureIndicator
            cell.accessoryView =  disclosureAccessoryView
            
        }

    }
    
    func userDidSelectRow(withSettingRawValue rawValue: Int, forSection section: Int, for bluetoothPeripheral: BluetoothPeripheral, bluetoothPeripheralManager: BluetoothPeripheralManaging) -> SettingsSelectedRowAction {
        
        // verify that bluetoothPeripheral is a MiaoMiao
        guard let miaoMiao = bluetoothPeripheral as? MiaoMiao else {
            fatalError("MiaoMiaoBluetoothPeripheralViewModel userDidSelectRow, bluetoothPeripheral is not MiaoMiao")
        }
        
        guard let setting = Settings(rawValue: rawValue) else { fatalError("MiaoMiaoBluetoothPeripheralViewModel userDidSelectRow, unexpected setting") }
        
        switch setting {
            
        case .batteryLevel, .sensorType, .sensorState:
            return .nothing
            
        case .firmWare:
            
            // firmware text could be longer than screen width, clicking the row allos to see it in pop up with more text place
            if let firmware = miaoMiao.firmware {
                return .showInfoText(title: Texts_HomeView.info, message: Texts_Common.firmware + ": " + firmware)
            }

        case .hardWare:

            // hardware text could be longer than screen width, clicking the row allows to see it in pop up with more text place
            if let hardware = miaoMiao.hardware {
                return .showInfoText(title: Texts_HomeView.info, message: Texts_Common.hardware + ": " + hardware)
            }
            
        case .sensorSerialNumber:
            
            // serial text could be longer than screen width, clicking the row allows to see it in a pop up with more text place
            if let serialNumber = miaoMiao.blePeripheral.sensorSerialNumber {
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

// MARK: - conform to CGMMiaoMiaoTransmitterDelegate

extension MiaoMiaoBluetoothPeripheralViewModel: CGMMiaoMiaoTransmitterDelegate {
    
    func received(libreSensorType: LibreSensorType, from cGMMiaoMiaoTransmitter: CGMMiaoMiaoTransmitter) {
        
        // inform bluetoothPeripheralManager, bluetoothPeripheralManager will store the libreSensorType in the miaomiao object
        (bluetoothPeripheralManager as? CGMMiaoMiaoTransmitterDelegate)?.received(libreSensorType: libreSensorType, from: cGMMiaoMiaoTransmitter)
        
        // here's the trigger to update the table row for sensorType
        reloadRow(row: Settings.sensorType.rawValue)
        
    }
    
    func received(serialNumber: String, from cGMMiaoMiaoTransmitter: CGMMiaoMiaoTransmitter) {
        
        // inform also bluetoothPeripheralManager
        (bluetoothPeripheralManager as? CGMMiaoMiaoTransmitterDelegate)?.received(serialNumber: serialNumber, from: cGMMiaoMiaoTransmitter)
        
        // here's the trigger to update the table
        reloadRow(row: Settings.sensorSerialNumber.rawValue)
        
    }
    
    func received(batteryLevel: Int, from cGMMiaoMiaoTransmitter: CGMMiaoMiaoTransmitter) {
        
        // inform also bluetoothPeripheralManager
        (bluetoothPeripheralManager as? CGMMiaoMiaoTransmitterDelegate)?.received(batteryLevel: batteryLevel, from: cGMMiaoMiaoTransmitter)
        
        // here's the trigger to update the table
        reloadRow(row: Settings.batteryLevel.rawValue)

    }
    
    func received(sensorStatus: LibreSensorState, from cGMMiaoMiaoTransmitter: CGMMiaoMiaoTransmitter) {
        
        // inform also bluetoothPeripheralManager
        (bluetoothPeripheralManager as? CGMMiaoMiaoTransmitterDelegate)?.received(sensorStatus: sensorStatus, from: cGMMiaoMiaoTransmitter)
        
        // here's the trigger to update the table
        reloadRow(row: Settings.sensorState.rawValue)
        
    }

    func received(firmware: String, from cGMMiaoMiaoTransmitter: CGMMiaoMiaoTransmitter) {
        
        // inform also bluetoothPeripheralManager
        (bluetoothPeripheralManager as? CGMMiaoMiaoTransmitterDelegate)?.received(firmware: firmware, from: cGMMiaoMiaoTransmitter)
        
        // here's the trigger to update the table
        reloadRow(row: Settings.firmWare.rawValue)
        
    }
    
    func received(hardware: String, from cGMMiaoMiaoTransmitter: CGMMiaoMiaoTransmitter) {
        
        // inform also bluetoothPeripheralManager
        (bluetoothPeripheralManager as? CGMMiaoMiaoTransmitterDelegate)?.received(hardware: hardware, from: cGMMiaoMiaoTransmitter)
        
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
            let section = bluetoothPeripheralViewController.numberOfGeneralSections() + self.sectionNumberForMiaoMiaoSpecificSettings
            
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
