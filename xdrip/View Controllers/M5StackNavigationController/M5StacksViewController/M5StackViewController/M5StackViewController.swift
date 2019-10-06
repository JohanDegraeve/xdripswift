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
    
}

/// UIViewController to show 
final class M5StackViewController: UIViewController {
    
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
    private var m5StackAsNSObject:M5Stack?
    
    /// this is for cases where a new M5Stack is being scanned. If there's a new M5Stack, and if the user has clicked 'done', then when closing the viewcontroller, the M5Stack should be deleted. This attribute defines if the M5Stack should be deleted or not
    private var deleteM5StackWhenClosingViewController: Bool = false

    /// reference to coreDataManager
    private var coreDataManager:CoreDataManager?
    
    /// an m5stackManager
    private weak var m5StackManager: M5StackManaging?
    
    /// name given by user as alias , to easier recognize different M5Stacks
    private var userDefinedName: String?
    
    /// should the app try to connect automatically to the M5Stack or not, setting to false because compiler needs to have a value. It's set to the correct value in configure
    private var shouldConnect: Bool = false
    
    /// M5StackNames accessor
    private var m5StackNameAccessor: M5StackNameAccessor?
    
    // MARK:- public functions
    
    /// configure the viewController
    public func configure(m5Stack: M5Stack?, coreDataManager: CoreDataManager, m5StackManager: M5StackManaging) {

        self.m5StackAsNSObject = m5Stack
        self.coreDataManager = coreDataManager
        self.m5StackNameAccessor = M5StackNameAccessor(coreDataManager: coreDataManager)
        self.m5StackManager = m5StackManager
        
        if let m5StackAsNSObject = m5StackAsNSObject {
            
            // set self as delegate in bluetoothTransmitter
            m5StackManager.m5StackBluetoothTransmitter(forM5stack: m5StackAsNSObject, createANewOneIfNecesssary: false)?.m5StackBluetoothTransmitterDelegateVariable = self
            
            // temporary store the userDefinedName, user can change this name via the view, it will be stored back in the m5StackAsNSObject only after clicking 'done' button
            userDefinedName = m5StackAsNSObject.m5StackName?.userDefinedName
            
            // temporary store the value of shouldConnect, user can change this via the view, it will be stored back in the m5StackAsNSObject only after clicking 'done' button
            shouldConnect = m5StackAsNSObject.shouldconnect
            
            // don't delete the M5Stack when going back to prevous viewcontroller
            deleteM5StackWhenClosingViewController = false
            
        }
        
    }
    
    // MARK: - View Life Cycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        title = Texts_M5StackView.screenTitle
        
