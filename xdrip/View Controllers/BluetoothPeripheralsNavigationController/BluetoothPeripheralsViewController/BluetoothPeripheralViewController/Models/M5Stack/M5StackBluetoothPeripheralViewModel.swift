import Foundation
import UIKit
import CoreBluetooth

class M5StackBluetoothPeripheralViewModel {
   
    // MARK: - Setting
    
    /// Settings common to M5Stack and M5StickC
    /// - a case per attribute that can be set
    /// - these are attributes specific to M5Stack, the generic ones are defined in BluetoothPeripheralViewController
    public enum CommonM5Setting:Int, CaseIterable {
        
        /// helptext for M5Stack software
        case m5StackHelpText = 0
        
        /// ble password
        case blePassword = 1
        
        /// textColor
        case textColor = 2
        
        /// backGroundColor
        case backGroundColor = 3
        
        /// rotation
        case rotation = 4
        
        /// should the M5Stack connect to WiFi or not
        case connectToWiFi = 5
        
    }
    
    // MARK: - private properties
    
    private enum SpecificM5StackSettings:Int, CaseIterable {
        
        /// batteryLevel
        case batteryLevel = 0
        
        /// case brightness
        case brightness = 1
        
        /// user is requesting power off
        case powerOff = 2
        
    }
    
    /// - list of sections available in M5Stack, the last section is only applicable to M5Stack, not M5Stick
    /// - counting starts at 0
    private enum M5StackSections: Int, CaseIterable {
        
        /// helptest, blepassword, rotation, color, ... settings applicable to both M5Stack and M5StickC
        case commonM5Settings = 0
        
        /// - settings only applicable to M5Stack : battery level, brightness, power off
        /// - THIS SHOULD ALWAYS BE THE LAST SECTION - so if sections are added, add them before this setting and increase the number of this setting
        case specificM5StackSettings = 1
        
        func sectionTitle() -> String {
            switch self {
            case .commonM5Settings:
                return "M5"
            case .specificM5StackSettings:// hidden for M5StickC
                return "M5Stack"
            }
        }
        
    }
    
    /// brightness to be used in M5Stack
    ///
    /// possible rotation keys, , the value is shown to the user
    private let rotationStrings: [String] = [ "0", "90", "180", "270"]
    
    /// possible brightness values, the value is shown to the user
    private let brightnessStrings: [String] = ["0", "10", "20", "30", "40", "50", "60", "70", "80", "90", "100"]
    
    /// reference to bluetoothPeripheralManager
    private weak var bluetoothPeripheralManager: BluetoothPeripheralManaging?
    
    /// reference to the tableView
    private weak var tableView: UITableView?
    
    /// reference to BluetoothPeripheralViewController that will own this M5StackBluetoothPeripheralViewModel - needed to present stuff etc
    private(set) weak var bluetoothPeripheralViewController: BluetoothPeripheralViewController?
    
    /// temporary reference to bluetoothPerpipheral, will be set in configure function.
    private var bluetoothPeripheral: BluetoothPeripheral?
    
    /// it's the bluetoothPeripheral as M5Stack
    private var m5Stack: M5Stack? {
        get {
            return bluetoothPeripheral as? M5Stack
        }
    }
    
    // MARK: - public functions
    
    /// get screenTitle
    ///
    /// because screentitle is different for M5Stick, this function allows override by M5Stick specific viewmodel
    public func m5StackcreenTitle() -> String {
        return Texts_M5StackView.m5StackViewscreenTitle
    }
    
