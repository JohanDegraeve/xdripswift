import UIKit
import CoreBluetooth

/// - a case per attribute that can be set in BluetoothPeripheralViewController
/// - these are applicable to all types of bluetoothperipheral types (M5Stack ...)
fileprivate enum Setting:Int, CaseIterable {
    
    /// the name received from bluetoothTransmitter, ie the name hardcoded in the BluetoothPeripheral
    case name = 0

    /// the alias that user has given, possibly nil
    case alias = 1
    
    /// the address
    case address = 2
    
    /// the current connection status
    case connectionStatus = 3
    
    /// transmitterID, only for devices that need it
    case transmitterId = 4
    
}

/// base class for UIViewController's that allow to edit specific type of bluetooth transmitters to show 
class BluetoothPeripheralViewController: UIViewController {
    
    // MARK: - IBOutlet's and IBAction's
    
    /// action for connectButton, will also be used to disconnect, depending on the connection status
    @IBAction func connectButtonAction(_ sender: UIButton) {
        connectButtonHandler()
    }
    
    /// action to confirm changes if any
    @IBAction func doneButtonAction(_ sender: UIBarButtonItem) {
        doneButtonHandler()
    }
    
    /// action for trashButton, to delete the BluetoothPeripheral
    @IBAction func trashButtonAction(_ sender: UIBarButtonItem) {
        trashButtonClicked()
    }

    /// action for scan Button, to scan for BluetoothPeripheral
    @IBAction func scanButtonAction(_ sender: UIButton) {
        
        if let expectedBluetoothPeripheralType = expectedBluetoothPeripheralType {
            
            self.scanForBluetoothPeripheral(type: expectedBluetoothPeripheralType)
            
        } else {
            fatalError("in scanButtonAction, expectedBluetoothPeripheralType is nil")
        }
        
    }

    /// action for cancelbutton
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
    
    // MARK: - public properties

    // MARK: - private properties
    
    /// the BluetoothPeripheral being edited - will only be used initially to initialize the temp properties used locally, and in the end to update the BluetoothPeripheral - if nil then it's about creating a new BluetoothPeripheral
    private var bluetoothPeripheralAsNSObject:BluetoothPeripheral?
    
    /// this is for cases where a new BluetoothPeripheral is being scanned. If there's a new BluetoothPeripheral, and if the user has clicked 'cancel', then when closing the viewcontroller, the BluetoothPeripheral should be deleted. This attribute defines if the BluetoothPeripheral should be deleted or not
    private var deleteBluetoothPeripheralWhenClosingViewController: Bool = false

    /// reference to coreDataManager
    private var coreDataManager:CoreDataManager?
    
    /// a BluetoothPeripheralManager
    private weak var bluetoothPeripheralManager: BluetoothPeripheralManaging!
    
    /// name given by user as alias , to easier recognize different BluetoothPeripherals
    ///
    /// temp storage of value while user is editing the BluetoothPeripheral attributes
    private var aliasTemporaryValue: String?
    
    /// temp storage of transmitterId value while user is creating the DexcomG5
    ///
    /// this value can only be set once by the user, ie it can change from nil to a value. As soon as a value is set by the user, and if transmitterStartsScanningAfterInit returns true, then a transmitter will be created and scanning will start. If transmitterStartsScanningAfterInit returns false, then the user needs to start the scanning (there are no transmitters for the moment that use transmitter id and that do have transmitterStartsScanningAfterInit = false)
    private var transmitterIdTempValue: String?
    
    /// needed to support the bluetooth peripheral type specific attributes
    private var bluetoothPeripheralViewModel: BluetoothPeripheralViewModel!
    
    /// BluetoothPeripheralType for which this viewcontroller is created
    private var expectedBluetoothPeripheralType: BluetoothPeripheralType?
    
    /// temp storage of assigned BluetoothTransmitterDelegate
    private weak var previouslyAssignedBluetoothTransmitterDelegate: BluetoothTransmitterDelegate?

    // MARK:- public functions
    
