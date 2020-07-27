import UIKit
import CoreBluetooth
import os

fileprivate let generalSettingSectionNumber = 0

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
    
    /// timestamp when connection changed to connected or not connected
    case connectOrDisconnectTimeStamp = 4
    
    /// transmitterID, only for devices that need it
    case transmitterId = 5

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
    private let webOOPSettingsSectionNumber = 2
    
    /// is the webOOPSettingsSection currently shown or not
    private var webOOPSettingsSectionIsShown = false
    
    /// in which section do we find the non fixed calibration slopes setting, if enabled
    private let nonFixedSettingsSectionNumber = 1
    
    /// is the nonFixedSettingsSection currently shown or not
    private var nonFixedSettingsSectionIsShown = false
    
    /// when user starts scanning, info will be shown in UIAlertController. This will be
    private var infoAlertWhenScanningStarts: UIAlertController?
    
    /// for trace
    private let log = OSLog(subsystem: ConstantsLog.subSystem, category: ConstantsLog.categoryBluetoothPeripheralViewController)

    /// to keep track of scanning result
    private var previousScanningResult: BluetoothTransmitter.startScanningResult?
    
    // MARK:- public functions
    
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
    public static func setConnectButtonLabelTextAndGetStatusDetailedText(bluetoothPeripheral: BluetoothPeripheral?, isScanning: Bool, connectButtonOutlet: UIButton?, expectedBluetoothPeripheralType: BluetoothPeripheralType?, transmitterId: String?, bluetoothPeripheralManager: BluetoothPeripheralManager) -> String {
        
        // by default connectbutton is enabled
        connectButtonOutlet?.enable()
        
        // explanation see below in this file
        
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
                
                connectButtonOutlet?.setTitle(Texts_BluetoothPeripheralView.donotconnect, for: .normal)
                
                return Texts_BluetoothPeripheralView.tryingToConnect
                
            }
            
            // not connected, shouldconnect = false
            connectButtonOutlet?.setTitle(Texts_BluetoothPeripheralView.connect, for: .normal)
            
            return Texts_BluetoothPeripheralView.notTryingToConnect
            
            
        } else {
            
            // BluetoothPeripheral is nil
            
            // if needs transmitterId, but no transmitterId is given by user, then button allows to set transmitter id, row text = "needs transmitter id"
            if let expectedBluetoothPeripheralType = expectedBluetoothPeripheralType, expectedBluetoothPeripheralType.needsTransmitterId(), transmitterId == nil {
                
                connectButtonOutlet?.setTitle(Texts_SettingsView.labelTransmitterId, for: .normal)
                
                return Texts_BluetoothPeripheralView.needsTransmitterId
                
            }
            
            //if transmitter id not needed or transmitter id needed and already given, but not yet scanning
            if let expectedBluetoothPeripheralType = expectedBluetoothPeripheralType {
                
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
    public func setShouldConnectToFalse(for bluetoothPeripheral: BluetoothPeripheral) {
        
        guard let bluetoothPeripheralManager = bluetoothPeripheralManager else {return}
        
        // device should not automaticaly connect in future, which means, each time the app restarts, it will not try to connect to this bluetoothPeripheral
        bluetoothPeripheral.blePeripheral.shouldconnect = false
        
        // save in coredata
        coreDataManager?.saveChanges()
        
        // connect button label text needs to change because shouldconnect value has changed
        _ = BluetoothPeripheralViewController.setConnectButtonLabelTextAndGetStatusDetailedText(bluetoothPeripheral: bluetoothPeripheral, isScanning: isScanning, connectButtonOutlet: connectButtonOutlet, expectedBluetoothPeripheralType: expectedBluetoothPeripheralType, transmitterId: transmitterIdTempValue, bluetoothPeripheralManager: bluetoothPeripheralManager as! BluetoothPeripheralManager)
        
        // this will set bluetoothTransmitter to nil which will result in disconnecting also
        bluetoothPeripheralManager.setBluetoothTransmitterToNil(forBluetoothPeripheral: bluetoothPeripheral)
        
        // as transmitter is now set to nil, call again configure. Maybe not necessary, but it can't hurt
        bluetoothPeripheralViewModel?.configure(bluetoothPeripheral: bluetoothPeripheral, bluetoothPeripheralManager: bluetoothPeripheralManager, tableView: tableView, bluetoothPeripheralViewController: self, onLibreSensorTypeReceived: libreSensorTypeReceived)
        
        // delegate doesn't work here anymore, because the delegate is set to zero, so reset the row with the connection status by calling reloadRows
        tableView.reloadRows(at: [IndexPath(row: Setting.connectionStatus.rawValue, section: 0)], with: .none)
        
    }
    
    /// the BluetoothPeripheralViewController has already a few sections defined (eg bluetooth, weboop). This is the amount of sections defined in BluetoothPeripheralViewController.
    public func numberOfGeneralSections() -> Int {
        
        // first check if bluetoothPeripheral already known
        if let bluetoothPeripheral = bluetoothPeripheral {

            // bluetoothPeripheral already known
            
            // if sensor type is known and it requires oop web, then there's no need to show the oop web settings and the non-fixed slope settings
            if let sensorType = bluetoothPeripheral.blePeripheral.libreSensorType, sensorType.needsWebOOP() {
                
                // mark web oop and non fixed slope settings sections as not shown
                webOOPSettingsSectionIsShown = false
                nonFixedSettingsSectionIsShown = false
                
                return 1
                
            } else {

                // if it's a cgm transmitter type that supports web oop and non fixed slopes
                // then show the webOOP section and nonFixed section
                if let expectedBluetoothPeripheralType = expectedBluetoothPeripheralType, expectedBluetoothPeripheralType.canWebOOP(), expectedBluetoothPeripheralType.canUseNonFixedSlope() {
                    
                    // mark web oop and non fixed slope settings sections as shown
                    webOOPSettingsSectionIsShown = true
                    nonFixedSettingsSectionIsShown = true

                    return 3
                    
                    // if bluetoothPeripheral already known,
                    // and it's a cgm transmitter type that supports non fixed slopes but doesn't support weboop
                    // then show only the nonFixed section
                } else if let expectedBluetoothPeripheralType = expectedBluetoothPeripheralType, expectedBluetoothPeripheralType.canUseNonFixedSlope() {
                    
                    // mark web oop and non fixed slope settings sections as not shown
                    webOOPSettingsSectionIsShown = false
                    nonFixedSettingsSectionIsShown = true

                    return 2
                    
                }

            }

        }
        
        // bluetoothPeripheral not yet known, only show first section with name alias, ...
        return 1
        
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
        bluetoothPeripheralViewModel?.configure(bluetoothPeripheral: bluetoothPeripheral, bluetoothPeripheralManager: bluetoothPeripheralManager, tableView: tableView, bluetoothPeripheralViewController: self, onLibreSensorTypeReceived: libreSensorTypeReceived)
        
        // assign the self delegate in the transmitter object
        if let bluetoothPeripheral = bluetoothPeripheral, let bluetoothTransmitter = bluetoothPeripheralManager.getBluetoothTransmitter(for: bluetoothPeripheral, createANewOneIfNecesssary: false) {
            
            bluetoothTransmitter.bluetoothTransmitterDelegate = self
            
        }

        setupView()
        
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
        _ = BluetoothPeripheralViewController.setConnectButtonLabelTextAndGetStatusDetailedText(bluetoothPeripheral: bluetoothPeripheral, isScanning: isScanning, connectButtonOutlet: connectButtonOutlet, expectedBluetoothPeripheralType: expectedBluetoothPeripheralType, transmitterId: transmitterIdTempValue, bluetoothPeripheralManager: bluetoothPeripheralManager as! BluetoothPeripheralManager)
        
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
        
        // initiailize previousScanningResult to nil
        previousScanningResult = nil
        
        bluetoothPeripheralManager.startScanningForNewDevice(type: type, transmitterId: transmitterIdTempValue, callBackForScanningResult: handleScanningResult(startScanningResult:), callback: { (bluetoothPeripheral) in

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
            self.bluetoothPeripheralViewModel?.configure(bluetoothPeripheral: self.bluetoothPeripheral, bluetoothPeripheralManager: bluetoothPeripheralManager, tableView: self.tableView,  bluetoothPeripheralViewController: self, onLibreSensorTypeReceived: self.libreSensorTypeReceived)
            
            // enable the connect button
            self.connectButtonOutlet.enable()
            
            // set right text for connect button
            _ = BluetoothPeripheralViewController.setConnectButtonLabelTextAndGetStatusDetailedText(bluetoothPeripheral: bluetoothPeripheral, isScanning: self.isScanning, connectButtonOutlet: self.connectButtonOutlet, expectedBluetoothPeripheralType: self.expectedBluetoothPeripheralType, transmitterId: self.transmitterIdTempValue, bluetoothPeripheralManager: bluetoothPeripheralManager as! BluetoothPeripheralManager)
            
            // enable the trashbutton
            self.trashButtonOutlet.enable()
            
            // set self as delegate in the bluetoothTransmitter
            if let bluetoothTransmitter = bluetoothPeripheralManager.getBluetoothTransmitter(for: bluetoothPeripheral, createANewOneIfNecesssary: false) {
                
                bluetoothTransmitter.bluetoothTransmitterDelegate = self

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
            
            // show info that user should keep the app in the foreground
            self.infoAlertWhenScanningStarts = UIAlertController(title: Texts_HomeView.info, message: Texts_HomeView.startScanningInfo, actionHandler: nil)
            self.present(self.infoAlertWhenScanningStarts!, animated:true)
            
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
            
        }

    }
    
    /// use clicked trash button, need to delete the bluetoothperipheral
    private func trashButtonClicked() {
        
        // let's first check if bluetoothPeripheral exists, otherwise there's nothing to trash, normally this shouldn't happen because trashbutton should be disabled if there's no bluetoothPeripheral
        guard let bluetoothPeripheral = bluetoothPeripheral else {return}

        // unwrap bluetoothPeripheralManager
        guard let bluetoothPeripheralManager = bluetoothPeripheralManager else {return}
        
        // textToAdd is either 'address' + the address, or 'alias' + the alias, depending if alias has a value
        var textToAdd = Texts_BluetoothPeripheralView.address + " " + bluetoothPeripheral.blePeripheral.address
        if let alias = bluetoothPeripheral.blePeripheral.alias {
            textToAdd = Texts_BluetoothPeripheralView.bluetoothPeripheralAlias + " " + alias
        }
        
        // first ask user if ok to delete and if yes delete
        let alert = UIAlertController(title: Texts_BluetoothPeripheralView.confirmDeletionBluetoothPeripheral + " " + textToAdd + "?", message: nil, actionHandler: {
            
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
        
        // unwrap bluetoothPeripheralManager
        guard let bluetoothPeripheralManager = bluetoothPeripheralManager else {return}
        
        // unwrap expectedBluetoothPeripheralType
        guard let expectedBluetoothPeripheralType = expectedBluetoothPeripheralType else {return}
        
        // let's first check if bluetoothPeripheral exists
        if let bluetoothPeripheral = bluetoothPeripheral {
            
            // if shouldconnect = true then set setshouldconnect to false, this will also result in disconnecting
            if bluetoothPeripheral.blePeripheral.shouldconnect {
                
                // disconnect
                setShouldConnectToFalse(for: bluetoothPeripheral)
                
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
                    bluetoothPeripheralViewModel?.configure(bluetoothPeripheral: bluetoothPeripheral, bluetoothPeripheralManager: bluetoothPeripheralManager, tableView: tableView, bluetoothPeripheralViewController: self, onLibreSensorTypeReceived: libreSensorTypeReceived)
                    
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
        _ = BluetoothPeripheralViewController.setConnectButtonLabelTextAndGetStatusDetailedText(bluetoothPeripheral: bluetoothPeripheral, isScanning: isScanning, connectButtonOutlet: connectButtonOutlet, expectedBluetoothPeripheralType: expectedBluetoothPeripheralType, transmitterId: transmitterIdTempValue, bluetoothPeripheralManager: bluetoothPeripheralManager as! BluetoothPeripheralManager)
        
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
        
        SettingsViewUtilities.runSelectedRowAction(selectedRowAction: SettingsSelectedRowAction.askText(title: Texts_SettingsView.labelTransmitterId, message: Texts_SettingsView.labelGiveTransmitterId, keyboardType: UIKeyboardType.alphabet, text: transmitterIdTempValue, placeHolder: "00000", actionTitle: nil, cancelTitle: nil, actionHandler:
            {(transmitterId:String) in
                
                // convert to uppercase
                let transmitterIdUpper = transmitterId.uppercased().toNilIfLength0()
                
                self.transmitterIdTempValue = transmitterIdUpper
                
                // reload the specific row in the table
                self.tableView.reloadRows(at: [IndexPath(row: Setting.transmitterId.rawValue, section: 0)], with: .none)
                
                // as transmitter id has been set (or set to nil), connect button label text must change
                _ = BluetoothPeripheralViewController.setConnectButtonLabelTextAndGetStatusDetailedText(bluetoothPeripheral: self.bluetoothPeripheral, isScanning: self.isScanning, connectButtonOutlet: self.connectButtonOutlet, expectedBluetoothPeripheralType: self.expectedBluetoothPeripheralType, transmitterId: transmitterIdUpper, bluetoothPeripheralManager: bluetoothPeripheralManager as! BluetoothPeripheralManager)
                
        }, cancelHandler: nil, inputValidator: { (transmitterId) in
            
            return self.expectedBluetoothPeripheralType?.validateTransmitterId(transmitterId: transmitterId)
            
        }), forRowWithIndex: Setting.transmitterId.rawValue, forSectionWithIndex: generalSettingSectionNumber, withSettingsViewModel: nil, tableView: tableView, forUIViewController: self)

    }
    
    /// dismiss alert screen that shows info after cliking start scanning button
    private func dismissInfoAlertWhenScanningStarts() {

        if let infoAlertWhenScanningStarts = infoAlertWhenScanningStarts {
            
            infoAlertWhenScanningStarts.dismiss(animated: true, completion: nil)
            self.infoAlertWhenScanningStarts = nil
            
        }
        
    }
    
    /// function called by model, if it receives a libre sensor type
    private func libreSensorTypeReceived(libreSensorType: LibreSensorType) {
       
        // if the sensortype needs web oop, and if web oop or non fixed slope settings sections are shown then delete those sections
        // and if not, then the other way around
        
        if libreSensorType.needsWebOOP() {
            
            var indexSet = IndexSet()
            
            if webOOPSettingsSectionIsShown {
                
                indexSet.insert(webOOPSettingsSectionNumber)
                
                webOOPSettingsSectionIsShown = false
                    
            }
            
            if nonFixedSettingsSectionIsShown {
                
                indexSet.insert(nonFixedSettingsSectionNumber)
                
                nonFixedSettingsSectionIsShown = false
                
            }
            
            if indexSet.count > 0 {

                tableView.deleteSections(indexSet, with: .none)

            }
            
        } else {
            
            var indexSet = IndexSet()
            
            // unwrap expectedBluetoothPeripheralType, should be non nil here
            guard let expectedBluetoothPeripheralType = expectedBluetoothPeripheralType else {return}
            
            if expectedBluetoothPeripheralType.canWebOOP() {
                
                if !webOOPSettingsSectionIsShown {

                    indexSet.insert(webOOPSettingsSectionNumber)
                    
                    webOOPSettingsSectionIsShown = true

                }
                
            }
            
            if expectedBluetoothPeripheralType.canUseNonFixedSlope() {
                
                if !nonFixedSettingsSectionIsShown {
                    
                    indexSet.insert(nonFixedSettingsSectionNumber)
                    
                    nonFixedSettingsSectionIsShown = true
                    
                }
                
            }
            
            if indexSet.count > 0 {
                
                tableView.insertSections(indexSet, with: .none)
                
            }
            
            
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
                
                // if the bluetoothperipheral type supports non fixed then this is the non fixed
                if expectedBluetoothPeripheralType.canUseNonFixedSlope() {
                    
                    return 1;
                    
                }
                
            } else if section == 2  {
                
                // if the bluetoothperipheral type supports oopweb then this is the oop web section
                if expectedBluetoothPeripheralType.canWebOOP() {
                    
                    // check if weboopenabled and if yes return the number of settings in that section
                    if let bluetoothPeripheral = bluetoothPeripheral {
                        
                        if bluetoothPeripheral.blePeripheral.webOOPEnabled {
                            return WebOOPSettings.allCases.count
                        }
                    }
                    
                    // weboop supported by the peripheral but not enabled
                    return 1
                    
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
                
                cell.textLabel?.text = Texts_BluetoothPeripheralView.address
                cell.detailTextLabel?.text = bluetoothPeripheral?.blePeripheral.address
                if cell.detailTextLabel?.text == nil {
                    cell.accessoryType = .none
                } else {
                    cell.accessoryType = .disclosureIndicator
                }
                
            case .connectionStatus:
                
                cell.textLabel?.text = Texts_BluetoothPeripheralView.status
                cell.detailTextLabel?.text = BluetoothPeripheralViewController.setConnectButtonLabelTextAndGetStatusDetailedText(bluetoothPeripheral: bluetoothPeripheral, isScanning: isScanning, connectButtonOutlet: connectButtonOutlet, expectedBluetoothPeripheralType: expectedBluetoothPeripheralType, transmitterId: transmitterIdTempValue, bluetoothPeripheralManager: bluetoothPeripheralManager as! BluetoothPeripheralManager)
                cell.accessoryType = .none
                
            case .alias:
                
                cell.textLabel?.text = Texts_BluetoothPeripheralView.bluetoothPeripheralAlias
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
                
            case .connectOrDisconnectTimeStamp:
                
                if let bluetoothPeripheral = bluetoothPeripheral, let lastConnectionStatusChangeTimeStamp = bluetoothPeripheral.blePeripheral.lastConnectionStatusChangeTimeStamp {
                    
                    if BluetoothPeripheralViewController.bluetoothPeripheralIsConnected(bluetoothPeripheral: bluetoothPeripheral, bluetoothPeripheralManager: bluetoothPeripheralManager as! BluetoothPeripheralManager) {
                        
                        cell.textLabel?.text = Texts_BluetoothPeripheralView.connectedAt
                        
                    } else {
                        
                        cell.textLabel?.text = Texts_BluetoothPeripheralView.disConnectedAt
                        
                    }
                    
                    cell.detailTextLabel?.text = lastConnectionStatusChangeTimeStamp.toShortString()
                    
                } else {
                    cell.textLabel?.text = Texts_BluetoothPeripheralView.connectedAt
                    cell.detailTextLabel?.text = ""
                }

            }

        } else if indexPath.section == 1 {
            // non fixed calibration slope settings
            
            guard let setting = NonFixedCalibrationSlopesSettings(rawValue: indexPath.row) else { fatalError("BluetoothPeripheralViewController cellForRowAt, Unexpected setting, row = " + indexPath.row.description) }
            switch setting {
                
            case .nonFixedSlopeEnabled:
                
                cell.textLabel?.text = Texts_SettingsView.labelNonFixedTransmitter
                cell.detailTextLabel?.text = nil
                
                var currentStatus = false
                if let bluetoothPeripheral = bluetoothPeripheral {
                    currentStatus = bluetoothPeripheral.blePeripheral.nonFixedSlopeEnabled
                }
                
                cell.accessoryView = UISwitch(isOn: currentStatus, action: { (isOn:Bool) in
                    
                    self.bluetoothPeripheral?.blePeripheral.nonFixedSlopeEnabled = isOn
                    
                    // send info to bluetoothPeripheralManager
                    if let bluetoothPeripheral = self.bluetoothPeripheral {

                        bluetoothPeripheralManager.receivedNewValue(nonFixedSlopeEnabled: isOn, for: bluetoothPeripheral)

                        tableView.reloadSections(IndexSet(integer: self.nonFixedSettingsSectionNumber), with: .none)

                    }
                    
                })
                
                // if it's a bluetoothPeripheral that uses oop web, then the setting can not be changed
                if let bluetoothPeripheral = self.bluetoothPeripheral {
                    if bluetoothPeripheral.blePeripheral.webOOPEnabled {
                        
                        cell.accessoryView?.isUserInteractionEnabled = false
                        
                    }
                }

                cell.accessoryType = .none
                
            }
        }  else if indexPath.section == 2 {
            
            // web oop settings
            
            guard let setting = WebOOPSettings(rawValue: indexPath.row) else { fatalError("BluetoothPeripheralViewController cellForRowAt, Unexpected setting, row = " + indexPath.row.description) }
            
            // configure the cell depending on setting
            switch setting {
                
            case .webOOPEnabled:
                
                // set row text and set default row label to nil
                cell.textLabel?.text = Texts_SettingsView.labelWebOOPTransmitter
                cell.detailTextLabel?.text = nil
                
                // get current value of webOOPEnabled, default false
                var currentWebOOPEnabledValue = false
                if let bluetoothPeripheral = bluetoothPeripheral {
                    
                    currentWebOOPEnabledValue = bluetoothPeripheral.blePeripheral.webOOPEnabled
                    
                }
                
                cell.accessoryView = UISwitch(isOn: currentWebOOPEnabledValue, action: { (isOn:Bool) in
                    
                    self.bluetoothPeripheral?.blePeripheral.webOOPEnabled = isOn
                    
                    // send info to bluetoothPeripheralManager
                    if let bluetoothPeripheral = self.bluetoothPeripheral {
                        
                        bluetoothPeripheralManager.receivedNewValue(webOOPEnabled: isOn, for: bluetoothPeripheral)
                        
                        tableView.reloadSections(IndexSet(integer: self.webOOPSettingsSectionNumber), with: .none)
                        
                        
                        // if user switches on web oop, then we need to force also use of non-fixed slopes to off
                        if isOn {

                            bluetoothPeripheral.blePeripheral.nonFixedSlopeEnabled = false
                            
                            bluetoothPeripheralManager.receivedNewValue(nonFixedSlopeEnabled: false, for: bluetoothPeripheral)
                            
                        }

                        // reload the section for nonFixedSettingsSectionNumber, even though the value may not have changed, because possibly isUserInteractionEnabled needs to be set to false for the nonFixedSettingsSectionNumber UISwitch
                        tableView.reloadSections(IndexSet(integer: self.nonFixedSettingsSectionNumber), with: .none)

                    }
                    
                })
                
                // if it's a bluetoothPeripheral that supports libre and if it's a libre sensor type that needs oopWeb, then value can not be changed,
                if let bluetoothPeripheral = self.bluetoothPeripheral, let libreSensorType = bluetoothPeripheral.blePeripheral.libreSensorType {
                    if libreSensorType.needsWebOOP() {

                        cell.accessoryView?.isUserInteractionEnabled = false
                        
                    }
                }

                cell.accessoryType = .none
                
            }
            
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
                
            case .address:
                guard let bluetoothPeripheral = bluetoothPeripheral else {return}
                
                let alert = UIAlertController(title: Texts_BluetoothPeripheralView.address, message: bluetoothPeripheral.blePeripheral.address, actionHandler: nil)
                
                // present the alert
                self.present(alert, animated: true, completion: nil)
                
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
            
        } else if indexPath.section == 1 {
            // non fixed slopes settings
            
            guard let setting = NonFixedCalibrationSlopesSettings(rawValue: indexPath.row) else { fatalError("BluetoothPeripheralViewController didSelectRowAt, Unexpected setting") }
            
            switch setting {
                
            case .nonFixedSlopeEnabled:
                // this is a uiswitch, user needs to click the uiswitch, not just the row
                return
            }
        } else if indexPath.section == 2 {
            
            // web oop settings
            
            guard let setting = WebOOPSettings(rawValue: indexPath.row) else { fatalError("BluetoothPeripheralViewController didSelectRowAt, Unexpected setting") }
            
            switch setting {
                
            case .webOOPEnabled:
                // this is a uiswitch, user needs to click the uiswitch, not just the row
                return
                
            }
        
        }
        
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        
        // unwrap variables
        guard let bluetoothPeripheralViewModel = bluetoothPeripheralViewModel else {return nil}

        if section == 0 {
            
            // title for first section
            return Texts_SettingsView.m5StackSectionTitleBluetooth
            
        } else if section >= numberOfGeneralSections() {
            
            // title defined in viewmodel
            return bluetoothPeripheralViewModel.sectionTitle(forSection: section)

        } else if section == 2 {
            
            // web oop section
            return Texts_SettingsView.labelWebOOP
            
        } else { //if section == 1
            
            // non fixed section
            return Texts_SettingsView.labelNonFixed
            
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
    
    func didConnectTo(bluetoothTransmitter: BluetoothTransmitter) {

        // handled in BluetoothPeripheralManager
        bluetoothPeripheralManager?.didConnectTo(bluetoothTransmitter: bluetoothTransmitter)
        
        // refresh row with status
        tableView.reloadRows(at: [IndexPath(row: Setting.connectionStatus.rawValue, section: 0)], with: .none)
        
        // refresh row with connection timestamp
        tableView.reloadRows(at: [IndexPath(row: Setting.connectOrDisconnectTimeStamp.rawValue, section: 0)], with: .none)
        
    }
    
    func didDisconnectFrom(bluetoothTransmitter: BluetoothTransmitter) {
        
        // handled in BluetoothPeripheralManager
        bluetoothPeripheralManager?.didDisconnectFrom(bluetoothTransmitter: bluetoothTransmitter)
        
        // refresh row with status
        tableView.reloadRows(at: [IndexPath(row: Setting.connectionStatus.rawValue, section: 0)], with: .none)

        // refresh row with connection timestamp
         tableView.reloadRows(at: [IndexPath(row: Setting.connectOrDisconnectTimeStamp.rawValue, section: 0)], with: .none)
        
    }
    
    func deviceDidUpdateBluetoothState(state: CBManagerState, bluetoothTransmitter: BluetoothTransmitter) {

        // handled in BluetoothPeripheralManager
        bluetoothPeripheralManager?.deviceDidUpdateBluetoothState(state: state, bluetoothTransmitter: bluetoothTransmitter)
        
        // when bluetooth status changes to powered off, the device, if connected, will disconnect, however didDisConnect doesn't get call (looks like an error in iOS) - so let's reload the cell that shows the connection status, this will refresh the cell
        // do this whenever the bluetooth status changes
        tableView.reloadRows(at: [IndexPath(row: Setting.connectionStatus.rawValue, section: 0)], with: .none)
        
        // same explanation for connection timestamp
        tableView.reloadRows(at: [IndexPath(row: Setting.connectOrDisconnectTimeStamp.rawValue, section: 0)], with: .none)

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
 */
