import UIKit

class BubbleBluetoothPeripheralViewModel {
    
    // MARK: - private properties
    
    /// settings specific for bubble
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
    
    /// Bubble settings willb be in section 0 + numberOfGeneralSections
    private let sectionNumberForBubbleSpecificSettings = 0
    
    /// reference to bluetoothPeripheralManager
    private weak var bluetoothPeripheralManager: BluetoothPeripheralManaging?
    
    /// reference to the tableView
    private weak var tableView: UITableView?
    
    /// reference to BluetoothPeripheralViewController that will own this BubbleBluetoothPeripheralViewModel - needed to present stuff etc
    private weak var bluetoothPeripheralViewController: BluetoothPeripheralViewController?
    
    /// temporary reference to bluetoothPerpipheral, will be set in configure function.
    private var bluetoothPeripheral: BluetoothPeripheral?
    
    /// it's the bluetoothPeripheral as Bubble
    private var bubble: Bubble? {
        get {
            return bluetoothPeripheral as? Bubble
        }
    }
    
    // MARK: - deinit
    
    deinit {

        // when closing the viewModel, and if there's still a bluetoothTransmitter existing, then reset the specific delegate to BluetoothPeripheralManager
        
        guard let bluetoothPeripheralManager = bluetoothPeripheralManager else {return}
        
        guard let bubble = bubble else {return}
        
        guard let blueToothTransmitter = bluetoothPeripheralManager.getBluetoothTransmitter(for: bubble, createANewOneIfNecesssary: false) else {return}
        
        guard let cGMBubbleBluetoothTransmitter = blueToothTransmitter as? CGMBubbleTransmitter else {return}
        
        cGMBubbleBluetoothTransmitter.cGMBubbleTransmitterDelegate = bluetoothPeripheralManager as! BluetoothPeripheralManager

    }
    
}

// MARK: - conform to BluetoothPeripheralViewModel

extension BubbleBluetoothPeripheralViewModel: BluetoothPeripheralViewModel {

    func configure(bluetoothPeripheral: BluetoothPeripheral?, bluetoothPeripheralManager: BluetoothPeripheralManaging, tableView: UITableView, bluetoothPeripheralViewController: BluetoothPeripheralViewController) {
        
        self.bluetoothPeripheralManager = bluetoothPeripheralManager
        
        self.tableView = tableView
        
        self.bluetoothPeripheralViewController = bluetoothPeripheralViewController
        
        self.bluetoothPeripheral = bluetoothPeripheral
        
        if let bluetoothPeripheral = bluetoothPeripheral {
            
            if let bubble = bluetoothPeripheral as? Bubble {
                
                if let blueToothTransmitter = bluetoothPeripheralManager.getBluetoothTransmitter(for: bubble, createANewOneIfNecesssary: false), let cGMBubbleTransmitter = blueToothTransmitter as? CGMBubbleTransmitter {
                    
                    // set CGMBubbleTransmitter delegate to self.
                    cGMBubbleTransmitter.cGMBubbleTransmitterDelegate = self
                    
                }
                
            } else {
                fatalError("in BubbleBluetoothPeripheralViewModel, configure. bluetoothPeripheral is not Bubble")
            }
        }

    }
    
    func screenTitle() -> String {
        return BluetoothPeripheralType.BubbleType.rawValue
    }
    
    func sectionTitle(forSection section: Int) -> String {
        return BluetoothPeripheralType.BubbleType.rawValue
    }
    
    func update(cell: UITableViewCell, forRow rawValue: Int, forSection section: Int, for bluetoothPeripheral: BluetoothPeripheral) {
        
        // verify that bluetoothPeripheral is a Bubble
        guard let bubble = bluetoothPeripheral as? Bubble else {
            fatalError("BubbleBluetoothPeripheralViewModel update, bluetoothPeripheral is not Bubble")
        }
        
        // default value for accessoryView is nil
        cell.accessoryView = nil

        // create disclosureIndicator in color ConstantsUI.disclosureIndicatorColor
        // will be used whenever accessoryType is to be set to disclosureIndicator
        let  disclosureAccessoryView = DTCustomColoredAccessory(color: ConstantsUI.disclosureIndicatorColor)

        guard let setting = Settings(rawValue: rawValue) else { fatalError("BubbleBluetoothPeripheralViewModel update, unexpected setting") }
        
        switch setting {
            
        case .batteryLevel:
            
            cell.textLabel?.text = Texts_BluetoothPeripheralsView.batteryLevel
            if bubble.batteryLevel > 0 {
                cell.detailTextLabel?.text = bubble.batteryLevel.description + " %"
            } else {
                cell.detailTextLabel?.text = ""
            }
            cell.accessoryType = .none
            
        case .firmWare:
            
            cell.textLabel?.text = Texts_Common.firmware
            cell.detailTextLabel?.text = bubble.firmware
            cell.accessoryType = .disclosureIndicator
            cell.accessoryView =  disclosureAccessoryView
            
        case .hardWare:
            
            cell.textLabel?.text = Texts_Common.hardware
            cell.detailTextLabel?.text = bubble.hardware
            cell.accessoryType = .disclosureIndicator
            cell.accessoryView =  disclosureAccessoryView
            
        case .sensorSerialNumber:
            
            cell.textLabel?.text = Texts_BluetoothPeripheralView.sensorSerialNumber
            if let sensorSerialNumber = bubble.blePeripheral.sensorSerialNumber {

                cell.detailTextLabel?.text = sensorSerialNumber
                cell.accessoryType = .disclosureIndicator
                cell.accessoryView =  disclosureAccessoryView
                
            } else {
                
                cell.detailTextLabel?.text = Texts_Common.unknown
                cell.accessoryType = .none
                
            }
            
            
        case .sensorType:
            
            cell.accessoryType = .none
            
            cell.textLabel?.text = Texts_BluetoothPeripheralView.sensorType
            
            if let libreSensorType = bubble.blePeripheral.libreSensorType {
                
                cell.detailTextLabel?.text = libreSensorType.description
                
            } else {
                
                cell.detailTextLabel?.text = nil
            }
            
        case .sensorState:
            
            cell.accessoryType = .none
            
            cell.textLabel?.text = Texts_Common.sensorStatus
            
            cell.detailTextLabel?.text = bubble.sensorState.translatedDescription
            
        }

    }
    