    /// configure the viewController
    public func configure(bluetoothPeripheral: BluetoothPeripheral?, coreDataManager: CoreDataManager, bluetoothPeripheralManager: BluetoothPeripheralManaging, expectedBluetoothPeripheralType type: BluetoothPeripheralType) {
        
        bluetoothPeripheralAsNSObject = bluetoothPeripheral
        self.coreDataManager = coreDataManager
        self.bluetoothPeripheralManager = bluetoothPeripheralManager
        self.expectedBluetoothPeripheralType = type
        
        if let bluetoothPeripheralASNSObject = bluetoothPeripheralAsNSObject {
            
            // temporary store the alias, user can change this name via the view, it will be stored back in the bluetoothPeripheralASNSObject only after clicking 'done' button
            aliasTemporaryValue = bluetoothPeripheralASNSObject.blePeripheral.alias
            
            // temporary store the transmitterId, user can change this name via the view, it will be stored back in the bluetoothPeripheralASNSObject only after clicking 'done' button
            transmitterIdTempValue = bluetoothPeripheralAsNSObject?.blePeripheral.transmitterId
            
            // don't delete the BluetoothPeripheral when going back to prevous viewcontroller
            deleteBluetoothPeripheralWhenClosingViewController = false

        }
        
    }
    
    /// sets shouldconnect for bluetoothPeripheral to false
    public func setShouldConnectToFalse(for bluetoothPeripheral: BluetoothPeripheral) {
        
        bluetoothPeripheral.blePeripheral.shouldconnect = false
        
        coreDataManager?.saveChanges()
        
        self.setConnectButtonLabelText()
        
    }

    // MARK: - View Life Cycle
    
    override func viewDidLoad() {
        
        super.viewDidLoad()
        
        // here the tableView is not nil, we can safely call bluetoothPeripheralViewModel.configure, this one requires a non-nil tableView
        
        // get a viewModel instance for the expectedBluetoothPeripheralType
        bluetoothPeripheralViewModel = expectedBluetoothPeripheralType?.viewModel()

        // configure the bluetoothPeripheralViewModel
        bluetoothPeripheralViewModel?.configure(bluetoothPeripheral: bluetoothPeripheralAsNSObject, bluetoothPeripheralManager: self.bluetoothPeripheralManager, tableView: tableView, bluetoothPeripheralViewController: self)
        
        // still need to assign the delegate in the transmitter object
        if let bluetoothPeripheralASNSObject = bluetoothPeripheralAsNSObject, let bluetoothTransmitter = bluetoothPeripheralManager.getBluetoothTransmitter(for: bluetoothPeripheralASNSObject, createANewOneIfNecesssary: false) {
            
            // this will store the current value of the bluetoothTransitterDelegate, and assign self as new delegate
            assignPreviouslyAssignedBluetoothTransmitterDelegateAndSetSelfAsDelegate(bluetoothTransmitter: bluetoothTransmitter, assignDelegateTo: self)
            
            // this will internally store the BluetoothTransmitter type specific delegate
            bluetoothPeripheralViewModel.assignBluetoothTransmitterDelegate(to: bluetoothTransmitter)
            
        }

        setupView()
        
    }
    
    // MARK: - De-initialization
    
    deinit {
        
        // to be sure that previouslyAssignedBluetoothTransmitterDelegate is reassigned although it's probably already done for example in doneButtonHandler
        
        if let bluetoothPeripheralAsNSObject = bluetoothPeripheralAsNSObject, let previouslyAssignedBluetoothTransmitterDelegate = previouslyAssignedBluetoothTransmitterDelegate, let bluetoothTransmitter = bluetoothPeripheralManager.getBluetoothTransmitter(for: bluetoothPeripheralAsNSObject, createANewOneIfNecesssary: false) {
            
            // this will internally reset the BluetoothTransmitter delegate to the original value
            bluetoothPeripheralViewModel.reAssignBluetoothTransmitterDelegateToOriginal(for: bluetoothTransmitter)
            
            // reassign delegate
            bluetoothTransmitter.bluetoothTransmitterDelegate = previouslyAssignedBluetoothTransmitterDelegate

        }
        
    }

    // MARK: - other overriden functions
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        
        guard let segueIdentifier = segue.identifier else {
            fatalError("In BluetoothPeripheralViewController, prepare for segue, Segue had no identifier")
        }
        
        guard let segueIdentifierAsCase = BluetoothPeripheralViewController.UnwindSegueIdentifiers(rawValue: segueIdentifier) else {
            fatalError("In BluetoothPeripheralViewController, segueIdentifierAsCase could not be initialized")
        }
        
