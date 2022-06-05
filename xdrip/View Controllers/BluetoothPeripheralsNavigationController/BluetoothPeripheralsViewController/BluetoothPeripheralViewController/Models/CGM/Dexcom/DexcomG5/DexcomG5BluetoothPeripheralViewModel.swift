import Foundation
import UIKit
import CoreBluetooth

class DexcomG5BluetoothPeripheralViewModel {
    
    // MARK: - private and public properties
    
    /// settings specific for Dexcom G5
    public enum Settings:Int, CaseIterable {
        
        /// sensor start time
        case sensorStartDate = 0
        
        /// transmitter start time
        case transmitterStartDate = 1

        /// firmware version
        case firmWareVersion = 2
        
        // next are only for transmitters that use the firefly flow
        
        /// case sensorStatus
        case sensorStatus = 3
        
        /// let other app run in parallel with xDrip4iOS. If true then xDrip4iOS will only listen and never send, except for calibration and sensor start
        case userOtherApp = 4
        
    }
     
    private enum ResetSettings:Int, CaseIterable {
        
        /// should reset be done yes or no
        case resetRequired = 0
        
        /// last time reset was done
        case lastResetTimeStamp = 1
        
    }
    
    private enum TransmitterBatteryInfoSettings: Int, CaseIterable {
        
        case voltageA = 0
        
        case voltageB = 1
        
        case batteryRuntime = 2
        
        case batteryTemperature = 3

        case batteryResist = 4

    }
    
    /// - list of sections available in Dexcom
    /// - counting starts at 0
    public enum DexcomSection: Int, CaseIterable {
        
        /// helptest, blepassword, rotation, color, ... settings applicable to both M5Stack and M5StickC
        case commonDexcomSettings = 0

        /// batterySettings
        case batterySettings = 1
        
        /// reset settings
        case resetSetings = 2
        
    }
    
    /// reference to bluetoothPeripheralManager
    private weak var bluetoothPeripheralManager: BluetoothPeripheralManaging?
    
    /// reference to the tableView
    private weak var tableView: UITableView?
    
    /// reference to BluetoothPeripheralViewController that will own this DexcomG5BluetoothPeripheralViewModel - needed to present stuff etc
    private weak var bluetoothPeripheralViewController: BluetoothPeripheralViewController?
    
    /// temporary reference to bluetoothPerpipheral, will be set in configure function.
    private var bluetoothPeripheral: BluetoothPeripheral?
    
    /// it's the bluetoothPeripheral as dexcomG6
    private var dexcomG5: DexcomG5? {
        get {
            return bluetoothPeripheral as? DexcomG5
        }
    }
    
// MARK: - deinit
    
    deinit {
        
        // when closing the viewModel, and if there's still a bluetoothTransmitter existing, then reset the specific delegate to BluetoothPeripheralManager
        
        guard let dexcomG5 = dexcomG5 else {return}
        
        guard let cGMG5Transmitter = getTransmitter(for: dexcomG5) else {return}
        
        cGMG5Transmitter.cGMG5TransmitterDelegate = bluetoothPeripheralManager as! BluetoothPeripheralManager
        
    }

    // MARK: - private functions
    
    private func getDexcomSection(forSectionInTable section: Int) -> DexcomSection {
        
        guard let bluetoothPeripheralViewController = bluetoothPeripheralViewController else {
            fatalError("in DexcomG5BluetoothPeripheralViewModel, getDexcomSection(forSectionInTable section: Int),  bluetoothPeripheralViewController is nil")
        }

        guard let dexcomSection = DexcomSection(rawValue: section - bluetoothPeripheralViewController.numberOfGeneralSections()) else {
             fatalError("in DexcomG5BluetoothPeripheralViewModel, getDexcomSection(forSectionInTable section: Int),  could not create dexcomSection is nil")
        }

        return dexcomSection
        
    }
    
    private func getTransmitter(for dexcomG5: DexcomG5) ->  CGMG5Transmitter? {
        
        if let bluetoothPeripheralManager = bluetoothPeripheralManager, let blueToothTransmitter = bluetoothPeripheralManager.getBluetoothTransmitter(for: dexcomG5, createANewOneIfNecesssary: false), let cGMG5Transmitter = blueToothTransmitter as? CGMG5Transmitter {
            
                return cGMG5Transmitter
        }
        
        return nil
        
    }
    
