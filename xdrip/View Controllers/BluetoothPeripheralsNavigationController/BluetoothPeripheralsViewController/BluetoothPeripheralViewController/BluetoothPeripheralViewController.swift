import UIKit
import CoreBluetooth

/// a case per attribute that can be set in M5StackViewController
fileprivate enum Setting:Int, CaseIterable {
    
    /// the address
    case address = 0
    
    /// the name received from bluetoothTransmitter, ie the name hardcoded in the M5Stack
    case name = 1

    /// the alias that user has given, possibly nil
    case userDefinedName = 2
    
    /// the current connection status
    case connectionStatus = 3
    
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

/// UIViewController to show 
final class BluetoothPeripheralViewController: UIViewController {
    
    // MARK: - IBOutlet's and IBAction's
    
    /// action for connectButton, will also be used to disconnect, depending on the connection status
    @IBAction func connectButtonAction(_ sender: UIButton) {
        connectButtonAction()
    }
    
    /// action to confirm changes if any
    @IBAction func doneButtonAction(_ sender: UIBarButtonItem) {
        doneButtonAction()
    }
    
    /// action for trashButton, to delete the M5Stack
    @IBAction func trashButtonAction(_ sender: UIBarButtonItem) {
        trashButtonAction()
    }

    /// action for scan Button, to scan for M5Stack
    @IBAction func scanButtonAction(_ sender: UIButton) {
        scanButtonAction()
    }
    

    @IBAction func cancelButtonAction(_ sender: UIBarButtonItem) {
        cancelButtonAction()
    }
    
    /// outlet for scanButton, to set the text in the scanButton
    @IBOutlet weak var scanButtonOutlet: UIButton!
    
    /// outlet for connectButton, to set the text in the connectButton
    @IBOutlet weak var connectButtonOutlet: UIButton!

    /// outlet for trashButton, to enable or disable
    @IBOutlet weak var trashButtonOutlet: UIBarButtonItem!
    
    /// outlet for doneButton, to enable or disable
    @IBOutlet weak var doneButtonOutlet: UIBarButtonItem!
    
    /// outlet for tableView
    @IBOutlet weak var tableView: UITableView!
    
    /// outlet for topLabel, to show in what screen user is
    @IBOutlet weak var topLabel: UILabel!
    
    // MARK: - private properties
    
    /// the m5stack being edited - will only be used initially to initialize the temp properties used locally, and in the end to update the m5stack - if nil then it's about creating a new m5stack
    private var bluetoothPeripheralAsNSObject:M5Stack?
    
    /// this is for cases where a new M5Stack is being scanned. If there's a new M5Stack, and if the user has clicked 'done', then when closing the viewcontroller, the M5Stack should be deleted. This attribute defines if the M5Stack should be deleted or not
    private var deleteM5StackWhenClosingViewController: Bool = false

    /// reference to coreDataManager
    private var coreDataManager:CoreDataManager?
    
    /// a BluetoothPeripheralManager
    private weak var bluetoothPeripheralManager: BluetoothPeripheralManaging?
    
    /// name given by user as alias , to easier recognize different M5Stacks
    ///
    /// temp storage of value while user is editing the M5Stack attributes
    private var userDefinedNameTemporaryValue: String?
    
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
    
    /// M5StackNames accessor
    private var m5StackNameAccessor: M5StackNameAccessor?
    
    /// possible rotation keys, , the value is shown to the user
    private let rotationStrings: [String] = [ "0", "90", "180", "270"]
    
    /// possible brightness values, the value is shown to the user
    private let brightnessStrings: [String] = ["0", "10", "20", "30", "40", "50", "60", "70", "80", "90", "100"]
    
    // MARK:- public functions
    
    /// configure the viewController
    public func configure(bluetoothPeripheral: BluetoothPeripheral?, coreDataManager: CoreDataManager, bluetoothPeripheralManager: BluetoothPeripheralManaging) {
        
        self.bluetoothPeripheralASNSObject = bluetoothPeripheral
        self.coreDataManager = coreDataManager
        self.m5StackNameAccessor = M5StackNameAccessor(coreDataManager: coreDataManager)
        self.bluetoothPeripheralManager = bluetoothPeripheralManager
        
        if let bluetoothPeripheralASNSObject = bluetoothPeripheralAsNSObject {
            
            // set self as delegate in bluetoothTransmitter
            if let bluetoothTransmitter = bluetoothPeripheralManager.m5StackBluetoothTransmitter(forBluetoothPeripheral: bluetoothPeripheralASNSObject, createANewOneIfNecesssary: false) {
                bluetoothTransmitter.m5StackBluetoothTransmitterDelegateVariable = self
            }
            
            // temporary store the userDefinedName, user can change this name via the view, it will be stored back in the bluetoothPeripheralASNSObject only after clicking 'done' button
            userDefinedNameTemporaryValue = bluetoothPeripheralASNSObject.m5StackName?.userDefinedName
            
            // temporary store the value of textColor, user can change this via the view, it will be stored back in the bluetoothPeripheralASNSObject only after clicking 'done' button
            textColorTemporaryValue = M5StackColor(forUInt16: UInt16(bluetoothPeripheralASNSObject.textcolor))
            
            // temporary store the value of rotation, user can change this via the view, it will be stored back in the bluetoothPeripheralASNSObject only after clicking 'done' button
            rotationTempValue = UInt16(bluetoothPeripheralASNSObject.rotation)
            
            // temporary store the value of backGroundColor, user can change this via the view, it will be stored back in the bluetoothPeripheralASNSObject only after clicking 'done' button
            backGroundColorTemporaryValue = M5StackColor(forUInt16: UInt16(bluetoothPeripheralASNSObject.backGroundColor))
            
            // temporary store the value of brightness, user can change this via the view, it will be stored back in the bluetoothPeripheralASNSObject only after clicking 'done' button
            brightnessTemporaryValue = Int(bluetoothPeripheralASNSObject.brightness)
            
            // don't delete the M5Stack when going back to prevous viewcontroller
            deleteM5StackWhenClosingViewController = false
            
        }
        
    }
    
    // MARK: - View Life Cycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        title = Text_BluetoothPeripheralView.screenTitle
        
        setupView()
    }
    
    // MARK: - other overriden functions
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        
        guard let segueIdentifier = segue.identifier else {
            fatalError("In M5StackViewController, prepare for segue, Segue had no identifier")
        }
        
        guard let segueIdentifierAsCase = BluetoothPeripheralViewController.UnwindSegueIdentifiers(rawValue: segueIdentifier) else {
            fatalError("In M5StackViewController, segueIdentifierAsCase could not be initialized")
        }
        
        switch segueIdentifierAsCase {
            
        case BluetoothPeripheralViewController.UnwindSegueIdentifiers.M5StackToBluetoothPeripheralsUnWindSegueIdentifier:
            
            if deleteM5StackWhenClosingViewController, let bluetoothPeripheralASNSObject = bluetoothPeripheralAsNSObject {
                bluetoothPeripheralManager?.deleteBluetoothPeripheral(bluetoothPeripheral: bluetoothPeripheralASNSObject)
            }
        }
    }

    // MARK: - View Methods
    
    private func setupView() {
        
        // set label of connect button, according to current status
        setConnectButtonLabelText()
        
        if bluetoothPeripheralAsNSObject == nil {

            // should be disabled, as there's nothing to delete yet
            trashButtonOutlet.disable()
            
            // connect button should be disabled, as there's nothing to connect to
            connectButtonOutlet.disable()

        } else {
            
            // there's already a known m5stack, no need to scan for it
            scanButtonOutlet.disable()
            
        }
        
        // initially donebutton is disabled, it will get enabled as soon as a new M5Stack is scanned for, or changes are done in the existing M5Stack settings
        doneButtonOutlet.disable()
        
        setupTableView()
        
    }
    
    // MARK: - private helper functions
    
    /// setup datasource, delegate, seperatorInset
    private func setupTableView() {
        if let tableView = tableView {
            tableView.separatorInset = UIEdgeInsets.zero
            tableView.dataSource = self
            tableView.delegate = self
        }
    }
    
    /// helper function to transform the optional global variable coredatamanager in to a non-optional
    private func getCoreDataManager() -> CoreDataManager {
        if let coreDataManager = coreDataManager {
            return coreDataManager
        } else {
            fatalError("in M5StackViewController, coreDataManager is nil")
        }
    }
    
    /// user cliks done button
    private func doneButtonAction() {
        
        if let bluetoothPeripheralASNSObject = bluetoothPeripheralAsNSObject, let coreDataManager = coreDataManager, let m5StackNameAccessor = m5StackNameAccessor {
            
            // set variable delegate in bluetoothPeripheralASNSObject to nil,  no need anymore to receive info
            bluetoothPeripheralManager?.m5StackBluetoothTransmitter(forBluetoothPeripheral: bluetoothPeripheralASNSObject, createANewOneIfNecesssary: false)?.m5StackBluetoothTransmitterDelegateVariable = nil
            
            // if user has set or changed a userDefinedName, stored it, or delete it if userDefinedName is set to nil
            if let m5StackName = bluetoothPeripheralASNSObject.m5StackName {
                if let userDefinedName = userDefinedNameTemporaryValue {
                    m5StackName.userDefinedName = userDefinedName
                } else {
                    // user has set the userDefinedName to nil, let's delete that m5stackname
                    m5StackNameAccessor.deleteM5StackName(m5StackName: m5StackName)
                }
                
            } else if let userDefinedName = userDefinedNameTemporaryValue {
                let m5Stackname = M5StackName(address: bluetoothPeripheralASNSObject.address, userDefinedName: userDefinedName, nsManagedObjectContext: coreDataManager.mainManagedObjectContext)
                bluetoothPeripheralASNSObject.m5StackName = m5Stackname
            }
            
            // store value of textColor
            if let textColor = textColorTemporaryValue {
                bluetoothPeripheralASNSObject.textcolor = Int32(textColor.rawValue)
            }
            
            // store value of backGroundColor
            if let backGroundColor = backGroundColorTemporaryValue {
                bluetoothPeripheralASNSObject.backGroundColor = Int32(backGroundColor.rawValue)
            }

            // store value of rotation
            if let rotation = rotationTempValue {
                bluetoothPeripheralASNSObject.rotation = Int32(rotation)
            }
            
            // store value of brightness
            if let brightness = brightnessTemporaryValue {
                bluetoothPeripheralASNSObject.brightness = Int16(brightness)
            }
            
            // save all changes now
            coreDataManager.saveChanges()

        }
        
        // don't delete the M5Stack when going back to prevous viewcontroller
        self.deleteM5StackWhenClosingViewController = false
        
        // return to BluetoothPeripheralsViewController
        performSegue(withIdentifier: UnwindSegueIdentifiers.M5StackToBluetoothPeripheralsUnWindSegueIdentifier.rawValue, sender: self)
        
    }
    
    /// user clicks scan button
    private func scanButtonAction() {
        
        // if bluetoothPeripheralASNSObject is not nil, then there's already an M5stack for which scanning has started or which is already known from a previous scan (either connected or not connected) (bluetoothPeripheralASNSObject should be nil because if it is not, the scanbutton should not even be enabled, anyway let's check).
        // Also check BluetoothPeripheralManager not nil
        guard bluetoothPeripheralAsNSObject == nil, let bluetoothPeripheralManager =  bluetoothPeripheralManager else {return}
        
        bluetoothPeripheralManager.startScanningForNewDevice(callback: { (m5Stack) in
            
            // assign internal bluetoothPeripheralASNSObject to new m5Stack
            self.bluetoothPeripheralASNSObject = m5Stack
            
            // assign local variables
            self.userDefinedNameTemporaryValue = m5Stack.m5StackName?.userDefinedName //should be nil anyway
            self.textColorTemporaryValue = M5StackColor(forUInt16: UInt16(m5Stack.textcolor))
            self.backGroundColorTemporaryValue = M5StackColor(forUInt16: UInt16(m5Stack.backGroundColor))
            self.rotationTempValue = UInt16(m5Stack.rotation)
            
            // reload the full section , all rows in the tableView
            self.tableView.reloadSections(IndexSet(integer: 0), with: .none)
            
            // enable the connect button
            self.connectButtonOutlet.enable()
            
            // set right rext for connect button
            self.setConnectButtonLabelText()
            
            // enable the trashbutton
            self.trashButtonOutlet.enable()
            
            // enable the doneButtonAction
            self.doneButtonOutlet.enable()
            
            // if user goes back to previous screen via the back button, then delete the newly discovered M5Stack
            self.deleteM5StackWhenClosingViewController = true
            
            // set self as delegate in the bluetoothTransmitter
            self.bluetoothPeripheralManager?.m5StackBluetoothTransmitter(forBluetoothPeripheral: m5Stack, createANewOneIfNecesssary: false)?.m5StackBluetoothTransmitterDelegateVariable = self
            
            })
        
        // scanning now, scanning button can be disabled
        scanButtonOutlet.disable()
        
    }
    
    private func trashButtonAction() {
        
        // let's first check if m5stack exists, otherwise there's nothing to trash, normally this shouldn't happen because trashbutton should be disabled if there's no bluetoothPeripheralASNSObject
        guard let bluetoothPeripheralASNSObject = bluetoothPeripheralAsNSObject else {return}

        // textToAdd is either 'address' + the address, or 'alias' + the userDefinedName, depending if userDefinedName has a value
        var textToAdd = Text_BluetoothPeripheralView.address + bluetoothPeripheralASNSObject.address
        if let userDefinedName = userDefinedNameTemporaryValue {
            textToAdd = Text_BluetoothPeripheralView.m5StackAlias + userDefinedName
        }
        
        // first ask user if ok to delete and if yes delete
        let alert = UIAlertController(title: Text_BluetoothPeripheralView.confirmDeletionM5Stack + " " + textToAdd + "?", message: nil, actionHandler: {
            
            // delete
            self.bluetoothPeripheralManager?.deleteBluetoothPeripheral(bluetoothPeripheral: bluetoothPeripheralASNSObject)
            
            // as the M5Stack is already deleted, there's no need to call delete again, when prepareForSegue
            self.deleteM5StackWhenClosingViewController = false
            
            self.performSegue(withIdentifier: UnwindSegueIdentifiers.M5StackToBluetoothPeripheralsUnWindSegueIdentifier.rawValue, sender: self)
            
        }, cancelHandler: nil)
        
        self.present(alert, animated:true)

    }
    
    private func connectButtonAction() {
        
        // let's first check if m5stack exists, it should because otherwise connectButton should be disabled
        guard let bluetoothPeripheralASNSObject = bluetoothPeripheralAsNSObject else {return}
        
        if bluetoothPeripheralASNSObject.shouldconnect {
            
            // device should not automaticaly connect, which means, each time the app restarts, it will not try to connect to this M5Stack
            bluetoothPeripheralASNSObject.shouldconnect = false
            
            // save the update in coredata
            coreDataManager?.saveChanges()

            // update the connect button text
            setConnectButtonLabelText()

            // normally there should be a bluetoothTransmitter
            if let bluetoothTransmitter = bluetoothPeripheralManager?.m5StackBluetoothTransmitter(forBluetoothPeripheral: bluetoothPeripheralASNSObject, createANewOneIfNecesssary: false) {
                
                // set delegate in bluetoothtransmitter to nil, as we're going to disconnect permenantly, so not interested anymore to receive info
                bluetoothTransmitter.m5StackBluetoothTransmitterDelegateVariable = nil

                // this will also set bluetoothTransmitter to nil and also disconnect the M5Stack
                bluetoothPeripheralManager?.setBluetoothTransmitterToNil(forBluetoothPeripheral: bluetoothPeripheralASNSObject)
                
            }
            
        } else {
            
            // device should automatically connect, this will be stored in coredata
            bluetoothPeripheralASNSObject.shouldconnect = true
            coreDataManager?.saveChanges()
            
            // get bluetoothTransmitter
            if let bluetoothTransmitter = bluetoothPeripheralManager?.m5StackBluetoothTransmitter(forBluetoothPeripheral: bluetoothPeripheralASNSObject, createANewOneIfNecesssary: true) {
                
                // set delegate
                bluetoothTransmitter.m5StackBluetoothTransmitterDelegateVariable = self
                
                // connect
                bluetoothTransmitter.connect()
                
            }
            
        }
        
        // will change text of the button
        self.setConnectButtonLabelText()
        
    }
    
    /// checks if bluetoothPeripheralASNSObject is not nil, etc.
    /// - returns: true if m5stack exists and is connected, false in all other cases
    private func m5StackIsConnected() -> Bool {
        
        guard let bluetoothPeripheralASNSObject = bluetoothPeripheralAsNSObject else {return false}
        
        guard let connectionStatus = bluetoothPeripheralManager?.m5StackBluetoothTransmitter(forBluetoothPeripheral: bluetoothPeripheralASNSObject, createANewOneIfNecesssary: false)?.getConnectionStatus() else {return false}
        
        return connectionStatus == CBPeripheralState.connected

    }
    
    private func setConnectButtonLabelText() {

        // if M5Stack is nil, then set text to "Always Connect", it's disabled anyway - if m5Stack not nil, then set depending on value of shouldconnect
        if let bluetoothPeripheralASNSObject = bluetoothPeripheralAsNSObject {
            
            // set label of connect button, according to curren status
            connectButtonOutlet.setTitle(bluetoothPeripheralASNSObject.shouldconnect ? Text_BluetoothPeripheralView.donotconnect:Text_BluetoothPeripheralView.alwaysConnect, for: .normal)
            
        } else {
            
            connectButtonOutlet.setTitle(Text_BluetoothPeripheralView.alwaysConnect, for: .normal)
            
        }
        
    }
    
    /// user clicked cancel button
    private func cancelButtonAction() {
        
        // just in case scanning for a new device is still ongoing, call stopscanning
        bluetoothPeripheralManager?.stopScanningForNewDevice()
        
        // return to BluetoothPeripheralsViewController
        performSegue(withIdentifier: UnwindSegueIdentifiers.M5StackToBluetoothPeripheralsUnWindSegueIdentifier.rawValue, sender: self)

    }

    /// sets m5Stack.shouldconnect to false, saves in coredata, calls setConnectButtonLabelText
    private func setShouldConnectToFalse(forM5Stack m5Stack: M5Stack) {

        m5Stack.shouldconnect = false
        
        coreDataManager?.saveChanges()
        
        self.setConnectButtonLabelText()

    }
}