        switch segueIdentifierAsCase {
            
        case BluetoothPeripheralViewController.UnwindSegueIdentifiers.BluetoothPeripheralToBluetoothPeripheralsUnWindSegueIdentifier:
            
            if deleteBluetoothPeripheralWhenClosingViewController, let bluetoothPeripheralASNSObject = bluetoothPeripheralAsNSObject {
                bluetoothPeripheralManager.deleteBluetoothPeripheral(bluetoothPeripheral: bluetoothPeripheralASNSObject)
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
            
            // unwrap expectedBluetoothPeripheralType
            guard let expectedBluetoothPeripheralType = expectedBluetoothPeripheralType else {return}
            
            // if it's a bluetoothperipheraltype for which the bluetoothTransmitter starts scnanning as soon as it's created, then there's no need to let the user to the start scanning, so let's hide the button - this will only be the case for transmitters that need transmitterId
            if expectedBluetoothPeripheralType.transmitterStartsScanningAfterInit() {
                scanButtonOutlet.isHidden = true
            } else if expectedBluetoothPeripheralType.needsTransmitterId() && transmitterIdTempValue == nil {

                // if it's a bluetoothperipheraltype that needs a transmitterId but there's no transmitterId set, then disable the scanbutton
                scanButtonOutlet.disable()
                
            }
            

        } else {
            
            // there's already a known bluetoothperipheral, no need to scan for it
            scanButtonOutlet.disable()
            
        }
        
        // initially donebutton is disabled, it will get enabled as soon as a new bluetoothperipheral is scanned for, or changes are done in the existing bluetoothperipheral settings
        doneButtonOutlet.disable()
        
        // set title
        title = bluetoothPeripheralViewModel.screenTitle()
        
        setupTableView()
        
    }
    