    /// is the selected dexcom a firefly or not?
    /// - if not known yet (because transmitter id not yet set, then returns false)
    private func isFireFly() -> Bool {
        
        if let bluetoothPeripheral = bluetoothPeripheral, let transmitterId = bluetoothPeripheral.blePeripheral.transmitterId {
            
            return transmitterId.isFireFly()
            
        }

        return false
        
    }

    // MARK: - public functions
    
    /// screenTitle, can be overriden for G6
    public func dexcomScreenTitle() -> String {
        return BluetoothPeripheralType.DexcomType.rawValue
    }
    
}

// MARK: - conform to BluetoothPeripheralViewModel

extension DexcomG5BluetoothPeripheralViewModel: BluetoothPeripheralViewModel {

    func configure(bluetoothPeripheral: BluetoothPeripheral?, bluetoothPeripheralManager: BluetoothPeripheralManaging, tableView: UITableView, bluetoothPeripheralViewController: BluetoothPeripheralViewController) {
        
        self.bluetoothPeripheralManager = bluetoothPeripheralManager
        
        self.tableView = tableView
        
        self.bluetoothPeripheralViewController = bluetoothPeripheralViewController
        
        self.bluetoothPeripheral = bluetoothPeripheral
        
        if let bluetoothPeripheral = bluetoothPeripheral {
            
            if let dexcomG5 = bluetoothPeripheral as? DexcomG5 {
                
                if let cGMG5Transmitter = getTransmitter(for: dexcomG5) {
                    
                    // set cGMG5Transmitter delegate to self.
                    cGMG5Transmitter.cGMG5TransmitterDelegate = self
                    
                }
                
            } else {
                fatalError("in DexcomG5BluetoothPeripheralViewModel, configure. bluetoothPeripheral is not DexcomG5")
            }
            
        }
        
    }
    
    func screenTitle() -> String {
        return dexcomScreenTitle()
    }
    
    func sectionTitle(forSection section: Int) -> String {
        
        switch getDexcomSection(forSectionInTable: section) {
            
        case .resetSetings:
            return Texts_SettingsView.labelResetTransmitter

        case .batterySettings:
            return Texts_BluetoothPeripheralView.battery
            
        case .commonDexcomSettings:
            return "Dexcom"
            
        }

    }
    