// MARK: - extensions

// MARK: extension UITableViewDataSource, UITableViewDelegate

extension BluetoothPeripheralViewController: UITableViewDataSource, UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return Setting.allCases.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        guard let cell = tableView.dequeueReusableCell(withIdentifier: SettingsTableViewCell.reuseIdentifier, for: indexPath) as? SettingsTableViewCell else { fatalError("M5StackViewController cellforrowat, Unexpected Table View Cell ") }
        
        guard let setting = Setting(rawValue: indexPath.row) else { fatalError("M5StackViewController cellForRowAt, Unexpected setting") }
        
        // default value for accessoryView is nil
        cell.accessoryView = nil
        
        // configure the cell depending on setting
        switch setting {
            
        case .name:
            cell.textLabel?.text = Texts_Common.name
            cell.detailTextLabel?.text = bluetoothPeripheralAsNSObject?.name
            cell.accessoryType = .none
            
        case .address:
            cell.textLabel?.text = Text_BluetoothPeripheralView.address
            cell.detailTextLabel?.text = bluetoothPeripheralAsNSObject?.address
            cell.accessoryType = .disclosureIndicator
            
        case .blePassword:
            cell.textLabel?.text = Texts_Common.password
            cell.detailTextLabel?.text = bluetoothPeripheralAsNSObject?.blepassword
            cell.accessoryType = .none

        case .connectionStatus:
            cell.textLabel?.text = Text_BluetoothPeripheralView.status
            cell.detailTextLabel?.text = bluetoothPeripheralAsNSObject == nil ? nil : m5StackIsConnected() ? Text_BluetoothPeripheralView.connected:Text_BluetoothPeripheralView.notConnected
            
        case .userDefinedName:
            cell.textLabel?.text = Text_BluetoothPeripheralView.m5StackAlias
            cell.detailTextLabel?.text = userDefinedNameTemporaryValue
            cell.accessoryType = .disclosureIndicator
            
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
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        tableView.deselectRow(at: indexPath, animated: true)
        
        guard let setting = Setting(rawValue: indexPath.row) else { fatalError("M5StackViewController didSelectRowAt, Unexpected setting") }
        
        // configure the cell depending on setting
        switch setting {
            
        case .address:
            guard let bluetoothPeripheralASNSObject = bluetoothPeripheralAsNSObject else {return}
            
            let alert = UIAlertController(title: Text_BluetoothPeripheralView.address, message: bluetoothPeripheralASNSObject.address, actionHandler: nil)
            
            // present the alert
            self.present(alert, animated: true, completion: nil)
            
        case .name, .blePassword, .connectionStatus:
            break

        case .userDefinedName:
            
            // clicked cell to change userdefined name (alias) - need to ask for new name, and verify if there's already another M5Stack existing with the same name

            // first off al check that M5Stack already exists, otherwise makes no sense to change the name, check here also m5StackNameAccessor, although should not be nil, but it needs to happen
            guard let bluetoothPeripheralASNSObject = bluetoothPeripheralAsNSObject, let m5StackNameAccessor = m5StackNameAccessor  else {return}
            
            let alert = UIAlertController(title: Text_BluetoothPeripheralView.m5StackAlias, message: Text_BluetoothPeripheralView.selectAliasText, keyboardType: .default, text: userDefinedNameTemporaryValue, placeHolder: nil, actionTitle: nil, cancelTitle: nil, actionHandler: { (text:String) in
                
                let newUserDefinedName = text.toNilIfLength0()
                
                if newUserDefinedName != nil {
                    for m5StackName in m5StackNameAccessor.getM5StackNames() {
                        // not checking address of bluetoothPeripheralASNSObject, because obviously that one could have the same userdefinedname
                        if m5StackName.address != bluetoothPeripheralASNSObject.address {
                            if m5StackName.userDefinedName == text {
                                
                                // m5stack userdefined name already exists
                                let alreadyExistsAlert = UIAlertController(title: Texts_Common.warning, message: Text_BluetoothPeripheralView.userdefinedNameAlreadyExists, actionHandler: nil)
                                
                                // present the alert
                                self.present(alreadyExistsAlert, animated: true, completion: nil)
                                
                                return
                                
                            }
                        }
                    }
                }
                
                // not returned during loop, means name is unique
                self.userDefinedNameTemporaryValue = newUserDefinedName
                
                // reload the specific row in the table
                tableView.reloadRows(at: [IndexPath(row: Setting.userDefinedName.rawValue, section: 0)], with: .none)
                
                // enable the done button
                self.doneButtonOutlet.enable()
                
            }, cancelHandler: nil)
            
            // present the alert
            self.present(alert, animated: true, completion: nil)
            
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
                    if let m5Stack = self.bluetoothPeripheralAsNSObject, let bluetoothPeripheralManager = self.bluetoothPeripheralManager {
                        if let textColor = self.textColorTemporaryValue, let blueToothTransmitter = bluetoothPeripheralManager.m5StackBluetoothTransmitter(forBluetoothPeripheral: m5Stack, createANewOneIfNecesssary: false), blueToothTransmitter.writeTextColor(textColor: textColor) {
                            // do nothing, textColor successfully written to m5Stack - although it's not yet 100% sure because 
                        } else {
                            bluetoothPeripheralManager.updateNeeded(forBluetoothPeripheral: m5Stack)
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
                    if let m5Stack = self.bluetoothPeripheralAsNSObject, let bluetoothPeripheralManager = self.bluetoothPeripheralManager {
                        if let backGroundColor = self.backGroundColorTemporaryValue, let blueToothTransmitter = bluetoothPeripheralManager.m5StackBluetoothTransmitter(forBluetoothPeripheral: m5Stack, createANewOneIfNecesssary: false), blueToothTransmitter.writeBackGroundColor(backGroundColor: backGroundColor) {
                            // do nothing, backGroundColor successfully written to m5Stack - although it's not yet 100% sure because write returns true without waiting for response from bluetooth peripheral
                        } else {
                            bluetoothPeripheralManager.updateNeeded(forBluetoothPeripheral: m5Stack)
                        }
                    }
                    
                    // reload table
                    tableView.reloadRows(at: [IndexPath(row: Setting.backGroundColor.rawValue, section: 0)], with: .none)
                    
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
                    if let m5Stack = self.bluetoothPeripheralAsNSObject, let bluetoothPeripheralManager = self.bluetoothPeripheralManager {
                        if let blueToothTransmitter = bluetoothPeripheralManager.m5StackBluetoothTransmitter(forBluetoothPeripheral: m5Stack, createANewOneIfNecesssary: false), blueToothTransmitter.writeRotation(rotation: index) {
                            // do nothing, rotation successfully written to m5Stack - although it's not yet 100% sure because write returns true without waiting for response from bluetooth peripheral
                        } else {
                            bluetoothPeripheralManager.updateNeeded(forBluetoothPeripheral: m5Stack)
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
                    if let m5Stack = self.bluetoothPeripheralAsNSObject, let bluetoothPeripheralManager = self.bluetoothPeripheralManager {
                        if let blueToothTransmitter = bluetoothPeripheralManager.m5StackBluetoothTransmitter(forBluetoothPeripheral: m5Stack, createANewOneIfNecesssary: false), blueToothTransmitter.writeBrightness(brightness: index * 10) {
                            // do nothing, brightness successfully written to m5Stack - although it's not yet 100% sure because write returns true without waiting for response from bluetooth peripheral
                        } else {
                            bluetoothPeripheralManager.updateNeeded(forBluetoothPeripheral: m5Stack)
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

// MARK: extension M5StackBluetoothDelegate

extension BluetoothPeripheralViewController: M5StackBluetoothDelegate {
    
    func isAskingForAllParameters(m5Stack: M5Stack) {
        // viewcontroller doesn't use this
    }
    
    func isReadyToReceiveData(m5Stack: M5Stack) {
        // viewcontroller doesn't use this
    }
    
    func newBlePassWord(newBlePassword: String, forM5Stack m5Stack: M5Stack) {
        
        // blePassword is also saved in BluetoothPeripheralManager, tant pis
        bluetoothPeripheralAsNSObject?.blepassword = newBlePassword
        
        tableView.reloadRows(at: [IndexPath(row: Setting.blePassword.rawValue, section: 0)], with: .none)
        
    }
    
    func authentication(success: Bool, forM5Stack m5Stack: M5Stack) {
        
        if !success {
            
            // show warning, inform that user should set password or reset M5Stack
            let alert = UIAlertController(title: Texts_Common.warning, message: Text_BluetoothPeripheralView.authenticationFailureWarning + " " + Text_BluetoothPeripheralView.alwaysConnect, actionHandler: {
                
                // by the time user clicks 'ok', the M5stack will be disconnected by the BluetoothPeripheralManager (see authentication in BluetoothPeripheralManager)
                self.setShouldConnectToFalse(forM5Stack: m5Stack)

            })
            
            self.present(alert, animated: true, completion: nil)
        }
    }
    
    func blePasswordMissing(forM5Stack m5Stack: M5Stack) {
        
        // show warning, inform that user should set password
        let alert = UIAlertController(title: Texts_Common.warning, message: Text_BluetoothPeripheralView.authenticationFailureWarning + " " + Text_BluetoothPeripheralView.alwaysConnect, actionHandler: {
            
            // by the time user clicks 'ok', the M5stack will be disconnected by the BluetoothPeripheralManager (see authentication in BluetoothPeripheralManager)
            self.setShouldConnectToFalse(forM5Stack: m5Stack)

        })
        
        self.present(alert, animated: true, completion: nil)

    }
    
    func m5StackResetRequired(forM5Stack m5Stack: M5Stack) {

        // show warning, inform that user should reset M5Stack
        let alert = UIAlertController(title: Texts_Common.warning, message: Text_BluetoothPeripheralView.m5StackResetRequiredWarning + " " + Text_BluetoothPeripheralView.alwaysConnect, actionHandler: {
            
            // by the time user clicks 'ok', the M5stack will be disconnected by the BluetoothPeripheralManager (see authentication in BluetoothPeripheralManager)
            self.setShouldConnectToFalse(forM5Stack: m5Stack)

        })

        self.present(alert, animated: true, completion: nil)
        
    }
    
    func didConnect(forM5Stack m5Stack: M5Stack?, address: String?, name: String?, bluetoothTransmitter: M5StackBluetoothTransmitter) {
        
        tableView.reloadRows(at: [IndexPath(row: Setting.connectionStatus.rawValue, section: 0)], with: .none)
        
    }
    
    func didDisconnect(forM5Stack m5Stack: M5Stack) {
        
        tableView.reloadRows(at: [IndexPath(row: Setting.connectionStatus.rawValue, section: 0)], with: .none)

    }
    
    func deviceDidUpdateBluetoothState(state: CBManagerState, forM5Stack m5Stack: M5Stack) {

        // when bluetooth status changes to powered off, the device, if connected, will disconnect, however didDisConnect doesn't get call (looks like an error in iOS) - so let's reload the cell that shows the connection status, this will refresh the cell
        if state == CBManagerState.poweredOff {
            tableView.reloadRows(at: [IndexPath(row: Setting.connectionStatus.rawValue, section: 0)], with: .none)
        }

    }
    
    func error(message: String) {
        
        let alert = UIAlertController(title: Texts_Common.warning, message: message, actionHandler: nil)
        
        self.present(alert, animated: true, completion: nil)
    }
    
}

// MARK: extension M5StackBluetoothDelegate

/// defines perform segue identifiers used within M5StackViewController
extension BluetoothPeripheralViewController {
    public enum SegueIdentifiers:String {
        
        /// to go from BluetoothPeripheralsViewController to M5StackViewController
        case BluetoothPeripheralsToBluetoothPeripheralSegueIdentifier = "M5StacksToM5StackSegueIdentifier"
        
    }
    
    private enum UnwindSegueIdentifiers:String {
        
        /// to go back from M5StackViewController to BluetoothPeripheralsViewController
        case M5StackToBluetoothPeripheralsUnWindSegueIdentifier = "M5StackToBluetoothPeripheralsUnWindSegueIdentifier"
    }
}