    /// - implements the update functions defined in protocol BluetoothPeripheralViewModelProtocol
    /// - this function is defined to allow override by M5StickC specific model class, because
    public func userDidSelectM5StackRow(withSettingRawValue rawValue: Int, forSection section: Int, for bluetoothPeripheral: BluetoothPeripheral, bluetoothPeripheralManager: BluetoothPeripheralManaging) -> SettingsSelectedRowAction {

        // m5Stack should be non nil here, otherwise would be a software error, because the specific settings should still be hidden if m5Stack is nil
        guard let m5Stack = self.m5Stack else {return .nothing}

        switch section {
        case 1:

            guard let setting = CommonM5Setting(rawValue: rawValue) else { fatalError("M5StackBluetoothPeripheralViewModel userDidSelectRow, unexpected setting") }
            
            switch setting {
                
            case .connectToWiFi:
                return .nothing
                
            case .m5StackHelpText:
                
                return .showInfoText(title: Texts_HomeView.info, message: Texts_M5StackView.m5StackSoftWareHelpText + " " + ConstantsM5Stack.githubURLM5Stack)
                
            case .blePassword:
                return .nothing
                
            case .textColor:
                
                var texts = [String]()
                var colors = [M5StackColor]()
                for textColor in M5StackColor.allCases {
                    texts.append(textColor.description)
                    colors.append(textColor)
                }
                
                //find index for color stored in M5Stack or userdefaults
                var selectedRow:Int?
                if let textColor = M5StackColor(forUInt16: UInt16(m5Stack.textcolor)) {
                    selectedRow = texts.firstIndex(of:textColor.description)
                } else if let textColor = UserDefaults.standard.m5StackTextColor?.description {
                    selectedRow = texts.firstIndex(of:textColor)
                }
                
                return .selectFromList(title: Texts_SettingsView.m5StackTextColor, data: texts, selectedRow: selectedRow, actionTitle: nil, cancelTitle: nil, actionHandler: {
                    (_ index: Int) in
                    
                    if index != selectedRow {
                        
                        // set textColor to new value
                        m5Stack.textcolor = Int32(colors[index].rawValue)
                        
                        // send value to M5Stack, if that would fail then set updateNeeded for that m5Stack
                        if let blueToothTransmitter = bluetoothPeripheralManager.getBluetoothTransmitter(for: m5Stack, createANewOneIfNecesssary: false), let m5StackBluetoothTransmitter = blueToothTransmitter as? M5StackBluetoothTransmitter, m5StackBluetoothTransmitter.writeTextColor(textColor: colors[index]) {
                            // do nothing, textColor successfully written to m5Stack - although it's not yet 100% sure because
                        } else {
                            m5Stack.blePeripheral.parameterUpdateNeededAtNextConnect = true
                        }

                        // reload table
                        DispatchQueue.main.async { [weak self] in
                            guard let self = self, let tableView = self.tableView else { return }
                            tableView.reloadRows(at: [IndexPath(row: CommonM5Setting.textColor.rawValue, section: 1)], with: .none)
                        }
                    }
                    
                }, cancelHandler: nil, didSelectRowHandler: nil)
                
                
            case .backGroundColor:
                
                var texts = [String]()
                var colors = [M5StackColor]()
                for backGroundColor in M5StackColor.allCases {
                    texts.append(backGroundColor.description)
                    colors.append(backGroundColor)
                }
                
                //find index for color stored in M5Stack or userdefaults
                var selectedRow:Int?
                if let backGroundColor = M5StackColor(forUInt16: UInt16(m5Stack.backGroundColor)) {
                    // backGroundColor is an instance of textColor, description gives us the textual representation
                    selectedRow = texts.firstIndex(of:backGroundColor.description)
                } else  {
                    selectedRow = texts.firstIndex(of:ConstantsM5Stack.defaultBackGroundColor.description)
                }
                
                return .selectFromList(title: Texts_SettingsView.m5StackbackGroundColor, data: texts, selectedRow: selectedRow, actionTitle: nil, cancelTitle: nil, actionHandler: {
                    (_ index: Int) in
                    
                    if index != selectedRow {
                        
                        // set backGroundColor to new value
                        m5Stack.backGroundColor = Int32(colors[index].rawValue)
                        
                        // send value to M5Stack, if that would fail then set updateNeeded for that m5Stack
                        if let blueToothTransmitter = bluetoothPeripheralManager.getBluetoothTransmitter(for: m5Stack, createANewOneIfNecesssary: false), let m5StackBluetoothTransmitter = blueToothTransmitter as? M5StackBluetoothTransmitter, m5StackBluetoothTransmitter.writeBackGroundColor(backGroundColor: colors[index]) {
                            // do nothing, backGroundColor successfully written to m5Stack - although it's not yet 100% sure because write returns true without waiting for response from bluetooth peripheral
                        } else {
                            m5Stack.blePeripheral.parameterUpdateNeededAtNextConnect = true
                        }

                        // reload table
                        DispatchQueue.main.async { [weak self] in
                            guard let self = self, let tableView = self.tableView else { return }
                            tableView.reloadRows(at: [IndexPath(row: CommonM5Setting.backGroundColor.rawValue, section: 1)], with: .none)
                        }
                    }
                    
                    
                }, cancelHandler: nil, didSelectRowHandler: nil)
                
            case .rotation:
                
                //find index for rotation stored in M5Stack or userdefaults
                let selectedRow = Int(m5Stack.rotation)
                
                return .selectFromList(title: Texts_SettingsView.m5StackRotation, data: rotationStrings, selectedRow: selectedRow, actionTitle: nil, cancelTitle: nil, actionHandler: {
                    (_ index: Int) in
                    
                    if index != selectedRow {
                        
                        // set rotationTempValue to new rotation
                        m5Stack.rotation = Int32(UInt16(index))
                        
                        // send value to M5Stack, if that would fail then set updateNeeded for that m5Stack
                        if let blueToothTransmitter = bluetoothPeripheralManager.getBluetoothTransmitter(for: m5Stack, createANewOneIfNecesssary: false), let m5StackBluetoothTransmitter = blueToothTransmitter as? M5StackBluetoothTransmitter, m5StackBluetoothTransmitter.writeRotation(rotation: index) {
                            // do nothing, rotation successfully written to m5Stack - although it's not yet 100% sure because write returns true without waiting for response from bluetooth peripheral
                        } else {
                            m5Stack.blePeripheral.parameterUpdateNeededAtNextConnect = true
                        }
                        
                        // reload table
                        DispatchQueue.main.async { [weak self] in
                            guard let self = self, let tableView = self.tableView else { return }
                            tableView.reloadRows(at: [IndexPath(row: CommonM5Setting.rotation.rawValue, section: 1)], with: .none)
                        }
                    }
                }, cancelHandler: nil, didSelectRowHandler: nil)
            }

        case 2:
            
            guard let setting = SpecificM5StackSettings(rawValue: rawValue) else { fatalError("M5StackBluetoothPeripheralViewModel userDidSelectRow, unexpected setting") }
            
            switch setting {
                
            case .brightness:
                
                //find index for brightness stored in M5Stack or use 100 as default value
                // brightness goes from 0 to 100, in steps of 10. Dividing by 10 gives the selected row
                let selectedRow = Int(m5Stack.brightness/10)
                
                return .selectFromList(title: Texts_SettingsView.m5StackBrightness, data: brightnessStrings, selectedRow: selectedRow, actionTitle: nil, cancelTitle: nil, actionHandler: {
                    (_ index: Int) in
                    
                    if index != selectedRow {
                        
                        // set brightness to new brightness
                        m5Stack.brightness = Int16(index * 10)
                        
                        // send value to M5Stack, if that would fail then set updateNeeded for that m5Stack
                        if let blueToothTransmitter = bluetoothPeripheralManager.getBluetoothTransmitter(for: m5Stack, createANewOneIfNecesssary: false), let m5StackBluetoothTransmitter = blueToothTransmitter as? M5StackBluetoothTransmitter, m5StackBluetoothTransmitter.writeBrightness(brightness: index * 10) {
                            // do nothing, brightness successfully written to m5Stack - although it's not yet 100% sure because write returns true without waiting for response from bluetooth peripheral
                        } else {
                            m5Stack.blePeripheral.parameterUpdateNeededAtNextConnect = true
                        }
                        
                        // reload table
                        DispatchQueue.main.async { [weak self] in
                            guard let self = self, let tableView = self.tableView else { return }
                            tableView.reloadRows(at: [IndexPath(row: SpecificM5StackSettings.brightness.rawValue, section: M5StackSections.allCases.count)], with: .none)
                        }
                    }
                }, cancelHandler: nil, didSelectRowHandler: nil)
                
            case .batteryLevel:
                return .nothing
                
            case .powerOff:
                
                if let blueToothTransmitter = bluetoothPeripheralManager.getBluetoothTransmitter(for: bluetoothPeripheral, createANewOneIfNecesssary: false), let m5StackBluetoothTransmitter = blueToothTransmitter as? M5StackBluetoothTransmitter, m5StackBluetoothTransmitter.getConnectionStatus() == CBPeripheralState.connected {
                    
                    return .askConfirmation(title: Texts_M5StackView.powerOffConfirm, message: nil, actionHandler: {
                        _ = m5StackBluetoothTransmitter.powerOff()
                    }, cancelHandler: nil)
                    
                } else {
                    
                    let alert = UIAlertController(title: Texts_Common.warning, message: Texts_M5StackView.deviceMustBeConnectedToPowerOff, actionHandler: nil)
                    
                    // present the alert
                    bluetoothPeripheralViewController?.present(alert, animated: true, completion: nil)
                    
                }

            }
            
        default:
            return .nothing
        }
        
        return .nothing
    }
    
