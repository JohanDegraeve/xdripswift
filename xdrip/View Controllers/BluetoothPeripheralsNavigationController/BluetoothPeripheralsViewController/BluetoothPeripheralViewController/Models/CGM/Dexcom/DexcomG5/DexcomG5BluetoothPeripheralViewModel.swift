import CoreBluetooth
import Foundation
import os
import UIKit

class DexcomG5BluetoothPeripheralViewModel {
    // MARK: - private and public properties
    
    /// settings specific for Dexcom G5/G6
    public enum Settings: Int, CaseIterable {
        /// sensor start time
        case sensorStartDate = 0
        
        /// transmitter start time
        case transmitterStartDate = 1
        
        /// transmitter start time (this will be different for standard Dexcom G6 or Anubis-modified ones)
        case transmitterExpiryDate = 2

        /// firmware version
        case firmWareVersion = 3
        
        // next are only for transmitters that use the firefly flow
        
        /// case sensorStatus
        case sensorStatus = 4
        
        /// let other app run in parallel with xDrip4iOS. If true then xDrip4iOS will only listen and never send, except for calibration and sensor start
        case userOtherApp = 5
    }
     
    private enum AnubisSettings: Int, CaseIterable {
        /// should reset be done yes or no
        case resetRequired = 0
        
        /// last time reset was done
        case lastResetTimeStamp = 1
        
        /// override sensor max days
        case overrideSensorMaxDays = 2
    }
    
    private enum TransmitterBatteryInfoSettings: Int, CaseIterable {
        case voltageA = 0
        case voltageB = 1
    }
    
    /// - list of sections available in Dexcom
    /// - counting starts at 0
    public enum DexcomSection: Int, CaseIterable {
        /// helptest, blepassword, rotation, color, ... settings applicable to both M5Stack and M5StickC
        case commonDexcomSettings = 0
        
        /// batterySettings
        case batterySettings = 1
        
        /// Anubis settings
        case anubisSettings = 2
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
        return bluetoothPeripheral as? DexcomG5
    }
    
    // track if it is an anubis transmitter - mainly used to display specific features and
    // also to know how many sections to display
    private var isAnubis: Bool = false
    
    private var trackingNumberOfSections: Int?
    
    // MARK: - deinit
    