    // MARK: - private functions
    
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
            fatalError("in BluetoothPeripheralViewController, coreDataManager is nil")
        }
    }
    
    /// user cliks done button
    public func doneButtonHandler() {
        
        if let bluetoothPeripheralAsNSObject = bluetoothPeripheralAsNSObject, let coreDataManager = coreDataManager, let bluetoothTransmitter = bluetoothPeripheralManager.getBluetoothTransmitter(for: bluetoothPeripheralAsNSObject, createANewOneIfNecesssary: false) {
            
            // no need anymore to receive info from BluetoothTransmitter, reassign previouslyAssignedBluetoothTransmitterDelegate
            // previouslyAssignedBluetoothTransmitterDelegate must be non nil here. Otherwise there's a coding error.
            guard let previouslyAssignedBluetoothTransmitterDelegate = previouslyAssignedBluetoothTransmitterDelegate else {
                fatalError("BluetoothPeripheralViewController, doneButtonHandler, previouslyAssignedBluetoothTransmitterDelegate is nil")
            }
            
            // reassign previouslyAssignedBluetoothTransmitterDelegate as delegate in BluetoothTransmitter
            bluetoothTransmitter.bluetoothTransmitterDelegate = previouslyAssignedBluetoothTransmitterDelegate
            
            // set alias temp value, possibly this is a nil value
            bluetoothPeripheralAsNSObject.blePeripheral.alias = aliasTemporaryValue
            
            // set transmitterId temp value, possibly this is a nil value
            bluetoothPeripheralAsNSObject.blePeripheral.transmitterId = transmitterIdTempValue
            
            // temp values stored by viewmodel needs to be written to bluetoothPeripheralASNSObject
            bluetoothPeripheralViewModel.writeTempValues(to: bluetoothPeripheralAsNSObject)

            // this will internally reset the BluetoothTransmitter delegate to the original value
            bluetoothPeripheralViewModel.reAssignBluetoothTransmitterDelegateToOriginal(for: bluetoothTransmitter)

            // save all changes now
            coreDataManager.saveChanges()

        }
        
        // don't delete the BluetoothPeripheral when going back to previous viewcontroller
        self.deleteBluetoothPeripheralWhenClosingViewController = false
        
        // return to BluetoothPeripheralsViewController
        performSegue(withIdentifier: UnwindSegueIdentifiers.BluetoothPeripheralToBluetoothPeripheralsUnWindSegueIdentifier.rawValue, sender: self)
        
    }
    
    private func scanForBluetoothPeripheral(type: BluetoothPeripheralType) {
        
        // if bluetoothPeripheralASNSObject is not nil, then there's already a BluetoothPeripheral for which scanning has started or which is already known from a previous scan (either connected or not connected) (bluetoothPeripheralASNSObject should be nil because if it is not, the scanbutton should not even be enabled, anyway let's check).
        guard bluetoothPeripheralAsNSObject == nil else {return}
        
        // if bluetoothPeripheralType needs transmitterId, then check that transmitterId is present
        if type.needsTransmitterId() && transmitterIdTempValue == nil {return}
        
        bluetoothPeripheralManager.startScanningForNewDevice(type: type, transmitterId: transmitterIdTempValue, callback: { (bluetoothPeripheral) in
            
            // assign internal bluetoothPeripheralASNSObject to new bluetoothPeripheral
            self.bluetoothPeripheralAsNSObject = bluetoothPeripheral
            
            // assign local variables
            self.aliasTemporaryValue = nil //should be nil anyway
            
            // call storeTempValues in the model
            self.bluetoothPeripheralViewModel.storeTempValues(from: bluetoothPeripheral)
            
            // enable the connect button
            self.connectButtonOutlet.enable()
            
            // set right text for connect button
            self.setConnectButtonLabelText()
            
            // enable the trashbutton
            self.trashButtonOutlet.enable()
            
            // enable the doneButtonAction
            self.doneButtonOutlet.enable()
            
            // if user goes back to previous screen via the back button, then delete the newly discovered BluetoothPeripheral
            self.deleteBluetoothPeripheralWhenClosingViewController = true
            
            // set self as delegate in the bluetoothTransmitter, and assign currently assigned BluetoothTransmitterDelegate to previouslyAssignedBluetoothTransmitterDelegate
            if let bluetoothTransmitter = self.bluetoothPeripheralManager.getBluetoothTransmitter(for: bluetoothPeripheral, createANewOneIfNecesssary: false) {
                
                self.assignPreviouslyAssignedBluetoothTransmitterDelegateAndSetSelfAsDelegate(bluetoothTransmitter: bluetoothTransmitter, assignDelegateTo: self)
                
                // this will internally reset the BluetoothTransmitter delegate to the original value
                self.bluetoothPeripheralViewModel.assignBluetoothTransmitterDelegate(to: bluetoothTransmitter)
                
            }

            // reload the full screen , all rows in all sections in the tableView
            self.tableView.reloadData()
            
        })
        
        // scanning now, scanning button can be disabled
        scanButtonOutlet.disable()
        
        // app should be scanning now, update of cell is needed
        tableView.reloadRows(at: [IndexPath(row: Setting.connectionStatus.rawValue, section: 0)], with: .none)
        
    }
    
    /// use clicked trash button, need to delete the bluetoothperipheral
    private func trashButtonClicked() {
        
        // let's first check if bluetoothPeripheral exists, otherwise there's nothing to trash, normally this shouldn't happen because trashbutton should be disabled if there's no bluetoothPeripheralASNSObject
        guard let bluetoothPeripheralASNSObject = bluetoothPeripheralAsNSObject else {return}

        // textToAdd is either 'address' + the address, or 'alias' + the alias, depending if alias has a value
        var textToAdd = Text_BluetoothPeripheralView.address + " " + bluetoothPeripheralASNSObject.blePeripheral.address
        if let alias = aliasTemporaryValue {
            textToAdd = Text_BluetoothPeripheralView.bluetoothPeripheralAlias + " " + alias
        }
        
        // first ask user if ok to delete and if yes delete
        let alert = UIAlertController(title: Text_BluetoothPeripheralView.confirmDeletionBluetoothPeripheral + " " + textToAdd + "?", message: nil, actionHandler: {
            
            // delete
            self.bluetoothPeripheralManager.deleteBluetoothPeripheral(bluetoothPeripheral: bluetoothPeripheralASNSObject)
            
            // as the BluetoothPeripheral is already deleted, there's no need to call delete again, when prepareForSegue
            self.deleteBluetoothPeripheralWhenClosingViewController = false
            
            self.performSegue(withIdentifier: UnwindSegueIdentifiers.BluetoothPeripheralToBluetoothPeripheralsUnWindSegueIdentifier.rawValue, sender: self)
            
        }, cancelHandler: nil)
        
        self.present(alert, animated:true)

    }
    
    /// user clicked connect button
    private func connectButtonHandler() {
        
        // let's first check if bluetoothPeripheral exists, it should because otherwise connectButton should be disabled
        guard let bluetoothPeripheralASNSObject = bluetoothPeripheralAsNSObject else {return}
        
        // user clicked connectbutton. Check first the current value of shouldconnect and change
        if bluetoothPeripheralASNSObject.blePeripheral.shouldconnect {
            
            // device should not automaticaly connect in future, which means, each time the app restarts, it will not try to connect to this bluetoothPeripheral
            bluetoothPeripheralASNSObject.blePeripheral.shouldconnect = false
            
            // save the update in coredata
            coreDataManager?.saveChanges()

            // update the connect button text
            setConnectButtonLabelText()

            // disconnecting means also deleting the bluetoothTransmitter (which as a consequence also disconnects). Also reassign previouslyAssignedBluetoothTransmitterDelegate, although this is probably not necessary as the bluetoothTransmitter will be set to nil
            if let bluetoothTransmitter = bluetoothPeripheralManager.getBluetoothTransmitter(for: bluetoothPeripheralASNSObject, createANewOneIfNecesssary: false), let previouslyAssignedBluetoothTransmitterDelegate = previouslyAssignedBluetoothTransmitterDelegate {
                
                // set delegate in bluetoothtransmitter to nil, as we're going to disconnect permenantly, so not interested anymore to receive info
                bluetoothTransmitter.bluetoothTransmitterDelegate = previouslyAssignedBluetoothTransmitterDelegate
                
                // this will internally reset the BluetoothTransmitter delegate to the original value
                self.bluetoothPeripheralViewModel.reAssignBluetoothTransmitterDelegateToOriginal(for: bluetoothTransmitter)

                // this will also set bluetoothTransmitter to nil and also disconnect the peripheral
                bluetoothPeripheralManager.setBluetoothTransmitterToNil(forBluetoothPeripheral: bluetoothPeripheralASNSObject)
                
            }
            
        } else {
            
            // device should automatically connect, this will be stored in coredata
            bluetoothPeripheralASNSObject.blePeripheral.shouldconnect = true
            
            // save the update in coredata
            coreDataManager?.saveChanges()
            
            // get bluetoothTransmitter
            if let bluetoothTransmitter = bluetoothPeripheralManager.getBluetoothTransmitter(for: bluetoothPeripheralASNSObject, createANewOneIfNecesssary: true) {
                
                assignPreviouslyAssignedBluetoothTransmitterDelegateAndSetSelfAsDelegate(bluetoothTransmitter: bluetoothTransmitter, assignDelegateTo: self)
                
                // connect
                bluetoothTransmitter.connect()

                // this will internally store the BluetoothTransmitter type specific delegate
                bluetoothPeripheralViewModel.assignBluetoothTransmitterDelegate(to: bluetoothTransmitter)

            }
            
        }
        
        // will change text of the button
        self.setConnectButtonLabelText()
        
    }
    
    /// checks if bluetoothPeripheralASNSObject is not nil, etc.
    /// - returns: true if bluetoothperipheral exists and is connected, false in all other cases
    private func bluetoothPeripheralIsConnected() -> Bool {
        
        guard let bluetoothPeripheralASNSObject = bluetoothPeripheralAsNSObject else {return false}
        
        guard let connectionStatus = bluetoothPeripheralManager.getBluetoothTransmitter(for: bluetoothPeripheralASNSObject, createANewOneIfNecesssary: false)?.getConnectionStatus() else {return false}
        
        return connectionStatus == CBPeripheralState.connected

    }
    
    private func setConnectButtonLabelText() {

        // if BluetoothPeripheral is nil, then set text to "Always Connect", it's disabled anyway - if BluetoothPeripheral not nil, then set depending on value of shouldconnect
        if let bluetoothPeripheralASNSObject = bluetoothPeripheralAsNSObject {
            
            // set label of connect button, according to curren status
            connectButtonOutlet.setTitle(bluetoothPeripheralASNSObject.blePeripheral.shouldconnect ? Text_BluetoothPeripheralView.donotconnect:Text_BluetoothPeripheralView.alwaysConnect, for: .normal)
            
        } else {
            
            connectButtonOutlet.setTitle(Text_BluetoothPeripheralView.alwaysConnect, for: .normal)
            
        }
        
    }
    
    /// user clicked cancel button
    private func cancelButtonAction() {
        
        // just in case scanning for a new device is still ongoing, call stopscanning
        bluetoothPeripheralManager.stopScanningForNewDevice()
        
        // return to BluetoothPeripheralsViewController
        performSegue(withIdentifier: UnwindSegueIdentifiers.BluetoothPeripheralToBluetoothPeripheralsUnWindSegueIdentifier.rawValue, sender: self)

    }

    /// assign current delegate in bluetoothTransmitter to previouslyAssignedBluetoothTransmitterDelegate, and set delegate in to to self
    private func assignPreviouslyAssignedBluetoothTransmitterDelegateAndSetSelfAsDelegate(bluetoothTransmitter: BluetoothTransmitter, assignDelegateTo bluetoothTransmitterDelegate: BluetoothTransmitterDelegate) {
        
        // assign previouslyAssignedBluetoothTransmitterDelegate
        previouslyAssignedBluetoothTransmitterDelegate = bluetoothTransmitter.bluetoothTransmitterDelegate
        
        // assign self as BluetoothTransmitterDelegate
        bluetoothTransmitter.bluetoothTransmitterDelegate = bluetoothTransmitterDelegate

    }
    
}


