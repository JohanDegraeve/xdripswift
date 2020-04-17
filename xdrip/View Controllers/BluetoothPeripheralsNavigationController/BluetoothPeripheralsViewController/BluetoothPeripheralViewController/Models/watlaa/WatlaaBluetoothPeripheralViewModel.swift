import UIKit

class WatlaaBluetoothPeripheralViewModel {
    
    // MARK: - private properties
    
    /// settings specific for Watlaa
    private enum Settings:Int, CaseIterable {
        
        /// battery level
        case watlaaBatteryLevel = 0
        
        /// firmware version
        case firmWare = 1
        
        /// hardware version
        case hardWare = 2
        
        /// transmitter battery level
        case transmitterBatteryLevel = 3
        
        /// Sensor serial number
        case sensorSerialNumber = 4
        
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
    
    /// it's the bluetoothPeripheral as M5Stack
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
            
        case .firmWare:
            
            cell.textLabel?.text = Texts_Common.firmware
            cell.detailTextLabel?.text = watlaa.firmware
            cell.accessoryType = .disclosureIndicator
            
        case .hardWare:
            
            cell.textLabel?.text = Texts_Common.hardware
            cell.detailTextLabel?.text = watlaa.hardware
            cell.accessoryType = .disclosureIndicator
            
        case .sensorSerialNumber:
            
            cell.textLabel?.text = Texts_BluetoothPeripheralView.sensorSerialNumber
            cell.detailTextLabel?.text = watlaa.blePeripheral.sensorSerialNumber
            cell.accessoryType = .disclosureIndicator
            
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
        
        // verify that bluetoothPeripheral is a Watlaa
        guard let Watlaa = bluetoothPeripheral as? Watlaa else {
            fatalError("WatlaaBluetoothPeripheralViewModel userDidSelectRow, bluetoothPeripheral is not Watlaa")
        }
        
        guard let setting = Settings(rawValue: rawValue) else { fatalError("WatlaaBluetoothPeripheralViewModel userDidSelectRow, unexpected setting") }
        
        switch setting {
            
        case .watlaaBatteryLevel, .transmitterBatteryLevel:
            return .nothing
            
        case .firmWare:
            
            // firmware text could be longer than screen width, clicking the row allos to see it in pop up with more text place
            if let firmware = Watlaa.firmware {
                return .showInfoText(title: Texts_HomeView.info, message: Texts_Common.firmware + " : " + firmware)
            }
            
        case .hardWare:
            
            // hardware text could be longer than screen width, clicking the row allows to see it in pop up with more text place
            if let hardware = Watlaa.hardware {
                return .showInfoText(title: Texts_HomeView.info, message: Texts_Common.hardware + " : " + hardware)
            }
            
        case .sensorSerialNumber:
            
            // serial text could be longer than screen width, clicking the row allows to see it in a pop up with more text place
            if let serialNumber = Watlaa.blePeripheral.sensorSerialNumber {
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
        reloadRow(row: Settings.sensorSerialNumber.rawValue)
        
    }
    
    private func reloadRow(row: Int) {
        
        if let bluetoothPeripheralViewController = bluetoothPeripheralViewController {
            
            tableView?.reloadRows(at: [IndexPath(row: row, section: bluetoothPeripheralViewController.numberOfGeneralSections() + sectionNumberForWatlaaSpecificSettings)], with: .none)
            
        }
    }
    
}