    deinit {
        // when closing the viewModel, and if there's still a bluetoothTransmitter existing, then reset the specific delegate to BluetoothPeripheralManager
        guard let dexcomG5 = dexcomG5 else { return }
        guard let cGMG5Transmitter = getTransmitter(for: dexcomG5) else { return }
        
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
    
    private func getTransmitter(for dexcomG5: DexcomG5) -> CGMG5Transmitter? {
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
    
    /// should we show the sensor start time? This is needed because it is initialized to date() with a new peripheral and we don't really
    /// want to show any date until the sensor session is started and we get a real date
    private func shouldShowSensorStartDate() -> Bool {
        if let dexcomG5 = dexcomG5, dexcomG5.sensorStatus != DexcomAlgorithmState.SessionStopped.description {
            return true
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
                
                // set the anubis flag as per the status pulled from the bluetoothPeripheral if it exists
                isAnubis = dexcomG5.isAnubis
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
        case .anubisSettings:
            return Texts_SettingsView.labelResetTransmitter
        case .batterySettings:
            return Texts_BluetoothPeripheralView.battery
        case .commonDexcomSettings:
            return "Dexcom" + ((dexcomG5?.isAnubis ?? false) ? " (Anubis ✅)" : "")
        }
    }
    
    func update(cell: UITableViewCell, forRow rawValue: Int, forSection section: Int, for bluetoothPeripheral: BluetoothPeripheral) {
        // verify that bluetoothPeripheral is a DexcomG5
        guard let dexcomG5 = bluetoothPeripheral as? DexcomG5 else {
            fatalError("DexcomG5BluetoothPeripheralViewModel update, bluetoothPeripheral is not DexcomG5")
        }
        
        // default value for accessoryView is nil
        cell.accessoryView = nil
        
        // create disclosureIndicator in color ConstantsUI.disclosureIndicatorColor
        // will be used whenever accessoryType is to be set to disclosureIndicator
        let disclosureAccessoryView = DTCustomColoredAccessory(color: ConstantsUI.disclosureIndicatorColor)
        
        switch getDexcomSection(forSectionInTable: section) {
        case .commonDexcomSettings:
            // section that has for the moment only the firmware
            guard let setting = Settings(rawValue: rawValue) else { fatalError("DexcomG5BluetoothPeripheralViewModel update, unexpected setting") }
            
            switch setting {
            case .sensorStartDate:
                var startDateString = ""
                
                if let startDate = dexcomG5.sensorStartDate, shouldShowSensorStartDate() {
                    let sensorTimeInMinutes = -Int(startDate.timeIntervalSinceNow / 60)
                    let minimumSensorWarmUpRequiredInMinutes = dexcomG5.isAnubis ? ConstantsMaster.minimumSensorWarmUpRequiredInMinutesDexcomG6Anubis : ConstantsMaster.minimumSensorWarmUpRequiredInMinutesDexcomG5G6
                    
                    if sensorTimeInMinutes < Int(minimumSensorWarmUpRequiredInMinutes) {
                        // the Dexcom is still in the transmitter forced warm-up time so let's make it clear to the user
                        let sensorReadyDateTime = startDate.addingTimeInterval(minimumSensorWarmUpRequiredInMinutes * 60)
                        startDateString = Texts_BluetoothPeripheralView.warmingUpUntil + " " + sensorReadyDateTime.toStringInUserLocale(timeStyle: .short, dateStyle: .none)
                        
                    } else {
                        // Dexcom is not warming up so let's show the sensor start date and age
                        startDateString = startDate.toStringInUserLocale(timeStyle: .none, dateStyle: .short)
                        startDateString += " (" + startDate.daysAndHoursAgo(showOnlyDays: true) + ")"
                    }
                } else {
                    startDateString = Texts_HomeView.notStarted
                }
                
                cell.textLabel?.text = Texts_BluetoothPeripheralView.sensorStartDate
                cell.detailTextLabel?.text = startDateString
                cell.accessoryView = shouldShowSensorStartDate() ? disclosureAccessoryView : nil
                cell.accessoryType = shouldShowSensorStartDate() ? .disclosureIndicator : .none
                
            case .transmitterStartDate:
                var startDateString = ""
                
                if let startDate = dexcomG5.transmitterStartDate {
                    startDateString = dexcomG5.transmitterStartDate?.toStringInUserLocale(timeStyle: .none, dateStyle: .short) ?? ""
                    startDateString += " (" + startDate.daysAndHoursAgo(showOnlyDays: true) + ")"
                }
                
                cell.textLabel?.text = Texts_BluetoothPeripheralView.transmittterStartDate
                cell.detailTextLabel?.text = startDateString
                cell.accessoryType = .disclosureIndicator
                cell.accessoryView = disclosureAccessoryView
                
            case .transmitterExpiryDate:
                cell.textLabel?.text = Texts_BluetoothPeripheralView.transmittterExpiryDate
                
                // add 90 days (or 180 days if Anubis) to the transmitter start date to get the expiry date
                if let transmitterExpiryDate = dexcomG5.transmitterStartDate?.addingTimeInterval(60 * 60 * 24 * (dexcomG5.isAnubis ? ConstantsMaster.transmitterExpiryDaysDexcomG6Anubis : ConstantsMaster.transmitterExpiryDaysDexcomG5G6)) {
                    cell.detailTextLabel?.text = transmitterExpiryDate.toStringInUserLocale(timeStyle: .none, dateStyle: .short) + " (" + transmitterExpiryDate.daysAndHoursRemaining(showOnlyDays: true) + ")"
                } else {
                    cell.detailTextLabel?.text = "-"
                }
                
                cell.accessoryType = .disclosureIndicator
                cell.accessoryView = disclosureAccessoryView
                
            case .firmWareVersion:
                cell.textLabel?.text = Texts_Common.firmware
                cell.detailTextLabel?.text = dexcomG5.firmwareVersion
                cell.accessoryType = .none
                
            case .sensorStatus:
                cell.textLabel?.text = Texts_Common.sensorStatus
                cell.detailTextLabel?.text = dexcomG5.sensorStatus
                if cell.detailTextLabel?.text == nil {
                    cell.accessoryType = .none
                } else {
                    cell.accessoryType = .disclosureIndicator
                    cell.accessoryView = disclosureAccessoryView
                }
                
            case .userOtherApp:
                cell.textLabel?.text = Texts_BluetoothPeripheralView.useOtherDexcomApp
                cell.detailTextLabel?.text = nil // it's a UISwitch,  no detailed text
                cell.accessoryView = UISwitch(isOn: dexcomG5.useOtherApp, action: { (isOn: Bool) in
                    dexcomG5.useOtherApp = isOn
                    
                    if let cGMG5Transmitter = self.getTransmitter(for: dexcomG5) {
                        // set isOn value to cGMG5Transmitter
                        cGMG5Transmitter.useOtherApp = isOn
                        
                        // define and present alertcontroller, this will show a message to explain that another app must be running in parallel to handle G6 authentication or we won't get any readings. Change the message to show the enabled/disabled version.
                        let alert = UIAlertController(title: Texts_BluetoothPeripheralView.useOtherDexcomApp, message: isOn ? Texts_BluetoothPeripheralView.useOtherDexcomAppMessageEnabled : Texts_BluetoothPeripheralView.useOtherDexcomAppMessageDisabled, actionHandler: nil)
                        
                        self.bluetoothPeripheralViewController?.present(alert, animated: true, completion: nil)
                    }
                })
            }
            
        case .batterySettings:
            // battery info section
            guard let setting = TransmitterBatteryInfoSettings(rawValue: rawValue) else { fatalError("DexcomG5BluetoothPeripheralViewModel update, unexpected setting") }
            cell.accessoryType = .none
            
            switch setting {
            case .voltageA:
                cell.textLabel?.text = "Voltage A"
                cell.detailTextLabel?.text = dexcomG5.voltageA != 0 ? dexcomG5.voltageA.description + "0 mV" : "Waiting for data..."
                
            case .voltageB:
                cell.textLabel?.text = "Voltage B"
                
                // here we will add a simple battery indicator to the text string. This is probably not very accurate for G4/G5 users but there are probably very few of them left so it's better to just hard code than add unneeded extra options to adjust these values.
                var dexcomBatteryLevelIndicator = ""
                
                if dexcomG5.voltageB != 0 {
                    if dexcomG5.voltageB < 270 {
                        dexcomBatteryLevelIndicator = "🔴 "
                    } else if dexcomG5.voltageB < 280 {
                        dexcomBatteryLevelIndicator = "🟡 "
                    } else {
                        dexcomBatteryLevelIndicator = "🟢 "
                    }
                }
                
                cell.detailTextLabel?.text = dexcomG5.voltageB != 0 ? dexcomBatteryLevelIndicator + dexcomG5.voltageB.description + "0 mV" : "Waiting for data..."
            }
            
        case .anubisSettings:
            // reset/anubis  section
            guard let setting = AnubisSettings(rawValue: rawValue) else { fatalError("DexcomG5BluetoothPeripheralViewModel update, unexpected setting") }
            
            switch setting {
            case .resetRequired:
                cell.textLabel?.text = Texts_BluetoothPeripheralView.resetRequired
                cell.detailTextLabel?.text = nil // it's a UISwitch, no detailed text
                cell.accessoryType = .none
                cell.accessoryView = UISwitch(isOn: dexcomG5.resetRequired, action: { (isOn: Bool) in
                    dexcomG5.resetRequired = isOn
                    
                    if let cGMG5Transmitter = self.getTransmitter(for: dexcomG5) {
                        // set isOn value to cGMG5Transmitter
                        cGMG5Transmitter.reset(requested: isOn)
                        
                        if isOn {
                            // define and present alertcontroller, this will show a message to explain that the reset function only works with certain transmitters
                            let alert = UIAlertController(title: Texts_BluetoothPeripheralView.resetRequired, message: Texts_SettingsView.resetDexcomTransmitterMessage, actionHandler: nil)
                            
                            self.bluetoothPeripheralViewController?.present(alert, animated: true, completion: nil)
                        }
                    }
                })
                
            case .lastResetTimeStamp:
                cell.textLabel?.text = Texts_BluetoothPeripheralView.lastResetTimeStamp
                
                if let lastResetTimeStamp = dexcomG5.lastResetTimeStamp {
                    cell.detailTextLabel?.text = lastResetTimeStamp.toStringInUserLocale(timeStyle: .short, dateStyle: .short)
                } else {
                    cell.detailTextLabel?.text = "-"
                }
                
                cell.accessoryType = .none
                
            case .overrideSensorMaxDays:
                cell.textLabel?.text = Texts_BluetoothPeripheralView.maxSensorAgeInDaysOverridenAnubis
                if let maxSensorAgeInDaysOverridenAnubis = UserDefaults.standard.activeSensorMaxSensorAgeInDaysOverridenAnubis, maxSensorAgeInDaysOverridenAnubis > 0 {
                    cell.detailTextLabel?.text = "\(maxSensorAgeInDaysOverridenAnubis.stringWithoutTrailingZeroes) \(Texts_Common.days)"
                } else {
                    cell.detailTextLabel?.text = "(\(Texts_Common.default0) \(ConstantsDexcomG5.maxSensorAgeInDays.stringWithoutTrailingZeroes) \(Texts_Common.days))"
                }
                cell.accessoryType = .disclosureIndicator
                cell.accessoryView = disclosureAccessoryView
            }
        }
    }
    
    func userDidSelectRow(withSettingRawValue rawValue: Int, forSection section: Int, for bluetoothPeripheral: BluetoothPeripheral, bluetoothPeripheralManager: BluetoothPeripheralManaging) -> SettingsSelectedRowAction {
        // just show select row actions for the general dexcom section
        switch section {
        case 1:
            guard let setting = Settings(rawValue: rawValue) else { fatalError("DexcomG5BluetoothPeripheralViewModel userDidSelectRow, unexpected setting") }
            
            switch setting {
            case .sensorStatus:
                // firmware text could be longer than screen width, clicking the row allos to see it in pop up with more text place
                if let sensorStatus = dexcomG5?.sensorStatus {
                    return .showInfoText(title: Texts_Common.sensorStatus, message: "\n" + sensorStatus)
                }
                
            case .sensorStartDate:
                if let startDate = dexcomG5?.sensorStartDate, shouldShowSensorStartDate() {
                    var startDateString = startDate.toStringInUserLocale(timeStyle: .short, dateStyle: .short)
                    
                    startDateString += "\n\n" + startDate.daysAndHoursAgo() + " " + Texts_HomeView.ago
                    
                    return .showInfoText(title: Texts_BluetoothPeripheralView.sensorStartDate, message: "\n" + startDateString)
                    
                } else {
                    return .nothing
                }
                
            case .transmitterStartDate:
                if let startDate = dexcomG5?.transmitterStartDate {
                    var startDateString = startDate.toStringInUserLocale(timeStyle: .short, dateStyle: .short)
                    
                    startDateString += "\n\n" + startDate.daysAndHoursAgo() + " " + Texts_HomeView.ago
                    
                    return .showInfoText(title: Texts_BluetoothPeripheralView.transmittterStartDate, message: "\n" + startDateString)
                }
                
            case .transmitterExpiryDate:
                let isAnubis = dexcomG5?.isAnubis ?? false
                
                if let transmitterExpiryDate = dexcomG5?.transmitterStartDate?.addingTimeInterval(60 * 60 * 24 * (isAnubis ? ConstantsMaster.transmitterExpiryDaysDexcomG6Anubis : ConstantsMaster.transmitterExpiryDaysDexcomG5G6)) {
                    var expiryDateString = transmitterExpiryDate.toStringInUserLocale(timeStyle: .short, dateStyle: .short)
                    expiryDateString += "\n\n" + transmitterExpiryDate.daysAndHoursRemaining(showOnlyDays: true) + " / " + (isAnubis ? ConstantsMaster.transmitterExpiryDaysDexcomG6Anubis.stringWithoutTrailingZeroes : ConstantsMaster.transmitterExpiryDaysDexcomG5G6.stringWithoutTrailingZeroes) + Texts_Common.dayshort + " " + Texts_HomeView.remaining
                    expiryDateString += isAnubis ? "\n\n Anubis ✅" : ""
                    
                    return .showInfoText(title: Texts_BluetoothPeripheralView.transmittterExpiryDate, message: "\n" + expiryDateString)
                }
                
            case .firmWareVersion, .userOtherApp:
                return .nothing
            }
            
        case 3:
            guard let setting = AnubisSettings(rawValue: rawValue) else { fatalError("DexcomG5BluetoothPeripheralViewModel userDidSelectRow, unexpected setting") }
            
            switch setting {
            case .overrideSensorMaxDays:
                return SettingsSelectedRowAction.askText(title: Texts_BluetoothPeripheralView.maxSensorAgeInDaysOverridenAnubis, message: Texts_BluetoothPeripheralView.maxSensorAgeInDaysOverridenAnubisMessage, keyboardType: .numberPad, text: (UserDefaults.standard.activeSensorMaxSensorAgeInDaysOverridenAnubis ?? ConstantsDexcomG5.maxSensorAgeInDays).stringWithoutTrailingZeroes, placeHolder: nil, actionTitle: nil, cancelTitle: nil, actionHandler: { (activeSensorMaxSensorAgeInDaysOverridenAnubisString: String) in
                    
                    // check that the user entered a plausible value although set the userdefaults to nil if zero is entered
                    if let activeSensorMaxSensorAgeInDaysOverridenAnubis = Double(activeSensorMaxSensorAgeInDaysOverridenAnubisString) {
                        if activeSensorMaxSensorAgeInDaysOverridenAnubis >= 0 && activeSensorMaxSensorAgeInDaysOverridenAnubis <= ConstantsDexcomG5.maxSensorAgeInDaysOverridenAnubisMaximum {
                            UserDefaults.standard.activeSensorMaxSensorAgeInDaysOverridenAnubis = activeSensorMaxSensorAgeInDaysOverridenAnubis
                        }
                    }
                }, cancelHandler: nil, inputValidator: nil)
                
            default:
                return .nothing
            }
                
        default:
            return .nothing
        }
        
        return .nothing
    }
    
    func numberOfSettings(inSection section: Int) -> Int {
        switch getDexcomSection(forSectionInTable: section) {
        case .commonDexcomSettings:
            return Settings.allCases.count
            
        case .batterySettings:
            return TransmitterBatteryInfoSettings.allCases.count

        case .anubisSettings:
            return AnubisSettings.allCases.count
        }
    }
    
    // only show all sections if this is an Anubis transmitter. If it isn't, then hide the last one
    func numberOfSections() -> Int {
        return dexcomG5?.isAnubis ?? false ? DexcomSection.allCases.count : DexcomSection.allCases.count - 1
    }
    
}

extension DexcomG5BluetoothPeripheralViewModel: CGMG5TransmitterDelegate {
    func reset(for cGMG5Transmitter: CGMG5Transmitter, successful: Bool) {
        // storage in dexcomG5 object is handled in bluetoothPeripheralManager
        (bluetoothPeripheralManager as? CGMG5TransmitterDelegate)?.reset(for: cGMG5Transmitter, successful: successful)
        
        // update two rows
        if let bluetoothPeripheralViewController = bluetoothPeripheralViewController {
            tableView?.reloadSections(IndexSet(integer: DexcomSection.anubisSettings.rawValue +
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
            reloadRow(row: Settings.transmitterStartDate.rawValue, section: DexcomSection.commonDexcomSettings.rawValue + bluetoothPeripheralViewController.numberOfGeneralSections())
            reloadRow(row: Settings.transmitterExpiryDate.rawValue, section: DexcomSection.commonDexcomSettings.rawValue + bluetoothPeripheralViewController.numberOfGeneralSections())
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
    
    /// received isAnubis
    func received(isAnubis: Bool, cGMG5Transmitter: CGMG5Transmitter) {
        // storage in dexcomG5 object is handled in bluetoothPeripheralManager
        (bluetoothPeripheralManager as? CGMG5TransmitterDelegate)?.received(isAnubis: isAnubis, cGMG5Transmitter: cGMG5Transmitter)
        
        // force a reload of the whole table. This will incorporate the anubis section as needed
        tableView?.reloadData()
    }
    
    private func reloadRow(row: Int, section: Int) {
        tableView?.reloadRows(at: [IndexPath(row: row, section: section)], with: .none)
    }
}