// MARK: - extension UITableViewDataSource, UITableViewDelegate

extension BluetoothPeripheralViewController: UITableViewDataSource, UITableViewDelegate {
    
    func numberOfSections(in tableView: UITableView) -> Int {
        
        // one general section with settings applicable for all peripheral types, one or more specific section(s) with settings specific to type of bluetooth peripheral
        if bluetoothPeripheralAsNSObject == nil {
            return 1
        } else {
            return bluetoothPeripheralViewModel.numberOfSections() + 1
        }
        
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        
        if section == 0 {
            if let expectedBluetoothPeripheralType = expectedBluetoothPeripheralType, !expectedBluetoothPeripheralType.needsTransmitterId() {
                return Setting.allCases.count - 1
            }
            return Setting.allCases.count
        } else {
            // normally if bluetoothPeripheralViewModel would be nil, then there wouldn't be a second section, so normall bluetoothPeripheralViewModel is not nil here
            return bluetoothPeripheralViewModel?.numberOfSettings(inSection: section) ?? 0
        }
        
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        guard let cell = tableView.dequeueReusableCell(withIdentifier: SettingsTableViewCell.reuseIdentifier, for: indexPath) as? SettingsTableViewCell else { fatalError("BluetoothPeripheralViewController cellforrowat, Unexpected Table View Cell ") }
        
        // check if it's a Setting defined here in BluetoothPeripheralViewController, or a setting specific to the type of BluetoothPeripheral
        if indexPath.section >= 1 {
            
            // it's a setting not defined here but in a BluetoothPeripheralViewModel
            // bluetoothPeripheralViewModel should not be nil here, otherwise user wouldn't be able to click a row which is higher than maximum
            if let bluetoothPeripheralViewModel = bluetoothPeripheralViewModel, let bluetoothPeripheral = bluetoothPeripheralAsNSObject {

                bluetoothPeripheralViewModel.update(cell: cell, forRow: indexPath.row, forSection: indexPath.section, for: bluetoothPeripheral, doneButtonOutlet: doneButtonOutlet)
                
            }
            
            return cell
            
        }
            
        //it's a Setting defined here in BluetoothPeripheralViewController
        guard let setting = Setting(rawValue: indexPath.row) else { fatalError("BluetoothPeripheralViewController cellForRowAt, Unexpected setting") }
        
        // default value for accessoryView is nil
        cell.accessoryView = nil
        
        // configure the cell depending on setting
        switch setting {
            
        case .name:
            cell.textLabel?.text = Texts_Common.name
            cell.detailTextLabel?.text = bluetoothPeripheralAsNSObject?.blePeripheral.name
            cell.accessoryType = .none
            
        case .address:
            cell.textLabel?.text = Text_BluetoothPeripheralView.address
            cell.detailTextLabel?.text = bluetoothPeripheralAsNSObject?.blePeripheral.address
            if cell.detailTextLabel?.text == nil {
                cell.accessoryType = .none
            } else {
                cell.accessoryType = .disclosureIndicator
            }
            
        case .connectionStatus:
            cell.textLabel?.text = Text_BluetoothPeripheralView.status
            cell.detailTextLabel?.text = bluetoothPeripheralAsNSObject == nil ? (bluetoothPeripheralManager.isScanning() ? "Scanning" : nil) : bluetoothPeripheralIsConnected() ? Text_BluetoothPeripheralView.connected:Text_BluetoothPeripheralView.notConnected
            cell.accessoryType = .none
            
        case .alias:
            cell.textLabel?.text = Text_BluetoothPeripheralView.bluetoothPeripheralAlias
            cell.detailTextLabel?.text = aliasTemporaryValue
            if bluetoothPeripheralAsNSObject == nil {
                cell.accessoryType = .none
            } else {
                cell.accessoryType = .disclosureIndicator
            }

        case .transmitterId:
            
            cell.textLabel?.text = Texts_SettingsView.labelTransmitterId
            cell.detailTextLabel?.text = transmitterIdTempValue
            
            // if transmitterId already has a value, then it can't be changed anymore. To change it, user must delete the transmitter and recreate one.
            cell.accessoryType = transmitterIdTempValue == nil ? .disclosureIndicator : .none

        }

        return cell
        
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        tableView.deselectRow(at: indexPath, animated: true)
        
        // check if it's one of the common settings or one of the peripheral type specific settings
        if indexPath.section >= 1 {
          
            // it's a setting not defined here but in a BluetoothPeripheralViewModel
            // bluetoothPeripheralViewModel should not be nil here, otherwise user wouldn't be able to click a row which is higher than maximum
            if let bluetoothPeripheralViewModel = bluetoothPeripheralViewModel, let bluetoothPeripheral = bluetoothPeripheralAsNSObject {

                // parameter withSettingsViewModel is set to nil here, is used in the general settings page, where a view model represents a specific section, not used here
                SettingsViewUtilities.runSelectedRowAction(selectedRowAction: bluetoothPeripheralViewModel.userDidSelectRow(withSettingRawValue: indexPath.row, forSection: indexPath.section, for: bluetoothPeripheral, bluetoothPeripheralManager: bluetoothPeripheralManager, doneButtonOutlet: doneButtonOutlet), forRowWithIndex: indexPath.row, forSectionWithIndex: indexPath.section, withSettingsViewModel: nil, tableView: tableView, forUIViewController: self)

            }

            return
            
        }
        
        guard let setting = Setting(rawValue: indexPath.row) else { fatalError("BluetoothPeripheralViewController didSelectRowAt, Unexpected setting") }
        
        switch setting {
            
        case .address:
            guard let bluetoothPeripheralASNSObject = bluetoothPeripheralAsNSObject else {return}
            
            let alert = UIAlertController(title: Text_BluetoothPeripheralView.address, message: bluetoothPeripheralASNSObject.blePeripheral.address, actionHandler: nil)
            
            // present the alert
            self.present(alert, animated: true, completion: nil)
            
        case .name, .connectionStatus:
            break

        case .alias:
            
            // clicked cell to change alias - need to ask for new name, and verify if there's already another BluetoothPerpiheral existing with the same name

            // first off al check that BluetoothPeripheral already exists, otherwise makes no sense to change the name
            guard let bluetoothPeripheralASNSObject = bluetoothPeripheralAsNSObject else {return}
            
            let alert = UIAlertController(title: Text_BluetoothPeripheralView.bluetoothPeripheralAlias, message: Text_BluetoothPeripheralView.selectAliasText, keyboardType: .default, text: aliasTemporaryValue, placeHolder: nil, actionTitle: nil, cancelTitle: nil, actionHandler: { (text:String) in
                
                let newalias = text.toNilIfLength0()
                
                if newalias != nil {
                    
                    // need to check if there's already another peripheral with the same name
                    for bluetoothPeripheral in self.bluetoothPeripheralManager.getBluetoothPeripherals() {
                        
                        // not checking address of bluetoothPeripheralASNSObject, because obviously that one could have the same alias
                        if bluetoothPeripheral.blePeripheral.address != bluetoothPeripheralASNSObject.blePeripheral.address {
                            if bluetoothPeripheral.blePeripheral.alias == text {
                                
                                // bluetoothperipheral userdefined name already exists
                                let alreadyExistsAlert = UIAlertController(title: Texts_Common.warning, message: Text_BluetoothPeripheralView.aliasAlreadyExists, actionHandler: nil)
                                
                                // present the alert
                                self.present(alreadyExistsAlert, animated: true, completion: nil)
                                
                                return
                                
                            }
                        }
                    }
                }
                
                // not returned during loop, means name is unique
                self.aliasTemporaryValue = newalias
                
                // reload the specific row in the table
                tableView.reloadRows(at: [IndexPath(row: Setting.alias.rawValue, section: 0)], with: .none)
                
                // enable the done button
                self.doneButtonOutlet.enable()
                
            }, cancelHandler: nil)
            
            // present the alert
            self.present(alert, animated: true, completion: nil)
         
        case .transmitterId:
            
            // if transmitterId already has a value, then it can't be changed anymore. To change it, user must delete the transmitter and recreate one.
            if transmitterIdTempValue != nil {return}
            
            SettingsViewUtilities.runSelectedRowAction(selectedRowAction: SettingsSelectedRowAction.askText(title: Texts_SettingsView.labelTransmitterId, message: Texts_SettingsView.labelGiveTransmitterId, keyboardType: UIKeyboardType.alphabet, text: transmitterIdTempValue, placeHolder: "00000", actionTitle: nil, cancelTitle: nil, actionHandler:
                {(transmitterId:String) in
                    
                    // convert to uppercase
                    let transmitterIdUpper = transmitterId.uppercased().toNilIfLength0()
                    
                    self.transmitterIdTempValue = transmitterIdUpper
                    
                    // reload the specific row in the table
                    tableView.reloadRows(at: [IndexPath(row: Setting.transmitterId.rawValue, section: 0)], with: .none)
                    
                    // if transmitterId is not nil, and if user doesn't need to start the scanning, then start scanning automatically
                    if self.transmitterIdTempValue != nil, let expectedBluetoothPeripheralType = self.expectedBluetoothPeripheralType {
                        
                        if expectedBluetoothPeripheralType.transmitterStartsScanningAfterInit() {

                            // transmitterId presence will be checked in scanForBluetoothPeripheral
                            self.scanForBluetoothPeripheral(type: expectedBluetoothPeripheralType)

                        } else {
                            
                            // time to enable the scan button
                            self.scanButtonOutlet.enable()
                            
                        }
                        
                    }
                    
            }, cancelHandler: nil, inputValidator: { (transmitterId) in
                    
                return self.expectedBluetoothPeripheralType?.validateTransimtterId(transmitterId: transmitterId)
                
            }), forRowWithIndex: indexPath.row, forSectionWithIndex: indexPath.section, withSettingsViewModel: nil, tableView: tableView, forUIViewController: self)

        }
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        
        if section == 0 {
            // title for first section
            return Texts_SettingsView.m5StackSectionTitleBluetooth
        }
        
        // title for bluetoothperipheral type section
        return bluetoothPeripheralViewModel.sectionTitle(forSection: section)

    }
    
}

