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
    
    /// ANY NEW SETTINGS SHOULD BE INSERTED HERE
    
    /// transmitterID, only for devices that need it
    case transmitterId = 4

}

fileprivate enum WebOOPSettings: Int, CaseIterable {
    
    /// is web OOP enabled or not
    case webOOPEnabled = 0
    
    /// if webOOP enabled, what site to use
    case webOOPsite = 1
    
    /// if webOOP enabled, value of the token
    case webOOPtoken = 2

}

/// base class for UIViewController's that allow to edit specific type of bluetooth transmitters to show 
class BluetoothPeripheralViewController: UIViewController {
    
    // MARK: - IBOutlet's and IBAction's
    
    /// action for connectButton, will also be used to disconnect, depending on the connection status
    @IBAction func connectButtonAction(_ sender: UIButton) {
        connectButtonHandler()
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

    /// outlet for scanButton, to set the text in the scanButton
    @IBOutlet weak var scanButtonOutlet: UIButton!
    
    /// outlet for connectButton, to set the text in the connectButton
    @IBOutlet weak var connectButtonOutlet: UIButton!

    /// outlet for trashButton, to enable or disable
    @IBOutlet weak var trashButtonOutlet: UIBarButtonItem!
    
    /// outlet for tableView
    @IBOutlet weak var tableView: UITableView!
    
    /// outlet for topLabel, to show in what screen user is
    @IBOutlet weak var topLabel: UILabel!
    
    // MARK: - private properties
    
    /// the BluetoothPeripheral being edited
    private var bluetoothPeripheral:BluetoothPeripheral?
    
    /// reference to coreDataManager
    private var coreDataManager:CoreDataManager?
    
    /// a BluetoothPeripheralManager
    private weak var bluetoothPeripheralManager: BluetoothPeripheralManaging?
    
    /// needed to support the bluetooth peripheral type specific attributes
    private var bluetoothPeripheralViewModel: BluetoothPeripheralViewModel?
    
    /// BluetoothPeripheralType for which this viewcontroller is created
    private var expectedBluetoothPeripheralType: BluetoothPeripheralType?
    
    /// temp storage of transmitterId value while user is creating the transmitter
    ///
    /// this value can only be set once by the user, ie it can change from nil to a value. As soon as a value is set by the user, and if transmitterStartsScanningAfterInit returns true, then a transmitter will be created and scanning will start. If transmitterStartsScanningAfterInit returns false, then the user needs to start the scanning (there are no transmitters for the moment that use transmitter id and that do have transmitterStartsScanningAfterInit = false)
    private var transmitterIdTempValue: String?
    
    // MARK:- public functions
    
    /// configure the viewController
    public func configure(bluetoothPeripheral: BluetoothPeripheral?, coreDataManager: CoreDataManager, bluetoothPeripheralManager: BluetoothPeripheralManaging, expectedBluetoothPeripheralType type: BluetoothPeripheralType) {

        self.bluetoothPeripheral = bluetoothPeripheral
        self.coreDataManager = coreDataManager
        self.bluetoothPeripheralManager = bluetoothPeripheralManager
        self.expectedBluetoothPeripheralType = type
        
    }
    
    /// sets shouldconnect for bluetoothPeripheral to false
    public func setShouldConnectToFalse(for bluetoothPeripheral: BluetoothPeripheral) {
        
        guard let bluetoothPeripheralManager = bluetoothPeripheralManager else {return}
        
        // device should not automaticaly connect in future, which means, each time the app restarts, it will not try to connect to this bluetoothPeripheral
        bluetoothPeripheral.blePeripheral.shouldconnect = false
        
        // save in coredata
        coreDataManager?.saveChanges()
        
        // connect button label text needs to change because shouldconnect value has changed
        self.setConnectButtonLabelText()
        
        // this will set bluetoothTransmitter to nil which will result in disconnecting also
        bluetoothPeripheralManager.setBluetoothTransmitterToNil(forBluetoothPeripheral: bluetoothPeripheral)
        
        // as transmitter is now set to nil, call again configure. Maybe not necessary, but it can't hurt
        bluetoothPeripheralViewModel?.configure(bluetoothPeripheral: bluetoothPeripheral, bluetoothPeripheralManager: bluetoothPeripheralManager, tableView: tableView, bluetoothPeripheralViewController: self)
        
        // delegate doesn't work here anymore, because the delegate is set to zero, so reset the row with the connection status by calling reloadRows
        tableView.reloadRows(at: [IndexPath(row: Setting.connectionStatus.rawValue, section: 0)], with: .none)
        
    }
    
    // MARK: - View Life Cycle
    
    override func viewDidLoad() {
        
        super.viewDidLoad()
        
        guard let bluetoothPeripheralManager = bluetoothPeripheralManager else {
            fatalError("in BluetoothPeripheralViewController viewDidLoad, bluetoothPeripheralManager is nil")
        }
        
        // here the tableView is not nil, we can safely call bluetoothPeripheralViewModel.configure, this one requires a non-nil tableView
        
        // get a viewModel instance for the expectedBluetoothPeripheralType
        bluetoothPeripheralViewModel = expectedBluetoothPeripheralType?.viewModel()

        // configure the bluetoothPeripheralViewModel
        bluetoothPeripheralViewModel?.configure(bluetoothPeripheral: bluetoothPeripheral, bluetoothPeripheralManager: bluetoothPeripheralManager, tableView: tableView, bluetoothPeripheralViewController: self)
        
        // assign the self delegate in the transmitter object
        if let bluetoothPeripheral = bluetoothPeripheral, let bluetoothTransmitter = bluetoothPeripheralManager.getBluetoothTransmitter(for: bluetoothPeripheral, createANewOneIfNecesssary: false) {
            
            bluetoothTransmitter.bluetoothTransmitterDelegate = self
            
        }

        setupView()
        
    }
    
    // MARK: - other overriden functions
    override func viewWillDisappear(_ animated: Bool) {
        
        // save any changes that are made
        coreDataManager?.saveChanges()
        
        // reassign delegate in BluetoothTransmitter to bluetoothPeripheralManager
        reassignBluetoothTransmitterDelegateToBluetoothPeripheralManager()
        
        // just in case scanning for a new device is still ongoing, call stopscanning
        bluetoothPeripheralManager?.stopScanningForNewDevice()
        
        // set bluetoothPeripheralViewModel to nil, so it can change the delegates
        bluetoothPeripheralViewModel = nil

    }
    
    // MARK: - View Methods
    
    private func setupView() {
        
        // set label of connect button, according to current status
        setConnectButtonLabelText()
        
        if bluetoothPeripheral == nil {

            // should be disabled, as there's nothing to delete yet
            trashButtonOutlet.disable()
            
            // connect button should be disabled, as there's nothing to connect to
            connectButtonOutlet.disable()
            
            // unwrap expectedBluetoothPeripheralType
            guard let expectedBluetoothPeripheralType = expectedBluetoothPeripheralType else {return}
            
            // if it's a bluetoothperipheraltype for which the bluetoothTransmitter starts scanning as soon as it's created, then there's no need to let the user do the start scanning, so let's hide the button - this will only be the case for transmitters that need transmitterId
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
        
        // set title
        title = bluetoothPeripheralViewModel?.screenTitle()
        
        setupTableView()
        
    }
    
    // MARK: - private functions
    
    /// setup datasource, delegate, seperatorInset
    private func setupTableView() {
        if let tableView = tableView {
            // insert slightly the separator text so that it doesn't touch the safe area limit
            tableView.separatorInset = UIEdgeInsets(top: 0, left: 10, bottom: 0, right: 0)
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
    
    private func scanForBluetoothPeripheral(type: BluetoothPeripheralType) {
        
        // if bluetoothPeripheral is not nil, then there's already a BluetoothPeripheral for which scanning has started or which is already known from a previous scan (either connected or not connected) (bluetoothPeripheral should be nil because if it is not, the scanbutton should not even be enabled, anyway let's check).
        guard bluetoothPeripheral == nil else {return}
        
        guard let bluetoothPeripheralManager = bluetoothPeripheralManager else {
            fatalError("in BluetoothPeripheralViewController scanForBluetoothPeripheral, bluetoothPeripheralManager is nil")
        }
        
        // if bluetoothPeripheralType needs transmitterId, then check that transmitterId is present
        if type.needsTransmitterId() && transmitterIdTempValue == nil {return}
        
        bluetoothPeripheralManager.startScanningForNewDevice(type: type, transmitterId: transmitterIdTempValue, callback: { (bluetoothPeripheral) in
            
            // assign internal bluetoothPeripheral to new bluetoothPeripheral
            self.bluetoothPeripheral = bluetoothPeripheral

            // assign transmitterid
            bluetoothPeripheral.blePeripheral.transmitterId = self.transmitterIdTempValue
            
            // recall configure in bluetoothPeripheralViewModel
            self.bluetoothPeripheralViewModel?.configure(bluetoothPeripheral: self.bluetoothPeripheral, bluetoothPeripheralManager: bluetoothPeripheralManager, tableView: self.tableView, bluetoothPeripheralViewController: self)
            
            // enable the connect button
            self.connectButtonOutlet.enable()
            
            // set right text for connect button
            self.setConnectButtonLabelText()
            
            // enable the trashbutton
            self.trashButtonOutlet.enable()
            
            // set self as delegate in the bluetoothTransmitter
            if let bluetoothTransmitter = bluetoothPeripheralManager.getBluetoothTransmitter(for: bluetoothPeripheral, createANewOneIfNecesssary: false) {
                
                bluetoothTransmitter.bluetoothTransmitterDelegate = self

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
        
        // let's first check if bluetoothPeripheral exists, otherwise there's nothing to trash, normally this shouldn't happen because trashbutton should be disabled if there's no bluetoothPeripheral
        guard let bluetoothPeripheral = bluetoothPeripheral else {return}

        // unwrap bluetoothPeripheralManager
        guard let bluetoothPeripheralManager = bluetoothPeripheralManager else {return}
        
        // textToAdd is either 'address' + the address, or 'alias' + the alias, depending if alias has a value
        var textToAdd = Text_BluetoothPeripheralView.address + " " + bluetoothPeripheral.blePeripheral.address
        if let alias = bluetoothPeripheral.blePeripheral.alias {
            textToAdd = Text_BluetoothPeripheralView.bluetoothPeripheralAlias + " " + alias
        }
        
        // first ask user if ok to delete and if yes delete
        let alert = UIAlertController(title: Text_BluetoothPeripheralView.confirmDeletionBluetoothPeripheral + " " + textToAdd + "?", message: nil, actionHandler: {
            
            // delete
            bluetoothPeripheralManager.deleteBluetoothPeripheral(bluetoothPeripheral: bluetoothPeripheral)
            
            self.bluetoothPeripheral = nil
            
            // close the viewcontroller
            self.navigationController?.popViewController(animated: true)
            self.dismiss(animated: true, completion: nil)
            
        }, cancelHandler: nil)
        
        self.present(alert, animated:true)

    }
    
    /// user clicked connect button
    private func connectButtonHandler() {
        
        // let's first check if bluetoothPeripheral exists, it should because otherwise connectButton should be disabled
        guard let bluetoothPeripheral = bluetoothPeripheral else {return}
        
        guard let bluetoothPeripheralManager = bluetoothPeripheralManager else {
            fatalError("in BluetoothPeripheralViewController trashButtonClicked, bluetoothPeripheralManager is nil")
        }
        
        // user clicked connectbutton. Check first the current value of shouldconnect and change
        if bluetoothPeripheral.blePeripheral.shouldconnect {
            
            // value off shouldconnect needs to change from true to false
            setShouldConnectToFalse(for: bluetoothPeripheral)

        } else {
            
            // check if there's no other cgm which has shouldconnect = true
            if expectedBluetoothPeripheralType?.category() == .CGM, BluetoothPeripheralsViewController.self.otherCGMTransmitterHasShouldConnectTrue(bluetoothPeripheralManager: self.bluetoothPeripheralManager, uiViewController: self) {
                
                return
                
            }
            
            // device should automatically connect, this will be stored in coredata
            bluetoothPeripheral.blePeripheral.shouldconnect = true
            
            // save the update in coredata
            coreDataManager?.saveChanges()
            
            // get bluetoothTransmitter
            if let bluetoothTransmitter = bluetoothPeripheralManager.getBluetoothTransmitter(for: bluetoothPeripheral, createANewOneIfNecesssary: true) {
                
                // set delegate of the new transmitter to self
                bluetoothTransmitter.bluetoothTransmitterDelegate = self
                
                // call configure in the model, as we have a new transmitter here
                bluetoothPeripheralViewModel?.configure(bluetoothPeripheral: bluetoothPeripheral, bluetoothPeripheralManager: bluetoothPeripheralManager, tableView: tableView, bluetoothPeripheralViewController: self)
                
                // connect (probably connection is already done because transmitter has just been created by bluetoothPeripheralManager, this is a transmitter for which mac address is known, so it will by default try to connect
                bluetoothTransmitter.connect()

            }
            
        }
        
        // will change text of the button
        self.setConnectButtonLabelText()
        
    }
    
    /// checks if bluetoothPeripheral is not nil, etc.
    /// - returns: true if bluetoothperipheral exists and is connected, false in all other cases
    private func bluetoothPeripheralIsConnected() -> Bool {
        
        guard let bluetoothPeripheral = bluetoothPeripheral else {return false}
        
        guard let bluetoothPeripheralManager = bluetoothPeripheralManager, let connectionStatus = bluetoothPeripheralManager.getBluetoothTransmitter(for: bluetoothPeripheral, createANewOneIfNecesssary: false)?.getConnectionStatus() else {return false}
        
        return connectionStatus == CBPeripheralState.connected

    }
    
    private func setConnectButtonLabelText() {

        // if BluetoothPeripheral is nil, then set text to "Always Connect", it's disabled anyway - if BluetoothPeripheral not nil, then set depending on value of shouldconnect
        if let bluetoothPeripheral = bluetoothPeripheral {
            
            // set label of connect button, according to curren status
            connectButtonOutlet.setTitle(bluetoothPeripheral.blePeripheral.shouldconnect ? Text_BluetoothPeripheralView.donotconnect:Text_BluetoothPeripheralView.alwaysConnect, for: .normal)
            
        } else {
            
            connectButtonOutlet.setTitle(Text_BluetoothPeripheralView.alwaysConnect, for: .normal)
            
        }
        
    }
    
    /// resets the bluetoothTransmitterDelegate to bluetoothPeripheralManager
    private func reassignBluetoothTransmitterDelegateToBluetoothPeripheralManager() {
        
        guard let bluetoothPeripheralManager = bluetoothPeripheralManager else {return}
        
        if let bluetoothPeripheral = bluetoothPeripheral, let bluetoothTransmitter = bluetoothPeripheralManager.getBluetoothTransmitter(for: bluetoothPeripheral, createANewOneIfNecesssary: false) {
            
            // reassign delegate, actually as we're closing BluetoothPeripheralViewController, where BluetoothPeripheralsViewController
            bluetoothTransmitter.bluetoothTransmitterDelegate = bluetoothPeripheralManager
            
        }
        
    }

}


// MARK: - extension UITableViewDataSource, UITableViewDelegate

extension BluetoothPeripheralViewController: UITableViewDataSource, UITableViewDelegate {
    
    func numberOfSections(in tableView: UITableView) -> Int {
        
        // there is one general section with settings applicable for all peripheral types, one or more specific section(s) with settings specific to type of bluetooth peripheral
        
        if bluetoothPeripheral == nil {
            
            // no peripheral known yet, only the first, bluetooth transmitter related settings are shown

            return 1
            
        } else {
            
            // bluetoothPeripheralViewModel should noramlly not be nil here
            guard let bluetoothPeripheralViewModel = bluetoothPeripheralViewModel else {return 0}
            
            // if it's a cgm transmitter type that supports web op, then also show the web oop section
            if bluetoothPeripheralViewModel.canWebOOP() {
                    return bluetoothPeripheralViewModel.numberOfSections() + 2
            }

            return bluetoothPeripheralViewModel.numberOfSections() + 1
            
        }
        
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        
        // expectedBluetoothPeripheralType should not be nil here, unwrap it
        guard let expectedBluetoothPeripheralType = expectedBluetoothPeripheralType else {return 0}
        
        // bluetoothPeripheralViewModel should not be nil here, unwrap it
        guard let bluetoothPeripheralViewModel = bluetoothPeripheralViewModel else {return 0}
        
        if section == 0 {

            // this is the general section, applicable to all types of transmitters
            
            // number of rows will be calculated, starting with all rows
            var numberOfRows = Setting.allCases.count
            
            // if bluetooth transmitter does not need transmitterId then don't show that row
            if !expectedBluetoothPeripheralType.needsTransmitterId() {
                numberOfRows = numberOfRows - 1
            }
            
            return numberOfRows
            
        } else if (section >= 1 && !bluetoothPeripheralViewModel.canWebOOP()) || (section >= 2) {
            
            // this is the section with the transmitter specific settings
            return bluetoothPeripheralViewModel.numberOfSettings(inSection: section)
            
        } else {
            
            // it's the web oop section
            return WebOOPSettings.allCases.count
            
        }
        
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        guard let cell = tableView.dequeueReusableCell(withIdentifier: SettingsTableViewCell.reuseIdentifier, for: indexPath) as? SettingsTableViewCell else { fatalError("BluetoothPeripheralViewController cellforrowat, Unexpected Table View Cell ") }
        
        // unwrap bluetoothPeripheralManager
        guard let bluetoothPeripheralManager = bluetoothPeripheralManager else {return cell}
        
        // unwrap bluetoothPeripheralViewModel
        guard let bluetoothPeripheralViewModel = bluetoothPeripheralViewModel else {return cell}
        
        // check if it's a Setting defined here in BluetoothPeripheralViewController, or a setting specific to the type of BluetoothPeripheral
        if (indexPath.section >= 1 && !bluetoothPeripheralViewModel.canWebOOP()) || (indexPath.section >= 2) {
            
            // it's a setting not defined here but in a BluetoothPeripheralViewModel
            if let bluetoothPeripheral = bluetoothPeripheral {

                bluetoothPeripheralViewModel.update(cell: cell, forRow: indexPath.row, forSection: indexPath.section, for: bluetoothPeripheral)
                
            }
            
            return cell
            
        }
           
        // default value for accessoryView is nil
        cell.accessoryView = nil
        
        //it's a Setting defined here in BluetoothPeripheralViewController
        // is it a bluetooth setting or web oop setting ?
        
        if indexPath.section == 0 {
            
            // bluetooth settings
            
            guard let setting = Setting(rawValue: indexPath.row) else { fatalError("BluetoothPeripheralViewController cellForRowAt, Unexpected setting") }
            
            // configure the cell depending on setting
            switch setting {
                
            case .name:
                
                cell.textLabel?.text = Texts_Common.name
                cell.detailTextLabel?.text = bluetoothPeripheral?.blePeripheral.name
                cell.accessoryType = .none
                
            case .address:
                
                cell.textLabel?.text = Text_BluetoothPeripheralView.address
                cell.detailTextLabel?.text = bluetoothPeripheral?.blePeripheral.address
                if cell.detailTextLabel?.text == nil {
                    cell.accessoryType = .none
                } else {
                    cell.accessoryType = .disclosureIndicator
                }
                
            case .connectionStatus:
                
                cell.textLabel?.text = Text_BluetoothPeripheralView.status
                cell.detailTextLabel?.text = bluetoothPeripheral == nil ? (bluetoothPeripheralManager.isScanning() ? "Scanning" : nil) : bluetoothPeripheralIsConnected() ? Text_BluetoothPeripheralView.connected:Text_BluetoothPeripheralView.notConnected
                cell.accessoryType = .none
                
            case .alias:
                
                cell.textLabel?.text = Text_BluetoothPeripheralView.bluetoothPeripheralAlias
                cell.detailTextLabel?.text = bluetoothPeripheral?.blePeripheral.alias
                if bluetoothPeripheral == nil {
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

        }  else {
            
            // web oop settings
            
            guard let setting = WebOOPSettings(rawValue: indexPath.row) else { fatalError("BluetoothPeripheralViewController cellForRowAt, Unexpected setting") }
            
            // configure the cell depending on setting
            switch setting {
                
            case .webOOPEnabled:
                
                cell.textLabel?.text = Texts_SettingsView.labelWebOOPTransmitter
                cell.detailTextLabel?.text = nil
                
                var currentStatus = false
                if let bluetoothPeripheral = bluetoothPeripheral {
                    currentStatus = bluetoothPeripheral.blePeripheral.webOOPEnabled
                }
                
                cell.accessoryView = UISwitch(isOn: currentStatus, action: { (isOn:Bool) in
                    
                    self.bluetoothPeripheral?.blePeripheral.webOOPEnabled = isOn
                    
                    // send info to bluetoothPeripheralManager
                    if let bluetoothPeripheral = self.bluetoothPeripheral {
                        
                        bluetoothPeripheralManager.receivedNewValue(webOOPEnabled: isOn, for: bluetoothPeripheral)

                    }
                    
                })
                
                cell.accessoryType = .none
                
            case .webOOPsite:
                
                cell.textLabel?.text = Texts_SettingsView.labelWebOOPSite
                cell.detailTextLabel?.text = bluetoothPeripheral?.blePeripheral.oopWebSite
                cell.accessoryType = .disclosureIndicator
                
            case .webOOPtoken:
                
                cell.textLabel?.text = Texts_SettingsView.labelWebOOPtoken
                cell.detailTextLabel?.text = bluetoothPeripheral?.blePeripheral.oopWebToken
                cell.accessoryType = .disclosureIndicator
                
            }
            
        }
        
        
        return cell
        
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        tableView.deselectRow(at: indexPath, animated: true)
        
        // unwrap bluetoothPeripheralManager
        guard let bluetoothPeripheralManager = bluetoothPeripheralManager else {return}
        
        // unwrap bluetoothPeripheralViewModel
        guard let bluetoothPeripheralViewModel = bluetoothPeripheralViewModel else {return}

        // check if it's one of the common settings or one of the peripheral type specific settings
        if (indexPath.section >= 1 && !bluetoothPeripheralViewModel.canWebOOP()) || (indexPath.section >= 2) {
          
            // it's a setting not defined here but in a BluetoothPeripheralViewModel
            // bluetoothPeripheralViewModel should not be nil here, otherwise user wouldn't be able to click a row which is higher than maximum
            if let bluetoothPeripheral = bluetoothPeripheral {

                // parameter withSettingsViewModel is set to nil here, is used in the general settings page, where a view model represents a specific section, not used here
                SettingsViewUtilities.runSelectedRowAction(selectedRowAction: bluetoothPeripheralViewModel.userDidSelectRow(withSettingRawValue: indexPath.row, forSection: indexPath.section, for: bluetoothPeripheral, bluetoothPeripheralManager: bluetoothPeripheralManager), forRowWithIndex: indexPath.row, forSectionWithIndex: indexPath.section, withSettingsViewModel: nil, tableView: tableView, forUIViewController: self)

            }

            return
            
        }
        
        //it's a Setting defined here in BluetoothPeripheralViewController
        // is it a bluetooth setting or web oop setting ?
        
        if indexPath.section == 0 {
            
            guard let setting = Setting(rawValue: indexPath.row) else { fatalError("BluetoothPeripheralViewController didSelectRowAt, Unexpected setting") }
            
            switch setting {
                
            case .address:
                guard let bluetoothPeripheral = bluetoothPeripheral else {return}
                
                let alert = UIAlertController(title: Text_BluetoothPeripheralView.address, message: bluetoothPeripheral.blePeripheral.address, actionHandler: nil)
                
                // present the alert
                self.present(alert, animated: true, completion: nil)
                
            case .name, .connectionStatus:
                break
                
            case .alias:
                
                // clicked cell to change alias - need to ask for new name, and verify if there's already another BluetoothPerpiheral existing with the same name
                
                // first off al check that BluetoothPeripheral already exists, otherwise makes no sense to change the name
                guard let bluetoothPeripheral = bluetoothPeripheral else {return}
                
                let alert = UIAlertController(title: Text_BluetoothPeripheralView.bluetoothPeripheralAlias, message: Text_BluetoothPeripheralView.selectAliasText, keyboardType: .default, text: bluetoothPeripheral.blePeripheral.alias, placeHolder: nil, actionTitle: nil, cancelTitle: nil, actionHandler: { (text:String) in
                    
                    let newalias = text.toNilIfLength0()
                    
                    if newalias != nil {
                        
                        // need to check if there's already another peripheral with the same name
                        for bluetoothPeripheral in bluetoothPeripheralManager.getBluetoothPeripherals() {
                            
                            // not checking address of bluetoothPeripheral, because obviously that one could have the same alias
                            if bluetoothPeripheral.blePeripheral.address != bluetoothPeripheral.blePeripheral.address {
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
                    bluetoothPeripheral.blePeripheral.alias = newalias
                    
                    // reload the specific row in the table
                    tableView.reloadRows(at: [IndexPath(row: Setting.alias.rawValue, section: 0)], with: .none)
                    
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
                    
                    return self.expectedBluetoothPeripheralType?.validateTransmitterId(transmitterId: transmitterId)
                    
                }), forRowWithIndex: indexPath.row, forSectionWithIndex: indexPath.section, withSettingsViewModel: nil, tableView: tableView, forUIViewController: self)
                
            }
            
        } else {
            
            // web oop settings
            
            guard let setting = WebOOPSettings(rawValue: indexPath.row) else { fatalError("BluetoothPeripheralViewController cellForRowAt, Unexpected setting") }
            
            switch setting {
                
            case .webOOPEnabled:
                // this is a uiswitch, user needs to click the uiswitch, not just the row
                return
                
            case .webOOPsite:
                
                // this option should only be shown if there's already a bluetoothPeripheral assigned
                guard let bluetoothPeripheral = bluetoothPeripheral else {return}
                
                SettingsViewUtilities.runSelectedRowAction(selectedRowAction: SettingsSelectedRowAction.askText(title: Texts_SettingsView.labelWebOOP, message: Texts_SettingsView.labelWebOOPSiteExplainingText, keyboardType: .URL, text: bluetoothPeripheral.blePeripheral.oopWebSite, placeHolder: Texts_Common.default0, actionTitle: nil, cancelTitle: nil, actionHandler: {(oopwebsiteurl:String) in
                    
                    if oopwebsiteurl != bluetoothPeripheral.blePeripheral.oopWebSite {
                        
                        // store in nsobject
                        bluetoothPeripheral.blePeripheral.oopWebSite = oopwebsiteurl.toNilIfLength0()
                        
                        // send new value to bluetoothPeripheralManager
                        bluetoothPeripheralManager.receivedNewValue(oopWebSite: oopwebsiteurl.toNilIfLength0(), for: bluetoothPeripheral)
                        
                    }
                    
                }, cancelHandler: nil, inputValidator: nil), forRowWithIndex: indexPath.row, forSectionWithIndex: indexPath.section, withSettingsViewModel: nil, tableView: tableView, forUIViewController: self)
                
            case .webOOPtoken:
                
                // this option should only be shown if there's already a bluetoothPeripheral assigned
                guard let bluetoothPeripheral = bluetoothPeripheral else {return}
                
                SettingsViewUtilities.runSelectedRowAction(selectedRowAction: SettingsSelectedRowAction.askText(title: Texts_SettingsView.labelWebOOP, message: Texts_SettingsView.labelWebOOPtokenExplainingText, keyboardType: .default, text: bluetoothPeripheral.blePeripheral.oopWebToken, placeHolder: Texts_Common.default0, actionTitle: nil, cancelTitle: nil, actionHandler: {(oopwebsitetoken:String) in
                    
                    if oopwebsitetoken != bluetoothPeripheral.blePeripheral.oopWebToken {
                        
                        // store in nsobject
                        bluetoothPeripheral.blePeripheral.oopWebToken = oopwebsitetoken.toNilIfLength0()
                        
                        // send new value to bluetoothPeripheralManager
                        bluetoothPeripheralManager.receivedNewValue(oopWebToken: oopwebsitetoken.toNilIfLength0(), for: bluetoothPeripheral)
                        
                    }
                    
                }, cancelHandler: nil, inputValidator: nil), forRowWithIndex: indexPath.row, forSectionWithIndex: indexPath.section, withSettingsViewModel: nil, tableView: tableView, forUIViewController: self)
                

            }
        
        }
        
        
        
        
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        
        // unwrap bluetoothPeripheralViewModel
        guard let bluetoothPeripheralViewModel = bluetoothPeripheralViewModel else {return nil}

        if section == 0 {
            
            // title for first section
            return Texts_SettingsView.m5StackSectionTitleBluetooth
            
        } else if (section >= 1 && !bluetoothPeripheralViewModel.canWebOOP()) || (section >= 2) {
            
            // title for bluetoothperipheral type section
            return bluetoothPeripheralViewModel.sectionTitle(forSection: section)

        } else {
            
            // web oop section
            return Texts_SettingsView.labelWebOOP
            
        }
        
    }
    
}

extension BluetoothPeripheralViewController: BluetoothTransmitterDelegate {
    
    func transmitterNeedsPairing(bluetoothTransmitter: BluetoothTransmitter) {
        
        // handled in BluetoothPeripheralManager
        bluetoothPeripheralManager?.transmitterNeedsPairing(bluetoothTransmitter: bluetoothTransmitter)
        
    }
    
    func successfullyPaired() {
        
        // handled in BluetoothPeripheralManager
        bluetoothPeripheralManager?.successfullyPaired()
        
    }
    
    func pairingFailed() {

        // need to inform also other delegates
        bluetoothPeripheralManager?.pairingFailed()

    }
    
    func reset(for bluetoothTransmitter: BluetoothTransmitter, successful: Bool) {

        // handled in BluetoothPeripheralManager
        bluetoothPeripheralManager?.reset(for: bluetoothTransmitter, successful: successful)
        
    }
    
    func didConnectTo(bluetoothTransmitter: BluetoothTransmitter) {

        // handled in BluetoothPeripheralManager
        bluetoothPeripheralManager?.didConnectTo(bluetoothTransmitter: bluetoothTransmitter)
        
        tableView.reloadRows(at: [IndexPath(row: Setting.connectionStatus.rawValue, section: 0)], with: .none)
        
    }
    
    func didDisconnectFrom(bluetoothTransmitter: BluetoothTransmitter) {
        
        // handled in BluetoothPeripheralManager
        bluetoothPeripheralManager?.didDisconnectFrom(bluetoothTransmitter: bluetoothTransmitter)
        
        tableView.reloadRows(at: [IndexPath(row: Setting.connectionStatus.rawValue, section: 0)], with: .none)

    }
    
    func deviceDidUpdateBluetoothState(state: CBManagerState, bluetoothTransmitter: BluetoothTransmitter) {

        // handled in BluetoothPeripheralManager
        bluetoothPeripheralManager?.deviceDidUpdateBluetoothState(state: state, bluetoothTransmitter: bluetoothTransmitter)
        
        // when bluetooth status changes to powered off, the device, if connected, will disconnect, however didDisConnect doesn't get call (looks like an error in iOS) - so let's reload the cell that shows the connection status, this will refresh the cell
        // do this whenever the bluetooth status changes
        tableView.reloadRows(at: [IndexPath(row: Setting.connectionStatus.rawValue, section: 0)], with: .none)

    }
    
    func error(message: String) {
        
        // need to inform also other delegates
        bluetoothPeripheralManager?.error(message: message)
        
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
    
}
