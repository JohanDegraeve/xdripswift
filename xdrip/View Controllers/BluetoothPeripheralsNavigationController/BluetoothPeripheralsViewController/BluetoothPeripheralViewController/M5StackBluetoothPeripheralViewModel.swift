import Foundation
import UIKit
import CoreBluetooth

/// - a case per attribute that can be set
/// - these are attributes specific to M5Stack, the generic ones are defined in BluetoothPeripheralViewController
fileprivate enum Setting:Int, CaseIterable {
    
    /// ble password
    case blePassword = 0
    
    /// textColor
    case textColor = 1
    
    /// backGroundColor
    case backGroundColor = 2
    
    /// rotation
    case rotation = 3
    
    /// case brightness
    case brightness = 4
    
}

class M5StackBluetoothPeripheralViewModel {
   
    // MARK: - private properties
    
    /// textColor to be used in M5Stack
    ///
    /// temp storage of value while user is editing the M5Stack attributes
    private var textColorTemporaryValue: M5StackColor?
    
    /// roration to be used in M5Stack
    ///
    /// temp storage of value while user is editing the M5Stack attributes
    private var rotationTempValue: UInt16?
    
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
    
    private weak var bluetoothPeripheralViewController: BluetoothPeripheralViewController?

}

// MARK: - extension BluetoothTransmitterDelegate

extension M5StackBluetoothPeripheralViewModel: BluetoothTransmitterDelegate {
    
    func didConnectTo(bluetoothTransmitter: BluetoothTransmitter) {
        bluetoothPeripheralViewController?.didConnectTo(bluetoothTransmitter: bluetoothTransmitter)
    }
    
    func didDisconnectFrom(bluetoothTransmitter: BluetoothTransmitter) {
        bluetoothPeripheralViewController?.didDisconnectFrom(bluetoothTransmitter: bluetoothTransmitter)
    }
    
    func deviceDidUpdateBluetoothState(state: CBManagerState, bluetoothTransmitter: BluetoothTransmitter) {
        bluetoothPeripheralViewController?.deviceDidUpdateBluetoothState(state: state, bluetoothTransmitter: bluetoothTransmitter)
    }
    
    
}

// MARK: - extension M5StackBluetoothTransmitterDelegate

extension M5StackBluetoothPeripheralViewModel: M5StackBluetoothTransmitterDelegate {
    
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
            
            tableView?.reloadRows(at: [IndexPath(row: Setting.blePassword.rawValue, section: 0)], with: .none)
            
        }
        
    }
    
    func authentication(success: Bool, m5StackBluetoothTransmitter: M5StackBluetoothTransmitter) {
        
        if !success, let m5StackPeripheral = bluetoothPeripheralManager?.getBluetoothPeripheral(for: m5StackBluetoothTransmitter) as? M5Stack {
            
            // show warning, inform that user should set password or reset M5Stack
            let alert = UIAlertController(title: Texts_Common.warning, message: Text_BluetoothPeripheralView.authenticationFailureWarning + " " + Text_BluetoothPeripheralView.alwaysConnect, actionHandler: {
                
                // by the time user clicks 'ok', the M5stack will be disconnected by the BluetoothPeripheralManager (see authentication in BluetoothPeripheralManager)
                self.bluetoothPeripheralViewController?.setShouldConnectToFalse(for: m5StackPeripheral)
                
            })
            
            bluetoothPeripheralViewController?.present(alert, animated: true, completion: nil)
        }
    }
    
    func blePasswordMissing(m5StackBluetoothTransmitter: M5StackBluetoothTransmitter) {
        
        guard let m5StackPeripheral = bluetoothPeripheralManager?.getBluetoothPeripheral(for: m5StackBluetoothTransmitter) as? M5Stack else {return}
        
        // show warning, inform that user should set password
        let alert = UIAlertController(title: Texts_Common.warning, message: Text_BluetoothPeripheralView.authenticationFailureWarning + " " + Text_BluetoothPeripheralView.alwaysConnect, actionHandler: {
            
            // by the time user clicks 'ok', the M5stack will be disconnected by the BluetoothPeripheralManager (see authentication in BluetoothPeripheralManager)
            self.bluetoothPeripheralViewController?.setShouldConnectToFalse(for: m5StackPeripheral)
            
        })
        
        bluetoothPeripheralViewController?.present(alert, animated: true, completion: nil)
        
    }
    
    func m5StackResetRequired(m5StackBluetoothTransmitter: M5StackBluetoothTransmitter) {
        
        guard let m5StackBluetoothPeripheral = bluetoothPeripheralManager?.getBluetoothPeripheral(for: m5StackBluetoothTransmitter) as? M5Stack else {return}
        
        // show warning, inform that user should reset M5Stack
        let alert = UIAlertController(title: Texts_Common.warning, message: Text_BluetoothPeripheralView.m5StackResetRequiredWarning + " " + Text_BluetoothPeripheralView.alwaysConnect, actionHandler: {
            
            // by the time user clicks 'ok', the M5stack will be disconnected by the BluetoothPeripheralManager (see authentication in BluetoothPeripheralManager)
            self.bluetoothPeripheralViewController?.setShouldConnectToFalse(for: m5StackBluetoothPeripheral)
            
        })
        
        bluetoothPeripheralViewController?.present(alert, animated: true, completion: nil)
        
    }
    
}

