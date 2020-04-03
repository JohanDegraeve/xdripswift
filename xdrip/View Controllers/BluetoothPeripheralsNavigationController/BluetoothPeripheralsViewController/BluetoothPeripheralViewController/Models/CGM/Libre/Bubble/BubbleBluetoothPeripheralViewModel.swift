import UIKit

class BubbleBluetoothPeripheralViewModel {
    
    // MARK: - private properties
    
    /// settings specific for bubble
    private enum Settings:Int, CaseIterable {
        
        /// battery level
        case batteryLevel = 0
        
        /// firmware version
        case firmWare = 1
        
        /// hardware version
        case hardWare = 2
        
        /// Sensor serial number
        case sensorSerialNumber = 3
        
    }
    
    /// Bubble settings willb be in section 0 + numberOfGeneralSections
    private let sectionNumberForBubbleSpecificSettings = 0
    
    /// reference to bluetoothPeripheralManager
    private weak var bluetoothPeripheralManager: BluetoothPeripheralManaging?
    
    /// reference to the tableView
    private weak var tableView: UITableView?
    
    /// reference to BluetoothPeripheralViewController that will own this WatlaaMasterBluetoothPeripheralViewModel - needed to present stuff etc
    private weak var bluetoothPeripheralViewController: BluetoothPeripheralViewController?
    
    /// temporary reference to bluetoothPerpipheral, will be set in configure function.
    private var bluetoothPeripheral: BluetoothPeripheral?
    
    /// it's the bluetoothPeripheral as M5Stack
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

    func canWebOOP() -> Bool {
        return CGMTransmitterType.Bubble.canWebOOP()
    }
    
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
            
        case .hardWare:
            
            cell.textLabel?.text = Texts_Common.hardware
            cell.detailTextLabel?.text = bubble.hardware
            cell.accessoryType = .disclosureIndicator
            
        case .sensorSerialNumber:
            
            cell.textLabel?.text = Texts_BluetoothPeripheralView.sensorSerialNumber
            cell.detailTextLabel?.text = bubble.blePeripheral.sensorSerialNumber
            cell.accessoryType = .disclosureIndicator
            
        }

    }
    
    func userDidSelectRow(withSettingRawValue rawValue: Int, forSection section: Int, for bluetoothPeripheral: BluetoothPeripheral, bluetoothPeripheralManager: BluetoothPeripheralManaging) -> SettingsSelectedRowAction {
        
        // verify that bluetoothPeripheral is a Bubble
        guard let bubble = bluetoothPeripheral as? Bubble else {
            fatalError("BubbleBluetoothPeripheralViewModel userDidSelectRow, bluetoothPeripheral is not Bubble")
        }
        
        guard let setting = Settings(rawValue: rawValue) else { fatalError("BubbleBluetoothPeripheralViewModel userDidSelectRow, unexpected setting") }
        
        switch setting {
            
        case .batteryLevel:
            return .nothing
            
        case .firmWare:
            
            // firmware text could be longer than screen width, clicking the row allos to see it in pop up with more text place
            if let firmware = bubble.firmware {
                return .showInfoText(title: Texts_HomeView.info, message: Texts_Common.firmware + " : " + firmware)
            }

        case .hardWare:

            // hardware text could be longer than screen width, clicking the row allows to see it in pop up with more text place
            if let hardware = bubble.hardware {
                return .showInfoText(title: Texts_HomeView.info, message: Texts_Common.hardware + " : " + hardware)
            }
            
        case .sensorSerialNumber:
            
            // serial text could be longer than screen width, clicking the row allows to see it in a pop up with more text place
            if let serialNumber = bubble.blePeripheral.sensorSerialNumber {
                return .showInfoText(title: Texts_HomeView.info, message: Texts_BluetoothPeripheralView.sensorSerialNumber + " : " + serialNumber)
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
        
        // inform also bluetoothPeripheralManager
        (bluetoothPeripheralManager as? CGMBubbleTransmitterDelegate)?.received(hardware: hardware, from: cGMBubbleTransmitter)
        
        // here's the trigger to update the table
        reloadRow(row: Settings.hardWare.rawValue)
        
    }
    
    private func reloadRow(row: Int) {
        
        if let bluetoothPeripheralViewController = bluetoothPeripheralViewController {
            
            tableView?.reloadRows(at: [IndexPath(row: row, section: bluetoothPeripheralViewController.numberOfGeneralSections() + sectionNumberForBubbleSpecificSettings)], with: .none)
        
        }
    }
    
}