    /// - implements the update functions defined in protocol BluetoothPeripheralViewModelProtocol
    /// - this function is defined to allow override by M5StickC specific model class, because update behaviour is different
    public func updateM5Stack(cell: UITableViewCell, forRow row: Int, forSection section: Int, for bluetoothPeripheral: BluetoothPeripheral) {
      
        // unwrap m5Stack
        guard let m5Stack = m5Stack else {return}
        
        // default value for accessoryView is nil
        cell.accessoryView = nil

        // create disclosureIndicator in color ConstantsUI.disclosureIndicatorColor
        // will be used whenever accessoryType is to be set to disclosureIndicator
        let  disclosureAccessoryView = DTCustomColoredAccessory(color: ConstantsUI.disclosureIndicatorColor)

        switch section {
        case 1:
            // this is the section with settings common to M5Stack and M5StickC
            // verify that rawValue is within range of setting
            guard let setting = CommonM5Setting(rawValue: row) else { fatalError("M5StackBluetoothPeripheralViewModel update, Unexpected setting")
            }

            // configure the cell depending on setting
            switch setting {
                
            case .connectToWiFi:
                cell.textLabel?.text = Texts_M5StackView.connectToWiFi
                cell.detailTextLabel?.text = nil
                
                cell.accessoryView = UISwitch(isOn: m5Stack.connectToWiFi, action: {
                    (isOn:Bool) in
                    
                    m5Stack.connectToWiFi = isOn
                    
                    // send value to M5Stack, if that would fail then set updateNeeded for that m5Stack
                    if let m5StackAsPeripheral = bluetoothPeripheral as? M5Stack, let bluetoothPeripheralManager = self.bluetoothPeripheralManager {
                        if let blueToothTransmitter = bluetoothPeripheralManager.getBluetoothTransmitter(for: m5StackAsPeripheral, createANewOneIfNecesssary: false), let m5StackBluetoothTransmitter = blueToothTransmitter as? M5StackBluetoothTransmitter, m5StackBluetoothTransmitter.writeConnectToWiFi(connect: isOn) {
                            // do nothing, ConnectToWiFi successfully written to m5Stack - although it's not yet 100% sure because write returns true without waiting for response from bluetooth peripheral
                        } else {
                            m5StackAsPeripheral.blePeripheral.parameterUpdateNeededAtNextConnect = true
                        }
                    }
                    
                    DispatchQueue.main.async { [weak self] in
                        guard let self = self, let tableView = self.tableView else { return }
                        tableView.reloadRows(at: [IndexPath(row: CommonM5Setting.connectToWiFi.rawValue, section: 1)], with: .none)
                    }
                })
                
            case .m5StackHelpText:
                cell.textLabel?.text = Texts_M5StackView.m5StackSoftWhereHelpCellText
                cell.detailTextLabel?.text = nil
                cell.accessoryType = .disclosureIndicator
                cell.accessoryView =  disclosureAccessoryView
                
            case .blePassword:
                cell.textLabel?.text = Texts_Common.password
                cell.detailTextLabel?.text = m5Stack.blepassword
                cell.accessoryType = .none
                
            case .textColor:
                cell.textLabel?.text = Texts_SettingsView.m5StackTextColor
                
                if let textColor = M5StackColor(forUInt16: UInt16(m5Stack.textcolor)) {
                    cell.detailTextLabel?.text = textColor.description
                } else {
                    if let textColor = UserDefaults.standard.m5StackTextColor {
                        cell.detailTextLabel?.text = textColor.description
                    } else {
                        cell.detailTextLabel?.text = ConstantsM5Stack.defaultTextColor.description
                    }
                }
                
                cell.accessoryType = .disclosureIndicator
                cell.accessoryView =  disclosureAccessoryView
                
            case .backGroundColor:
                cell.textLabel?.text = Texts_SettingsView.m5StackbackGroundColor
                
                if let backGroundColor = M5StackColor(forUInt16: UInt16(m5Stack.backGroundColor)) {
                    cell.detailTextLabel?.text = backGroundColor.description
                } else {
                    cell.detailTextLabel?.text = ConstantsM5Stack.defaultBackGroundColor.description
                }
                
                cell.accessoryType = .disclosureIndicator
                cell.accessoryView =  disclosureAccessoryView
                
            case .rotation:
                cell.textLabel?.text = Texts_SettingsView.m5StackRotation
                cell.detailTextLabel?.text = rotationStrings[Int(m5Stack.rotation)]
                cell.accessoryType = .disclosureIndicator
                cell.accessoryView =  disclosureAccessoryView
                
            }
            
        case 2:
            // this is the section with settings only applicable to M5Stack
            // verify that rawValue is within range of setting
            guard let setting = SpecificM5StackSettings(rawValue: row) else {
                fatalError("M5StackBluetoothPeripheralViewModel update, Unexpected setting")
            }
            
            // configure the cell depending on setting
            switch setting {
                
            case .brightness:
                cell.textLabel?.text = Texts_SettingsView.m5StackBrightness
                cell.detailTextLabel?.text = brightnessStrings[Int(m5Stack.brightness/10)]
                cell.accessoryType = .disclosureIndicator
                cell.accessoryView =  disclosureAccessoryView
                
            case .batteryLevel:
                cell.textLabel?.text = Texts_BluetoothPeripheralsView.batteryLevel
                if m5Stack.batteryLevel > 0 {
                    cell.detailTextLabel?.text = m5Stack.batteryLevel.description
                } else {
                    cell.detailTextLabel?.text = ""
                }
                cell.accessoryType = .none
                
            case .powerOff:
                cell.textLabel?.text = Texts_M5StackView.powerOff
                cell.accessoryType = .disclosureIndicator
                cell.detailTextLabel?.text = nil
                cell.accessoryView =  disclosureAccessoryView
                
            }

        default:
            break
        }
        
    }
    
