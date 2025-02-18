import UIKit
import CoreBluetooth
import os
import AVFoundation

fileprivate let generalSettingSectionNumber = 0

/// - a case per attribute that can be set in BluetoothPeripheralViewController
/// - these are applicable to all types of bluetoothperipheral types (M5Stack ...)
fileprivate enum Setting:Int, CaseIterable {
    
    /// the name received from bluetoothTransmitter, ie the name hardcoded in the BluetoothPeripheral
    case name = 0
    
    /// the alias that user has given, possibly nil
    case alias = 1
    
    /// the current connection status
    case connectionStatus = 2
    
    /// timestamp when connection changed to connected or not connected
    case connectOrDisconnectTimeStamp = 3
    
    /// transmitterID, only for devices that need it
    case transmitterId = 4
    
}

fileprivate enum WebOOPSettings: Int, CaseIterable {
    
    /// is web OOP enabled or not
    case webOOPEnabled = 0
    
}

fileprivate enum NonFixedCalibrationSlopesSettings: Int, CaseIterable {
    
    /// is non fixed slope enabled or not
    case nonFixedSlopeEnabled = 0
    
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
    
    /// if user clicks start scanning, then this variable will be set to true. Used to verify if scanning is ongoing or not,
    private var isScanning: Bool = false
    
    /// in which section do we find the weboop settings, if enabled
    ///
    /// this value assumes that if webOOPSettingsSection is shown then also nonFixedSettings section is shown
    private let webOOPSettingsSectionNumber = 1
    
    /// is the webOOPSettingsSection currently shown or not
    private var webOOPSettingsSectionIsShown = false
    
    /// if true, webOOPSettingsSectionIsShown and nonFixedSettingsSectionIsShown was already calculated once.
    /// - this is to avoid that it jumps from true to false or vice versa when the user clicks disconnect or stops scanning, which deletes the transmitter, and then calculation of webOOPSettingsSectionIsShown and nonFixedSettingsSectionIsShown gets different values
    private var webOOpSettingsAndNonFixedSlopeSectionIsShownIsKnown = false
    
    /// in which section do we find the non fixed calibration slopes setting, if enabled
    private let nonFixedSettingsSectionNumber = 2
    
    /// is the nonFixedSettingsSection currently shown or not
    private var nonFixedSettingsSectionIsShown = false
    
    /// when user starts scanning, info will be shown in UIAlertController.
    private var infoAlertWhenScanningStarts: UIAlertController?
    
    /// for trace
    private let log = OSLog(subsystem: ConstantsLog.subSystem, category: ConstantsLog.categoryBluetoothPeripheralViewController)
    
    /// to keep track of scanning result
    private var previousScanningResult: BluetoothTransmitter.startScanningResult?
    
    /// used to verify if an NFC scan is needed or not. Will be set to true when the user initiates scanning of a transmitter that requires NFC to connect such as Libre 2.
    private var nfcScanNeeded: Bool = false
    
    /// used to verify if a valid NFC scan has been recorded
    private var nfcScanSuccessful: Bool = false
    
    /// keep track of whether the observers were already added/registered (to make sure before we try to remove them)
    private var didAddObservers: Bool = false
    
    
    // MARK: - public functions
    
    /// configure the viewController
    public func configure(bluetoothPeripheral: BluetoothPeripheral?, coreDataManager: CoreDataManager, bluetoothPeripheralManager: BluetoothPeripheralManaging, expectedBluetoothPeripheralType type: BluetoothPeripheralType) {
        
        self.bluetoothPeripheral = bluetoothPeripheral
        self.coreDataManager = coreDataManager
        self.bluetoothPeripheralManager = bluetoothPeripheralManager
        self.expectedBluetoothPeripheralType = type
        self.transmitterIdTempValue = bluetoothPeripheral?.blePeripheral.transmitterId
        
    }
    
    /// - sets text in connect button (only applicable to BluetoothPeripheralViewController) and gets status text
    /// - used in BluetoothPeripheralsViewController and BluetoothPeripheralViewController. BluetoothPeripheralsViewController doen't have a connect button, so that outlet is optional
    public static func setConnectButtonLabelTextAndGetStatusDetailedText(bluetoothPeripheral: BluetoothPeripheral?, isScanning: Bool, nfcScanNeeded: Bool?, nfcScanSuccessful: Bool?, connectButtonOutlet: UIButton?, expectedBluetoothPeripheralType: BluetoothPeripheralType?, transmitterId: String?, bluetoothPeripheralManager: BluetoothPeripheralManager) -> String {
        
        // by default connectbutton is enabled
        connectButtonOutlet?.enable()
        
        var nfcScanIsNeeded = false
        var nfcScanWasSuccessful = false
        
        if nfcScanNeeded ?? false {
            nfcScanIsNeeded = true
        }
        
        if nfcScanSuccessful ?? false {
            nfcScanWasSuccessful = true
        }
        
        
        // if BluetoothPeripheral not nil
        if let bluetoothPeripheral = bluetoothPeripheral {
            
            // if connected then status = connected, button text = disconnect
            if bluetoothPeripheralIsConnected(bluetoothPeripheral: bluetoothPeripheral, bluetoothPeripheralManager: bluetoothPeripheralManager) {
                
                connectButtonOutlet?.setTitle(Texts_BluetoothPeripheralView.disconnect, for: .normal)
                
                return Texts_BluetoothPeripheralView.connected
            }
            
            // if not connected, but shouldconnect = true, means the app is trying to connect
            // by clicking the button, app will stop trying to connect
            if bluetoothPeripheral.blePeripheral.shouldconnect {
                
                // if an NFC scan is needed then set the status text to show it so that the user doesn't think it is scanning
                if nfcScanIsNeeded {
                    
                    connectButtonOutlet?.setTitle(Texts_BluetoothPeripheralView.donotconnect, for: .normal)
                    
                    return Texts_BluetoothPeripheralView.nfcScanNeeded
                    
                } else {
                    
                    connectButtonOutlet?.setTitle(Texts_BluetoothPeripheralView.donotconnect, for: .normal)
                    
                    return Texts_BluetoothPeripheralView.tryingToConnect
                    
                }
                
            }
            
            // not connected, shouldconnect = false
            connectButtonOutlet?.setTitle(Texts_BluetoothPeripheralView.connect, for: .normal)
            
            return Texts_BluetoothPeripheralView.notTryingToConnect
            
        } else {
            
            // BluetoothPeripheral is nil
            
            // if needs transmitterId, but no transmitterId is given by user, then button allows to set transmitter id, row text = "needs transmitter id"
            if let expectedBluetoothPeripheralType = expectedBluetoothPeripheralType, expectedBluetoothPeripheralType.needsTransmitterId(), transmitterId == nil {
                
                connectButtonOutlet?.setTitle(Texts_SettingsView.labelTransmitterIdTextForButton, for: .normal)
                
                return Texts_BluetoothPeripheralView.needsTransmitterId
                
            }
            
            //if transmitter id not needed or transmitter id needed and already given, but not yet scanning
            if let expectedBluetoothPeripheralType = expectedBluetoothPeripheralType {
                
                // if an NFC scan is needed then set the status text to show it so that the user doesn't think it is scanning
                if nfcScanIsNeeded {
                    
                    connectButtonOutlet?.setTitle(Texts_BluetoothPeripheralView.scanning, for: .normal)
                    
                    return Texts_BluetoothPeripheralView.nfcScanNeeded
                    
                }
                
                // if a successful NFC scan has taken place then set the status text to show that it is now scanning
                if nfcScanWasSuccessful {
                    
                    // disable, while scanning there's no need to click that button
                    connectButtonOutlet?.disable()
                    
                    connectButtonOutlet?.setTitle(Texts_BluetoothPeripheralView.donotconnect, for: .normal)
                    
                    return Texts_BluetoothPeripheralView.tryingToConnect
                    
                }
                
                if (!expectedBluetoothPeripheralType.needsTransmitterId() || (expectedBluetoothPeripheralType.needsTransmitterId() && transmitterId != nil)) && !isScanning {
                    
                    connectButtonOutlet?.setTitle(Texts_BluetoothPeripheralView.scan, for: .normal)
                    
                    return Texts_BluetoothPeripheralView.readyToScan
                    
                }
                
            }
            
            // getting here, means it should be scanning
            if isScanning {
                
                // disable, while scanning there's no need to click that button
                connectButtonOutlet?.disable()
                
                connectButtonOutlet?.setTitle(Texts_BluetoothPeripheralView.scanning, for: .normal)
                
                return Texts_BluetoothPeripheralView.scanning
                
            }
            
            // we're here, looks like an error, let's write that in the status field
            connectButtonOutlet?.setTitle("error", for: .normal)
            return "error"
            
        }
        
    }
    
    /// sets shouldconnect for bluetoothPeripheral to false, and disconnect
    /// - parameters:
    ///     - bluetoothPeripheral: the currently set bluetooth peripheral as defined by the delegate
    ///     - asUser: should be set to true if we want to ask the user to confirm the disconnect
    public func setShouldConnectToFalse(for bluetoothPeripheral: BluetoothPeripheral, askUser: Bool) {
        
        guard let bluetoothPeripheralManager = bluetoothPeripheralManager else {return}
        
        if askUser {
            
            // create uialertcontroller to ask the user if they really want to disconnect
            let confirmDisconnectAlertController = UIAlertController(title: Texts_BluetoothPeripheralView.confirmDisconnectTitle , message: Texts_BluetoothPeripheralView.confirmDisconnectMessage, preferredStyle: .alert)
            
            // create buttons for uialertcontroller
            let OKAction = UIAlertAction(title: Texts_BluetoothPeripheralView.disconnect, style: .default) {
                (action:UIAlertAction!) in
                
                // device should not automaticaly connect in future, which means, each time the app restarts, it will not try to connect to this bluetoothPeripheral
                bluetoothPeripheral.blePeripheral.shouldconnect = false
                
                // save in coredata
                self.coreDataManager?.saveChanges()
                
                // in case it's a Libre2 CGM, libre1DerivedAlgorithmParameters has a non nil value. When deleting the transmitter, by setting to nil, this will ensure that user first need to do a successful NFC scan.
                if let bluetoothTransmitter = bluetoothPeripheralManager.getBluetoothTransmitter(for: bluetoothPeripheral, createANewOneIfNecesssary: false), bluetoothTransmitter is CGMTransmitter {
                    
                    UserDefaults.standard.libre1DerivedAlgorithmParameters = nil
                    
                    // we'll also take advantage to stop the active sensor session for this type of CGM. This will cause the sensor info to be disabled until another sensor session is started with a max sensor age value
                    UserDefaults.standard.stopActiveSensor = true
                    
                }
                
                // connect button label text needs to change because shouldconnect value has changed
                _ = BluetoothPeripheralViewController.setConnectButtonLabelTextAndGetStatusDetailedText(bluetoothPeripheral: bluetoothPeripheral, isScanning: self.isScanning, nfcScanNeeded: self.nfcScanNeeded, nfcScanSuccessful: self.nfcScanSuccessful, connectButtonOutlet: self.connectButtonOutlet, expectedBluetoothPeripheralType: self.expectedBluetoothPeripheralType, transmitterId: self.transmitterIdTempValue, bluetoothPeripheralManager: bluetoothPeripheralManager as! BluetoothPeripheralManager)
                
                // this will set bluetoothTransmitter to nil which will result in disconnecting also
                bluetoothPeripheralManager.setBluetoothTransmitterToNil(forBluetoothPeripheral: bluetoothPeripheral)
                
                // as transmitter is now set to nil, call again configure. Maybe not necessary, but it can't hurt
                self.bluetoothPeripheralViewModel?.configure(bluetoothPeripheral: bluetoothPeripheral, bluetoothPeripheralManager: bluetoothPeripheralManager, tableView: self.tableView, bluetoothPeripheralViewController: self)
                
                // delegate doesn't work here anymore, because the delegate is set to zero, so reset the row with the connection status by calling reloadRows
                self.tableView.reloadRows(at: [IndexPath(row: Setting.connectionStatus.rawValue, section: 0)], with: .none)
                
            }
            
            // create a cancel button. If the user clicks it then we will just return directly
            let cancelAction = UIAlertAction(title: Texts_Common.Cancel, style: .cancel) {
                (action:UIAlertAction!) in
            }
            
            // add buttons to the alert
            confirmDisconnectAlertController.addAction(OKAction)
            confirmDisconnectAlertController.addAction(cancelAction)
            
            // show alert
            present(confirmDisconnectAlertController, animated: true, completion:nil)
            
        } else {
            
            // device should not automaticaly connect in future, which means, each time the app restarts, it will not try to connect to this bluetoothPeripheral
            bluetoothPeripheral.blePeripheral.shouldconnect = false
            
            // save in coredata
            self.coreDataManager?.saveChanges()
            
            // in case it's a Libre2 CGM, libre1DerivedAlgorithmParameters has a non nil value. When deleting the transmitter, by setting to nil, this will ensure that user first need to do a successful NFC scan.
            if let bluetoothTransmitter = bluetoothPeripheralManager.getBluetoothTransmitter(for: bluetoothPeripheral, createANewOneIfNecesssary: false), bluetoothTransmitter is CGMTransmitter {
                
                UserDefaults.standard.libre1DerivedAlgorithmParameters = nil
                
                // we'll also take advantage to stop the active sensor session for this type of CGM. This will cause the sensor info to be disabled until another sensor session is started with a max sensor age value
                UserDefaults.standard.stopActiveSensor = true
                
            }
            
            // connect button label text needs to change because shouldconnect value has changed
            _ = BluetoothPeripheralViewController.setConnectButtonLabelTextAndGetStatusDetailedText(bluetoothPeripheral: bluetoothPeripheral, isScanning: self.isScanning, nfcScanNeeded: self.nfcScanNeeded, nfcScanSuccessful: self.nfcScanSuccessful, connectButtonOutlet: self.connectButtonOutlet, expectedBluetoothPeripheralType: self.expectedBluetoothPeripheralType, transmitterId: self.transmitterIdTempValue, bluetoothPeripheralManager: bluetoothPeripheralManager as! BluetoothPeripheralManager)
            
            // this will set bluetoothTransmitter to nil which will result in disconnecting also
            bluetoothPeripheralManager.setBluetoothTransmitterToNil(forBluetoothPeripheral: bluetoothPeripheral)
            
            // as transmitter is now set to nil, call again configure. Maybe not necessary, but it can't hurt
            self.bluetoothPeripheralViewModel?.configure(bluetoothPeripheral: bluetoothPeripheral, bluetoothPeripheralManager: bluetoothPeripheralManager, tableView: self.tableView, bluetoothPeripheralViewController: self)
            
            // delegate doesn't work here anymore, because the delegate is set to zero, so reset the row with the connection status by calling reloadRows
            self.tableView.reloadRows(at: [IndexPath(row: Setting.connectionStatus.rawValue, section: 0)], with: .none)
            
        }
        
    }
    
    
    /// based upon setShouldConnectToFalse(), this function will be called by the observer if the Libre 2 NFC scan fails
    /// the actions will depend on if a valid bluetoothPeripheral is passed to it (existing sensor) or if it is nil (adding a new sensor)
    /// after disconnecting the transmitter (if required), it will open a dialog to ask the user if they want to try scanning again
    ///
    /// - parameters:
    ///     - bluetoothPeripheral - the currently set bluetooth peripheral as defined by the delegate
    private func nfcScanFailed(for bluetoothPeripheral: BluetoothPeripheral?) {
        
        // unwrap bluetoothPeripheralManager
        guard let bluetoothPeripheralManager = bluetoothPeripheralManager else {return}
        
        // check if there is an existing transmitter configured. If so, disconnect it using setShouldConnectToFalse (this will also update the table and button labels)
        if let bluetoothPeripheral = bluetoothPeripheral {
            
            setShouldConnectToFalse(for: bluetoothPeripheral, askUser: false)
            
        } else {
            
            // connect button label text needs to change because shouldconnect value has changed
            _ = BluetoothPeripheralViewController.setConnectButtonLabelTextAndGetStatusDetailedText(bluetoothPeripheral: bluetoothPeripheral, isScanning: self.isScanning, nfcScanNeeded: self.nfcScanNeeded, nfcScanSuccessful: self.nfcScanSuccessful, connectButtonOutlet: self.connectButtonOutlet, expectedBluetoothPeripheralType: self.expectedBluetoothPeripheralType, transmitterId: self.transmitterIdTempValue, bluetoothPeripheralManager: bluetoothPeripheralManager as! BluetoothPeripheralManager)
            
            // TODO: need to fix crash: This reload can sometimes cause a crash under certain circumstances
            // delegate doesn't work here anymore, because the delegate is set to zero, so reset the row with the connection status by calling reloadRows
            self.tableView.reloadRows(at: [IndexPath(row: Setting.connectionStatus.rawValue, section: 0)], with: .none)
        }
        
        // create UIAlertController to ask the user if they want to try running a new NFC scan, or just stay disconnected
        let nfcScanFailedAlert = UIAlertController(title: TextsLibreNFC.nfcScanFailedTitle , message: TextsLibreNFC.nfcScanFailedMessage, preferredStyle: .alert)
        
        // create a scan again button. If the user clicks it, update everything and initiate a new connection (which will initiate an NFC scan first in this case).
        let scanAgainAction = UIAlertAction(title: TextsLibreNFC.nfcScanFailedScanAgainButton, style: .default) {
            (action:UIAlertAction!) in
            
            AudioServicesPlaySystemSound(1102)
            
            self.checkIfNFCScanIsNeeded()
            
            self.connectButtonHandler()
            
        }
        
        // create a cancel button
        let cancelAction = UIAlertAction(title: Texts_Common.Cancel, style: .cancel) {
            (action:UIAlertAction!) in
            
            // check if an existing transmitter exists
            if bluetoothPeripheral != nil {
                
                // no need to do anything else except reset the private vars and userdefaults as needed
                self.checkIfNFCScanIsNeeded()
                
            } else {
                
                // no transmitter has been added yet so just go back to the previous view
                
                // just go back to the BluetoothPeripheralsViewController and cancel the transmitter add
                if let navigationController = self.navigationController {
                    
                    self.tableView.removeFromSuperview()
                    
                    navigationController.popViewController(animated: true)
                    
                } else {
                    
                    self.dismiss(animated: true, completion: nil)
                    
                }
                
            }
            
        }
        
        // add the buttons to the UI alert
        nfcScanFailedAlert.addAction(scanAgainAction)
        nfcScanFailedAlert.addAction(cancelAction)
        
        // show the UI alert
        present(nfcScanFailedAlert, animated: true, completion:nil)
        
    }
    
    
    /// The BluetoothPeripheralViewController has already a few sections defined (bluetooth, weboop, nonfixedslopeenabled). This function gives the amount of general sections to be shown. This depends on the availability of weboop and nonfixedslopeenabled for the transmitter
    public func numberOfGeneralSections() -> Int {
        
        // start with one general section, which is Setting
        var numberOfGeneralSections: Int = 1
        
        // means we already calculated numberOfGeneralSections while bluetoothTransmitter was not nil so we can skip the rest
        if webOOpSettingsAndNonFixedSlopeSectionIsShownIsKnown {
            return numberOfGeneralSections + (webOOPSettingsSectionIsShown ? 1 : 0) + (nonFixedSettingsSectionIsShown ? 1 : 0)
        }
        
        // first check if bluetoothPeripheral already known
        if let bluetoothPeripheral = bluetoothPeripheral {
            
            // bluetoothPeripheral already known, so let's unwrap expectedBluetoothPeripheralType
            if let expectedBluetoothPeripheralType = expectedBluetoothPeripheralType {
                
                // if transmitter is cgmTransmitter, if not nonWebOOPAllowed, then it means this is a transmitter that can not give rawdata
                // in that case don't show the sections  weboopenabled and nonfixedslope
                if let bluetoothPeripheralManager = bluetoothPeripheralManager, let bluetoothTransmitter = bluetoothPeripheralManager.getBluetoothTransmitter(for: bluetoothPeripheral, createANewOneIfNecesssary: false) {
                    // no need to recalculate webOOPSettingsSectionIsShown and nonFixedSettingsSectionIsShown later
                    webOOpSettingsAndNonFixedSlopeSectionIsShownIsKnown = true
                    
                    if let cgmTransmitter = bluetoothTransmitter as? CGMTransmitter {
                        
                        // is it allowed for this transmitter to work with rawdata?
                        // if not then don't show weboopsettings and nonfixedslopesettings
                        // there's only one section (the first) in this case
                        if !cgmTransmitter.nonWebOOPAllowed() {
                            // mark web oop and non fixed slope settings sections as not shown
                            webOOPSettingsSectionIsShown = false
                            nonFixedSettingsSectionIsShown = false
                            
                            return numberOfGeneralSections
                        }
                    }
                }
                
                // mark web oop and non fixed slope settings sections as not shown
                // this will be updated as applicable in the next lines
                webOOPSettingsSectionIsShown = false
                nonFixedSettingsSectionIsShown = false
                
                if expectedBluetoothPeripheralType.canWebOOP() {
                    // mark web oop settings section as shown
                    webOOPSettingsSectionIsShown = true
                    numberOfGeneralSections += 1
                    
                    if expectedBluetoothPeripheralType.canUseNonFixedSlope() {
                        // mark non fixed slope settings section as shown
                        nonFixedSettingsSectionIsShown = true
                        numberOfGeneralSections += 1
                    }
                }
                
                return numberOfGeneralSections
            }
        }
        
        // bluetoothPeripheral not yet known, only show first section with name alias, ...
        return numberOfGeneralSections
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
    
    override func viewWillAppear(_ animated: Bool) {
        // check if the observers have already been added. If not, then add them
        if !didAddObservers {
            // Listen for changes in the nfcScanFailed setting when it is changed by the delegate after a failed NFC scan
            UserDefaults.standard.addObserver(self, forKeyPath: UserDefaults.Key.nfcScanFailed.rawValue, options: .new, context: nil)
            
            // Listen for changes in the nfcScanSuccessful setting when it is changed by the delegate after a successful NFC scan
            UserDefaults.standard.addObserver(self, forKeyPath: UserDefaults.Key.nfcScanSuccessful.rawValue, options: .new, context: nil)
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        // we need to remove all observers from the view controller before removing it from the navigation stack
        // otherwise the app crashes when one of the userdefault values changes and the observer tries to
        // update the UI (which isn't available any more)
        
        // as viewWillAppear could get called (or maybe not) several times, we need to check that the observers
        // have really been registered before we try and remove them
        if didAddObservers {
            // Listen for changes in the nfcScanFailed setting when it is changed by the delegate after a failed NFC scan
            UserDefaults.standard.removeObserver(self, forKeyPath: UserDefaults.Key.nfcScanFailed.rawValue)
            
            // Listen for changes in the nfcScanSuccessful setting when it is changed by the delegate after a successful NFC scan
            UserDefaults.standard.removeObserver(self, forKeyPath: UserDefaults.Key.nfcScanSuccessful.rawValue)
        }
    }
    
    override func willMove(toParent parent: UIViewController?) {
        
        super.willMove(toParent: parent)
        
        // willMove is called when BluetoothPeripheralViewController is added and when BluetoothPeripheralViewController is removed.
        // It has no added value in the adding phase
        // It doe shave an added value when being removed. bluetoothPeripheralViewModel must be assigned to nil. bluetoothPeripheralViewModel deinit will be called which should reassign the delegate to BluetoothPeripheralManager. Also here the bluetoothtransmitter delegate will be reassigned to BluetoothPeripheralManager
        // and finally stopScanningForNewDevice will be called, for the case where scanning would still be ongoing
        
        // save any changes that are made
        coreDataManager?.saveChanges()
        
        // set bluetoothPeripheralViewModel to nil. The bluetoothPeripheralViewModel's deinit will be called, which will set the delegate in the model to BluetoothPeripheralManager
        
        bluetoothPeripheralViewModel = nil
        
        // reassign delegate in BluetoothTransmitter to bluetoothPeripheralManager
        reassignBluetoothTransmitterDelegateToBluetoothPeripheralManager()
        
        // just in case scanning for a new device is still ongoing, call stopscanning
        bluetoothPeripheralManager?.stopScanningForNewDevice()
        
    }
    
    // MARK: - View Methods
    
    private func setupView() {
        
        // set label of connect button, according to current status
        _ = BluetoothPeripheralViewController.setConnectButtonLabelTextAndGetStatusDetailedText(bluetoothPeripheral: bluetoothPeripheral, isScanning: isScanning, nfcScanNeeded: nfcScanNeeded, nfcScanSuccessful: nfcScanSuccessful, connectButtonOutlet: connectButtonOutlet, expectedBluetoothPeripheralType: expectedBluetoothPeripheralType, transmitterId: transmitterIdTempValue, bluetoothPeripheralManager: bluetoothPeripheralManager as! BluetoothPeripheralManager)
        
        if bluetoothPeripheral == nil {
            
            // should be disabled, as there's nothing to delete yet
            trashButtonOutlet.disable()
            
            // if transmitterid is needed then connect button should be disabled, until transmitter id is set
            if let expectedBluetoothPeripheralType = expectedBluetoothPeripheralType, expectedBluetoothPeripheralType.needsTransmitterId() {
                connectButtonOutlet.disable()
            }
            
            // unwrap expectedBluetoothPeripheralType
            guard let expectedBluetoothPeripheralType = expectedBluetoothPeripheralType else {return}
            
            // if transmitterId needed, request for it now and set button text
            if expectedBluetoothPeripheralType.needsTransmitterId() {
                
                requestTransmitterId()
                
            }
            
        }
        
        // set title
        title = bluetoothPeripheralViewModel?.screenTitle()
        
        setupTableView()
        
    }
    
    // MARK: - private functions
    
    /// setup datasource, delegate, seperatorInset
    private func setupTableView() {
        if let tableView = self.tableView {
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
        
        // initiailize previousScanningResult to nil
        previousScanningResult = nil
        
        bluetoothPeripheralManager.startScanningForNewDevice(type: type, transmitterId: transmitterIdTempValue, bluetoothTransmitterDelegate: self, callBackForScanningResult: handleScanningResult(startScanningResult:), callback: { (bluetoothPeripheral) in
            
            trace("in BluetoothPeripheralViewController, callback. bluetoothPeripheral address = %{public}@, name = %{public}@", log: self.log, category: ConstantsLog.categoryBluetoothPeripheralViewController, type: .info, bluetoothPeripheral.blePeripheral.address, bluetoothPeripheral.blePeripheral.name)
            
            // remove info alert screen which may still be there
            self.dismissInfoAlertWhenScanningStarts()
            
            // set isScanning true
            self.isScanning = false
            
            // enable screen lock
            UIApplication.shared.isIdleTimerDisabled = false
            
            // assign internal bluetoothPeripheral to new bluetoothPeripheral
            self.bluetoothPeripheral = bluetoothPeripheral
            
            // assign transmitterid, if it's a new one then the value is nil
            bluetoothPeripheral.blePeripheral.transmitterId = self.transmitterIdTempValue
            
            // recall configure in bluetoothPeripheralViewModel
            self.bluetoothPeripheralViewModel?.configure(bluetoothPeripheral: self.bluetoothPeripheral, bluetoothPeripheralManager: bluetoothPeripheralManager, tableView: self.tableView,  bluetoothPeripheralViewController: self)
            
            // enable the connect button
            self.connectButtonOutlet.enable()
            
            // set right text for connect button
            _ = BluetoothPeripheralViewController.setConnectButtonLabelTextAndGetStatusDetailedText(bluetoothPeripheral: bluetoothPeripheral, isScanning: self.isScanning, nfcScanNeeded: self.nfcScanNeeded, nfcScanSuccessful: self.nfcScanSuccessful, connectButtonOutlet: self.connectButtonOutlet, expectedBluetoothPeripheralType: self.expectedBluetoothPeripheralType, transmitterId: self.transmitterIdTempValue, bluetoothPeripheralManager: bluetoothPeripheralManager as! BluetoothPeripheralManager)
            
            // enable the trashbutton
            self.trashButtonOutlet.enable()
            
            // set self as delegate in the bluetoothTransmitter
            if let bluetoothTransmitter = bluetoothPeripheralManager.getBluetoothTransmitter(for: bluetoothPeripheral, createANewOneIfNecesssary: false) {
                
                bluetoothTransmitter.bluetoothTransmitterDelegate = self
                
                // tracing added to analyse issue 221
                if let connectionStatus = bluetoothTransmitter.getConnectionStatus() {
                    
                    trace("in BluetoothPeripheralViewController, callback. bluetoothPeripheral connection status = %{public}@", log: self.log, category: ConstantsLog.categoryBluetoothPeripheralViewController, type: .info, connectionStatus.description())
                    
                } else {
                    
                    trace("in BluetoothPeripheralViewController, callback. bluetoothPeripheral connection status is nil", log: self.log, category: ConstantsLog.categoryBluetoothPeripheralViewController, type: .info)
                    
                }
                
            } else {
                
                trace("in BluetoothPeripheralViewController, callback. no transmitter found for bluetoothperipheral", log: self.log, category: ConstantsLog.categoryBluetoothPeripheralViewController, type: .info)
                
            }
            
            // reload the full screen , all rows in all sections in the tableView
            self.tableView.reloadData()
            
            // dismiss alert screen that shows info after cliking start scanning button
            if let infoAlertWhenScanningStarts = self.infoAlertWhenScanningStarts {
                infoAlertWhenScanningStarts.dismiss(animated: true, completion: nil)
                self.infoAlertWhenScanningStarts = nil
            }
            
        })
        
        
    }
    
    private func handleScanningResult(startScanningResult: BluetoothTransmitter.startScanningResult) {
        
        // if we already processed the same scanning result, then return
        guard startScanningResult != previousScanningResult else {return}
        
        previousScanningResult = startScanningResult
        
        // dismiss info alert screen, in case it's still there
        dismissInfoAlertWhenScanningStarts()
        
        // check startScanningResult
        switch startScanningResult {
            
        case .success :
            
            // unknown is the initial status returned, although it will actually start scanning
            
            // set isScanning true
            isScanning = true
            
            // disable the connect button
            self.connectButtonOutlet.disable()
            
            // app should be scanning now, update of cell is needed
            tableView.reloadRows(at: [IndexPath(row: Setting.connectionStatus.rawValue, section: 0)], with: .none)
            
            // disable screen lock
            UIApplication.shared.isIdleTimerDisabled = true
            
            // let's first check to make sure we're not using the "NFC scan required first" workflow and can connect straight away via BLE to the transmitter
            if let expectedBluetoothPeripheralType = expectedBluetoothPeripheralType, !expectedBluetoothPeripheralType.needsNFCScanToConnect() {
                
                // show info that user should keep the app in the foreground
                self.infoAlertWhenScanningStarts = UIAlertController(title: Texts_HomeView.info, message: Texts_HomeView.startScanningInfo, actionHandler: nil)
                self.present(self.infoAlertWhenScanningStarts!, animated:true)
                
            }
            
        case .alreadyScanning, .alreadyConnected, .connecting :
            
            trace("in handleScanningResult, scanning not started. Scanning result = %{public}@", log: log, category: ConstantsLog.categoryBluetoothPeripheralViewController, type: .error, startScanningResult.description())
            // no further processing, should normally not happen,
            
            // set isScanning false, although it should already be false
            isScanning = false
            
        case .poweredOff:
            
            trace("in handleScanningResult, scanning not started. Bluetooth is not on", log: log, category: ConstantsLog.categoryBluetoothPeripheralViewController, type: .error)
            
            // show info that user should switch on bluetooth
            self.infoAlertWhenScanningStarts = UIAlertController(title: Texts_Common.warning, message: Texts_HomeView.bluetoothIsNotOn, actionHandler: nil)
            self.present(self.infoAlertWhenScanningStarts!, animated:true)
            
        case .other(let reason):
            
            trace("in handleScanningResult, scanning not started. Scanning result = %{public}@", log: log, category: ConstantsLog.categoryBluetoothPeripheralViewController, type: .error, reason)
            // no further processing, should normally not happen,
            
        case .unauthorized:
            
            trace("in handleScanningResult, scanning not started. Scanning result = unauthorized", log: log, category: ConstantsLog.categoryBluetoothPeripheralViewController, type: .error)
            
            // show info that user should switch on bluetooth
            self.infoAlertWhenScanningStarts = UIAlertController(title: Texts_Common.warning, message: Texts_HomeView.bluetoothIsNotAuthorized, actionHandler: nil)
            self.present(self.infoAlertWhenScanningStarts!, animated:true)
            
        case .unknown:
            
            trace("in handleScanningResult, scanning not started. Scanning result = unknown - this is always occuring when a BluetoothTransmitter starts scanning the first time. You should see now a new call to handleScanningResult", log: log, category: ConstantsLog.categoryBluetoothPeripheralViewController, type: .info)
            
        case .nfcScanNeeded:
            
            trace("in handleScanningResult, an NFC scan is required before BLE scanning will be started. Scanning result = nfcScanNeeded", log: log, category: ConstantsLog.categoryBluetoothPeripheralViewController, type: .error)
            
        }
        
    }
    
    /// use clicked trash button, need to delete the bluetoothperipheral
    private func trashButtonClicked() {
        
        // let's first check if bluetoothPeripheral exists, otherwise there's nothing to trash, normally this shouldn't happen because trashbutton should be disabled if there's no bluetoothPeripheral
        guard let bluetoothPeripheral = bluetoothPeripheral else {return}
        
        // unwrap bluetoothPeripheralManager
        guard let bluetoothPeripheralManager = bluetoothPeripheralManager else {return}
        
        // textToAdd is either the name, or 'alias' + the alias, depending if alias has a value
        var textToAdd = bluetoothPeripheral.blePeripheral.name
        if let alias = bluetoothPeripheral.blePeripheral.alias {
            textToAdd = Texts_BluetoothPeripheralView.bluetoothPeripheralAlias + " " + alias
        }
        
        // first ask user if ok to delete and if yes delete
        let alert = UIAlertController(title: Texts_Common.delete , message: Texts_BluetoothPeripheralView.confirmDeletionBluetoothPeripheral + " " + textToAdd + "?", actionHandler: {
            
            // in case it's a Libre2 CGM, libre1DerivedAlgorithmParameters has a non nil value. When deleting the transmitter, by setting to nil, this will ensure that user first need to do a successful NFC scan.
            if let bluetoothTransmitter = bluetoothPeripheralManager.getBluetoothTransmitter(for: bluetoothPeripheral, createANewOneIfNecesssary: false), bluetoothTransmitter is CGMTransmitter {
                
                UserDefaults.standard.libre1DerivedAlgorithmParameters = nil
                
                // we'll also take advantage to stop the active sensor session for this type of CGM. This will cause the sensor info to be disabled until another sensor session is started with a max sensor age value
                UserDefaults.standard.stopActiveSensor = true
                
            }
            
            // delete
            bluetoothPeripheralManager.deleteBluetoothPeripheral(bluetoothPeripheral: bluetoothPeripheral)
            
            // call configure in the model, as we have a new transmitter here
            self.bluetoothPeripheralViewModel?.configure(bluetoothPeripheral: bluetoothPeripheral, bluetoothPeripheralManager: bluetoothPeripheralManager, tableView: self.tableView, bluetoothPeripheralViewController: self)
            
            self.bluetoothPeripheral = nil
            
            // close the viewcontroller
            
            self.tableView.removeFromSuperview()
            
            self.navigationController?.popViewController(animated: true)
            self.dismiss(animated: true, completion: nil)
            
        }, cancelHandler: nil)
        
        self.present(alert, animated:true)
        
    }
    
    /// user clicked connect button
    private func connectButtonHandler() {
        
        // unwrap bluetoothPeripheralManager
        guard let bluetoothPeripheralManager = bluetoothPeripheralManager else {return}
        
        // unwrap expectedBluetoothPeripheralType
        guard let expectedBluetoothPeripheralType = expectedBluetoothPeripheralType else {return}
        
        checkIfNFCScanIsNeeded()
        
        // let's first check if bluetoothPeripheral exists
        if let bluetoothPeripheral = bluetoothPeripheral {
            
            // if shouldconnect = true then set setshouldconnect to false, this will also result in disconnecting
            if bluetoothPeripheral.blePeripheral.shouldconnect {
                
                // disconnect
                setShouldConnectToFalse(for: bluetoothPeripheral, askUser: true)
                
                // call configure in the model, as we have a new transmitter here
                bluetoothPeripheralViewModel?.configure(bluetoothPeripheral: bluetoothPeripheral, bluetoothPeripheralManager: bluetoothPeripheralManager, tableView: tableView, bluetoothPeripheralViewController: self)
                
            } else {
                
                // check if it's a CGM being activated and if so that there's no other cgm which has shouldconnect = true
                if expectedBluetoothPeripheralType.category() == .CGM, BluetoothPeripheralsViewController.self.otherCGMTransmitterHasShouldConnectTrue(bluetoothPeripheralManager: self.bluetoothPeripheralManager, uiViewController: self) {
                    
                    return
                    
                }
                
                // check if it's a CGM being activated and if so that app is in master mode
                if expectedBluetoothPeripheralType.category() == .CGM, !UserDefaults.standard.isMaster {
                    
                    self.present(UIAlertController(title: Texts_Common.warning, message: Texts_BluetoothPeripheralView.cannotActiveCGMInFollowerMode, actionHandler: nil), animated: true, completion: nil)
                    
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
            
        } else {
            
            // there's no bluetoothperipheral yet, so this is the case where viewcontroller is opened to scan for a new peripheral
            // if it's a transmitter type that needs a transmitter id, and if there's no transmitterid yet, then ask transmitter id
            // else start scanning
            if expectedBluetoothPeripheralType.needsTransmitterId() && transmitterIdTempValue == nil {
                
                requestTransmitterId()
                
            } else {
                
                scanForBluetoothPeripheral(type: expectedBluetoothPeripheralType)
                
            }
            
            
        }
        
        // will change text of the button
        _ = BluetoothPeripheralViewController.setConnectButtonLabelTextAndGetStatusDetailedText(bluetoothPeripheral: bluetoothPeripheral, isScanning: isScanning, nfcScanNeeded: nfcScanNeeded, nfcScanSuccessful: nfcScanSuccessful, connectButtonOutlet: connectButtonOutlet, expectedBluetoothPeripheralType: expectedBluetoothPeripheralType, transmitterId: transmitterIdTempValue, bluetoothPeripheralManager: bluetoothPeripheralManager as! BluetoothPeripheralManager)
        
        // call configure in the model, as we have a new transmitter here
        bluetoothPeripheralViewModel?.configure(bluetoothPeripheral: bluetoothPeripheral, bluetoothPeripheralManager: bluetoothPeripheralManager, tableView: tableView, bluetoothPeripheralViewController: self)
        
    }
    
    /// checks if bluetoothPeripheral is not nil, etc.
    /// - returns: true if bluetoothperipheral exists and is connected, false in all other cases
    private static func bluetoothPeripheralIsConnected(bluetoothPeripheral: BluetoothPeripheral, bluetoothPeripheralManager: BluetoothPeripheralManager) -> Bool {
        
        guard let connectionStatus = bluetoothPeripheralManager.getBluetoothTransmitter(for: bluetoothPeripheral, createANewOneIfNecesssary: false)?.getConnectionStatus() else {return false}
        
        return connectionStatus == CBPeripheralState.connected
        
    }
    
    /// resets the bluetoothTransmitterDelegate to bluetoothPeripheralManager
    private func reassignBluetoothTransmitterDelegateToBluetoothPeripheralManager() {
        
        guard let bluetoothPeripheralManager = bluetoothPeripheralManager else {return}
        
        if let bluetoothPeripheral = bluetoothPeripheral, let bluetoothTransmitter = bluetoothPeripheralManager.getBluetoothTransmitter(for: bluetoothPeripheral, createANewOneIfNecesssary: false) {
            
            // reassign delegate, actually as we're closing BluetoothPeripheralViewController, where BluetoothPeripheralsViewController
            bluetoothTransmitter.bluetoothTransmitterDelegate = bluetoothPeripheralManager
            
        }
        
    }
    
    private func requestTransmitterId() {
        
        // unwrap bluetoothPeripheralManager
        guard let bluetoothPeripheralManager = bluetoothPeripheralManager else {return}
        
        // set default text strings. These will be overwritten if needed.
        var transmitterIdTitleText = Texts_SettingsView.labelTransmitterId
        var transmitterIdMessageText = Texts_SettingsView.labelGiveTransmitterId
        var placeHolder = "00000"
        
        // if using a special case (like a heartbeat), adapt the strings to include relevant instructions and information
        switch expectedBluetoothPeripheralType {
        case .Libre3HeartBeatType:
            transmitterIdTitleText = Texts_SettingsView.labelBluetoothDeviceName
            transmitterIdMessageText = Texts_SettingsView.heartbeatLibreMessage
            placeHolder = "000000000000"
        case .DexcomG7HeartBeatType:
            transmitterIdTitleText = Texts_SettingsView.labelBluetoothDeviceName
            transmitterIdMessageText = Texts_SettingsView.heartbeatG7Message
            placeHolder = "DXCM00"
        default:
            break
        }
        
        SettingsViewUtilities.runSelectedRowAction(selectedRowAction: SettingsSelectedRowAction.askText(title: transmitterIdTitleText, message: transmitterIdMessageText, keyboardType: UIKeyboardType.alphabet, text: transmitterIdTempValue, placeHolder: placeHolder, actionTitle: nil, cancelTitle: nil, actionHandler: {(transmitterId:String) in
            
            // convert to uppercase
            let transmitterIdUpper = transmitterId.uppercased().toNilIfLength0()
            
            self.transmitterIdTempValue = transmitterIdUpper
            
            // reload the specific row in the table
            self.tableView.reloadRows(at: [IndexPath(row: Setting.transmitterId.rawValue, section: 0)], with: .none)
            
            // as transmitter id has been set (or set to nil), connect button label text must change
            _ = BluetoothPeripheralViewController.setConnectButtonLabelTextAndGetStatusDetailedText(bluetoothPeripheral: self.bluetoothPeripheral, isScanning: self.isScanning, nfcScanNeeded: self.nfcScanNeeded, nfcScanSuccessful: self.nfcScanSuccessful, connectButtonOutlet: self.connectButtonOutlet, expectedBluetoothPeripheralType: self.expectedBluetoothPeripheralType, transmitterId: transmitterIdUpper, bluetoothPeripheralManager: bluetoothPeripheralManager as! BluetoothPeripheralManager)
            
        }, cancelHandler: nil, inputValidator: { (transmitterId) in
            
            return self.expectedBluetoothPeripheralType?.validateTransmitterId(transmitterId: transmitterId)
            
        }), forRowWithIndex: Setting.transmitterId.rawValue, forSectionWithIndex: generalSettingSectionNumber, withSettingsViewModel: nil, tableView: tableView, forUIViewController: self)
        
    }
    
    /// dismiss alert screen that shows info after clicking start scanning button (also used for nfc scan success/fail alerts)
    private func dismissInfoAlertWhenScanningStarts() {
        
        if let infoAlertWhenScanningStarts = infoAlertWhenScanningStarts {
            
            infoAlertWhenScanningStarts.dismiss(animated: true, completion: nil)
            self.infoAlertWhenScanningStarts = nil
            
        }
        
    }
    
    /// used to check if the current BLE peripheral type requires an NFC scan before BLE scanning
    /// - parameters:
    ///     - none
    /// - returns:
    ///     - none
    private func checkIfNFCScanIsNeeded() {
        
        // initialise both to false
        nfcScanNeeded = false
        nfcScanSuccessful = false
        
        // if a transmitter already exists and the type needs NFC, set nfcScanNeeded to true
        if let bluetoothPeripheral = bluetoothPeripheral, bluetoothPeripheral.bluetoothPeripheralType().needsNFCScanToConnect() {
            
            // set nfcScanNeeded to true if the transmitter needs to provoke an NFC scan
            nfcScanNeeded = true
            
        }
        
        // if the expected new transmitter type needs NFC, set nfcScanNeeded to true
        if let expectedBluetoothPeripheralType = expectedBluetoothPeripheralType, expectedBluetoothPeripheralType.needsNFCScanToConnect() {
            
            // set nfcScanNeeded to true if the transmitter needs to provoke an NFC scan
            nfcScanNeeded = true
            
        }
        
        // set the user defaults to false as
        UserDefaults.standard.nfcScanSuccessful = false
        UserDefaults.standard.nfcScanFailed = false
        
        
    }
    
    
    // MARK: - observe functions
    
    override public func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        guard let keyPath = keyPath,
              let keyPathEnum = UserDefaults.Key(rawValue: keyPath)
        else { return }
        
        switch keyPathEnum {
        case UserDefaults.Key.nfcScanFailed:
            
            // if failedToScan wasn't change to true then no further processing
            guard UserDefaults.standard.nfcScanFailed else {return}
            
            // we know that the scan failed so set nfcScanSuccessful to false and also set nfcScanNeeded to false as it the scan process has finished so a scan isn't actually needed any more
            self.nfcScanSuccessful = false
            self.nfcScanNeeded = false
            
            trace("in observeValue, nfcScanFailed has been set to true so will disconnect and offer to scan again", log: log, category: ConstantsLog.categoryBluetoothPeripheralViewController, type: .error)
            
            // let's first check if bluetoothPeripheral exists and then call the nfcScanFailed function accordingly
            if let bluetoothPeripheral = bluetoothPeripheral {
                
                nfcScanFailed(for: bluetoothPeripheral)
                
            } else {
                
                nfcScanFailed(for: nil)
                
            }
            
            
        case UserDefaults.Key.nfcScanSuccessful:
            
            // if scanSuccessful wasn't change to true then no further processing
            guard UserDefaults.standard.nfcScanSuccessful else {return}
            
            // we know that the scan was successful so set nfcScanSuccessful to true and also set nfcScanNeeded to false as it the scan process has finished so a scan isn't actually needed any more
            self.nfcScanSuccessful = true
            self.nfcScanNeeded = false
            
            trace("in observeValue, nfcScanSuccessful has been set to true so will inform the user and try and update the connection status to Scanning", log: log, category: ConstantsLog.categoryBluetoothPeripheralViewController, type: .error)
            
            // create uialertcontroller to inform the user that the scan is successful and to just wait patiently for the sensor to connect via bluetooth
            let nfcScanSuccessfulAlert = UIAlertController(title: TextsLibreNFC.nfcScanSuccessfulTitle , message: TextsLibreNFC.nfcScanSuccessfulMessage, actionHandler: nil)
            
            self.present(nfcScanSuccessfulAlert, animated:true)
            
            guard let bluetoothPeripheralManager = self.bluetoothPeripheralManager else {return}
            
            // connect button label text needs to change because we should now be scanning
            _ = BluetoothPeripheralViewController.setConnectButtonLabelTextAndGetStatusDetailedText(bluetoothPeripheral: bluetoothPeripheral, isScanning: self.isScanning, nfcScanNeeded: self.nfcScanNeeded, nfcScanSuccessful: self.nfcScanSuccessful, connectButtonOutlet: self.connectButtonOutlet, expectedBluetoothPeripheralType: self.expectedBluetoothPeripheralType, transmitterId: self.transmitterIdTempValue, bluetoothPeripheralManager: bluetoothPeripheralManager as! BluetoothPeripheralManager)
            
            // TODO: need to fix crash: This reload can sometimes cause a crash under certain circumstances
            self.tableView.reloadRows(at: [IndexPath(row: Setting.connectionStatus.rawValue, section: 0)], with: .none)
            
        default:
            break
        }
        
    }
    
}


// MARK: - extension UITableViewDataSource, UITableViewDelegate

extension BluetoothPeripheralViewController: UITableViewDataSource, UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        
        if let view = view as? UITableViewHeaderFooterView {
            
            view.textLabel?.textColor = ConstantsUI.tableViewHeaderTextColor
            
        }
        
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        
        // there is one general section with settings applicable for all peripheral types, one or more specific section(s) with settings specific to type of bluetooth peripheral
        
        if bluetoothPeripheral == nil {
            
            // no peripheral known yet, only the first, bluetooth transmitter related settings are shown
            return 1
            
        } else {
            
            // number of sections = number of general sections + number of sections specific for the type of bluetoothPeripheral
            
            var numberOfSections = numberOfGeneralSections()
            
            if let bluetoothPeripheralViewModel = bluetoothPeripheralViewModel {
                
                numberOfSections = numberOfSections + bluetoothPeripheralViewModel.numberOfSections()
                
            }
            
            return numberOfSections
            
        }
        
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        
        // expectedBluetoothPeripheralType should not be nil here, unwrap it
        guard let expectedBluetoothPeripheralType = expectedBluetoothPeripheralType else {
            fatalError("in tableView numberOfRowsInSection, expectedBluetoothPeripheralType is nil")
        }
        
        if section == 0 {
            
            // this is the general section, applicable to all types of transmitters
            
            // number of rows will be calculated, starting with all rows
            var numberOfRows = Setting.allCases.count
            
            // if bluetooth transmitter does not need transmitterId then don't show that row
            if !expectedBluetoothPeripheralType.needsTransmitterId() {
                numberOfRows = numberOfRows - 1
            }
            
            return numberOfRows
            
        } else if numberOfGeneralSections() > 1 {
            
            // the oop web and non-fixed slope sections are maybe present
            
            if section == 1 {
                
                // if the bluetoothperipheral type supports non fixed slope or oopweb then this section is one of them, number of rows is 1
                if expectedBluetoothPeripheralType.canUseNonFixedSlope() || expectedBluetoothPeripheralType.canWebOOP() {
                    
                    return 1;
                    
                } else {
                    
                    // so it's section 1 (ie the second section), and both canUseNonFixedSlope and canWebOOP are false, means it's none of those two sections, so it's bluetoothperipheral type specific section
                    // don't return any, will jump to bluetoothPeripheralViewModel.numberOfSettings(inSection: section)
                    
                }
                
            } else if section == 2  {
                
                // if the bluetoothperipheral type supports oopweb and canUseNonFixedSlope, then this is the oopwebsection
                if expectedBluetoothPeripheralType.canWebOOP() &&  expectedBluetoothPeripheralType.canUseNonFixedSlope() {
                    
                    /// there's only one row in that section
                    return 1
                    
                }  else {
                    
                    // don't return any, will jump to bluetoothPeripheralViewModel.numberOfSettings(inSection: section)
                    
                }
                
            }
            
        }
        
        // it's not section 0 and it's not section 2 && weboop supported and it's not section 1 && nonfixed supported
        
        // this is the section with the transmitter specific settings
        // unwrap bluetoothPeripheralViewModel
        if let bluetoothPeripheralViewModel = bluetoothPeripheralViewModel {
            return bluetoothPeripheralViewModel.numberOfSettings(inSection: section)
        } else {
            fatalError("in tableView numberOfRowsInSection, bluetoothPeripheralViewModel is nil")
        }
        
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        guard let cell = tableView.dequeueReusableCell(withIdentifier: SettingsTableViewCell.reuseIdentifier, for: indexPath) as? SettingsTableViewCell else { fatalError("BluetoothPeripheralViewController cellforrowat, Unexpected Table View Cell ") }
        
        // unwrap a few variables
        guard let bluetoothPeripheralManager = bluetoothPeripheralManager, let expectedBluetoothPeripheralType = expectedBluetoothPeripheralType else {return cell}
        
        // check if it's a Setting defined here in BluetoothPeripheralViewController, or a setting specific to the type of BluetoothPeripheral
        if indexPath.section >= numberOfGeneralSections() {
            
            // it's a setting not defined here but in a BluetoothPeripheralViewModel
            if let bluetoothPeripheral = bluetoothPeripheral, let bluetoothPeripheralViewModel = bluetoothPeripheralViewModel {
                
                bluetoothPeripheralViewModel.update(cell: cell, forRow: indexPath.row, forSection: indexPath.section, for: bluetoothPeripheral)
                
            }
            
            return cell
            
        }
        
        // default value for accessoryView is nil
        cell.accessoryView = nil
        
        // create disclosureIndicator in color ConstantsUI.disclosureIndicatorColor
        // will be used whenever accessoryType is to be set to disclosureIndicator
        let  disclosureAccessoryView = DTCustomColoredAccessory(color: ConstantsUI.disclosureIndicatorColor)
        
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
                
            case .connectionStatus:
                
                cell.textLabel?.text = Texts_BluetoothPeripheralView.status
                cell.detailTextLabel?.text = BluetoothPeripheralViewController.setConnectButtonLabelTextAndGetStatusDetailedText(bluetoothPeripheral: bluetoothPeripheral, isScanning: isScanning, nfcScanNeeded: nfcScanNeeded, nfcScanSuccessful: nfcScanSuccessful, connectButtonOutlet: connectButtonOutlet, expectedBluetoothPeripheralType: expectedBluetoothPeripheralType, transmitterId: transmitterIdTempValue, bluetoothPeripheralManager: bluetoothPeripheralManager as! BluetoothPeripheralManager)
                cell.accessoryType = .none
                
            case .alias:
                
                cell.textLabel?.text = Texts_BluetoothPeripheralView.bluetoothPeripheralAlias
                cell.detailTextLabel?.text = bluetoothPeripheral?.blePeripheral.alias
                if bluetoothPeripheral == nil {
                    cell.accessoryType = .none
                } else {
                    cell.accessoryType = .disclosureIndicator
                    cell.accessoryView =  disclosureAccessoryView
                }
                
            case .transmitterId:
                
                cell.textLabel?.text = Texts_SettingsView.labelTransmitterId
                cell.detailTextLabel?.text = transmitterIdTempValue
                
                // if transmitterId already has a value, then it can't be changed anymore. To change it, user must delete the transmitter and recreate one.
                cell.accessoryType = transmitterIdTempValue == nil ? .disclosureIndicator : .none
                if (transmitterIdTempValue == nil) {
                    cell.accessoryView =  disclosureAccessoryView
                }
                
            case .connectOrDisconnectTimeStamp:
                
                if let bluetoothPeripheral = bluetoothPeripheral, let lastConnectionStatusChangeTimeStamp = bluetoothPeripheral.blePeripheral.lastConnectionStatusChangeTimeStamp {
                    
                    if BluetoothPeripheralViewController.bluetoothPeripheralIsConnected(bluetoothPeripheral: bluetoothPeripheral, bluetoothPeripheralManager: bluetoothPeripheralManager as! BluetoothPeripheralManager) {
                        
                        cell.textLabel?.text = Texts_BluetoothPeripheralView.connectedAt
                        
                    } else {
                        
                        cell.textLabel?.text = Texts_BluetoothPeripheralView.disConnectedAt
                        
                    }
                    
                    cell.detailTextLabel?.text = lastConnectionStatusChangeTimeStamp.toStringInUserLocale(timeStyle: .short, dateStyle: .short)
                    
                } else {
                    cell.textLabel?.text = Texts_BluetoothPeripheralView.connectedAt
                    cell.detailTextLabel?.text = ""
                }
                
                cell.accessoryType = .none
                
            }
            
        } else if indexPath.section == 1 && webOOPSettingsSectionIsShown {
            
            // web oop settings
            
            guard let setting = WebOOPSettings(rawValue: indexPath.row) else { fatalError("BluetoothPeripheralViewController cellForRowAt, Unexpected setting, row = " + indexPath.row.description) }
            
            // configure the cell depending on setting
            switch setting {
                
            case .webOOPEnabled:
                
                // get current value of webOOPEnabled, default false
                var currentWebOOPEnabledValue = false
                
                if let bluetoothPeripheral = bluetoothPeripheral {
                    currentWebOOPEnabledValue = bluetoothPeripheral.blePeripheral.webOOPEnabled
                }
                
                cell.textLabel?.text = Texts_SettingsView.labelAlgorithmType
                cell.detailTextLabel?.text = currentWebOOPEnabledValue ? Texts_BluetoothPeripheralView.nativeAlgorithm : Texts_BluetoothPeripheralView.xDripAlgorithm
                cell.accessoryType = .disclosureIndicator
                cell.accessoryView =  disclosureAccessoryView
                
            }
            
        } else if (indexPath.section == 1 && nonFixedSettingsSectionIsShown) ||  (indexPath.section == 2 && nonFixedSettingsSectionIsShown && webOOPSettingsSectionIsShown) {
            
            // non fixed calibration slope settings
            
            guard let setting = NonFixedCalibrationSlopesSettings(rawValue: indexPath.row) else { fatalError("BluetoothPeripheralViewController cellForRowAt, Unexpected setting, row = " + indexPath.row.description) }
            
            switch setting {
                
            case .nonFixedSlopeEnabled:
                
                if let bluetoothPeripheral = self.bluetoothPeripheral, bluetoothPeripheral.blePeripheral.webOOPEnabled == false {
                    cell.textLabel?.text = Texts_SettingsView.labelCalibrationType
                    cell.detailTextLabel?.text = bluetoothPeripheral.blePeripheral.nonFixedSlopeEnabled ? Texts_Calibrations.multiPointCalibration : Texts_Calibrations.singlePointCalibration
                    cell.accessoryType = .disclosureIndicator
                    cell.accessoryView =  disclosureAccessoryView
                } else {
                    cell.textLabel?.text = Texts_SettingsView.labelCalibrationType
                    cell.detailTextLabel?.text = Texts_Common.notRequired
                    cell.accessoryView = .none
                    cell.accessoryView?.isUserInteractionEnabled = false
                }
            }
            
        } else if indexPath.section == 2 {
            // there should not be any other case
        }
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        tableView.deselectRow(at: indexPath, animated: true)
        
        // unwrap a few needed variables
        guard let bluetoothPeripheralManager = bluetoothPeripheralManager, let bluetoothPeripheralViewModel = bluetoothPeripheralViewModel else {return}
        
        // check if it's one of the common settings or one of the peripheral type specific settings
        if indexPath.section >= numberOfGeneralSections() {
            
            // it's a setting not defined here but in a BluetoothPeripheralViewModel
            // bluetoothPeripheralViewModel should not be nil here, otherwise user wouldn't be able to click a row which is higher than maximum
            if let bluetoothPeripheral = bluetoothPeripheral {
                
                // parameter withSettingsViewModel is set to nil here, is used in the general settings page, where a view model represents a specific section, not used here
                SettingsViewUtilities.runSelectedRowAction(selectedRowAction: bluetoothPeripheralViewModel.userDidSelectRow(withSettingRawValue: indexPath.row, forSection: indexPath.section, for: bluetoothPeripheral, bluetoothPeripheralManager: bluetoothPeripheralManager), forRowWithIndex: indexPath.row, forSectionWithIndex: indexPath.section, withSettingsViewModel: nil, tableView: tableView, forUIViewController: self)
                
            }
            
            return
            
        }
        
        // it's a Setting defined here in BluetoothPeripheralViewController
        // is it a bluetooth setting or web oop setting  or non-fixed calibration slopes setting ?
        
        if indexPath.section == 0 {
            
            guard let setting = Setting(rawValue: indexPath.row) else { fatalError("BluetoothPeripheralViewController didSelectRowAt, Unexpected setting") }
            
            switch setting {
                
            case .name, .connectionStatus:
                break
                
            case .alias:
                
                // clicked cell to change alias - need to ask for new name, and verify if there's already another BluetoothPerpiheral existing with the same name
                
                // first off al check that BluetoothPeripheral already exists, otherwise makes no sense to change the name
                guard let bluetoothPeripheral = bluetoothPeripheral else {return}
                
                let alert = UIAlertController(title: Texts_BluetoothPeripheralView.bluetoothPeripheralAlias, message: Texts_BluetoothPeripheralView.selectAliasText, keyboardType: .default, text: bluetoothPeripheral.blePeripheral.alias, placeHolder: nil, actionTitle: nil, cancelTitle: nil, actionHandler: { (text:String) in
                    
                    let newalias = text.toNilIfLength0()
                    
                    if newalias != nil {
                        
                        // need to check if there's already another peripheral with the same name
                        for bluetoothPeripheral in bluetoothPeripheralManager.getBluetoothPeripherals() {
                            
                            // not checking address of bluetoothPeripheral, because obviously that one could have the same alias
                            if bluetoothPeripheral.blePeripheral.address != bluetoothPeripheral.blePeripheral.address {
                                if bluetoothPeripheral.blePeripheral.alias == text {
                                    
                                    // bluetoothperipheral userdefined name already exists
                                    let alreadyExistsAlert = UIAlertController(title: Texts_Common.warning, message: Texts_BluetoothPeripheralView.aliasAlreadyExists, actionHandler: nil)
                                    
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
                
            case .connectOrDisconnectTimeStamp:
                break
                
            case .transmitterId:
                
                // if transmitterId already has a value, then it can't be changed anymore. To change it, user must delete the transmitter and recreate one.
                if transmitterIdTempValue != nil {return}
                
                requestTransmitterId()
            }
            
        } else if indexPath.section == 1 && webOOPSettingsSectionIsShown {
            // oop web setting
            // if webOOPEnabled is false, then this means the xDrip (raw value) algorithm will be used
            // if webOOPEnabled is true, then this means that the native/factory/transmitter algorithm will be used - either through a local implementation (Libre 2) or because the transmitter handles all calibration and outputs final/calibrated values.
            
            // clicked cell to change algorithm type
            
            // first off all check that BluetoothPeripheral already exists
            guard let bluetoothPeripheral = bluetoothPeripheral else {return}
            
            // data to be displayed in list from which user needs to pick an algorithm type
            var data = [String]()
            var selectedRow: Int?
            var index = 0
            let currentAlgorithmType = bluetoothPeripheral.blePeripheral.webOOPEnabled ? AlgorithmType.nativeAlgorithm : AlgorithmType.xDripAlgorithm
            
            // get all data source types and add the description to data. Search for the type that matches the AlgorithmType that is currently stored in userdefaults.
            for algorithmType in AlgorithmType.allCases {
                data.append(algorithmType.description)
                
                if algorithmType == currentAlgorithmType {
                    selectedRow = index
                }
                
                index += 1
            }
            
            SettingsViewUtilities.runSelectedRowAction(selectedRowAction: .selectFromList(title: Texts_SettingsView.labelAlgorithmType, data: data, selectedRow: selectedRow, actionTitle: nil, cancelTitle: nil, actionHandler: {(index:Int) in
                
                // we'll set this here so that we can use it in the else statement for logging
                let oldAlgorithmType = currentAlgorithmType
                
                if index != selectedRow {
                    let newAlgorithmType = AlgorithmType(rawValue: index) ?? .nativeAlgorithm
                    
                    // create uialertcontroller to ask the user if they really want to change algorithm
                    let confirmAlgorithmChangeAlertController = UIAlertController(title: Texts_SettingsView.labelAlgorithmType , message: newAlgorithmType == .nativeAlgorithm ? Texts_BluetoothPeripheralView.confirmAlgorithmChangeToTransmitterMessage : Texts_BluetoothPeripheralView.confirmAlgorithmChangeToxDripMessage, preferredStyle: .alert)
                    
                    // create buttons for UIAlertController
                    let OKAction = UIAlertAction(title: Texts_BluetoothPeripheralView.confirm, style: .default) {
                        (action:UIAlertAction!) in
                        
                        bluetoothPeripheral.blePeripheral.webOOPEnabled = (newAlgorithmType == .nativeAlgorithm) ? true : false
                        
                        bluetoothPeripheralManager.receivedNewValue(webOOPEnabled: (newAlgorithmType == .nativeAlgorithm) ? true : false, for: bluetoothPeripheral)
                        
                        if newAlgorithmType == .nativeAlgorithm {
                            bluetoothPeripheral.blePeripheral.nonFixedSlopeEnabled = false
                            bluetoothPeripheralManager.receivedNewValue(nonFixedSlopeEnabled: false, for: bluetoothPeripheral)
                        }
                        
                        // make sure that new value is stored in coredata, because a crash may happen here
                        self.coreDataManager?.saveChanges()
                        
                        // reload the section for nonFixedSettingsSectionNumber, even though the value may not have changed, because possibly isUserInteractionEnabled needs to be set to false for the nonFixedSettingsSectionNumber UISwitch
                        // also reload webOOPSettingsSectionNumber
                        tableView.reloadSections(IndexSet(arrayLiteral: self.nonFixedSettingsSectionNumber, self.webOOPSettingsSectionNumber), with: .none)
                        
                        print("Algorithm changed from: \(oldAlgorithmType.description) -> \(newAlgorithmType.description)")
                        
                        trace("Algorithm type was changed from '%{public}@' to '%{public}@'", log: self.log, category: ConstantsLog.categoryBluetoothPeripheralViewController, type: .info, oldAlgorithmType.description, newAlgorithmType.description)
                    }
                    
                    // create a cancel button. If the user clicks it then we will just return directly
                    let cancelAction = UIAlertAction(title: Texts_Common.Cancel, style: .cancel) {
                        (action:UIAlertAction!) in
                    }
                    
                    // add buttons to the alert
                    confirmAlgorithmChangeAlertController.addAction(OKAction)
                    confirmAlgorithmChangeAlertController.addAction(cancelAction)
                    
                    // show alert
                    self.present(confirmAlgorithmChangeAlertController, animated: true, completion:nil)
                }
                
            }, cancelHandler: nil, didSelectRowHandler: nil), forRowWithIndex: indexPath.row, forSectionWithIndex: indexPath.section, withSettingsViewModel: nil, tableView: tableView, forUIViewController: self)
            
            return
            
        } else if (indexPath.section == 1 && nonFixedSettingsSectionIsShown) ||  (indexPath.section == 2 && nonFixedSettingsSectionIsShown && webOOPSettingsSectionIsShown) {
            // non-fixed slope setting
            // if nonFixedSlopeEnabled is false, then this means single-point calibration (standard) should be used
            // if nonFixedSlopeEnabled is true, then this means multi-point calibration (non-fixed slope) should be used
            
            // clicked cell to change calibration type
            
            if let bluetoothPeripheral = self.bluetoothPeripheral, !bluetoothPeripheral.blePeripheral.webOOPEnabled {
                
                // data to be displayed in list from which user needs to pick a live activity type
                var data = [String]()
                var selectedRow: Int?
                var index = 0
                let currentCalibrationType = bluetoothPeripheral.blePeripheral.nonFixedSlopeEnabled ? CalibrationType.multiPoint : CalibrationType.singlePoint
                
                // get all data source types and add the description to data. Search for the type that matches the CalibrationType that is currently stored in userdefaults.
                for calibrationType in CalibrationType.allCases {
                    data.append(calibrationType.description)
                    
                    if calibrationType == currentCalibrationType {
                        selectedRow = index
                    }
                    
                    index += 1
                }
                
                SettingsViewUtilities.runSelectedRowAction(selectedRowAction: .selectFromList(title: Texts_SettingsView.labelCalibrationType, data: data, selectedRow: selectedRow, actionTitle: nil, cancelTitle: nil, actionHandler: {(index:Int) in
                    
                    // we'll set this here so that we can use it in the else statement for logging
                    let oldCalibrationType = currentCalibrationType
                    
                    if index != selectedRow {
                        let newCalibrationType = CalibrationType(rawValue: index) ?? .singlePoint
                        
                        // create uialertcontroller to ask the user if they really want to change calibration type
                        let confirmCalibrationChangeAlertController = UIAlertController(title: Texts_SettingsView.labelCalibrationType , message: newCalibrationType == .singlePoint ? Texts_BluetoothPeripheralView.confirmCalibrationChangeToSinglePointMessage : Texts_BluetoothPeripheralView.confirmCalibrationChangeToMultiPointMessage, preferredStyle: .alert)
                        
                        // create buttons for UIAlertController
                        let OKAction = UIAlertAction(title: Texts_BluetoothPeripheralView.confirm, style: .default) {
                            (action:UIAlertAction!) in
                            
                            bluetoothPeripheral.blePeripheral.nonFixedSlopeEnabled = (newCalibrationType == .multiPoint) ? true : false
                            
                            bluetoothPeripheralManager.receivedNewValue(nonFixedSlopeEnabled: (newCalibrationType == .multiPoint) ? true : false, for: bluetoothPeripheral)
                            
                            // make sure that new value is stored in coredata, because a crash may happen here
                            self.coreDataManager?.saveChanges()
                            
                            // reload the section for nonFixedSettingsSectionNumber, even though the value may not have changed, because possibly isUserInteractionEnabled needs to be set to false for the nonFixedSettingsSectionNumber UISwitch
                            tableView.reloadSections(IndexSet(integer: self.nonFixedSettingsSectionNumber), with: .none)
                            
                            trace("Calibration activity type was changed from '%{public}@' to '%{public}@'", log: self.log, category: ConstantsLog.categoryBlueToothTransmitter, type: .info, oldCalibrationType.description, newCalibrationType.description)
                        }
                        
                        // create a cancel button. If the user clicks it then we will just return directly
                        let cancelAction = UIAlertAction(title: Texts_Common.Cancel, style: .cancel) {
                            (action:UIAlertAction!) in
                        }
                        
                        // add buttons to the alert
                        confirmCalibrationChangeAlertController.addAction(OKAction)
                        confirmCalibrationChangeAlertController.addAction(cancelAction)
                        
                        // show alert
                        self.present(confirmCalibrationChangeAlertController, animated: true, completion:nil)
                        
                    }
                }, cancelHandler: nil, didSelectRowHandler: nil), forRowWithIndex: indexPath.row, forSectionWithIndex: indexPath.section, withSettingsViewModel: nil, tableView: tableView, forUIViewController: self)
            }
            
            return
        }
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        
        // unwrap variables
        guard let bluetoothPeripheralViewModel = bluetoothPeripheralViewModel else {return nil}
        
        // unwrap expectedBluetoothPeripheralType
        guard let expectedBluetoothPeripheralType = expectedBluetoothPeripheralType else {return ""}
        
        if section == 0 {
            
            // title for first section
            return Texts_SettingsView.m5StackSectionTitleBluetooth
            
        } else if section >= numberOfGeneralSections() {
            
            // title defined in viewmodel
            return bluetoothPeripheralViewModel.sectionTitle(forSection: section)
            
        } else if section == 1 {
            
            // if the bluetoothperipheral type supports non fixed slope then this is section 1
            if expectedBluetoothPeripheralType.canWebOOP() {
                
                return Texts_SettingsView.labelWebOOP
                
            } else if expectedBluetoothPeripheralType.canUseNonFixedSlope() {
                
                return Texts_SettingsView.labelCalibrationTitle
                
            } else {
                
                return "should not happen 1"
                
            }
            
        } else if section == 2  {
            
            return Texts_SettingsView.labelCalibrationTitle
            
        }
        
        return "should not happen 2"
        
    }
    
}

// MARK: - extension BluetoothTransmitterDelegate

extension BluetoothPeripheralViewController: BluetoothTransmitterDelegate {
    
    func heartBeat() {
        
        bluetoothPeripheralManager?.heartBeat()
        
    }
    
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
    
    func didConnectTo(bluetoothTransmitter: BluetoothTransmitter) {
        
        // handled in BluetoothPeripheralManager
        bluetoothPeripheralManager?.didConnectTo(bluetoothTransmitter: bluetoothTransmitter)
        
        // refresh complete first section (only status and connection timestamp changed but reload complete section)
        tableView.reloadSections(IndexSet(integer: 0), with: .none)
        
    }
    
    func didDisconnectFrom(bluetoothTransmitter: BluetoothTransmitter) {
        
        // handled in BluetoothPeripheralManager
        bluetoothPeripheralManager?.didDisconnectFrom(bluetoothTransmitter: bluetoothTransmitter)
        
        // refresh complete first section (only status and connection timestamp changed but reload complete section)
        tableView.reloadSections(IndexSet(integer: 0), with: .none)
        
    }
    
    func deviceDidUpdateBluetoothState(state: CBManagerState, bluetoothTransmitter: BluetoothTransmitter) {
        
        // handled in BluetoothPeripheralManager
        bluetoothPeripheralManager?.deviceDidUpdateBluetoothState(state: state, bluetoothTransmitter: bluetoothTransmitter)
        
        // when bluetooth status changes to powered off, the device, if connected, will disconnect, however didDisConnect doesn't get call (looks like an error in iOS) - so let's reload the cell that shows the connection status, this will refresh the cell
        // do this whenever the bluetooth status changes
        // refresh complete first section (only status and connection timestamp changed but reload complete section)
        tableView.reloadSections(IndexSet(integer: 0), with: .none)
        
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

/* EXPLANATION connect button text and status row detailed text
 For new ble
 - if needs transmitterId, but no transmitterId is given by user,
 - status = "need transmitter id"
 - button = "transmitter id" (same as text in cel)
 - if transmitter id not needed or transmitter id needed and already given, but not yet scanning :
 - status = "ready to scan"
 - button = "start scanning"
 - if  scanning :
 - status = "scanning"
 - button = "scanning" but button disabled
 - if the transmitter type needs a valid NFC scan before trying to connect by bluetooth
 - status = "NFC scan needed"
 - button = "scanning" but button disabled
 
 Once BLE is known (mac address known)
 - if connected
 - status = connected
 - button = "disconnect"
 - if not connected, but shouldconnect = true
 - status = "trying to connect" (renamed to scanning)
 - button = "do no try to connect"
 - if not connected, but shouldconnect = false
 - status = "not trying to connect" (not scanning)
 - button = "try to connect"
 - if not connected, but shouldconnect = true and the transmitter type needs a valid NFC scan before trying to connect by bluetooth
 - status = "NFC scan needed"
 - button = "try to connect" but button disabled
 */
