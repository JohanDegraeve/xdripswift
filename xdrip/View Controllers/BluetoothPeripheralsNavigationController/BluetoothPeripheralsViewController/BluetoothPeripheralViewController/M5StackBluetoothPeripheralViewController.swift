import Foundation
import UIKit

/// - a case per attribute that can be set in M5StackBluetoothPeripheralViewController
/// - these are attributes specific to M5StackBluetoothPeripheralViewController, the generic ones are defined in BluetoothPeripheralViewController
fileprivate enum Setting:Int, CaseIterable {
    
    /// ble password
    case blePassword = 4
    
    /// textColor
    case textColor = 5
    
    /// backGroundColor
    case backGroundColor = 6
    
    /// rotation
    case rotation = 7
    
    /// case brightness
    case brightness = 8
    
}

class M5StackBluetoothPeripheralViewController : BluetoothPeripheralViewController {
   
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
    
    /// configure the viewController
    public func configure(m5Stack: M5Stack?, coreDataManager: CoreDataManager, bluetoothPeripheralManager: BluetoothPeripheralManaging) {
        
        super.configure(bluetoothPeripheral: m5Stack, coreDataManager: coreDataManager, bluetoothPeripheralManager: bluetoothPeripheralManager)
        
        if let m5StackASNSObject = bluetoothPeripheralAsNSObject as? M5Stack  {
            
            // temporary store the value of textColor, user can change this via the view, it will be stored back in the m5StackASNSObject only after clicking 'done' button
            textColorTemporaryValue = M5StackColor(forUInt16: UInt16(m5StackASNSObject.textcolor))
            
            // temporary store the value of rotation, user can change this via the view, it will be stored back in the m5StackASNSObject only after clicking 'done' button
            rotationTempValue = UInt16(m5StackASNSObject.rotation)
            
            // temporary store the value of backGroundColor, user can change this via the view, it will be stored back in the m5StackASNSObject only after clicking 'done' button
            backGroundColorTemporaryValue = M5StackColor(forUInt16: UInt16(m5StackASNSObject.backGroundColor))
            
            // temporary store the value of brightness, user can change this via the view, it will be stored back in the m5StackASNSObject only after clicking 'done' button
            brightnessTemporaryValue = Int(m5StackASNSObject.brightness)
            
        }
        
    }
    
    // MARK: - View Life Cycle
    
    override func viewDidLoad() {
        
        super.viewDidLoad()
        
        title = Text_BluetoothPeripheralView.screenTitle
        
    }
    
    // MARK: - overriden functions
    
    /// user cliks done button
    public override func doneButtonHandler() {
        
        if let m5StackASNSObject = bluetoothPeripheralAsNSObject as? M5Stack {
            
            // store value of textColor
            if let textColor = textColorTemporaryValue {
                m5StackASNSObject.textcolor = Int32(textColor.rawValue)
            }
            
            // store value of backGroundColor
            if let backGroundColor = backGroundColorTemporaryValue {
                m5StackASNSObject.backGroundColor = Int32(backGroundColor.rawValue)
            }
            
            // store value of rotation
            if let rotation = rotationTempValue {
                m5StackASNSObject.rotation = Int32(rotation)
            }
            
            // store value of brightness
            if let brightness = brightnessTemporaryValue {
                m5StackASNSObject.brightness = Int16(brightness)
            }
            
        }

        // super to be called at the end, because that one will save the object and return to previous screen
        super.doneButtonHandler()
        
    }
    
    public override func scanForBluetoothPeripheral(type: BluetoothPeripheralType?, callback: ((BluetoothPeripheral) -> ())?) {
        
        // reason for overriding is to set the type, and the callback function, which can set the M5Stack specific attributes (like textColor, backGroundCOlor, rotation)
        
        super.scanForBluetoothPeripheral(type: .M5Stack, callback: { (bluetoothPeripheral) in
            
            guard let m5Stack = bluetoothPeripheral as? M5Stack else {return}
            
            self.textColorTemporaryValue = M5StackColor(forUInt16: UInt16(m5Stack.textcolor))

            self.backGroundColorTemporaryValue = M5StackColor(forUInt16: UInt16(m5Stack.backGroundColor))

            self.rotationTempValue = UInt16(m5Stack.rotation)
            
        })
        
    }

