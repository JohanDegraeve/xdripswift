//
//  DexcomG7BluetoothPeripheralViewModel.swift
//  xdrip
//
//  Created by Johan Degraeve on 08/02/2024.
//  Copyright © 2024 Johan Degraeve. All rights reserved.
//

import Foundation

class DexcomG7BluetoothPeripheralViewModel {
    
    /// settings specific for Dexcom G7
    public enum Settings:Int, CaseIterable {
        
        /// sensor start time
        case sensorStartDate = 0
        
        /// case sensorStatus
        case sensorStatus = 1
        
    }
     

    /// reference to bluetoothPeripheralManager
    private weak var bluetoothPeripheralManager: BluetoothPeripheralManaging?
    
    /// temporary reference to bluetoothPerpipheral, will be set in configure function.
    private var bluetoothPeripheral: BluetoothPeripheral?
    
    /// reference to BluetoothPeripheralViewController that will own this DexcomG7BluetoothPeripheralViewModel - needed to present stuff etc
    private weak var bluetoothPeripheralViewController: BluetoothPeripheralViewController?

    /// reference to the tableView
    private weak var tableView: UITableView?
    
    // MARK: - private functions

    private func getTransmitter(for dexcomG7: DexcomG7) ->  CGMG7Transmitter? {
        
        if let bluetoothPeripheralManager = bluetoothPeripheralManager, let blueToothTransmitter = bluetoothPeripheralManager.getBluetoothTransmitter(for: dexcomG7, createANewOneIfNecesssary: false), let cGMG7Transmitter = blueToothTransmitter as? CGMG7Transmitter {
            
                return cGMG7Transmitter
        }
        
        return nil
        
    }

}

// MARK: - conform to BluetoothPeripheralViewModel

extension DexcomG7BluetoothPeripheralViewModel: BluetoothPeripheralViewModel {
    
    func configure(bluetoothPeripheral: BluetoothPeripheral?, bluetoothPeripheralManager: BluetoothPeripheralManaging, tableView: UITableView, bluetoothPeripheralViewController: BluetoothPeripheralViewController) {
        
        self.bluetoothPeripheralManager = bluetoothPeripheralManager
        
        self.tableView = tableView
        
        self.bluetoothPeripheralViewController = bluetoothPeripheralViewController
        
        self.bluetoothPeripheral = bluetoothPeripheral
        
        if let bluetoothPeripheral = bluetoothPeripheral {
            
            if let dexcomG7 = bluetoothPeripheral as? DexcomG7 {
                
                if let cGMG7Transmitter = getTransmitter(for: dexcomG7) {
                    
                    // set cGMG7Transmitter delegate to self.
                    cGMG7Transmitter.cGMG7TransmitterDelegate = self
                    
                }
                
            } else {
                fatalError("in DexcomG7BluetoothPeripheralViewModel, configure. bluetoothPeripheral is not DexcomG7")
            }
            
        }

    }
    
    func screenTitle() -> String {
        return BluetoothPeripheralType.DexcomG7Type.rawValue
    }
    
    func sectionTitle(forSection section: Int) -> String {
        return "Dexcom G7 / ONE+ / Stelo"
    }
    
    func update(cell: UITableViewCell, forRow rawValue: Int, forSection section: Int, for bluetoothPeripheral: BluetoothPeripheral) {
            
        // verify that bluetoothPeripheral is a DexcomG7
        guard let dexcomG7 = bluetoothPeripheral as? DexcomG7 else {
            fatalError("DexcomG7BluetoothPeripheralViewModel update, bluetoothPeripheral is not DexcomG7")
        }
        
        // default value for accessoryView is nil
        cell.accessoryView = nil
    
        guard let setting = Settings(rawValue: rawValue) else { fatalError("DexcomG7BluetoothPeripheralViewModel update, unexpected setting") }
    
        switch setting {
        
            case .sensorStatus:
            
                cell.textLabel?.text = Texts_Common.sensorStatus
                cell.detailTextLabel?.text = dexcomG7.sensorStatus
                cell.accessoryType = .none
            
            case .sensorStartDate:
            
                var startDateString = ""
                
                if let startDate = dexcomG7.sensorStartDate {
                    startDateString = startDate.toStringInUserLocale(timeStyle: .none, dateStyle: .short)
                    startDateString += " (" + startDate.daysAndHoursAgo() + ")"
                }
                cell.textLabel?.text = Texts_BluetoothPeripheralView.sensorStartDate
                cell.detailTextLabel?.text = startDateString
                cell.accessoryType = .none

        }

    }

    
    func userDidSelectRow(withSettingRawValue rawValue: Int, forSection section: Int, for bluetoothPeripheral: BluetoothPeripheral, bluetoothPeripheralManager: BluetoothPeripheralManaging) -> SettingsSelectedRowAction {
        
        // there's no section specific for this type of transmitter, so user won't click anything, this function will not be called
        return .nothing
        
    }
    
    func numberOfSettings(inSection section: Int) -> Int {
        
        return 2
        
    }
    
    func numberOfSections() -> Int {
        
        // one specific section
        return 1
        
    }
    
}

// MARK: - conform to CGMG7TransmitterDelegate

extension DexcomG7BluetoothPeripheralViewModel: CGMG7TransmitterDelegate {
    
    /// received sensorStartDate
    func received(sensorStartDate: Date?, cGMG7Transmitter: CGMG7Transmitter) {
        
        (bluetoothPeripheralManager as? CGMG7TransmitterDelegate)?.received(sensorStartDate: sensorStartDate, cGMG7Transmitter: cGMG7Transmitter)
        
        // sensorStartDate should get updated in DexcomG5 object by bluetoothPeripheralManager, here's the trigger to update the table
        
        if let bluetoothPeripheralViewController = bluetoothPeripheralViewController {
            reloadRow(row: Settings.sensorStartDate.rawValue, section: bluetoothPeripheralViewController.numberOfGeneralSections() + 1)
        }
        
    }
    
    /// received sensorStatus
    func received(sensorStatus: String?, cGMG7Transmitter: CGMG7Transmitter) {
        
        (bluetoothPeripheralManager as? CGMG7TransmitterDelegate)?.received(sensorStatus: sensorStatus, cGMG7Transmitter: cGMG7Transmitter)
        
        // sensorStatus should get updated in DexcomG5 object by bluetoothPeripheralManager, here's the trigger to update the table
        
        if let bluetoothPeripheralViewController = bluetoothPeripheralViewController {
            reloadRow(row: Settings.sensorStatus.rawValue, section: bluetoothPeripheralViewController.numberOfGeneralSections() + 1)
        }
        
    }
    
    private func reloadRow(row: Int, section: Int) {
        DispatchQueue.main.async {
            guard let tableView = self.tableView else { return }

            // Always reload the general section (0) first, because its row count may have changed.
            tableView.reloadSections(IndexSet(integer: 0), with: .none)

            // Guard against invalid section index. A mismatch between calculated section and the current
            // table structure can occur during updates, which previously caused a crash in
            // -[UITableViewRowData numberOfRowsInSection:]. If the section is gone/shifted, fall back to a full reload.
            let totalSections = tableView.numberOfSections
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