    /// - this function is defined to allow override by M5StickC specific model class, because the number of sections is different for M5StickC
    public func numberOfM5Sections() -> Int {
        return M5StackSections.allCases.count
    }
    
    // MARK: - deinit
    
    deinit {
        
        // when closing the viewModel, and if there's still a bluetoothTransmitter existing, then reset the specific delegate to BluetoothPeripheralManager
        guard let bluetoothPeripheralManager = bluetoothPeripheralManager else {return}
        
        guard let m5Stack = m5Stack else {return}
        
        guard let blueToothTransmitter = bluetoothPeripheralManager.getBluetoothTransmitter(for: m5Stack, createANewOneIfNecesssary: false) else {return}
        
        guard let m5StackBluetoothTransmitter = blueToothTransmitter as? M5StackBluetoothTransmitter else {return}

        m5StackBluetoothTransmitter.m5StackBluetoothTransmitterDelegate = bluetoothPeripheralManager as! BluetoothPeripheralManager

    }

}

// MARK: - conform to M5StackBluetoothTransmitterDelegate

extension M5StackBluetoothPeripheralViewModel: M5StackBluetoothTransmitterDelegate {
    
    func receivedBattery(level: Int, m5StackBluetoothTransmitter: M5StackBluetoothTransmitter) {
        
        // inform bluetoothPeripheralManager also
        (bluetoothPeripheralManager as? M5StackBluetoothTransmitterDelegate)?.receivedBattery(level: level, m5StackBluetoothTransmitter: m5StackBluetoothTransmitter)
        
        // batteryLevel should get updated in M5Stack object by bluetoothPeripheralManager, here's the trigger to update the table
        DispatchQueue.main.async { [weak self] in
            guard let self = self, let tableView = self.tableView else { return }
            tableView.reloadRows(at: [IndexPath(row: SpecificM5StackSettings.batteryLevel.rawValue, section: M5StackSections.specificM5StackSettings.rawValue)], with: .none)
        }
    }
    