extension BluetoothPeripheralViewController: BluetoothTransmitterDelegate {
    
    func transmitterNeedsPairing(bluetoothTransmitter: BluetoothTransmitter) {
        
        // need to inform also other delegates
        previouslyAssignedBluetoothTransmitterDelegate?.transmitterNeedsPairing(bluetoothTransmitter: bluetoothTransmitter)

        // handled in BluetoothPeripheralManager
        
    }
    
    func successfullyPaired() {
        
        // need to inform also other delegates
        previouslyAssignedBluetoothTransmitterDelegate?.successfullyPaired()
        
        // handled in BluetoothPeripheralManager
        
    }
    
    func pairingFailed() {

        // need to inform also other delegates
        previouslyAssignedBluetoothTransmitterDelegate?.pairingFailed()

        // handled in BluetoothPeripheralManager
        
    }
    
    func reset(successful: Bool) {

        // need to inform also other delegates
        previouslyAssignedBluetoothTransmitterDelegate?.reset(successful: successful)
        
        // handled in BluetoothPeripheralManager
        
    }
    
    func didConnectTo(bluetoothTransmitter: BluetoothTransmitter) {
        
        // need to inform also other delegates
        previouslyAssignedBluetoothTransmitterDelegate?.didConnectTo(bluetoothTransmitter: bluetoothTransmitter)
        
       tableView.reloadRows(at: [IndexPath(row: Setting.connectionStatus.rawValue, section: 0)], with: .none)
        
    }
    