        setupView()
    }
    
    // MARK: - other overriden functions
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        
        guard let segueIdentifier = segue.identifier else {
            fatalError("In M5StackViewController, prepare for segue, Segue had no identifier")
        }
        
        guard let segueIdentifierAsCase = M5StackViewController.UnwindSegueIdentifiers(rawValue: segueIdentifier) else {
            fatalError("In M5StackViewController, segueIdentifierAsCase could not be initialized")
        }
        
        switch segueIdentifierAsCase {
            
        case M5StackViewController.UnwindSegueIdentifiers.M5StackToM5StacksUnWindSegueIdentifier:
            
            if deleteM5StackWhenClosingViewController, let m5StackAsNSObject = m5StackAsNSObject {
                m5StackManager?.deleteM5Stack(m5Stack: m5StackAsNSObject)
            }
        }
    }

    // MARK: - View Methods
    
    private func setupView() {
        
        // set label of connect button, according to current status
        setConnectButtonLabelText()
        
        if m5StackAsNSObject == nil {

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
            fatalError("in AlertTypeSettingsViewController, coreDataManager is nil")
        }
    }
    
    /// user cliks done button
    private func doneButtonAction() {
        
        if let m5StackAsNSObject = m5StackAsNSObject, let coreDataManager = coreDataManager, let m5StackNameAccessor = m5StackNameAccessor {
            
            // set variable delegate in m5StackAsNSObject to nil,  no need anymore to receive info
            m5StackManager?.m5StackBluetoothTransmitter(forM5stack: m5StackAsNSObject, createANewOneIfNecesssary: false)?.m5StackBluetoothTransmitterDelegateVariable = nil
            
            // if user has set or changed a userDefinedName, stored it, or delete it if userDefinedName is set to nil
            if let m5StackName = m5StackAsNSObject.m5StackName {
                if let userDefinedName = userDefinedName {
                    m5StackName.userDefinedName = userDefinedName
                } else {
                    // user has set the userDefinedName to nil, let's delete that m5stackname
                    m5StackNameAccessor.deleteM5StackName(m5StackName: m5StackName)
                }
                
            } else if let userDefinedName = userDefinedName {
                let m5Stackname = M5StackName(address: m5StackAsNSObject.address, userDefinedName: userDefinedName, nsManagedObjectContext: coreDataManager.mainManagedObjectContext)
                m5StackAsNSObject.m5StackName = m5Stackname
            }
            
            // shouldConnect to be stored
            m5StackAsNSObject.shouldconnect = shouldConnect
            debuglogging("shouldconnect = " + shouldConnect.description)
            
            // save all changes now
            m5StackManager?.save()

        }
        
        // don't delete the M5Stack when going back to prevous viewcontroller
        self.deleteM5StackWhenClosingViewController = false
        
        // return to M5StacksViewController
        performSegue(withIdentifier: UnwindSegueIdentifiers.M5StackToM5StacksUnWindSegueIdentifier.rawValue, sender: self)
        
    }
    
    /// user clicks scan button
    private func scanButtonAction() {
        
        // if m5StackAsNSObject is not nil, then there's already an M5stack for which scanning has started or which is already known from a previous scan (either connected or not connected) (m5StackAsNSObject should be nil because if it is not, the scanbutton should not even be enabled, anyway let's check).
        // Also check m5StackManager not nil
        guard m5StackAsNSObject == nil, let m5StackManager =  m5StackManager else {return}
        
        m5StackManager.startScanningForNewDevice(callback: { (m5Stack) in
            
            // assign internal m5StackAsNSObject to new m5Stack
            self.m5StackAsNSObject = m5Stack
            
            // assign local variables
            self.shouldConnect = m5Stack.shouldconnect
            self.userDefinedName = m5Stack.m5StackName?.userDefinedName //should be nil anyway
            
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
            self.m5StackManager?.m5StackBluetoothTransmitter(forM5stack: m5Stack, createANewOneIfNecesssary: false)?.m5StackBluetoothTransmitterDelegateVariable = self
            
            })
        
        // scanning now, scanning button can be disabled
        scanButtonOutlet.disable()
        
    }
    
    private func trashButtonAction() {
        
        // let's first check if m5stack exists, otherwise there's nothing to trash, normally this shouldn't happen because trashbutton should be disabled if there's no m5StackAsNSObject
        guard let m5StackAsNSObject = m5StackAsNSObject else {return}

        // textToAdd is either 'address' + the address, or 'alias' + the userDefinedName, depending if userDefinedName has a value
        var textToAdd = Texts_M5StackView.address + m5StackAsNSObject.address
        if let userDefinedName = userDefinedName {
            textToAdd = Texts_M5StackView.m5StackAlias + userDefinedName
        }
        
        // first ask user if ok to delete and if yes delete
        UIAlertController(title: Texts_M5StackView.confirmDeletionM5Stack + " " + textToAdd + "?", message: nil, actionHandler: {
            
            // delete
            self.m5StackManager?.deleteM5Stack(m5Stack: m5StackAsNSObject)
            
            // as the M5Stack is already deleted, there's no need to call delete again, when prepareForSegue
            self.deleteM5StackWhenClosingViewController = false
            
            self.performSegue(withIdentifier: UnwindSegueIdentifiers.M5StackToM5StacksUnWindSegueIdentifier.rawValue, sender: self)
            
        }, cancelHandler: nil).presentInOwnWindow(animated: true, completion: {})

    }
    
    private func connectButtonAction() {
        
        // let's first check if m5stack exists, it should because otherwise connectButton should be disabled
        guard let m5StackAsNSObject = m5StackAsNSObject else {return}
        
        if shouldConnect {
            
            // device should not automaticaly connect, which means, each time the app restarts, it will not try to connect to this M5Stack
            // if user clicks cancel button (ie goes back to previous view controller without clicking done, then this value will not be saved
            shouldConnect = false
            
            // normally there should be a bluetoothTransmitter
            if let bluetoothTransmitter = m5StackManager?.m5StackBluetoothTransmitter(forM5stack: m5StackAsNSObject, createANewOneIfNecesssary: false) {
                
                // disconnect, even if not connected for the moment
                bluetoothTransmitter.disconnect(reconnectAfterDisconnect: false)
                
            }
            
        } else {
            
            // device should automatically connect, this will be stored in coredata (only after clicking done button), which means, each time the app restarts, it will try to connect to this M5Stack
            // if user clicks cancel button (ie goes back to previous view controller without clicking done, then this value will not be saved
            shouldConnect = true
            
            // connect,
            m5StackManager?.m5StackBluetoothTransmitter(forM5stack: m5StackAsNSObject, createANewOneIfNecesssary: true)?.connect()
            
        }
        
        // enable the done button, because this m5Stack has modified values, user can click done button which will save those changes
        self.doneButtonOutlet.enable()
        
        // will change text of the button
        self.setConnectButtonLabelText()
        
    }
    
    /// checks if m5StackAsNSObject is not nil, etc.
    /// - returns: true if m5stack exists and is connected, false in all other cases
    private func m5StackIsConnected() -> Bool {
        
        guard let m5StackAsNSObject = m5StackAsNSObject else {return false}
        
        guard let connectionStatus = m5StackManager?.m5StackBluetoothTransmitter(forM5stack: m5StackAsNSObject, createANewOneIfNecesssary: false)?.getConnectionStatus() else {return false}
        
        return connectionStatus == CBPeripheralState.connected

    }
    
    private func setConnectButtonLabelText() {

        // if M5Stack is nil, then set text to "Always Connect", it's disabled anyway - if m5Stack not nil, then set depending on value of shouldconnect
        if m5StackAsNSObject == nil {
            connectButtonOutlet.setTitle(Texts_M5StackView.alwaysConnect, for: .normal)
        } else {
            // set label of connect button, according to curren status
            connectButtonOutlet.setTitle(shouldConnect ? Texts_M5StackView.donotconnect:Texts_M5StackView.alwaysConnect, for: .normal)
        }

    }
    
    /// user clicked cancel button
    public func cancelButtonAction() {
        
        // just in case scanning for a new device is still ongoing, call stopscanning
        m5StackManager?.stopScanningForNewDevice()
        
        // return to M5StacksViewController
        performSegue(withIdentifier: UnwindSegueIdentifiers.M5StackToM5StacksUnWindSegueIdentifier.rawValue, sender: self)

    }

}