    public override func update(cell: UITableViewCell, withSettingRawValue row: Int) {
        
        // verify that row is within range of setting
        guard let setting = Setting(rawValue: row) else { fatalError("M5StackbluetoothPeripheralViewController cellForRowAt, Unexpected setting")
        }
        
        // verify that bluetoothPeripheralAsNSObject is an M5Stack
        guard let m5Stack = bluetoothPeripheralAsNSObject as? M5Stack else {
            fatalError("M5StackbluetoothPeripheralViewController cellForRowAt, bluetoothPeripheralAsNSObject is not M5Stack")
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
    
    public override func userDidSelectRow(withSettingRawValue rawValue: Int, rowOffset: Int, inTableView tableView: UITableView) {
        
        guard let setting = Setting(rawValue: rawValue) else { fatalError("M5StackBluetoothPeripheralViewController didSelectRowAt, unexpected setting") }

        // configure the cell depending on setting
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
                    if let m5StackPeripheral = self.bluetoothPeripheralAsNSObject {
                        if let textColor = self.textColorTemporaryValue, let blueToothTransmitter = self.bluetoothPeripheralManager.getBluetoothTransmitter(for: m5StackPeripheral, createANewOneIfNecesssary: false), let m5StackBluetoothTransmitter = blueToothTransmitter as? M5StackBluetoothTransmitter, m5StackBluetoothTransmitter.writeTextColor(textColor: textColor) {
                            // do nothing, textColor successfully written to m5Stack - although it's not yet 100% sure because
                        } else {
                            m5StackPeripheral.parameterUpdateNeededAtNextConnect()
                        }
                    }
                    
                    // reload table
                    tableView.reloadRows(at: [IndexPath(row: Setting.textColor.rawValue, section: 0)], with: .none)
                    
                    // enable the done button
                    self.doneButtonOutlet.enable()
                    
                }
                
            }, onCancelClick: nil, didSelectRowHandler: nil)
            
            // create and present PickerViewController
            PickerViewController.displayPickerViewController(pickerViewData: pickerViewData, parentController: self)
            
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
                    if let m5StackPeripheral = self.bluetoothPeripheralAsNSObject {
                        if let backGroundColor = self.backGroundColorTemporaryValue, let blueToothTransmitter = self.bluetoothPeripheralManager.getBluetoothTransmitter(for: m5StackPeripheral, createANewOneIfNecesssary: false), let m5StackBluetoothTransmitter = blueToothTransmitter as? M5StackBluetoothTransmitter, m5StackBluetoothTransmitter.writeBackGroundColor(backGroundColor: backGroundColor) {
                            // do nothing, backGroundColor successfully written to m5Stack - although it's not yet 100% sure because write returns true without waiting for response from bluetooth peripheral
                        } else {
                            m5StackPeripheral.parameterUpdateNeededAtNextConnect()
                        }
                    }
                    
                    // reload table
                    tableView.reloadRows(at: [IndexPath(row: Setting.backGroundColor.rawValue + rowOffset, section: 0)], with: .none)
                    
                    // enable the done button
                    self.doneButtonOutlet.enable()
                    
                }
                
            }, onCancelClick: nil, didSelectRowHandler: nil)
            
            // create and present PickerViewController
            PickerViewController.displayPickerViewController(pickerViewData: pickerViewData, parentController: self)
            
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
                    if let m5StackAsPeripheral = self.bluetoothPeripheralAsNSObject {
                        if let blueToothTransmitter = self.bluetoothPeripheralManager.getBluetoothTransmitter(for: m5StackAsPeripheral, createANewOneIfNecesssary: false), let m5StackBluetoothTransmitter = blueToothTransmitter as? M5StackBluetoothTransmitter, m5StackBluetoothTransmitter.writeRotation(rotation: index) {
                            // do nothing, rotation successfully written to m5Stack - although it's not yet 100% sure because write returns true without waiting for response from bluetooth peripheral
                        } else {
                            m5StackAsPeripheral.parameterUpdateNeededAtNextConnect()
                        }
                    }
                    
                    // reload table
                    tableView.reloadRows(at: [IndexPath(row: Setting.rotation.rawValue, section: 0)], with: .none)
                    
                    // enable the done button
                    self.doneButtonOutlet.enable()
                    
                }
                
            }, onCancelClick: nil, didSelectRowHandler: nil)
            
            // create and present PickerViewController
            PickerViewController.displayPickerViewController(pickerViewData: pickerViewData, parentController: self)
            
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
                    if let m5StackPeripheral = self.bluetoothPeripheralAsNSObject {
                        if let blueToothTransmitter = self.bluetoothPeripheralManager.getBluetoothTransmitter(for: m5StackPeripheral, createANewOneIfNecesssary: false), let m5StackBluetoothTransmitter = blueToothTransmitter as? M5StackBluetoothTransmitter, m5StackBluetoothTransmitter.writeBrightness(brightness: index * 10) {
                            // do nothing, brightness successfully written to m5Stack - although it's not yet 100% sure because write returns true without waiting for response from bluetooth peripheral
                        } else {
                            m5StackPeripheral.parameterUpdateNeededAtNextConnect()
                        }
                    }
                    
                    // reload table
                    tableView.reloadRows(at: [IndexPath(row: Setting.brightness.rawValue, section: 0)], with: .none)
                    
                    // enable the done button
                    self.doneButtonOutlet.enable()
                    
                }
                
            }, onCancelClick: nil, didSelectRowHandler: nil)
            
            // create and present PickerViewController
            PickerViewController.displayPickerViewController(pickerViewData: pickerViewData, parentController: self)
            
            
        }

        
    }

}

