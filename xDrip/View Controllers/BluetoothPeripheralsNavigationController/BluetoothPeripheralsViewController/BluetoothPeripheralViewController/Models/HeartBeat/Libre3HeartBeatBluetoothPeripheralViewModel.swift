//
//  Libre3HeartBeatBluetoothPeripheralViewModel.swift
//  xdrip
//
//  Created by Johan Degraeve on 05/08/2023.
//  Copyright © 2024 Johan Degraeve. All rights reserved.
//

import Foundation

class Libre3HeartBeatBluetoothPeripheralViewModel {
    
    /// reference to bluetoothPeripheralManager
    private weak var bluetoothPeripheralManager: BluetoothPeripheralManaging?
    
    /// temporary reference to bluetoothPerpipheral, will be set in configure function.
    private var bluetoothPeripheral: BluetoothPeripheral?

}

// MARK: - conform to BluetoothPeripheralViewModel

extension Libre3HeartBeatBluetoothPeripheralViewModel: BluetoothPeripheralViewModel {
    
    func configure(bluetoothPeripheral: BluetoothPeripheral?, bluetoothPeripheralManager: BluetoothPeripheralManaging, tableView: UITableView, bluetoothPeripheralViewController: BluetoothPeripheralViewController) {
        
        self.bluetoothPeripheralManager = bluetoothPeripheralManager
        
        self.bluetoothPeripheral = bluetoothPeripheral
        
    }
    
    func screenTitle() -> String {
        return BluetoothPeripheralType.Libre3HeartBeatType.rawValue
    }
    
    func sectionTitle(forSection section: Int) -> String {
        
        // there's no section specific for this type of transmitter, this function will not be called
        return "Libre/Generic Heartbeat ♥"
        
    }
    
    func update(cell: UITableViewCell, forRow rawValue: Int, forSection section: Int, for bluetoothPeripheral: BluetoothPeripheral) {
    }
    
    
    func userDidSelectRow(withSettingRawValue rawValue: Int, forSection section: Int, for bluetoothPeripheral: BluetoothPeripheral, bluetoothPeripheralManager: BluetoothPeripheralManaging) -> SettingsSelectedRowAction {
        
        // there's no section specific for this type of transmitter, so user won't click anything, this function will not be called
        return .nothing
        
    }
    
    func numberOfSettings(inSection section: Int) -> Int {
        
        return 0
        
    }
    
    func numberOfSections() -> Int {
        
        // one specific section
        return 0
        
    }
    
}