// MARK: - extensions

extension M5StackViewController: UITableViewDataSource, UITableViewDelegate {
    
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
            cell.detailTextLabel?.text = m5StackAsNSObject?.name
            cell.accessoryType = UITableViewCell.AccessoryType.none
            
        case .address:
            cell.textLabel?.text = Texts_M5StackView.address
            cell.detailTextLabel?.text = m5StackAsNSObject?.address
            cell.accessoryType = UITableViewCell.AccessoryType.disclosureIndicator
            
        case .blePassword:
            cell.textLabel?.text = Texts_Common.password
            cell.detailTextLabel?.text = m5StackAsNSObject?.blepassword
            cell.accessoryType = UITableViewCell.AccessoryType.none

        case .connectionStatus:
            cell.textLabel?.text = Texts_M5StackView.status
            cell.detailTextLabel?.text = m5StackAsNSObject == nil ? nil : m5StackIsConnected() ? Texts_M5StackView.connected:Texts_M5StackView.notConnected
            
        case .userDefinedName:
            cell.textLabel?.text = Texts_M5StackView.m5StackAlias
            cell.detailTextLabel?.text = userDefinedName
            cell.accessoryType = UITableViewCell.AccessoryType.disclosureIndicator
        }
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        tableView.deselectRow(at: indexPath, animated: true)
        
        guard let setting = Setting(rawValue: indexPath.row) else { fatalError("M5StackViewController didSelectRowAt, Unexpected setting") }
        
        // configure the cell depending on setting
        switch setting {
            
        case .address:
            guard let m5StackAsNSObject = m5StackAsNSObject else {return}
            
            UIAlertController(title: Texts_M5StackView.address, message: m5StackAsNSObject.address, actionHandler: nil).presentInOwnWindow(animated: true, completion: nil)
            
        case .name, .blePassword, .connectionStatus:
            break
            
        case .userDefinedName:
            
            // clicked cell to change userdefined name (alias) - need to ask for new name, and verify if there's already another M5Stack existing with the same name

            // first off al check that M5Stack already exists, otherwise makes no sense to change the name, check here also m5StackNameAccessor, although should not be nil, but it needs to happen
            guard let m5StackAsNSObject = m5StackAsNSObject, let m5StackNameAccessor = m5StackNameAccessor  else {return}
            
            let alert = UIAlertController(title: Texts_M5StackView.m5StackAlias, message: Texts_M5StackView.selectAliasText, keyboardType: .default, text: userDefinedName, placeHolder: nil, actionTitle: nil, cancelTitle: nil, actionHandler: { (text:String) in
                
                let newUserDefinedName = text.toNilIfLength0()
                
                if newUserDefinedName != nil {
                    for m5StackName in m5StackNameAccessor.getM5StackNames() {
                        // not checking address of m5StackAsNSObject, because obviously that one could have the same userdefinedname
                        if m5StackName.address != m5StackAsNSObject.address {
                            if m5StackName.userDefinedName == text {
                                
                                // m5stack userdefined name already exists
                                UIAlertController(title: Texts_Common.warning, message: Texts_M5StackView.userdefinedNameAlreadyExists, actionHandler: nil).presentInOwnWindow(animated: true, completion: nil)
                                
                                return
                                
                            }
                        }
                    }
                }
                
                // not returned during loop, means name is unique
                self.userDefinedName = newUserDefinedName
                
                // reload the specific row in the table
                tableView.reloadRows(at: [IndexPath(row: Setting.userDefinedName.rawValue, section: 0)], with: .none)
                
                // enable the done button
                self.doneButtonOutlet.enable()
                
            }, cancelHandler: nil)
            
            // present the alert
            self.present(alert, animated: true, completion: nil)

        }
    }

}