    func isAskingForAllParameters(m5StackBluetoothTransmitter: M5StackBluetoothTransmitter) {
        
        // inform bluetoothPeripheralManager also
        (bluetoothPeripheralManager as? M5StackBluetoothTransmitterDelegate)?.isAskingForAllParameters(m5StackBluetoothTransmitter: m5StackBluetoothTransmitter)
        
        // viewcontroller doesn't use this
    }
    
    func isReadyToReceiveData(m5StackBluetoothTransmitter: M5StackBluetoothTransmitter) {
        
        // inform bluetoothPeripheralManager also
        (bluetoothPeripheralManager as? M5StackBluetoothTransmitterDelegate)?.isReadyToReceiveData(m5StackBluetoothTransmitter: m5StackBluetoothTransmitter)
        
        // viewcontroller doesn't use this
    }
    
    func newBlePassWord(newBlePassword: String, m5StackBluetoothTransmitter: M5StackBluetoothTransmitter) {
        
        // inform bluetoothPeripheralManager also
        (bluetoothPeripheralManager as? M5StackBluetoothTransmitterDelegate)?.newBlePassWord(newBlePassword: newBlePassword, m5StackBluetoothTransmitter: m5StackBluetoothTransmitter)
        
        // note : blePassword is also saved in BluetoothPeripheralManager, it will be saved two times
        if let m5StackPeripheral = bluetoothPeripheralManager?.getBluetoothPeripheral(for: m5StackBluetoothTransmitter) as? M5Stack {
            
            m5StackPeripheral.blepassword = newBlePassword
            
            DispatchQueue.main.async { [weak self] in
                guard let self = self, let tableView = self.tableView else { return }
                tableView.reloadRows(at: [IndexPath(row: CommonM5Setting.blePassword.rawValue, section: 1)], with: .none)
            }
        }
    }
    