// MARK: - extension BluetoothPeripheralViewModelProtocol

extension M5StackBluetoothPeripheralViewModel: BluetoothPeripheralViewModel {
    
    func storeTempValues(bluetoothPeripheral: BluetoothPeripheral) {
        
        guard let m5StackBluetoothPeripheral = bluetoothPeripheral as? M5Stack else {return}
        
        // temporary store the value of textColor, user can change this via the view, it will be stored back in the m5StackASNSObject only after clicking 'done' button
        textColorTemporaryValue = M5StackColor(forUInt16: UInt16(m5StackBluetoothPeripheral.textcolor))
        
        // temporary store the value of rotation, user can change this via the view, it will be stored back in the m5StackASNSObject only after clicking 'done' button
        rotationTempValue = UInt16(m5StackBluetoothPeripheral.rotation)
        
        // temporary store the value of backGroundColor, user can change this via the view, it will be stored back in the m5StackASNSObject only after clicking 'done' button
        backGroundColorTemporaryValue = M5StackColor(forUInt16: UInt16(m5StackBluetoothPeripheral.backGroundColor))
        
        // temporary store the value of brightness, user can change this via the view, it will be stored back in the m5StackASNSObject only after clicking 'done' button
        brightnessTemporaryValue = Int(m5StackBluetoothPeripheral.brightness)
        
    }

    func numberOfSettings() -> Int {
        return Setting.allCases.count
    }
    