    func update(cell: UITableViewCell, forRow rawValue: Int, forSection section: Int, for bluetoothPeripheral: BluetoothPeripheral) {
        
        // verify that bluetoothPeripheral is a DexcomG5
        guard let dexcomG5 = bluetoothPeripheral as? DexcomG5 else {
            fatalError("DexcomG5BluetoothPeripheralViewModel update, bluetoothPeripheral is not DexcomG5")
        }
        
        // default value for accessoryView is nil
        cell.accessoryView = nil

        switch getDexcomSection(forSectionInTable: section) {
            
        case .commonDexcomSettings:
            
            // section that has for the moment only the firmware
            guard let setting = Settings(rawValue: rawValue) else { fatalError("DexcomG5BluetoothPeripheralViewModel update, unexpected setting") }
            
            switch setting {

            case .sensorStartDate:
                
                cell.textLabel?.text = Texts_BluetoothPeripheralView.sensorStartDate
                cell.detailTextLabel?.text = dexcomG5.sensorStartDate?.toStringInUserLocale(timeStyle: .short, dateStyle: .short)
                cell.accessoryType = .none
                
            case .transmitterStartDate:
                
                cell.textLabel?.text = Texts_BluetoothPeripheralView.transmittterStartDate
                cell.detailTextLabel?.text = dexcomG5.transmitterStartDate?.toStringInUserLocale(timeStyle: .short, dateStyle: .short)
                cell.accessoryType = .none
                
            case .firmWareVersion:
                
                cell.textLabel?.text = Texts_Common.firmware
                cell.detailTextLabel?.text = dexcomG5.firmwareVersion
                cell.accessoryType = .none
                
            case .sensorStatus:
                
                cell.textLabel?.text = Texts_Common.sensorStatus
                cell.detailTextLabel?.text = dexcomG5.sensorStatus
                cell.accessoryType = .none
                
            case .userOtherApp:

                cell.textLabel?.text = Texts_BluetoothPeripheralView.useOtherDexcomApp
                cell.detailTextLabel?.text = nil // it's a UISwitch,  no detailed text
                cell.accessoryView = UISwitch(isOn: dexcomG5.useOtherApp, action: { (isOn:Bool) in
                    
                    dexcomG5.useOtherApp = isOn
                    
                    if let cGMG5Transmitter = self.getTransmitter(for: dexcomG5) {
                        
                        // set isOn value to cGMG5Transmitter
                        cGMG5Transmitter.useOtherApp = isOn
                        
                    }
                    
                })
                
            }

        case .resetSetings:
            
            // reset  section
            guard let setting = ResetSettings(rawValue: rawValue) else { fatalError("DexcomG5BluetoothPeripheralViewModel update, unexpected setting") }
            
            switch setting {
                
            case .resetRequired:
                
                cell.textLabel?.text = Texts_BluetoothPeripheralView.resetRequired
                cell.detailTextLabel?.text = nil //it's a UISwitch, no detailed text
                cell.accessoryType = .none
                cell.accessoryView = UISwitch(isOn: dexcomG5.resetRequired, action: { (isOn:Bool) in
                    
                    dexcomG5.resetRequired = isOn

                    if let cGMG5Transmitter = self.getTransmitter(for: dexcomG5) {
                        
                        // set isOn value to cGMG5Transmitter
                        cGMG5Transmitter.reset(requested: isOn)
                        
                    }
                    
                })
                
            case .lastResetTimeStamp:
            
                if let lastResetTimeStamp = dexcomG5.lastResetTimeStamp {

                    cell.textLabel?.text = Texts_BluetoothPeripheralView.lastResetTimeStamp
                    cell.detailTextLabel?.text = lastResetTimeStamp.toStringInUserLocale(timeStyle: .short, dateStyle: .short)
                    cell.accessoryType = .none

                } else {
                    
                    cell.textLabel?.text = Texts_BluetoothPeripheralView.lastResetTimeStampNotKnown
                    cell.detailTextLabel?.text = nil
                    cell.accessoryType = .none
                    
                }

            }
            
        case .batterySettings:
            
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
        
    }
    
    func numberOfSettings(inSection section: Int) -> Int {
        
        switch getDexcomSection(forSectionInTable: section) {
            
        case .commonDexcomSettings:
            
            return Settings.allCases.count
            
        case .batterySettings:
            return TransmitterBatteryInfoSettings.allCases.count

        case .resetSetings:
            return ResetSettings.allCases.count
            
        }

    }
    
    func numberOfSections() -> Int {
        
        if isFireFly() {
            
            return DexcomSection.allCases.count - 1
            
        } else {
            
            return DexcomSection.allCases.count
            
        }
        
    }
    
}

extension DexcomG5BluetoothPeripheralViewModel: CGMG5TransmitterDelegate {
    
    func reset(for cGMG5Transmitter: CGMG5Transmitter, successful: Bool) {
        
        // storage in dexcomG5 object is handled in bluetoothPeripheralManager
        (bluetoothPeripheralManager as? CGMG5TransmitterDelegate)?.reset(for: cGMG5Transmitter, successful: successful)
        
        // update two rows
        if let bluetoothPeripheralViewController = bluetoothPeripheralViewController {
            
            tableView?.reloadSections(IndexSet(integer: DexcomSection.resetSetings.rawValue +
                bluetoothPeripheralViewController.numberOfGeneralSections()), with: .none)
            
        }
        
        // Create Notification Content to give info about reset result of reset attempt
        let notificationContent = UNMutableNotificationContent()
        
        // Configure notificationContent title
        notificationContent.title = successful ? Texts_HomeView.info : Texts_Common.warning
        
        // Configure notificationContent body
        notificationContent.body = Texts_BluetoothPeripheralView.transmitterResetResult + " : " + (successful ? Texts_HomeView.success : Texts_HomeView.failed)
        
        // Create Notification Request
        let notificationRequest = UNNotificationRequest(identifier: ConstantsNotifications.NotificationIdentifierForResetResult.transmitterResetResult, content: notificationContent, trigger: nil)
        
        // Add Request to User Notification Center
        UNUserNotificationCenter.current().add(notificationRequest)
        
    }
    