    func didDisconnectFrom(bluetoothTransmitter: BluetoothTransmitter) {
        
        // need to inform also other delegates
        previouslyAssignedBluetoothTransmitterDelegate?.didDisconnectFrom(bluetoothTransmitter: bluetoothTransmitter)
        
       tableView.reloadRows(at: [IndexPath(row: Setting.connectionStatus.rawValue, section: 0)], with: .none)

    }
    
    func deviceDidUpdateBluetoothState(state: CBManagerState, bluetoothTransmitter: BluetoothTransmitter) {

        // need to inform also other delegates
        previouslyAssignedBluetoothTransmitterDelegate?.deviceDidUpdateBluetoothState(state: state, bluetoothTransmitter: bluetoothTransmitter)
        
      // when bluetooth status changes to powered off, the device, if connected, will disconnect, however didDisConnect doesn't get call (looks like an error in iOS) - so let's reload the cell that shows the connection status, this will refresh the cell
        // do this whenever the bluetooth status changes
        tableView.reloadRows(at: [IndexPath(row: Setting.connectionStatus.rawValue, section: 0)], with: .none)

    }
    
    func error(message: String) {
        
        // need to inform also other delegates
        previouslyAssignedBluetoothTransmitterDelegate?.error(message: message)
        
        let alert = UIAlertController(title: Texts_Common.warning, message: message, actionHandler: nil)
        
        self.present(alert, animated: true, completion: nil)
    }
    
}

// MARK: - extension adding Segue Identifiers

/// defines perform segue identifiers used within BluetoothPeripheralViewController
extension BluetoothPeripheralViewController {
    public enum SegueIdentifiers:String {
        
        /// to go from BluetoothPeripheralsViewController to BluetoothPeripheralViewController
        case BluetoothPeripheralsToBluetoothPeripheralSegueIdentifier = "BluetoothPeripheralsToBluetoothPeripheralSegueIdentifier"
        
    }
    
    private enum UnwindSegueIdentifiers:String {
        
        /// to go back from BluetoothPeripheralViewController to BluetoothPeripheralsViewController
        case BluetoothPeripheralToBluetoothPeripheralsUnWindSegueIdentifier = "BluetoothPeripheralToBluetoothPeripheralsUnWindSegueIdentifier"
    }
}
