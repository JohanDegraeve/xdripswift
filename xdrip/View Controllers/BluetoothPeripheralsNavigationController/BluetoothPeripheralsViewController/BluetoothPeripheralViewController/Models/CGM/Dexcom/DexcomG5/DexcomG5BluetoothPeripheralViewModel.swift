import Foundation
import UIKit
import CoreBluetooth

class DexcomG5BluetoothPeripheralViewModel {
    // 't is hier dat de transmitter id die gekozen werd door gebruiker, moet toegevoegd worden
    
    // MARK: - private properties
    
    /// settings specific for Dexcom G5
    private enum Settings:Int, CaseIterable {
        
        /// firmware version
        case firmWareVersion = 0
        
    }
    
    private enum TransmitterBatteryInfoSettings: Int, CaseIterable {
        
        case voltageA = 0
        
        case voltageB = 1
        
        case batteryRuntime = 2
        
        case batteryTemperature = 3

        case batteryResist = 4

    }
    
    /// reference to bluetoothPeripheralManager
    private weak var bluetoothPeripheralManager: BluetoothPeripheralManaging?
    
    /// reference to the tableView
    private weak var tableView: UITableView?
    
    /// reference to BluetoothPeripheralViewController that will own this WatlaaMasterBluetoothPeripheralViewModel - needed to present stuff etc
    private weak var bluetoothPeripheralViewController: BluetoothPeripheralViewController?
    
    /// temporary reference to bluetoothPerpipheral, will be set in configure function.
    private var bluetoothPeripheral: BluetoothPeripheral?
    
    /// it's the bluetoothPeripheral as M5Stack
    private var dexcomG5: DexcomG5? {
        get {
            return bluetoothPeripheral as? DexcomG5
        }
    }
    
    // MARK: - deinit
    
    deinit {
        
        // when closing the viewModel, and if there's still a bluetoothTransmitter existing, then reset the specific delegate to BluetoothPeripheralManager
        
        guard let bluetoothPeripheralManager = bluetoothPeripheralManager else {return}
        
        guard let dexcomG5 = dexcomG5 else {return}
        
        guard let blueToothTransmitter = bluetoothPeripheralManager.getBluetoothTransmitter(for: dexcomG5, createANewOneIfNecesssary: false) else {return}
        
        guard let cGMG5Transmitter = blueToothTransmitter as? CGMG5Transmitter else {return}
        
        cGMG5Transmitter.cGMG5TransmitterDelegate = bluetoothPeripheralManager as! BluetoothPeripheralManager
        
    }

}

// MARK: - conform to BluetoothPeripheralViewModel

extension DexcomG5BluetoothPeripheralViewModel: BluetoothPeripheralViewModel {
    
    func canWebOOP() -> Bool {
        // web oop only applicable to cgm transmitters and DexcomG5 is not a cgm transmitter
        return false
    }

    func configure(bluetoothPeripheral: BluetoothPeripheral?, bluetoothPeripheralManager: BluetoothPeripheralManaging, tableView: UITableView, bluetoothPeripheralViewController: BluetoothPeripheralViewController) {
        
        self.bluetoothPeripheralManager = bluetoothPeripheralManager
        
        self.tableView = tableView
        
        self.bluetoothPeripheralViewController = bluetoothPeripheralViewController
        
        self.bluetoothPeripheral = bluetoothPeripheral
        
        if let bluetoothPeripheral = bluetoothPeripheral {
            
            if let dexcomG5 = bluetoothPeripheral as? DexcomG5 {
                
                if let blueToothTransmitter = bluetoothPeripheralManager.getBluetoothTransmitter(for: dexcomG5, createANewOneIfNecesssary: false), let cGMG5Transmitter = blueToothTransmitter as? CGMG5Transmitter {
                    
                    // set cGMG5Transmitter delegate to self.
                    cGMG5Transmitter.cGMG5TransmitterDelegate = self

                }
                
            } else {
                fatalError("in DexcomG5BluetoothPeripheralViewModel, configure. bluetoothPeripheral is not DexcomG5")
            }
            
        }
        
    }
    
    func screenTitle() -> String {
        return BluetoothPeripheralType.DexcomG5Type.rawValue
    }
    
    func sectionTitle(forSection section: Int) -> String {
        
        if section == 1 {
            return "Dexcom"
        } else {
            return Texts_BluetoothPeripheralView.battery
        }
        
    }
    