    func received(transmitterBatteryInfo: TransmitterBatteryInfo, cGMG5Transmitter: CGMG5Transmitter) {
        
        // storage in dexcomG5 object is handled in bluetoothPeripheralManager
        (bluetoothPeripheralManager as? CGMG5TransmitterDelegate)?.received(transmitterBatteryInfo: transmitterBatteryInfo, cGMG5Transmitter: cGMG5Transmitter)
        
        // update rows
        if let bluetoothPeripheralViewController = bluetoothPeripheralViewController {
            tableView?.reloadSections(IndexSet(integer: DexcomSection.batterySettings.rawValue + bluetoothPeripheralViewController.numberOfGeneralSections()), with: .none)
        }
        
    }
    
    func received(firmware: String, cGMG5Transmitter: CGMG5Transmitter) {
        
        (bluetoothPeripheralManager as? CGMG5TransmitterDelegate)?.received(firmware: firmware, cGMG5Transmitter: cGMG5Transmitter)
        
        // firmware should get updated in DexcomG5 object by bluetoothPeripheralManager, here's the trigger to update the table
        if let bluetoothPeripheralViewController = bluetoothPeripheralViewController {
            reloadRow(row: Settings.firmWareVersion.rawValue, section: DexcomSection.commonDexcomSettings.rawValue + bluetoothPeripheralViewController.numberOfGeneralSections())
        }

    }
    
    /// received transmitterStartDate
    func received(transmitterStartDate: Date, cGMG5Transmitter: CGMG5Transmitter) {
        
        (bluetoothPeripheralManager as? CGMG5TransmitterDelegate)?.received(transmitterStartDate: transmitterStartDate, cGMG5Transmitter: cGMG5Transmitter)
        
        // transmitterStartDate should get updated in DexcomG5 object by bluetoothPeripheralManager, here's the trigger to update the table
        
        if let bluetoothPeripheralViewController = bluetoothPeripheralViewController {
            reloadRow(row: Settings.firmWareVersion.rawValue, section: DexcomSection.commonDexcomSettings.rawValue + bluetoothPeripheralViewController.numberOfGeneralSections())
        }
        
    }
    
    /// received sensorStartDate
    func received(sensorStartDate: Date?, cGMG5Transmitter: CGMG5Transmitter) {
        
        (bluetoothPeripheralManager as? CGMG5TransmitterDelegate)?.received(sensorStartDate: sensorStartDate, cGMG5Transmitter: cGMG5Transmitter)
        
        // sensorStartDate should get updated in DexcomG5 object by bluetoothPeripheralManager, here's the trigger to update the table
        
        if let bluetoothPeripheralViewController = bluetoothPeripheralViewController {
            reloadRow(row: Settings.sensorStartDate.rawValue, section: DexcomSection.commonDexcomSettings.rawValue + bluetoothPeripheralViewController.numberOfGeneralSections())
        }
        
    }
    
    /// received sensorStatus
    func received(sensorStatus: String?, cGMG5Transmitter: CGMG5Transmitter) {
        
        (bluetoothPeripheralManager as? CGMG5TransmitterDelegate)?.received(sensorStatus: sensorStatus, cGMG5Transmitter: cGMG5Transmitter)
        
        // sensorStatus should get updated in DexcomG5 object by bluetoothPeripheralManager, here's the trigger to update the table
        
        if let bluetoothPeripheralViewController = bluetoothPeripheralViewController {
            reloadRow(row: Settings.sensorStatus.rawValue, section: DexcomSection.commonDexcomSettings.rawValue + bluetoothPeripheralViewController.numberOfGeneralSections())
        }
        
    }
    
    private func reloadRow(row: Int, section: Int) {
        
            tableView?.reloadRows(at: [IndexPath(row: row, section: section)], with: .none)

    }

}