    func userDidSelectRow(withSettingRawValue rawValue: Int, forSection section: Int, for bluetoothPeripheral: BluetoothPeripheral, bluetoothPeripheralManager: BluetoothPeripheralManaging) -> SettingsSelectedRowAction {
        
        // verify that bluetoothPeripheral is a Bubble
        guard let bubble = bluetoothPeripheral as? Bubble else {
            fatalError("BubbleBluetoothPeripheralViewModel userDidSelectRow, bluetoothPeripheral is not Bubble")
        }
        
        guard let setting = Settings(rawValue: rawValue) else { fatalError("BubbleBluetoothPeripheralViewModel userDidSelectRow, unexpected setting") }
        
        switch setting {
            
        case .batteryLevel, .sensorType, .sensorState:
            return .nothing
            
        case .firmWare:
            
            // firmware text could be longer than screen width, clicking the row allos to see it in pop up with more text place
            if let firmware = bubble.firmware {
                return .showInfoText(title: Texts_HomeView.info, message: Texts_Common.firmware + ": " + firmware)
            }

        case .hardWare:

            // hardware text could be longer than screen width, clicking the row allows to see it in pop up with more text place
            if let hardware = bubble.hardware {
                return .showInfoText(title: Texts_HomeView.info, message: Texts_Common.hardware + ": " + hardware)
            }
            
        case .sensorSerialNumber:
            
            // serial text could be longer than screen width, clicking the row allows to see it in a pop up with more text place
            if let serialNumber = bubble.blePeripheral.sensorSerialNumber {
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

// MARK: - conform to CGMBubbleTransmitterDelegate

extension BubbleBluetoothPeripheralViewModel: CGMBubbleTransmitterDelegate {
    
    func received(batteryLevel: Int, from cGMBubbleTransmitter: CGMBubbleTransmitter) {
        
        // inform also bluetoothPeripheralManager
        (bluetoothPeripheralManager as? CGMBubbleTransmitterDelegate)?.received(batteryLevel: batteryLevel, from: cGMBubbleTransmitter)
        
        // here's the trigger to update the table
        reloadRow(row: Settings.batteryLevel.rawValue)

    }
    
    func received(sensorStatus: LibreSensorState, from cGMBubbleTransmitter: CGMBubbleTransmitter) {
        
        // inform also bluetoothPeripheralManager
        (bluetoothPeripheralManager as? CGMBubbleTransmitterDelegate)?.received(sensorStatus: sensorStatus, from: cGMBubbleTransmitter)
        
        // here's the trigger to update the table
        reloadRow(row: Settings.sensorState.rawValue)
        
    }
    
    func received(serialNumber: String, from cGMBubbleTransmitter: CGMBubbleTransmitter) {
        
        // inform also bluetoothPeripheralManager
        (bluetoothPeripheralManager as? CGMBubbleTransmitterDelegate)?.received(serialNumber: serialNumber, from: cGMBubbleTransmitter)
     
        // here's the trigger to update the table
        reloadRow(row: Settings.sensorSerialNumber.rawValue)

    }
    
    func received(firmware: String, from cGMBubbleTransmitter: CGMBubbleTransmitter) {
        
        // inform also bluetoothPeripheralManager
        (bluetoothPeripheralManager as? CGMBubbleTransmitterDelegate)?.received(firmware: firmware, from: cGMBubbleTransmitter)
        
        // here's the trigger to update the table
        reloadRow(row: Settings.firmWare.rawValue)
        
    }
    
    func received(hardware: String, from cGMBubbleTransmitter: CGMBubbleTransmitter) {
        
        // inform bluetoothPeripheralManager, bluetoothPeripheralManager will store the hardware in the bubble object
        (bluetoothPeripheralManager as? CGMBubbleTransmitterDelegate)?.received(hardware: hardware, from: cGMBubbleTransmitter)
        
        // here's the trigger to update the table
        reloadRow(row: Settings.hardWare.rawValue)
        
    }
    
    func received(libreSensorType: LibreSensorType, from cGMBubbleTransmitter: CGMBubbleTransmitter) {
        
        // inform bluetoothPeripheralManager, bluetoothPeripheralManager will store the libreSensorType in the bubble object
        (bluetoothPeripheralManager as? CGMBubbleTransmitterDelegate)?.received(libreSensorType: libreSensorType, from: cGMBubbleTransmitter)

        // here's the trigger to update the table row for sensorType
        reloadRow(row: Settings.sensorType.rawValue)
        
    }
    
    private func reloadRow(row: Int) {
        DispatchQueue.main.async {
            guard let tableView = self.tableView,
                  let bluetoothPeripheralViewController = self.bluetoothPeripheralViewController else { return }

            // Always reload the general section (0) first, because its row count may have changed.
            tableView.reloadSections(IndexSet(integer: 0), with: .none)
            
            let totalSections = tableView.numberOfSections
            let section = bluetoothPeripheralViewController.numberOfGeneralSections() + self.sectionNumberForBubbleSpecificSettings
            
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