extension M5StackBluetoothPeripheralViewController: M5StackBluetoothTransmitterDelegate {
    
    func isAskingForAllParameters(m5StackBluetoothTransmitter: M5StackBluetoothTransmitter) {
        // viewcontroller doesn't use this
    }
    
    func isReadyToReceiveData(m5StackBluetoothTransmitter: M5StackBluetoothTransmitter) {
        // viewcontroller doesn't use this
    }
    
    func newBlePassWord(newBlePassword: String, m5StackBluetoothTransmitter: M5StackBluetoothTransmitter) {
        
        // blePassword is also saved in BluetoothPeripheralManager, it will be saved two times
        if let m5StackPeripheral = bluetoothPeripheralAsNSObject as? M5Stack {
            
            m5StackPeripheral.blepassword = newBlePassword
            
            tableView.reloadRows(at: [IndexPath(row: Setting.blePassword.rawValue, section: 0)], with: .none)
            
        }
        
    }
    
    func authentication(success: Bool, m5StackBluetoothTransmitter: M5StackBluetoothTransmitter) {
        
        if !success, let m5StackBluetoothPeripheral = bluetoothPeripheralAsNSObject as? M5Stack {
            
            // show warning, inform that user should set password or reset M5Stack
            let alert = UIAlertController(title: Texts_Common.warning, message: Text_BluetoothPeripheralView.authenticationFailureWarning + " " + Text_BluetoothPeripheralView.alwaysConnect, actionHandler: {
                
                // by the time user clicks 'ok', the M5stack will be disconnected by the BluetoothPeripheralManager (see authentication in BluetoothPeripheralManager)
                self.setShouldConnectToFalse(for: m5StackBluetoothPeripheral)
                
            })
            
            self.present(alert, animated: true, completion: nil)
        }
    }
    
    func blePasswordMissing(m5StackBluetoothTransmitter: M5StackBluetoothTransmitter) {
        
        guard let m5StackBluetoothPeripheral = bluetoothPeripheralAsNSObject as? M5Stack else {return}
        
        // show warning, inform that user should set password
        let alert = UIAlertController(title: Texts_Common.warning, message: Text_BluetoothPeripheralView.authenticationFailureWarning + " " + Text_BluetoothPeripheralView.alwaysConnect, actionHandler: {
            
            // by the time user clicks 'ok', the M5stack will be disconnected by the BluetoothPeripheralManager (see authentication in BluetoothPeripheralManager)
            self.setShouldConnectToFalse(for: m5StackBluetoothPeripheral)
            
        })
        
        self.present(alert, animated: true, completion: nil)
        
    }
    
    func m5StackResetRequired(m5StackBluetoothTransmitter: M5StackBluetoothTransmitter) {
        
        guard let m5StackBluetoothPeripheral = bluetoothPeripheralAsNSObject as? M5Stack else {return}
        
        // show warning, inform that user should reset M5Stack
        let alert = UIAlertController(title: Texts_Common.warning, message: Text_BluetoothPeripheralView.m5StackResetRequiredWarning + " " + Text_BluetoothPeripheralView.alwaysConnect, actionHandler: {
            
            // by the time user clicks 'ok', the M5stack will be disconnected by the BluetoothPeripheralManager (see authentication in BluetoothPeripheralManager)
            self.setShouldConnectToFalse(for: m5StackBluetoothPeripheral)
            
        })
        
        self.present(alert, animated: true, completion: nil)
        
    }
    

    
}
