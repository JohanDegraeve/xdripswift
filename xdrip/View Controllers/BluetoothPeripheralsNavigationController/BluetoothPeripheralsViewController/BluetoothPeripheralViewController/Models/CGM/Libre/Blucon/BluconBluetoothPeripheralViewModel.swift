import UIKit

class BluconBluetoothPeripheralViewModel {
    
    // MARK: - private properties
    
    /// settings specific for blucon
    private enum Settings:Int, CaseIterable {
        
        /// battery level
        case batteryLevel = 0
        
        /// Sensor serial number
        case sensorSerialNumber = 1
        
    }
    
    /// Blucon settings willb be in section 0 + numberOfGeneralSections
    private let sectionNumberForBluconSpecificSettings = 0
    
    /// reference to bluetoothPeripheralManager
    private weak var bluetoothPeripheralManager: BluetoothPeripheralManaging?
    
    /// reference to the tableView
    private weak var tableView: UITableView?
    
    /// reference to BluetoothPeripheralViewController that will own this BluconBluetoothPeripheralViewModel - needed to present stuff etc
    private weak var bluetoothPeripheralViewController: BluetoothPeripheralViewController?
    
    /// temporary reference to bluetoothPerpipheral, will be set in configure function.
    private var bluetoothPeripheral: BluetoothPeripheral?
    
    /// it's the bluetoothPeripheral as M5Stack
    private var blucon: Blucon? {
        get {
            return bluetoothPeripheral as? Blucon
        }
    }
    
    // MARK: - deinit
    
    deinit {

        // when closing the viewModel, and if there's still a bluetoothTransmitter existing, then reset the specific delegate to BluetoothPeripheralManager
        
        guard let bluetoothPeripheralManager = bluetoothPeripheralManager else {return}
        
        guard let blucon = blucon else {return}
        
        guard let blueToothTransmitter = bluetoothPeripheralManager.getBluetoothTransmitter(for: blucon, createANewOneIfNecesssary: false) else {return}
        
        guard let cGMBluconBluetoothTransmitter = blueToothTransmitter as? CGMBluconTransmitter else {return}
        
        cGMBluconBluetoothTransmitter.cGMBluconTransmitterDelegate = bluetoothPeripheralManager as! BluetoothPeripheralManager

    }
    
}

// MARK: - conform to BluetoothPeripheralViewModel

extension BluconBluetoothPeripheralViewModel: BluetoothPeripheralViewModel {

    func configure(bluetoothPeripheral: BluetoothPeripheral?, bluetoothPeripheralManager: BluetoothPeripheralManaging, tableView: UITableView, bluetoothPeripheralViewController: BluetoothPeripheralViewController, onLibreSensorTypeReceived: ((LibreSensorType) -> ())?) {
        
        // this type of transmitter does not receive libre sensor types, so the closure onLibreSensorTypeReceived does not need to be stored
        
        self.bluetoothPeripheralManager = bluetoothPeripheralManager
        
        self.tableView = tableView
        
        self.bluetoothPeripheralViewController = bluetoothPeripheralViewController
        
        self.bluetoothPeripheral = bluetoothPeripheral
        
        if let bluetoothPeripheral = bluetoothPeripheral {
            
            if let blucon = bluetoothPeripheral as? Blucon {
                
                if let blueToothTransmitter = bluetoothPeripheralManager.getBluetoothTransmitter(for: blucon, createANewOneIfNecesssary: false), let cGMBluconTransmitter = blueToothTransmitter as? CGMBluconTransmitter {
                    
                    // set CGMBluconTransmitter delegate to self.
                    cGMBluconTransmitter.cGMBluconTransmitterDelegate = self
                    
                }
                
            } else {
                fatalError("in BluconBluetoothPeripheralViewModel, configure. bluetoothPeripheral is not Blucon")
            }
        }

    }
    
    func screenTitle() -> String {
        return BluetoothPeripheralType.BluconType.rawValue
    }
    
    func sectionTitle(forSection section: Int) -> String {
        return BluetoothPeripheralType.BluconType.rawValue
    }
    
    func update(cell: UITableViewCell, forRow rawValue: Int, forSection section: Int, for bluetoothPeripheral: BluetoothPeripheral) {
        
        // verify that bluetoothPeripheral is a Blucon
        guard let blucon = bluetoothPeripheral as? Blucon else {
            fatalError("BluconBluetoothPeripheralViewModel update, bluetoothPeripheral is not Blucon")
        }
        
        // default value for accessoryView is nil
        cell.accessoryView = nil
        
        guard let setting = Settings(rawValue: rawValue) else { fatalError("BluconBluetoothPeripheralViewModel update, unexpected setting") }
        
        switch setting {
            
        case .batteryLevel:
            
            cell.textLabel?.text = Texts_BluetoothPeripheralsView.batteryLevel
            if blucon.batteryLevel > 0 {
                cell.detailTextLabel?.text = blucon.batteryLevel.description + " %"
            } else {
                cell.detailTextLabel?.text = ""
            }
            cell.accessoryType = .none
            
        case .sensorSerialNumber:
            
            cell.textLabel?.text = Texts_BluetoothPeripheralView.sensorSerialNumber
            cell.detailTextLabel?.text = blucon.blePeripheral.sensorSerialNumber
            cell.accessoryType = .disclosureIndicator
            
        }

    }
    
    func userDidSelectRow(withSettingRawValue rawValue: Int, forSection section: Int, for bluetoothPeripheral: BluetoothPeripheral, bluetoothPeripheralManager: BluetoothPeripheralManaging) -> SettingsSelectedRowAction {
        
        // verify that bluetoothPeripheral is a Blucon
        guard let blucon = bluetoothPeripheral as? Blucon else {
            fatalError("BluconBluetoothPeripheralViewModel userDidSelectRow, bluetoothPeripheral is not Blucon")
        }
        
        guard let setting = Settings(rawValue: rawValue) else { fatalError("BluconBluetoothPeripheralViewModel userDidSelectRow, unexpected setting") }
        
        switch setting {
            
        case .batteryLevel:
            return .nothing
            
        case .sensorSerialNumber:
            
            // serial text could be longer than screen width, clicking the row allows to see it in a pop up with more text place
            if let serialNumber = blucon.blePeripheral.sensorSerialNumber {
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

// MARK: - conform to CGMBluconTransmitterDelegate

extension BluconBluetoothPeripheralViewModel: CGMBluconTransmitterDelegate {
    
    func received(batteryLevel: Int, from cGMBluconTransmitter: CGMBluconTransmitter) {
        
        // inform also bluetoothPeripheralManager
        (bluetoothPeripheralManager as? CGMBluconTransmitterDelegate)?.received(batteryLevel: batteryLevel, from: cGMBluconTransmitter)
        
        // here's the trigger to update the table
        reloadRow(row: Settings.batteryLevel.rawValue)

    }
    
    func received(serialNumber: String?, from cGMBluconTransmitter: CGMBluconTransmitter) {
        
        // inform also bluetoothPeripheralManager
        (bluetoothPeripheralManager as? CGMBluconTransmitterDelegate)?.received(serialNumber: serialNumber, from: cGMBluconTransmitter)
     
        // here's the trigger to update the table
        reloadRow(row: Settings.sensorSerialNumber.rawValue)

    }
    
    private func reloadRow(row: Int) {
        
        if let bluetoothPeripheralViewController = bluetoothPeripheralViewController {
            
            tableView?.reloadRows(at: [IndexPath(row: row, section: bluetoothPeripheralViewController.numberOfGeneralSections() + sectionNumberForBluconSpecificSettings)], with: .none)
        
        }
    }
    
}