extension M5StackViewController: M5StackBluetoothDelegate {
    
    func newBlePassWord(newBlePassword: String, forM5Stack m5Stack: M5Stack) {
        
        // blePassword is also saved in M5StackManager, tant pis
        m5StackAsNSObject?.blepassword = newBlePassword
        
        tableView.reloadRows(at: [IndexPath(row: Setting.blePassword.rawValue, section: 0)], with: .none)
        
    }
    
    func authentication(success: Bool, forM5Stack m5Stack: M5Stack) {
        
        if !success {
            UIAlertController(title: Texts_Common.warning, message: Texts_M5StackView.authenticationFailureWarning, actionHandler: nil).presentInOwnWindow(animated: true, completion: nil)
        }
    }
    
    func blePasswordMissing(forM5Stack m5Stack: M5Stack) {
        
        UIAlertController(title: Texts_Common.warning, message: Texts_M5StackView.authenticationFailureWarning, actionHandler: nil).presentInOwnWindow(animated: true, completion: nil)

    }
    
    func m5StackResetRequired(forM5Stack m5Stack: M5Stack) {

        UIAlertController(title: Texts_Common.warning, message: Texts_M5StackView.m5StackResetRequiredWarning, actionHandler: nil).presentInOwnWindow(animated: true, completion: nil)

    }
    
    func didConnect(forM5Stack m5Stack: M5Stack?, address: String?, name: String?, bluetoothTransmitter: M5StackBluetoothTransmitter) {
        
        tableView.reloadRows(at: [IndexPath(row: Setting.connectionStatus.rawValue, section: 0)], with: .none)
        
    }
    
    func didDisconnect(forM5Stack m5Stack: M5Stack) {
        
        tableView.reloadRows(at: [IndexPath(row: Setting.connectionStatus.rawValue, section: 0)], with: .none)

    }
    
    func deviceDidUpdateBluetoothState(state: CBManagerState, forM5Stack m5Stack: M5Stack) {
    }
    
    func error(message: String) {
        UIAlertController(title: Texts_Common.warning, message: message, actionHandler: nil).presentInOwnWindow(animated: true, completion: nil)
    }
    
    
}

/// defines perform segue identifiers used within M5StackViewController
extension M5StackViewController {
    public enum SegueIdentifiers:String {
        
        /// to go from M5StacksViewController to M5StackViewController
        case M5StacksToM5StackSegueIdentifier = "M5StacksToM5StackSegueIdentifier"
        
    }
    
    private enum UnwindSegueIdentifiers:String {
        
        /// to go back from alerttype settings screen to alerttypes settings screen
        case M5StackToM5StacksUnWindSegueIdentifier = "M5StackToM5StacksUnWindSegueIdentifier"
    }
}
