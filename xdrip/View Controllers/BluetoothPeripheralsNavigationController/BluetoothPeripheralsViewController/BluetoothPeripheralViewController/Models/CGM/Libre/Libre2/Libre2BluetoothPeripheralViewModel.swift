import UIKit
import OSLog

class Libre2BluetoothPeripheralViewModel {
    
    /// settings specific for Libre2
    private enum Settings: Int, CaseIterable {
        
        /// Sensor serial number
        case sensorSerialNumber = 0
        
        /// sensor start time
        case sensorStartTime = 1
        
        /// case smooth libre values
        case smoothLibreValues = 2
        
    }
    
    private let log = OSLog(subsystem: ConstantsLog.subSystem, category: "Libre2BluetoothPeripheralViewModel")
    
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
    
    /// it's the bluetoothPeripheral as Libre2
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
    
    func configure(bluetoothPeripheral: BluetoothPeripheral?, bluetoothPeripheralManager: BluetoothPeripheralManaging, tableView: UITableView, bluetoothPeripheralViewController: BluetoothPeripheralViewController) {
        
        self.bluetoothPeripheralManager = bluetoothPeripheralManager
        
        self.tableView = tableView
        
        self.bluetoothPeripheralViewController = bluetoothPeripheralViewController
        
        self.bluetoothPeripheral = bluetoothPeripheral
        
        if let bluetoothPeripheral = bluetoothPeripheral {
            
            if let libre2 = bluetoothPeripheral as? Libre2 {
                
                if let blueToothTransmitter = bluetoothPeripheralManager.getBluetoothTransmitter(for: libre2, createANewOneIfNecesssary: false), let cGMLibre2Transmitter = blueToothTransmitter as? CGMLibre2Transmitter {
                    
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
        guard let libre2 = bluetoothPeripheral as? Libre2 else {
            fatalError("Libre2BluetoothPeripheralViewModel update, bluetoothPeripheral is not Libre2")
        }
        
        // default value for accessoryView is nil
        cell.accessoryView = nil
        
        // create disclosureIndicator in color ConstantsUI.disclosureIndicatorColor
        // will be used whenever accessoryType is to be set to disclosureIndicator
        let  disclosureAccessoryView = DTCustomColoredAccessory(color: ConstantsUI.disclosureIndicatorColor)
        
        guard let setting = Settings(rawValue: rawValue) else { fatalError("Libre2BluetoothPeripheralViewModel update, unexpected setting") }
        
        switch setting {
            
        case .sensorSerialNumber:
            
            cell.textLabel?.text = Texts_BluetoothPeripheralView.sensorSerialNumber
            cell.detailTextLabel?.text = libre2.blePeripheral.sensorSerialNumber
            cell.accessoryType = .disclosureIndicator
            cell.accessoryView = disclosureAccessoryView
            
        case .sensorStartTime:
            
            var sensorStartTimeText = "Not Connected"
            
            cell.textLabel?.text = Texts_HomeView.sensorStart
            
            if let sensorTimeInMinutes = libre2.sensorTimeInMinutes {
                
                let startDate = Date(timeIntervalSinceNow: -Double(sensorTimeInMinutes*60))
                
                if sensorTimeInMinutes < Int(ConstantsMaster.minimumSensorWarmUpRequiredInMinutes) {
                    
                    // the Libre 2 is still in the forced warm-up time so let's make it clear to the user
                    let sensorReadyDateTime = startDate.addingTimeInterval(ConstantsMaster.minimumSensorWarmUpRequiredInMinutes * 60)
                    sensorStartTimeText = Texts_BluetoothPeripheralView.warmingUpUntil + " " + sensorReadyDateTime.toStringInUserLocale(timeStyle: .short, dateStyle: .none)
                    
                } else {
                    
                    // Libre 2 is not warming up so let's show the sensor start date and age
                    sensorStartTimeText = startDate.toStringInUserLocale(timeStyle: .none, dateStyle: .short)
                    sensorStartTimeText += " (" + startDate.daysAndHoursAgo() + ")"
                    
                }
                
            }
            cell.detailTextLabel?.text = sensorStartTimeText
            cell.accessoryType = .disclosureIndicator
            cell.accessoryView = disclosureAccessoryView
                        
        case .smoothLibreValues:
            
            cell.textLabel?.text = Texts_SettingsView.smoothLibreValues
            cell.detailTextLabel?.text = nil // it's a UISwitch,  no detailed text
            cell.accessoryView = UISwitch(isOn: UserDefaults.standard.smoothLibreValues, action: { (isOn:Bool) in
                UserDefaults.standard.smoothLibreValues = isOn
                // set the time at which this option was changed.
                // this is later used to make a cut-off in the read success calculations
                UserDefaults.standard.smoothLibreValuesChangedAtTimeStamp = .now
            })
        }
    }
    
    func userDidSelectRow(withSettingRawValue rawValue: Int, forSection section: Int, for bluetoothPeripheral: BluetoothPeripheral, bluetoothPeripheralManager: BluetoothPeripheralManaging) -> SettingsSelectedRowAction {
        
        // verify that bluetoothPeripheral is a Libre2
        guard let libre2 = bluetoothPeripheral as? Libre2 else {
            fatalError("Libre2BluetoothPeripheralViewModel update, bluetoothPeripheral is not Libre2")
        }
        
        guard let setting = Settings(rawValue: rawValue) else { fatalError("Libre2BluetoothPeripheralViewModel userDidSelectRow, unexpected setting") }
        
        switch setting {
            
        case .sensorSerialNumber:
            
            // serial text could be longer than screen width, clicking the row allows to see it in a pop up with more text place
            if let serialNumber = libre2.blePeripheral.sensorSerialNumber {
                return .showInfoText(title: Texts_BluetoothPeripheralView.sensorSerialNumber, message: "\n" + serialNumber)
            }
            
        case .sensorStartTime:
            
            if let sensorTimeInMinutes = libre2.sensorTimeInMinutes {
                
                let startDate = Date(timeIntervalSinceNow: -Double(sensorTimeInMinutes*60))
                
                var sensorStartTimeText = startDate.toStringInUserLocale(timeStyle: .short, dateStyle: .short)
                
                sensorStartTimeText += "\n\n" + startDate.daysAndHoursAgo() + " " + Texts_HomeView.ago
                
                return .showInfoText(title: Texts_BluetoothPeripheralView.sensorStartDate, message: "\n" + sensorStartTimeText)
            }
            
        case .smoothLibreValues:
            return .nothing
            
        }
        
        return .nothing
        
    }
    
    func numberOfSettings(inSection section: Int) -> Int {
        return Settings.allCases.count
    }
    
    func numberOfSections() -> Int {
        // for the moment only one specific section for Libre2
        return 1
    }
    
    
}

// MARK: - conform to CGMLibre2TransmitterDelegate

extension Libre2BluetoothPeripheralViewModel: CGMLibre2TransmitterDelegate {
    
    func received(sensorTimeInMinutes: Int, from cGMLibre2Transmitter: CGMLibre2Transmitter) {
        
        // inform also bluetoothPeripheralManager
        (bluetoothPeripheralManager as? CGMLibre2TransmitterDelegate)?.received(sensorTimeInMinutes: sensorTimeInMinutes, from: cGMLibre2Transmitter)
        
        // here's the trigger to update the table
        reloadRow(row: Settings.sensorStartTime.rawValue)
        
    }
    
    func received(serialNumber: String, from cGMLibre2Transmitter: CGMLibre2Transmitter) {
        
        // inform also bluetoothPeripheralManager
        (bluetoothPeripheralManager as? CGMLibre2TransmitterDelegate)?.received(serialNumber: serialNumber, from: cGMLibre2Transmitter)
        
        // here's the trigger to update the table
        reloadRow(row: Settings.sensorSerialNumber.rawValue)
        
    }
    
    private func reloadRow(row: Int) {
        DispatchQueue.main.async {
            guard let tableView = self.tableView,
                  let bluetoothPeripheralViewController = self.bluetoothPeripheralViewController else { return }

            // Always reload the general section (0) first, because its row count may have changed.
            tableView.reloadSections(IndexSet(integer: 0), with: .none)
            
            let totalSections = tableView.numberOfSections
            let section = bluetoothPeripheralViewController.numberOfGeneralSections() + self.sectionNumberForLibre2SpecificSettings
            
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