    func userDidSelectRow(withSettingRawValue rawValue: Int, rowOffset: Int, for bluetoothPeripheral: BluetoothPeripheral, bluetoothPeripheralManager: BluetoothPeripheralManaging, doneButtonOutlet: UIBarButtonItem) {
        
        guard let setting = Setting(rawValue: rawValue) else { fatalError("M5StackBluetoothPeripheralViewModel userDidSelectRow, unexpected setting") }
        
        switch setting {
            
        case .blePassword:
            break
            
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
            
            // configure PickerViewData
            let pickerViewData = PickerViewData(withMainTitle: nil, withSubTitle: Texts_SettingsView.m5StackTextColor, withData: texts, selectedRow: selectedRow, withPriority: nil, actionButtonText: nil, cancelButtonText: nil, onActionClick: {(_ index: Int) in
                
                if index != selectedRow {
                    
                    // set temp value textColor to new textColor
                    self.textColorTemporaryValue = colors[index]
                    
                    // send value to M5Stack, if that would fail then set updateNeeded for that m5Stack
                    if let m5StackPeripheral = bluetoothPeripheral as? M5Stack {
                        if let textColor = self.textColorTemporaryValue, let blueToothTransmitter = bluetoothPeripheralManager.getBluetoothTransmitter(for: m5StackPeripheral, createANewOneIfNecesssary: false), let m5StackBluetoothTransmitter = blueToothTransmitter as? M5StackBluetoothTransmitter, m5StackBluetoothTransmitter.writeTextColor(textColor: textColor) {
                            // do nothing, textColor successfully written to m5Stack - although it's not yet 100% sure because
                        } else {
                            m5StackPeripheral.parameterUpdateNeededAtNextConnect()
                        }
                    }
                    
                    // reload table
                    self.tableView?.reloadRows(at: [IndexPath(row: Setting.textColor.rawValue + rowOffset, section: 0)], with: .none)
                    
                    // enable the done button
                    doneButtonOutlet.enable()
                    
                }
                
            }, onCancelClick: nil, didSelectRowHandler: nil)
            
            // create and present PickerViewController
            if let bluetoothPeripheralViewController = bluetoothPeripheralViewController {
                PickerViewController.displayPickerViewController(pickerViewData: pickerViewData, parentController: bluetoothPeripheralViewController)
            }
            
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
            
            // configure PickerViewData
            let pickerViewData = PickerViewData(withMainTitle: nil, withSubTitle: Texts_SettingsView.m5StackbackGroundColor, withData: texts, selectedRow: selectedRow, withPriority: nil, actionButtonText: nil, cancelButtonText: nil, onActionClick: {(_ index: Int) in
                
                if index != selectedRow {
                    
                    // set temp value backGroundColor to new backGroundColor
                    self.backGroundColorTemporaryValue = colors[index]
                    
                    // send value to M5Stack, if that would fail then set updateNeeded for that m5Stack
                    if let m5StackPeripheral = bluetoothPeripheral as? M5Stack {
                        if let backGroundColor = self.backGroundColorTemporaryValue, let blueToothTransmitter = bluetoothPeripheralManager.getBluetoothTransmitter(for: m5StackPeripheral, createANewOneIfNecesssary: false), let m5StackBluetoothTransmitter = blueToothTransmitter as? M5StackBluetoothTransmitter, m5StackBluetoothTransmitter.writeBackGroundColor(backGroundColor: backGroundColor) {
                            // do nothing, backGroundColor successfully written to m5Stack - although it's not yet 100% sure because write returns true without waiting for response from bluetooth peripheral
                        } else {
                            m5StackPeripheral.parameterUpdateNeededAtNextConnect()
                        }
                    }
                    
                    // reload table
                    self.tableView?.reloadRows(at: [IndexPath(row: Setting.backGroundColor.rawValue + rowOffset, section: 0)], with: .none)
                    
                    // enable the done button
                    doneButtonOutlet.enable()
                    
                }
                
            }, onCancelClick: nil, didSelectRowHandler: nil)
            
            // create and present PickerViewController
            if let bluetoothPeripheralViewController = bluetoothPeripheralViewController {
                PickerViewController.displayPickerViewController(pickerViewData: pickerViewData, parentController: bluetoothPeripheralViewController)
            }

        case .rotation:
            //find index for rotation stored in M5Stack or userdefaults
            var selectedRow:Int? = nil
            if let rotation = rotationTempValue {
                selectedRow = Int(rotation)
            } else {
                selectedRow = Int(ConstantsM5Stack.defaultRotation)
            }
            
            // configure PickerViewData
            let pickerViewData = PickerViewData(withMainTitle: nil, withSubTitle: Texts_SettingsView.m5StackRotation, withData: rotationStrings, selectedRow: selectedRow, withPriority: nil, actionButtonText: nil, cancelButtonText: nil, onActionClick: {(_ index: Int) in
                
                if index != selectedRow {
                    
                    // set rotationTempValue to new rotation
                    self.rotationTempValue = UInt16(index)
                    
                    // send value to M5Stack, if that would fail then set updateNeeded for that m5Stack
                    if let m5StackAsPeripheral = bluetoothPeripheral as? M5Stack {
                        if let blueToothTransmitter = bluetoothPeripheralManager.getBluetoothTransmitter(for: m5StackAsPeripheral, createANewOneIfNecesssary: false), let m5StackBluetoothTransmitter = blueToothTransmitter as? M5StackBluetoothTransmitter, m5StackBluetoothTransmitter.writeRotation(rotation: index) {
                            // do nothing, rotation successfully written to m5Stack - although it's not yet 100% sure because write returns true without waiting for response from bluetooth peripheral
                        } else {
                            m5StackAsPeripheral.parameterUpdateNeededAtNextConnect()
                        }
                    }
                    
                    // reload table
                    self.tableView?.reloadRows(at: [IndexPath(row: Setting.rotation.rawValue + rowOffset, section: 0)], with: .none)
                    
                    // enable the done button
                    doneButtonOutlet.enable()
                    
                }
                
            }, onCancelClick: nil, didSelectRowHandler: nil)
            
            // create and present PickerViewController
            if let bluetoothPeripheralViewController = bluetoothPeripheralViewController {
                PickerViewController.displayPickerViewController(pickerViewData: pickerViewData, parentController: bluetoothPeripheralViewController)
            }

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
            
            // configure PickerViewData
            let pickerViewData = PickerViewData(withMainTitle: nil, withSubTitle: Texts_SettingsView.m5StackBrightness, withData: brightnessStrings, selectedRow: selectedRow, withPriority: nil, actionButtonText: nil, cancelButtonText: nil, onActionClick: {(_ index: Int) in
                
                if index != selectedRow {
                    
                    // set rotationTempValue to new rotation
                    self.brightnessTemporaryValue = index * 10
                    
                    // send value to M5Stack, if that would fail then set updateNeeded for that m5Stack
                    if let m5StackPeripheral = bluetoothPeripheral as? M5Stack {
                        if let blueToothTransmitter = bluetoothPeripheralManager.getBluetoothTransmitter(for: m5StackPeripheral, createANewOneIfNecesssary: false), let m5StackBluetoothTransmitter = blueToothTransmitter as? M5StackBluetoothTransmitter, m5StackBluetoothTransmitter.writeBrightness(brightness: index * 10) {
                            // do nothing, brightness successfully written to m5Stack - although it's not yet 100% sure because write returns true without waiting for response from bluetooth peripheral
                        } else {
                            m5StackPeripheral.parameterUpdateNeededAtNextConnect()
                        }
                    }
                    
                    // reload table
                    self.tableView?.reloadRows(at: [IndexPath(row: Setting.brightness.rawValue + rowOffset, section: 0)], with: .none)
                    
                    // enable the done button
                    doneButtonOutlet.enable()
                    
                }
                
            }, onCancelClick: nil, didSelectRowHandler: nil)
            
            // create and present PickerViewController
            if let bluetoothPeripheralViewController = bluetoothPeripheralViewController {
                PickerViewController.displayPickerViewController(pickerViewData: pickerViewData, parentController: bluetoothPeripheralViewController)
            }

        }

    }

    
    func update(cell: UITableViewCell, withSettingRawValue rawValue: Int, for bluetoothPeripheral: BluetoothPeripheral) {
        
        // verify that rawValue is within range of setting
        guard let setting = Setting(rawValue: rawValue) else { fatalError("M5StackBluetoothPeripheralViewModel update, Unexpected setting")
        }
        
        // verify that bluetoothPeripheralAsNSObject is an M5Stack
        guard let m5Stack = bluetoothPeripheral as? M5Stack else {
            fatalError("M5StackBluetoothPeripheralViewModel update, bluetoothPeripheral is not M5Stack")
        }
        
        // default value for accessoryView is nil
        cell.accessoryView = nil
        
        // configure the cell depending on setting
        switch setting {
            
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
            
        case .brightness:
            cell.textLabel?.text = Texts_SettingsView.m5StackBrightness
            
            if let brightness = brightnessTemporaryValue {
                cell.detailTextLabel?.text = brightnessStrings[Int(brightness/10)]
            } else {
                cell.detailTextLabel?.text = brightnessStrings[brightnessStrings.count - 1]
            }
            
            cell.accessoryType = .disclosureIndicator
            
        }

    }

