import UIKit
import CoreBluetooth

class WatlaaMasterBluetoothPeripheralViewModel {
 
    // MARK: - private properties

    /// reference to bluetoothPeripheralManager
    private weak var bluetoothPeripheralManager: BluetoothPeripheralManaging?
    
    /// reference to the tableView
    private weak var tableView: UITableView?
    
    /// reference to BluetoothPeripheralViewController that will own this WatlaaMasterBluetoothPeripheralViewModel - needed to present stuff etc
    private weak var bluetoothPeripheralViewController: BluetoothPeripheralViewController?

    private weak var bluetoothTransmitterDelegate: BluetoothTransmitterDelegate?
    

}

// MARK: - extension BluetoothPeripheralViewModelProtocol

extension WatlaaMasterBluetoothPeripheralViewModel: BluetoothPeripheralViewModel {
    
    func configure(bluetoothPeripheral: BluetoothPeripheral?, bluetoothPeripheralManager: BluetoothPeripheralManaging, tableView: UITableView, bluetoothPeripheralViewController: BluetoothPeripheralViewController, bluetoothTransmitterDelegate: BluetoothTransmitterDelegate) {
        
        self.bluetoothPeripheralManager = bluetoothPeripheralManager
        
        self.tableView = tableView
        
        self.bluetoothPeripheralViewController = bluetoothPeripheralViewController
        
        self.bluetoothTransmitterDelegate = bluetoothTransmitterDelegate

        if let watlaaPeripheral = bluetoothPeripheral as? Watlaa  {
            
            storeTempValues(from: watlaaPeripheral)
            
        }
        
    }
    
    func screenTitle() -> String {
        return TextsWatlaaView.watlaaViewscreenTitle
    }
    
    func sectionTitle(forSection section: Int) -> String {
        return "section title tbc"
    }
    
    func update(cell: UITableViewCell, forRow rawValue: Int, forSection section: Int, for bluetoothPeripheral: BluetoothPeripheral, doneButtonOutlet: UIBarButtonItem) {
        
    }
    
    func userDidSelectRow(withSettingRawValue rawValue: Int, forSection section: Int, for bluetoothPeripheral: BluetoothPeripheral, bluetoothPeripheralManager: BluetoothPeripheralManaging, doneButtonOutlet: UIBarButtonItem) {
        
    }
    
    func numberOfSettings(inSection section: Int) -> Int {
        return 0
    }
    
    func numberOfSections() -> Int {
        // for the moment only one specific section for watlaa
        return 0
    }
    
    func storeTempValues(from bluetoothPeripheral: BluetoothPeripheral) {
    }
    
    func writeTempValues(to bluetoothPeripheral: BluetoothPeripheral) {
    }
    
    
}

// MARK: - extension BluetoothTransmitterDelegate

extension WatlaaMasterBluetoothPeripheralViewModel: BluetoothTransmitterDelegate {
    
    func didConnectTo(bluetoothTransmitter: BluetoothTransmitter) {
        bluetoothTransmitterDelegate?.didConnectTo(bluetoothTransmitter: bluetoothTransmitter)
    }
    
    func didDisconnectFrom(bluetoothTransmitter: BluetoothTransmitter) {
        bluetoothTransmitterDelegate?.didDisconnectFrom(bluetoothTransmitter: bluetoothTransmitter)
    }
    
    func deviceDidUpdateBluetoothState(state: CBManagerState, bluetoothTransmitter: BluetoothTransmitter) {
        bluetoothTransmitterDelegate?.deviceDidUpdateBluetoothState(state: state, bluetoothTransmitter: bluetoothTransmitter)
    }
    
    
}

