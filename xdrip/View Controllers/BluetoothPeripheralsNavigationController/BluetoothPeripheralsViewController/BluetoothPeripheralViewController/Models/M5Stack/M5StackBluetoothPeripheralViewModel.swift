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
    /// - counting starts at 1
    private enum M5StackSections: Int, CaseIterable {
        
        /// helptest, blepassword, rotation, color, ... settings applicable to both M5Stack and M5StickC
        case commonM5Settings = 1
        
        /// - settings only applicable to M5Stack : battery level, brightness, power off
        /// - THIS SHOULD ALWAYS BE THE LAST SECTION - so if sections are added, add them before this setting and increase the number of this setting
        case specificM5StackSettings = 2
        
        func sectionTitle() -> String {
            switch self {
            case .commonM5Settings:
                return "M5"
            case .specificM5StackSettings:// hidden for M5StickC
                return "M5Stack"
            }
        }
        
    }
    
    /// section number for section with helpText, blePassword, textColor, backGroundColor, rotation, connectToWiFi
    private let sectionNumberForM5StackCommonSettings = 1
    
    /// textColor to be used in M5Stack
    ///
    /// temp storage of value while user is editing the M5Stack attributes
    private var textColorTemporaryValue: M5StackColor?
    
    /// rotation to be used in M5Stack
    ///
    /// temp storage of value while user is editing the M5Stack attributes
    private var rotationTempValue: UInt16?
    
    /// connectToWiFi value to be used in M5Stack
    ///
    /// temp storage of value while user is editing the M5Stack attributes
    private var connectToWiFiTempValue: Bool?
    
    /// backGroundColor to be used in M5Stack
    ///
    /// temp storage of value while user is editing the M5Stack attributes
    private var backGroundColorTemporaryValue: M5StackColor?
    
    /// brightness to be used in M5Stack
    ///
    /// temp storage of value while user is editing the M5Stack attributes
    private var brightnessTemporaryValue: Int?
    
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
    
    private weak var bluetoothTransmitterDelegate: BluetoothTransmitterDelegate?
    
    // MARK: - public functions
    
    /// get screenTitle
    ///
    /// because screentitle is different for M5Stick, this function allows override by M5Stick specific viewmodel
    public func m5StackcreenTitle() -> String {
        return Texts_M5StackView.m5StackViewscreenTitle
    }
    
    /// - implements the update functions defined in protocol BluetoothPeripheralViewModelProtocol
    /// - this function is defined to allow override by M5StickC specific model class, because
    public func userDidSelectM5StackRow(withSettingRawValue rawValue: Int, forSection section: Int, for bluetoothPeripheral: BluetoothPeripheral, bluetoothPeripheralManager: BluetoothPeripheralManaging, doneButtonOutlet: UIBarButtonItem) -> SettingsSelectedRowAction {
        
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
                if let textColor = textColorTemporaryValue {
                    selectedRow = texts.firstIndex(of:textColor.description)
                } else if let textColor = UserDefaults.standard.m5StackTextColor?.description {
                    selectedRow = texts.firstIndex(of:textColor)
                }
                
                return .selectFromList(title: Texts_SettingsView.m5StackTextColor, data: texts, selectedRow: selectedRow, actionTitle: nil, cancelTitle: nil, actionHandler: {
                    (_ index: Int) in
                    
                    if index != selectedRow {
                        
                        // set temp value textColor to new textColor
                        self.textColorTemporaryValue = colors[index]
                        
                        // send value to M5Stack, if that would fail then set updateNeeded for that m5Stack
                        if let m5StackPeripheral = bluetoothPeripheral as? M5Stack {
                            if let textColor = self.textColorTemporaryValue, let blueToothTransmitter = bluetoothPeripheralManager.getBluetoothTransmitter(for: m5StackPeripheral, createANewOneIfNecesssary: false), let m5StackBluetoothTransmitter = blueToothTransmitter as? M5StackBluetoothTransmitter, m5StackBluetoothTransmitter.writeTextColor(textColor: textColor) {
                                // do nothing, textColor successfully written to m5Stack - although it's not yet 100% sure because
                            } else {
                                m5StackPeripheral.blePeripheral.parameterUpdateNeededAtNextConnect = true
                            }
                        }
                        
                        // reload table
                        self.tableView?.reloadRows(at: [IndexPath(row: CommonM5Setting.textColor.rawValue, section: 1)], with: .none)
                        
                        // enable the done button
                        doneButtonOutlet.enable()
                        
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
                if let backGroundColor = backGroundColorTemporaryValue {
                    // backGroundColor is an instance of textColor, description gives us the textual representation
                    selectedRow = texts.firstIndex(of:backGroundColor.description)
                } else  {
                    selectedRow = texts.firstIndex(of:ConstantsM5Stack.defaultBackGroundColor.description)
                }
                
                return .selectFromList(title: Texts_SettingsView.m5StackbackGroundColor, data: texts, selectedRow: selectedRow, actionTitle: nil, cancelTitle: nil, actionHandler: {
                    (_ index: Int) in
                    
                    if index != selectedRow {
                        
                        // set temp value backGroundColor to new backGroundColor
                        self.backGroundColorTemporaryValue = colors[index]
                        
                        // send value to M5Stack, if that would fail then set updateNeeded for that m5Stack
                        if let m5StackPeripheral = bluetoothPeripheral as? M5Stack {
                            if let backGroundColor = self.backGroundColorTemporaryValue, let blueToothTransmitter = bluetoothPeripheralManager.getBluetoothTransmitter(for: m5StackPeripheral, createANewOneIfNecesssary: false), let m5StackBluetoothTransmitter = blueToothTransmitter as? M5StackBluetoothTransmitter, m5StackBluetoothTransmitter.writeBackGroundColor(backGroundColor: backGroundColor) {
                                // do nothing, backGroundColor successfully written to m5Stack - although it's not yet 100% sure because write returns true without waiting for response from bluetooth peripheral
                            } else {
                                m5StackPeripheral.blePeripheral.parameterUpdateNeededAtNextConnect = true
                            }
                        }
                        
                        // reload table
                        self.tableView?.reloadRows(at: [IndexPath(row: CommonM5Setting.backGroundColor.rawValue, section: 1)], with: .none)
                        
                        // enable the done button
                        doneButtonOutlet.enable()
                        
                    }
                    
                    
                }, cancelHandler: nil, didSelectRowHandler: nil)
                
            case .rotation:
                
                //find index for rotation stored in M5Stack or userdefaults
                var selectedRow:Int? = nil
                if let rotation = rotationTempValue {
                    selectedRow = Int(rotation)
                } else {
                    selectedRow = Int(ConstantsM5Stack.defaultRotation)
                }
                
                return .selectFromList(title: Texts_SettingsView.m5StackRotation, data: rotationStrings, selectedRow: selectedRow, actionTitle: nil, cancelTitle: nil, actionHandler: {
                    (_ index: Int) in
                    
                    if index != selectedRow {
                        
                        // set rotationTempValue to new rotation
                        self.rotationTempValue = UInt16(index)
                        
                        // send value to M5Stack, if that would fail then set updateNeeded for that m5Stack
                        if let m5StackAsPeripheral = bluetoothPeripheral as? M5Stack {
                            if let blueToothTransmitter = bluetoothPeripheralManager.getBluetoothTransmitter(for: m5StackAsPeripheral, createANewOneIfNecesssary: false), let m5StackBluetoothTransmitter = blueToothTransmitter as? M5StackBluetoothTransmitter, m5StackBluetoothTransmitter.writeRotation(rotation: index) {
                                // do nothing, rotation successfully written to m5Stack - although it's not yet 100% sure because write returns true without waiting for response from bluetooth peripheral
                            } else {
                                m5StackAsPeripheral.blePeripheral.parameterUpdateNeededAtNextConnect = true
                            }
                        }
                        
                        // reload table
                        self.tableView?.reloadRows(at: [IndexPath(row: CommonM5Setting.rotation.rawValue, section: 1)], with: .none)
                        
                        // enable the done button
                        doneButtonOutlet.enable()
                        
                    }
                    
                    
                }, cancelHandler: nil, didSelectRowHandler: nil)
                
            }

        case 2:
            
            guard let setting = SpecificM5StackSettings(rawValue: rawValue) else { fatalError("M5StackBluetoothPeripheralViewModel userDidSelectRow, unexpected setting") }
            
            switch setting {
                
            case .brightness:
                
                //find index for brightness stored in M5Stack or use 100 as default value
                var selectedRow:Int? = nil
                // brightness goes from 0 to 100, in steps of 10. Dividing by 10 gives the selected row
                if let brightness = brightnessTemporaryValue {
                    selectedRow = brightness/10
                } else {
                    // default value is 100
                    selectedRow = 10
                }
                
                return .selectFromList(title: Texts_SettingsView.m5StackBrightness, data: brightnessStrings, selectedRow: selectedRow, actionTitle: nil, cancelTitle: nil, actionHandler: {
                    (_ index: Int) in
                    
                    if index != selectedRow {
                        
                        // set rotationTempValue to new rotation
                        self.brightnessTemporaryValue = index * 10
                        
                        // send value to M5Stack, if that would fail then set updateNeeded for that m5Stack
                        if let m5StackPeripheral = bluetoothPeripheral as? M5Stack {
                            if let blueToothTransmitter = bluetoothPeripheralManager.getBluetoothTransmitter(for: m5StackPeripheral, createANewOneIfNecesssary: false), let m5StackBluetoothTransmitter = blueToothTransmitter as? M5StackBluetoothTransmitter, m5StackBluetoothTransmitter.writeBrightness(brightness: index * 10) {
                                // do nothing, brightness successfully written to m5Stack - although it's not yet 100% sure because write returns true without waiting for response from bluetooth peripheral
                            } else {
                                m5StackPeripheral.blePeripheral.parameterUpdateNeededAtNextConnect = true
                            }
                        }
                        
                        // reload table
                        self.tableView?.reloadRows(at: [IndexPath(row: SpecificM5StackSettings.brightness.rawValue, section: M5StackSections.allCases.count)], with: .none)
                        
                        // enable the done button
                        doneButtonOutlet.enable()
                        
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
    public func updateM5Stack(cell: UITableViewCell, forRow row: Int, forSection section: Int, for bluetoothPeripheral: BluetoothPeripheral, doneButtonOutlet: UIBarButtonItem) {
      
        // verify that bluetoothPeripheralAsNSObject is an M5Stack
        guard let m5Stack = bluetoothPeripheral as? M5Stack else {
            fatalError("M5StackBluetoothPeripheralViewModel update, bluetoothPeripheral is not M5Stack")
        }
        
        // default value for accessoryView is nil
        cell.accessoryView = nil
        
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
                
                cell.accessoryView = UISwitch(isOn: connectToWiFiTempValue ?? false, action: {
                    (isOn:Bool) in
                    
                    self.connectToWiFiTempValue = isOn
                    
                    // enable the done button, because value has changed
                    doneButtonOutlet.enable()
                    
                    // send value to M5Stack, if that would fail then set updateNeeded for that m5Stack
                    if let m5StackAsPeripheral = bluetoothPeripheral as? M5Stack, let bluetoothPeripheralManager = self.bluetoothPeripheralManager {
                        if let blueToothTransmitter = bluetoothPeripheralManager.getBluetoothTransmitter(for: m5StackAsPeripheral, createANewOneIfNecesssary: false), let m5StackBluetoothTransmitter = blueToothTransmitter as? M5StackBluetoothTransmitter, m5StackBluetoothTransmitter.writeConnectToWiFi(connect: isOn) {
                            // do nothing, ConnectToWiFi successfully written to m5Stack - although it's not yet 100% sure because write returns true without waiting for response from bluetooth peripheral
                        } else {
                            m5StackAsPeripheral.blePeripheral.parameterUpdateNeededAtNextConnect = true
                        }
                    }
                    
                    self.tableView?.reloadRows(at: [IndexPath(row: CommonM5Setting.connectToWiFi.rawValue, section: 1)], with: .none)
                    
                })
                
            case .m5StackHelpText:
                cell.textLabel?.text = Texts_M5StackView.m5StackSoftWhereHelpCellText
                cell.detailTextLabel?.text = nil
                cell.accessoryType = .disclosureIndicator
                
            case .blePassword:
                cell.textLabel?.text = Texts_Common.password
                cell.detailTextLabel?.text = m5Stack.blepassword
                cell.accessoryType = .none
                
            case .textColor:
                cell.textLabel?.text = Texts_SettingsView.m5StackTextColor
                
                if let textColor = textColorTemporaryValue {
                    cell.detailTextLabel?.text = textColor.description
                } else {
                    if let textColor = UserDefaults.standard.m5StackTextColor {
                        cell.detailTextLabel?.text = textColor.description
                    } else {
                        cell.detailTextLabel?.text = ConstantsM5Stack.defaultTextColor.description
                    }
                }
                
                cell.accessoryType = .disclosureIndicator
                
            case .backGroundColor:
                cell.textLabel?.text = Texts_SettingsView.m5StackbackGroundColor
                
                if let backGroundColor = backGroundColorTemporaryValue {
                    cell.detailTextLabel?.text = backGroundColor.description
                } else {
                    cell.detailTextLabel?.text = ConstantsM5Stack.defaultBackGroundColor.description
                }
                
                cell.accessoryType = .disclosureIndicator
                
            case .rotation:
                cell.textLabel?.text = Texts_SettingsView.m5StackRotation
                
                if let rotation = rotationTempValue {
                    cell.detailTextLabel?.text = rotationStrings[Int(rotation)]
                } else {
                    cell.detailTextLabel?.text = rotationStrings[Int(ConstantsM5Stack.defaultRotation)]
                }
                
                cell.accessoryType = .disclosureIndicator
                
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
                
                if let brightness = brightnessTemporaryValue {
                    cell.detailTextLabel?.text = brightnessStrings[Int(brightness/10)]
                } else {
                    cell.detailTextLabel?.text = brightnessStrings[brightnessStrings.count - 1]
                }
                
                cell.accessoryType = .disclosureIndicator
                
            case .batteryLevel:
                cell.textLabel?.text = Texts_BluetoothPeripheralsView.batteryLevel
                cell.detailTextLabel?.text = m5Stack.batteryLevel.description
                cell.accessoryType = .none
                
            case .powerOff:
                cell.textLabel?.text = Texts_M5StackView.powerOff
                cell.accessoryType = .disclosureIndicator
                cell.detailTextLabel?.text = nil

            }

        default:
            break
        }
        
    }
    
    /// - this function is defined to allow override by M5StickC specific model class, because the number of sections is different for M5StickC
    public func numberOfM5Sections() -> Int {
        return M5StackSections.allCases.count
    }
    
}

// MARK: - conform to M5StackBluetoothTransmitterDelegate

extension M5StackBluetoothPeripheralViewModel: M5StackBluetoothTransmitterDelegate {
    
    func receivedBattery(level: Int, m5StackBluetoothTransmitter: M5StackBluetoothTransmitter) {
        
        // batteryLevel should get updated in M5Stack object by bluetoothPeripheralManager, here's the trigger to update the table
        tableView?.reloadRows(at: [IndexPath(row: SpecificM5StackSettings.batteryLevel.rawValue, section: M5StackSections.allCases.count)], with: .none)
        
    }
    
    func isAskingForAllParameters(m5StackBluetoothTransmitter: M5StackBluetoothTransmitter) {
        // viewcontroller doesn't use this
    }
    
    func isReadyToReceiveData(m5StackBluetoothTransmitter: M5StackBluetoothTransmitter) {
        // viewcontroller doesn't use this
    }
    
    func newBlePassWord(newBlePassword: String, m5StackBluetoothTransmitter: M5StackBluetoothTransmitter) {
        
        // note : blePassword is also saved in BluetoothPeripheralManager, it will be saved two times
        if let m5StackPeripheral = bluetoothPeripheralManager?.getBluetoothPeripheral(for: m5StackBluetoothTransmitter) as? M5Stack {
            
            m5StackPeripheral.blepassword = newBlePassword
            
            tableView?.reloadRows(at: [IndexPath(row: CommonM5Setting.blePassword.rawValue, section: 1)], with: .none)
            
        }
        
    }
    
    func authentication(success: Bool, m5StackBluetoothTransmitter: M5StackBluetoothTransmitter) {
        
        if !success, let m5StackPeripheral = bluetoothPeripheralManager?.getBluetoothPeripheral(for: m5StackBluetoothTransmitter) as? M5Stack {
            
            // show warning, inform that user should set password or reset M5Stack
            let alert = UIAlertController(title: Texts_Common.warning, message: Texts_M5StackView.authenticationFailureWarning + " " + Text_BluetoothPeripheralView.alwaysConnect, actionHandler: {
                
                // by the time user clicks 'ok', the M5stack will be disconnected by the BluetoothPeripheralManager (see authentication in BluetoothPeripheralManager)
                self.bluetoothPeripheralViewController?.setShouldConnectToFalse(for: m5StackPeripheral)
                
            })
            
            bluetoothPeripheralViewController?.present(alert, animated: true, completion: nil)
        }
    }
    
    func blePasswordMissing(m5StackBluetoothTransmitter: M5StackBluetoothTransmitter) {
        
        guard let m5StackPeripheral = bluetoothPeripheralManager?.getBluetoothPeripheral(for: m5StackBluetoothTransmitter) as? M5Stack else {return}
        
        // show warning, inform that user should set password
        let alert = UIAlertController(title: Texts_Common.warning, message: Texts_M5StackView.authenticationFailureWarning + " " + Text_BluetoothPeripheralView.alwaysConnect, actionHandler: {
            
            // by the time user clicks 'ok', the M5stack will be disconnected by the BluetoothPeripheralManager (see authentication in BluetoothPeripheralManager)
            self.bluetoothPeripheralViewController?.setShouldConnectToFalse(for: m5StackPeripheral)
            
        })
        
        bluetoothPeripheralViewController?.present(alert, animated: true, completion: nil)
        
    }
    
    func m5StackResetRequired(m5StackBluetoothTransmitter: M5StackBluetoothTransmitter) {
        
        guard let m5StackBluetoothPeripheral = bluetoothPeripheralManager?.getBluetoothPeripheral(for: m5StackBluetoothTransmitter) as? M5Stack else {return}
        
        // show warning, inform that user should reset M5Stack
        let alert = UIAlertController(title: Texts_Common.warning, message: Texts_M5StackView.m5StackResetRequiredWarning + " " + Text_BluetoothPeripheralView.alwaysConnect, actionHandler: {
            
            // by the time user clicks 'ok', the M5stack will be disconnected by the BluetoothPeripheralManager (see authentication in BluetoothPeripheralManager)
            self.bluetoothPeripheralViewController?.setShouldConnectToFalse(for: m5StackBluetoothPeripheral)
            
        })
        
        bluetoothPeripheralViewController?.present(alert, animated: true, completion: nil)
        
    }
    
}

// MARK: - extension BluetoothPeripheralViewModelProtocol

extension M5StackBluetoothPeripheralViewModel: BluetoothPeripheralViewModel {

    func numberOfSections() -> Int {
        return numberOfM5Sections()
    }
    
    func writeTempValues(to bluetoothPeripheral: BluetoothPeripheral) {
        
        guard let m5StackBluetoothPeripheral = bluetoothPeripheral as? M5Stack else {return}
        
        // creating enum to make sure we don't forget new cases
        for setting in SpecificM5StackSettings.allCases {
            switch setting {
                
            case .batteryLevel, .powerOff :
                break

            case .brightness:
                if let brightness = brightnessTemporaryValue {
                    m5StackBluetoothPeripheral.brightness = Int16(brightness)
                }
            }
            
        }
        
        // creating enum to make sure we don't forget new cases
        for setting in CommonM5Setting.allCases {
            switch setting {
                
            case .m5StackHelpText, .blePassword :
                break
                
            case .textColor:
                if let textColorTemporaryValue = textColorTemporaryValue {
                    m5StackBluetoothPeripheral.textcolor = Int32(textColorTemporaryValue.rawValue)
                }
                
            case .backGroundColor:
                if let backGroundColor = backGroundColorTemporaryValue {
                    m5StackBluetoothPeripheral.backGroundColor = Int32(backGroundColor.rawValue)
                }

            case .rotation:
                if let rotation = rotationTempValue {
                    m5StackBluetoothPeripheral.rotation = Int32(rotation)
                }
                
            case .connectToWiFi:
                m5StackBluetoothPeripheral.connectToWiFi = connectToWiFiTempValue ?? false
                
            }
        }
        
    }
    
    func storeTempValues(from bluetoothPeripheral: BluetoothPeripheral) {
        
        guard let m5StackBluetoothPeripheral = bluetoothPeripheral as? M5Stack else {return}
        
        // creating enum to make sure we don't forget new cases
        for setting in SpecificM5StackSettings.allCases {
            
            switch setting {
                
            case .batteryLevel, .powerOff :
                break
                
            case .brightness:
                // temporary store the value of brightness, user can change this via the view, it will be stored back in the m5StackASNSObject only after clicking 'done' button
                brightnessTemporaryValue = Int(m5StackBluetoothPeripheral.brightness)
                
            }
            
        }

        // creating enum to make sure we don't forget new cases
        for setting in CommonM5Setting.allCases {
            
            switch setting {
                
            case .m5StackHelpText, .blePassword :
                break

            case .textColor:
                // temporary store the value of textColor, user can change this via the view, it will be stored back in the m5StackASNSObject only after clicking 'done' button
                textColorTemporaryValue = M5StackColor(forUInt16: UInt16(m5StackBluetoothPeripheral.textcolor))

            case .backGroundColor:
                // temporary store the value of backGroundColor, user can change this via the view, it will be stored back in the m5StackASNSObject only after clicking 'done' button
                backGroundColorTemporaryValue = M5StackColor(forUInt16: UInt16(m5StackBluetoothPeripheral.backGroundColor))

            case .rotation:
                // temporary store the value of rotation, user can change this via the view, it will be stored back in the m5StackASNSObject only after clicking 'done' button
                rotationTempValue = UInt16(m5StackBluetoothPeripheral.rotation)

            case .connectToWiFi:
                // temporary store the value of connectToWiFi, user can change this via the view, it will be stored back in the m5StackASNSObject only after clicking 'done' button
                connectToWiFiTempValue = m5StackBluetoothPeripheral.connectToWiFi

            }
            
        }
        
    }

    func numberOfSettings(inSection section:Int) -> Int {
        
        switch section {
        case 1:
            return CommonM5Setting.allCases.count
        case 2:
            return SpecificM5StackSettings.allCases.count
        default: //shouldn't happen
            return SpecificM5StackSettings.allCases.count
        }

    }
    
    func userDidSelectRow(withSettingRawValue rawValue: Int, forSection section: Int, for bluetoothPeripheral: BluetoothPeripheral, bluetoothPeripheralManager: BluetoothPeripheralManaging, doneButtonOutlet: UIBarButtonItem) -> SettingsSelectedRowAction {
        
        return userDidSelectM5StackRow(withSettingRawValue: rawValue, forSection: section, for: bluetoothPeripheral, bluetoothPeripheralManager: bluetoothPeripheralManager, doneButtonOutlet: doneButtonOutlet)
        
    }

    
    func update(cell: UITableViewCell, forRow row: Int, forSection section: Int, for bluetoothPeripheral: BluetoothPeripheral, doneButtonOutlet: UIBarButtonItem) {
        
        updateM5Stack(cell: cell, forRow: row, forSection: section, for: bluetoothPeripheral, doneButtonOutlet: doneButtonOutlet)
        
    }

    func screenTitle() -> String {
        return m5StackcreenTitle()
    }
    
    func sectionTitle(forSection section: Int) -> String {
        return M5StackSections(rawValue: section)?.sectionTitle() ?? ""
    }
    
    /// - parameters :
    ///    - bluetoothTransmitterDelegate : usually the uiViewController
    ///    - bluetoothPeripheral : if nil then the viewcontroller is opened to scan for a new peripheral
    ///    - bluetoothPeripheralManager : reference to bluetoothPeripheralManaging object
    ///    - tableView : needed to intiate refresh of row
    ///    - bluetoothPeripheralViewController : BluetoothPeripheralViewController
    func configure(bluetoothPeripheral: BluetoothPeripheral?, bluetoothPeripheralManager: BluetoothPeripheralManaging, tableView: UITableView, bluetoothPeripheralViewController: BluetoothPeripheralViewController, bluetoothTransmitterDelegate: BluetoothTransmitterDelegate) {
        
        self.bluetoothPeripheralManager = bluetoothPeripheralManager
        
        self.tableView = tableView
        
        self.bluetoothPeripheralViewController = bluetoothPeripheralViewController
        
        self.bluetoothTransmitterDelegate = bluetoothTransmitterDelegate
        
        if let m5Stack = bluetoothPeripheral as? M5Stack  {
            
            storeTempValues(from: m5Stack)
            
            // also request batteryLevel, this may have been updated
            if let blueToothTransmitter = bluetoothPeripheralManager.getBluetoothTransmitter(for: m5Stack, createANewOneIfNecesssary: false), let m5StackBluetoothTransmitter = blueToothTransmitter as? M5StackBluetoothTransmitter {
                
                _ = m5StackBluetoothTransmitter.readBatteryLevel()
                
            }
            
        }
    }
    
}