    func doneButtonHandler(bluetoothPeripheral: BluetoothPeripheral?) {
        
        if let bluetoothPeripheral = bluetoothPeripheral as? M5Stack {
            
            // store value of textColor
            if let textColor = textColorTemporaryValue {
                bluetoothPeripheral.textcolor = Int32(textColor.rawValue)
            }
            
            // store value of backGroundColor
            if let backGroundColor = backGroundColorTemporaryValue {
                bluetoothPeripheral.backGroundColor = Int32(backGroundColor.rawValue)
            }
            
            // store value of rotation
            if let rotation = rotationTempValue {
                bluetoothPeripheral.rotation = Int32(rotation)
            }
            
            // store value of brightness
            if let brightness = brightnessTemporaryValue {
                bluetoothPeripheral.brightness = Int16(brightness)
            }
            
        }

    }
    
    func screenTitle() -> String {
        Text_BluetoothPeripheralView.screenTitle
    }
    
    func configure(bluetoothPeripheral: BluetoothPeripheral?, bluetoothPeripheralManager: BluetoothPeripheralManaging, tableView: UITableView, bluetoothPeripheralViewController: BluetoothPeripheralViewController) {
        
        self.bluetoothPeripheralManager = bluetoothPeripheralManager
        
        self.tableView = tableView
        
        self.bluetoothPeripheralViewController = bluetoothPeripheralViewController
        
        if let bluetoothPeripheral = bluetoothPeripheral as? M5Stack  {
            
            storeTempValues(bluetoothPeripheral: bluetoothPeripheral)
            
        }
    }
    
}