    func authentication(success: Bool, m5StackBluetoothTransmitter: M5StackBluetoothTransmitter) {
        
        // inform bluetoothPeripheralManager also
        (bluetoothPeripheralManager as? M5StackBluetoothTransmitterDelegate)?.authentication(success: success, m5StackBluetoothTransmitter: m5StackBluetoothTransmitter)
        
        if !success, let m5StackPeripheral = bluetoothPeripheralManager?.getBluetoothPeripheral(for: m5StackBluetoothTransmitter) as? M5Stack {
            
            // show warning, inform that user should set password or reset M5Stack
            let alert = UIAlertController(title: Texts_Common.warning, message: Texts_M5StackView.authenticationFailureWarning + " " + Texts_BluetoothPeripheralView.connect, actionHandler: {
                
                // by the time user clicks 'ok', the M5stack will be disconnected by the BluetoothPeripheralManager (see authentication in BluetoothPeripheralManager)
                self.bluetoothPeripheralViewController?.setShouldConnectToFalse(for: m5StackPeripheral, askUser: false)
                
            })
            
            bluetoothPeripheralViewController?.present(alert, animated: true, completion: nil)
        }
    }
    
    func blePasswordMissing(m5StackBluetoothTransmitter: M5StackBluetoothTransmitter) {
        
        // inform bluetoothPeripheralManager also
        (bluetoothPeripheralManager as? M5StackBluetoothTransmitterDelegate)?.blePasswordMissing(m5StackBluetoothTransmitter: m5StackBluetoothTransmitter)
        
        guard let m5StackPeripheral = bluetoothPeripheralManager?.getBluetoothPeripheral(for: m5StackBluetoothTransmitter) as? M5Stack else {return}
        
        // show warning, inform that user should set password
        let alert = UIAlertController(title: Texts_Common.warning, message: Texts_M5StackView.authenticationFailureWarning + " " + Texts_BluetoothPeripheralView.connect, actionHandler: {
            
            // by the time user clicks 'ok', the M5stack will be disconnected by the BluetoothPeripheralManager (see authentication in BluetoothPeripheralManager)
            self.bluetoothPeripheralViewController?.setShouldConnectToFalse(for: m5StackPeripheral, askUser: false)
            
        })
        
        bluetoothPeripheralViewController?.present(alert, animated: true, completion: nil)
        
    }
    
