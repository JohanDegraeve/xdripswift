import UIKit

class DropletBluetoothPeripheralViewModel {
    
    // MARK: - private properties
    
    /// settings specific for Droplet
    private enum Settings:Int, CaseIterable {
        
        /// battery level
        case batteryLevel = 0
        
    }
    
    /// Droplet settings willb be in section 0 + numberOfGeneralSections
    private let sectionNumberForDropletSpecificSettings = 0
    
    /// reference to bluetoothPeripheralManager
    private weak var bluetoothPeripheralManager: BluetoothPeripheralManaging?
    
    /// reference to the tableView
    private weak var tableView: UITableView?
    
    /// reference to BluetoothPeripheralViewController that will own this DropletBluetoothPeripheralViewModel - needed to present stuff etc
    private weak var bluetoothPeripheralViewController: BluetoothPeripheralViewController?
    
    /// temporary reference to bluetoothPerpipheral, will be set in configure function.
    private var bluetoothPeripheral: BluetoothPeripheral?
    
    /// it's the bluetoothPeripheral as M5Stack
    private var Droplet: Droplet? {
        get {
            return bluetoothPeripheral as? Droplet
        }
    }
    
    // MARK: - deinit
    
    deinit {
        
        // when closing the viewModel, and if there's still a bluetoothTransmitter existing, then reset the specific delegate to BluetoothPeripheralManager
        
        guard let bluetoothPeripheralManager = bluetoothPeripheralManager else {return}
        
        guard let Droplet = Droplet else {return}
        
        guard let blueToothTransmitter = bluetoothPeripheralManager.getBluetoothTransmitter(for: Droplet, createANewOneIfNecesssary: false) else {return}
        
        guard let cGMDropletBluetoothTransmitter = blueToothTransmitter as? CGMDroplet1Transmitter else {return}
        
        cGMDropletBluetoothTransmitter.cGMDropletTransmitterDelegate = bluetoothPeripheralManager as! BluetoothPeripheralManager
        
    }
    
}

// MARK: - conform to BluetoothPeripheralViewModel

extension DropletBluetoothPeripheralViewModel: BluetoothPeripheralViewModel {
    
    func configure(bluetoothPeripheral: BluetoothPeripheral?, bluetoothPeripheralManager: BluetoothPeripheralManaging, tableView: UITableView, bluetoothPeripheralViewController: BluetoothPeripheralViewController, onLibreSensorTypeReceived: ((LibreSensorType) -> ())?) {
        
        // this type of transmitter does not receive libre sensor types, so the closure onLibreSensorTypeReceived does not need to be stored
        
        self.bluetoothPeripheralManager = bluetoothPeripheralManager
        
        self.tableView = tableView
        
        self.bluetoothPeripheralViewController = bluetoothPeripheralViewController
        
        self.bluetoothPeripheral = bluetoothPeripheral
        
        if let bluetoothPeripheral = bluetoothPeripheral {
            
            if let droplet = bluetoothPeripheral as? Droplet {
                
                if let blueToothTransmitter = bluetoothPeripheralManager.getBluetoothTransmitter(for: droplet, createANewOneIfNecesssary: false), let cGMDropletTransmitter = blueToothTransmitter as? CGMDroplet1Transmitter {
                    
                    // set CGMDropletTransmitter delegate to self.
                    cGMDropletTransmitter.cGMDropletTransmitterDelegate = self
                    
                }
                
            } else {
                fatalError("in DropletBluetoothPeripheralViewModel, configure. bluetoothPeripheral is not Droplet")
            }
        }
        
    }
    
    func screenTitle() -> String {
        return BluetoothPeripheralType.DropletType.rawValue
    }
    
    func sectionTitle(forSection section: Int) -> String {
        return BluetoothPeripheralType.DropletType.rawValue
    }
    
    func update(cell: UITableViewCell, forRow rawValue: Int, forSection section: Int, for bluetoothPeripheral: BluetoothPeripheral) {
        
        // verify that bluetoothPeripheral is a Droplet
        guard let Droplet = bluetoothPeripheral as? Droplet else {
            fatalError("DropletBluetoothPeripheralViewModel update, bluetoothPeripheral is not Droplet")
        }
        
        // default value for accessoryView is nil
        cell.accessoryView = nil
        
        guard let setting = Settings(rawValue: rawValue) else { fatalError("DropletBluetoothPeripheralViewModel update, unexpected setting") }
        
        switch setting {
            
        case .batteryLevel:
            
            cell.textLabel?.text = Texts_BluetoothPeripheralsView.batteryLevel
            if Droplet.batteryLevel > 0 {
                cell.detailTextLabel?.text = Droplet.batteryLevel.description + " %"
            } else {
                cell.detailTextLabel?.text = ""
            }
            cell.accessoryType = .none
            
        }
        
    }
    
    func userDidSelectRow(withSettingRawValue rawValue: Int, forSection section: Int, for bluetoothPeripheral: BluetoothPeripheral, bluetoothPeripheralManager: BluetoothPeripheralManaging) -> SettingsSelectedRowAction {
        
        guard let setting = Settings(rawValue: rawValue) else { fatalError("DropletBluetoothPeripheralViewModel userDidSelectRow, unexpected setting") }
        
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

// MARK: - conform to CGMDropletTransmitterDelegate

extension DropletBluetoothPeripheralViewModel: CGMDropletTransmitterDelegate {
    
    func received(batteryLevel: Int, from cGMDropletTransmitter: CGMDroplet1Transmitter) {
        
        // inform also bluetoothPeripheralManager
        (bluetoothPeripheralManager as? CGMDropletTransmitterDelegate)?.received(batteryLevel: batteryLevel, from: cGMDropletTransmitter)
        
        // here's the trigger to update the table
        reloadRow(row: Settings.batteryLevel.rawValue)
        
    }
    
    private func reloadRow(row: Int) {
        
        if let bluetoothPeripheralViewController = bluetoothPeripheralViewController {
            
            tableView?.reloadRows(at: [IndexPath(row: row, section: bluetoothPeripheralViewController.numberOfGeneralSections() + sectionNumberForDropletSpecificSettings)], with: .none)
            
        }
    }
    
}