    func update(cell: UITableViewCell, forRow rawValue: Int, forSection section: Int, for bluetoothPeripheral: BluetoothPeripheral) {
        
        // verify that bluetoothPeripheral is a DexcomG5
        guard let dexcomG5 = bluetoothPeripheral as? DexcomG5 else {
            fatalError("DexcomG5BluetoothPeripheralViewModel update, bluetoothPeripheral is not DexcomG5")
        }
        
        // default value for accessoryView is nil
        cell.accessoryView = nil

        if section == 1 {

            // section that has for the moment only the firmware
            guard let setting = Settings(rawValue: rawValue) else { fatalError("DexcomG5BluetoothPeripheralViewModel update, unexpected setting") }
            
            switch setting {
                
            case .firmWareVersion:
                
                cell.textLabel?.text = Texts_Common.firmware
                cell.detailTextLabel?.text = dexcomG5.firmwareVersion
                cell.accessoryType = .none
                
            }

        } else if section == 2 {

            // battery info section
            guard let setting = TransmitterBatteryInfoSettings(rawValue: rawValue) else { fatalError("DexcomG5BluetoothPeripheralViewModel update, unexpected setting") }
            
            cell.accessoryType = .none
            
            switch setting {
                
            case .voltageA:
                
                cell.textLabel?.text = "Voltage A"
                cell.detailTextLabel?.text = dexcomG5.voltageA != 0 ? dexcomG5.voltageA.description : ""
                
            case .voltageB:
                
                cell.textLabel?.text = "Voltage B"
                cell.detailTextLabel?.text = dexcomG5.voltageB != 0 ? dexcomG5.voltageB.description : ""
                
            case .batteryResist:
                
                cell.textLabel?.text = "Resistance"
                cell.detailTextLabel?.text = dexcomG5.batteryResist != 0 ? dexcomG5.batteryResist.description : ""
                
            case .batteryRuntime:
                
                cell.textLabel?.text = "Runtime"
                cell.detailTextLabel?.text = dexcomG5.batteryRuntime != 0 ? dexcomG5.batteryRuntime.description : ""
                
            case .batteryTemperature:
                
                cell.textLabel?.text = "Temperature"
                cell.detailTextLabel?.text = dexcomG5.batteryTemperature != 0 ? dexcomG5.batteryTemperature.description : ""
                
            }
            
        }
        
    }
    
    func userDidSelectRow(withSettingRawValue rawValue: Int, forSection section: Int, for bluetoothPeripheral: BluetoothPeripheral, bluetoothPeripheralManager: BluetoothPeripheralManaging) -> SettingsSelectedRowAction {
        
        return .nothing
        
        // verify that bluetoothPeripheral is a DexcomG5
        /*guard let dexcomG5 = bluetoothPeripheral as? DexcomG5 else {
            fatalError("DexcomG5BluetoothPeripheralViewModel userDidSelectRow, bluetoothPeripheral is not DexcomG5")
        }
        
        guard let setting = Settings(rawValue: rawValue) else { fatalError("DexcomG5BluetoothPeripheralViewModel userDidSelectRow, unexpected setting") }
        
        switch setting {
            
        case .firmWareVersion:
            return .nothing
            
        }*/

    }
    
    func numberOfSettings(inSection section: Int) -> Int {
        
        if section == 1 {
            return Settings.allCases.count
        } else {
            return TransmitterBatteryInfoSettings.allCases.count
        }
        
    }
    
    func numberOfSections() -> Int {
        // for the moment only one specific section for DexcomG5
        return 2
    }
    
}

extension DexcomG5BluetoothPeripheralViewModel: CGMG5TransmitterDelegate {
    
    func received(transmitterBatteryInfo: TransmitterBatteryInfo, cGMG5Transmitter: CGMG5Transmitter) {
        
        // storage in dexcomG5 object is handled in bluetoothPeripheralManager
        (bluetoothPeripheralManager as? CGMG5TransmitterDelegate)?.received(transmitterBatteryInfo: transmitterBatteryInfo, cGMG5Transmitter: cGMG5Transmitter)
        
        // update rows
        tableView?.reloadSections(IndexSet(integer: 2), with: .none)
        
    }
    
    func received(firmware: String, cGMG5Transmitter: CGMG5Transmitter) {
        
        (bluetoothPeripheralManager as? CGMG5TransmitterDelegate)?.received(firmware: firmware, cGMG5Transmitter: cGMG5Transmitter)
        
        // firmware should get updated in DexcomG5 object by bluetoothPeripheralManager, here's the trigger to update the table
        tableView?.reloadRows(at: [IndexPath(row: Settings.firmWareVersion.rawValue, section: 1)], with: .none)

    }
    
}