    func m5StackResetRequired(m5StackBluetoothTransmitter: M5StackBluetoothTransmitter) {
        
        // inform bluetoothPeripheralManager also
        (bluetoothPeripheralManager as? M5StackBluetoothTransmitterDelegate)?.m5StackResetRequired(m5StackBluetoothTransmitter: m5StackBluetoothTransmitter)
        
        guard let m5StackBluetoothPeripheral = bluetoothPeripheralManager?.getBluetoothPeripheral(for: m5StackBluetoothTransmitter) as? M5Stack else {return}
        
        // show warning, inform that user should reset M5Stack
        let alert = UIAlertController(title: Texts_Common.warning, message: Texts_M5StackView.m5StackResetRequiredWarning + " " + Texts_BluetoothPeripheralView.connect, actionHandler: {
            
            // by the time user clicks 'ok', the M5stack will be disconnected by the BluetoothPeripheralManager (see authentication in BluetoothPeripheralManager)
            self.bluetoothPeripheralViewController?.setShouldConnectToFalse(for: m5StackBluetoothPeripheral, askUser: false)
            
        })
        
        bluetoothPeripheralViewController?.present(alert, animated: true, completion: nil)
        
    }
    
}

// MARK: - conform to BluetoothPeripheralViewModel

extension M5StackBluetoothPeripheralViewModel: BluetoothPeripheralViewModel {
    
    func numberOfSections() -> Int {
        return numberOfM5Sections()
    }
    
    func numberOfSettings(inSection section:Int) -> Int {

        switch section {
        case 1://starts at 1 since oopweb is not enabled for M5Stack
            return CommonM5Setting.allCases.count
        case 2:
            return SpecificM5StackSettings.allCases.count
        default: //shouldn't happen
            return SpecificM5StackSettings.allCases.count
        }

    }
    
    func userDidSelectRow(withSettingRawValue rawValue: Int, forSection section: Int, for bluetoothPeripheral: BluetoothPeripheral, bluetoothPeripheralManager: BluetoothPeripheralManaging) -> SettingsSelectedRowAction {
        
        return userDidSelectM5StackRow(withSettingRawValue: rawValue, forSection: section, for: bluetoothPeripheral, bluetoothPeripheralManager: bluetoothPeripheralManager)
        
    }

    
    func update(cell: UITableViewCell, forRow row: Int, forSection section: Int, for bluetoothPeripheral: BluetoothPeripheral) {
        
        updateM5Stack(cell: cell, forRow: row, forSection: section, for: bluetoothPeripheral)
        
    }

    func screenTitle() -> String {
        return m5StackcreenTitle()
    }
    
    func sectionTitle(forSection section: Int) -> String {
        return M5StackSections(rawValue: section)?.sectionTitle() ?? ""
    }
    
    func configure(bluetoothPeripheral: BluetoothPeripheral?, bluetoothPeripheralManager: BluetoothPeripheralManaging, tableView: UITableView,  bluetoothPeripheralViewController: BluetoothPeripheralViewController) {
        
        self.bluetoothPeripheralManager = bluetoothPeripheralManager
        
        self.tableView = tableView
        
        self.bluetoothPeripheralViewController = bluetoothPeripheralViewController
        
        self.bluetoothPeripheral = bluetoothPeripheral
        
        if let bluetoothPeripheral = bluetoothPeripheral {
            
            if let m5Stack = bluetoothPeripheral as? M5Stack {
                
                if let blueToothTransmitter = bluetoothPeripheralManager.getBluetoothTransmitter(for: m5Stack, createANewOneIfNecesssary: false), let m5StackBluetoothTransmitter = blueToothTransmitter as? M5StackBluetoothTransmitter {
                    
                    // set m5StackBluetoothTransmitter delegate to self.
                    m5StackBluetoothTransmitter.m5StackBluetoothTransmitterDelegate = self
                    
                    // also request batteryLevel, this may have been updated
                    _ = m5StackBluetoothTransmitter.readBatteryLevel()
                    
                }
                
            } else {
                fatalError("in M5StackBluetoothPeripheralViewModel, configure. bluetoothPeripheral is not M5Stack")
            }
            
        }
                
    }
    
}
