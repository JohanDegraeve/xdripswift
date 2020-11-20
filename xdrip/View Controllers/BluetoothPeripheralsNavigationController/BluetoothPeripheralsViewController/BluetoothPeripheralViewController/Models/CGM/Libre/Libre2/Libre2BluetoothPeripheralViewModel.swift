import UIKit

class Libre2BluetoothPeripheralViewModel {
  
    /// settings specific for Libre2
    private enum Settings: Int, CaseIterable {
        
        /// battery level
        case batteryLevel = 0

    }
    
    /// Libre2 settings willb be in section 0 + numberOfGeneralSections
    private let sectionNumberForLibre2SpecificSettings = 0
    
    /// reference to bluetoothPeripheralManager
    private weak var bluetoothPeripheralManager: BluetoothPeripheralManaging?
    
    /// reference to the tableView
    private weak var tableView: UITableView?
    
    /// reference to BluetoothPeripheralViewController that will own this Libre2BluetoothPeripheralViewModel - needed to present stuff etc
    private weak var bluetoothPeripheralViewController: BluetoothPeripheralViewController?
    
    /// temporary reference to bluetoothPerpipheral, will be set in configure function.
    private var bluetoothPeripheral: BluetoothPeripheral?

    /// it's the bluetoothPeripheral as M5Stack
    private var libre2: Libre2? {
        get {
            return bluetoothPeripheral as? Libre2
        }
    }

    // MARK: - deinit
    
    deinit {
        
        // when closing the viewModel, and if there's still a bluetoothTransmitter existing, then reset the specific delegate to BluetoothPeripheralManager
        
        guard let bluetoothPeripheralManager = bluetoothPeripheralManager else {return}
        
        guard let libre2 = libre2 else {return}
        
        guard let blueToothTransmitter = bluetoothPeripheralManager.getBluetoothTransmitter(for: libre2, createANewOneIfNecesssary: false) else {return}
        
        guard let cGMLibre2BluetoothTransmitter = blueToothTransmitter as? CGMLibre2Transmitter else {return}
        
        cGMLibre2BluetoothTransmitter.cGMLibre2TransmitterDelegate = bluetoothPeripheralManager as! BluetoothPeripheralManager
        
    }

}

// MARK: - conform to BluetoothPeripheralViewModel

extension Libre2BluetoothPeripheralViewModel: BluetoothPeripheralViewModel {
    
    func configure(bluetoothPeripheral: BluetoothPeripheral?, bluetoothPeripheralManager: BluetoothPeripheralManaging, tableView: UITableView, bluetoothPeripheralViewController: BluetoothPeripheralViewController, onLibreSensorTypeReceived: ((LibreSensorType) -> ())?) {
        
        // this type of transmitter does not receive libre sensor types, so the closure onLibreSensorTypeReceived does not need to be stored
        
        self.bluetoothPeripheralManager = bluetoothPeripheralManager
        
        self.tableView = tableView
        
        self.bluetoothPeripheralViewController = bluetoothPeripheralViewController
        
        self.bluetoothPeripheral = bluetoothPeripheral
        
        if let bluetoothPeripheral = bluetoothPeripheral {
            
            if let droplet = bluetoothPeripheral as? Libre2 {
                
                if let blueToothTransmitter = bluetoothPeripheralManager.getBluetoothTransmitter(for: droplet, createANewOneIfNecesssary: false), let cGMLibre2Transmitter = blueToothTransmitter as? CGMLibre2Transmitter {
                    
                    // set CGMLibre2Transmitter delegate to self.
                    cGMLibre2Transmitter.cGMLibre2TransmitterDelegate = self
                    
                }
                
            } else {
                fatalError("in Libre2BluetoothPeripheralViewModel, configure. bluetoothPeripheral is not Libre2")
            }
        }
        
    }
    
    func screenTitle() -> String {
        return BluetoothPeripheralType.Libre2Type.rawValue
    }
    
    func sectionTitle(forSection section: Int) -> String {
        return BluetoothPeripheralType.Libre2Type.rawValue
    }
    
    func update(cell: UITableViewCell, forRow rawValue: Int, forSection section: Int, for bluetoothPeripheral: BluetoothPeripheral) {
        
        // verify that bluetoothPeripheral is a Libre2
        /*guard let Libre2 = bluetoothPeripheral as? Libre2 else {
            fatalError("Libre2BluetoothPeripheralViewModel update, bluetoothPeripheral is not Libre2")
        }*/
        
        // default value for accessoryView is nil
        cell.accessoryView = nil
        
        guard let setting = Settings(rawValue: rawValue) else { fatalError("Libre2BluetoothPeripheralViewModel update, unexpected setting") }
        
        switch setting {
            
        case .batteryLevel:
            
            cell.textLabel?.text = Texts_BluetoothPeripheralsView.batteryLevel

            // not yet supported, can we get the battery level for Libre 2 ?
            cell.detailTextLabel?.text = ""

            cell.accessoryType = .none
            
        }
        
    }
    
    func userDidSelectRow(withSettingRawValue rawValue: Int, forSection section: Int, for bluetoothPeripheral: BluetoothPeripheral, bluetoothPeripheralManager: BluetoothPeripheralManaging) -> SettingsSelectedRowAction {
        
        guard let setting = Settings(rawValue: rawValue) else { fatalError("Libre2BluetoothPeripheralViewModel userDidSelectRow, unexpected setting") }
        
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

extension Libre2BluetoothPeripheralViewModel: CGMLibre2TransmitterDelegate {
    
}

