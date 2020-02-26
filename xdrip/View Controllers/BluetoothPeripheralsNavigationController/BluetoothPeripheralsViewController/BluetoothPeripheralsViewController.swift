import UIKit
import CoreBluetooth

/// uiviewcontroller to show list of BluetoothPeripherals, first uiviewcontroller when clicking the BluetoothPeripheral tab
final class BluetoothPeripheralsViewController: UIViewController {
    
    // MARK: - IBOutlet's and IBAction's

    @IBOutlet weak var tableView: UITableView!
    
    @IBAction func addButtonAction(_ sender: UIBarButtonItem) {
        addButtonAction()
    }
    
    // MARK:- private properties
    
    /// reference to coreDataManager
    private var coreDataManager:CoreDataManager?
    
    /// a bluetoothPeripheralManager
    private weak var bluetoothPeripheralManager: BluetoothPeripheralManaging?
    
    // MARK: public functions
    
    /// configure
    public func configure(coreDataManager: CoreDataManager, bluetoothPeripheralManager: BluetoothPeripheralManaging) {

        // initalize private properties
        self.coreDataManager = coreDataManager
        self.bluetoothPeripheralManager = bluetoothPeripheralManager
        
        // setup bluetoothperipherals
        initializeBluetoothTransmitterDelegates()
        
    }

    /// - iterate through the known BluetoothPeripheral's.
    /// -  If there's one in the category CGM that has shouldConnect to true,
    ///     - then return true
    ///     - display alert that no more than one cgm should be connected
    public static func otherCGMTransmitterHasShouldConnectTrue(bluetoothPeripheralManager: BluetoothPeripheralManaging?, uiViewController: UIViewController) -> Bool {
        
        guard let bluetoothPeripheralManager = bluetoothPeripheralManager else {
            fatalError("in BluetoothPeripheralsViewController otherCGMTransmitterHasShouldConnectTrue, bluetoothPeripheralManager is nil")
        }
        
        for bluetoothPeripheral in bluetoothPeripheralManager.getBluetoothPeripherals() {
            
            if bluetoothPeripheral.bluetoothPeripheralType().category() == .CGM && bluetoothPeripheral.blePeripheral.shouldconnect {
                
                uiViewController.present(UIAlertController(title: Texts_Common.warning, message: Texts_BluetoothPeripheralsView.noMultipleActiveCGMsAllowed, actionHandler: nil), animated: true, completion: nil)
                
                return true
                
            }
        }
        
        return false
    }

    // MARK:- overrides
    
    override func viewDidAppear(_ animated: Bool) {
        
        // reinitialise bluetoothPeripherals because we're coming back from BluetoothPeripheralViewController where a BluetoothPeripheral may have been added or deleted
        initializeBluetoothTransmitterDelegates()
        
        // reload the table
        tableView.reloadSections(IndexSet(integer: 0), with: .none)

    }
    
    override func viewDidLoad() {
        
        super.viewDidLoad()
        
        title = Texts_BluetoothPeripheralsView.screenTitle
        
        setupTableView()
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        
        guard let segueIdentifier = segue.identifier else {
            fatalError("In BluetoothPeripheralsViewController, prepare for segue, Segue had no identifier")
        }
        
        guard let segueIdentifierAsCase = BluetoothPeripheralViewController.SegueIdentifiers(rawValue: segueIdentifier) else {
            fatalError("In BluetoothPeripheralsViewController, segueIdentifierAsCase could not be initialized")
        }
        
        switch segueIdentifierAsCase {
            
        case BluetoothPeripheralViewController.SegueIdentifiers.BluetoothPeripheralsToBluetoothPeripheralSegueIdentifier:
            
            guard let vc = segue.destination as? BluetoothPeripheralViewController, let coreDataManager = coreDataManager else {

                fatalError("In BluetoothPeripheralsViewController, prepare for segue, viewcontroller is not BluetoothPeripheralViewController or coreDataManager is nil" )

            }
            
            guard let expectedBluetoothPeripheralType = (sender as? BluetoothPeripheral) != nil ? (sender as! BluetoothPeripheral).bluetoothPeripheralType() : (sender as? BluetoothPeripheralType) != nil ? (sender as! BluetoothPeripheralType):nil  else {

                fatalError("In BluetoothPeripheralsViewController, prepare for segue, sender is not BluetoothPeripheral and not BluetoothPeripheralType" )

            }
            
            guard let bluetoothPeripheralManager = bluetoothPeripheralManager else {
                fatalError("In BluetoothPeripheralsViewController, prepare for segue, bluetoothPeripheralManager is nil" )
            }
            
            vc.configure(bluetoothPeripheral: sender as? BluetoothPeripheral, coreDataManager: coreDataManager, bluetoothPeripheralManager: bluetoothPeripheralManager, expectedBluetoothPeripheralType: expectedBluetoothPeripheralType)
            
        }
    }
    


    // MARK: private helper functions
    
    /// user clicked add button
    private func addButtonAction() {
        
        // first user needs to select category of bluetoothperipheral
        
        // configure PickerViewData to select category
        let pickerViewData = PickerViewData (withMainTitle: nil, withSubTitle: Texts_BluetoothPeripheralsView.selectCategory, withData: BluetoothPeripheralCategory.listOfCategories(), selectedRow: nil, withPriority: nil, actionButtonText: nil, cancelButtonText: nil, onActionClick: {(_ categoryIndex: Int) in
                
            // user selected category, now user needs to select type of bluetoothperipheral
            // but before doing that, check if user tries to add a CGM
            // if so, check that no other CGM has shouldconnect set to true
            if let category = BluetoothPeripheralCategory(rawValue: BluetoothPeripheralCategory.listOfCategories()[categoryIndex]), category == .CGM, BluetoothPeripheralsViewController.self.otherCGMTransmitterHasShouldConnectTrue(bluetoothPeripheralManager: self.bluetoothPeripheralManager, uiViewController: self) {
                
                return
                
            }
            
            let pickerViewData = PickerViewData (withMainTitle: nil, withSubTitle: Texts_BluetoothPeripheralsView.selectType, withData: BluetoothPeripheralCategory.listOfBluetoothPeripheralTypes(withCategory: BluetoothPeripheralCategory.listOfCategories()[categoryIndex]), selectedRow: nil, withPriority: nil, actionButtonText: nil, cancelButtonText: nil, onActionClick: {(_ typeIndex: Int) in
                
                // go to screen to add a new BluetoothPeripheral
                // in the sender we add the selected bluetoothperipheraltype
                let type = BluetoothPeripheralType(rawValue: BluetoothPeripheralCategory.listOfBluetoothPeripheralTypes(withCategory: BluetoothPeripheralCategory.listOfCategories()[categoryIndex])[typeIndex])
                
                self.performSegue(withIdentifier: BluetoothPeripheralViewController.SegueIdentifiers.BluetoothPeripheralsToBluetoothPeripheralSegueIdentifier.rawValue, sender: type)
                
            }, onCancelClick: nil, didSelectRowHandler: nil)
            
            // create and present PickerViewController
            PickerViewController.displayPickerViewController(pickerViewData: pickerViewData, parentController: self)
            
        }, onCancelClick: nil, didSelectRowHandler: nil)

        // create and present PickerViewController
        PickerViewController.displayPickerViewController(pickerViewData: pickerViewData, parentController: self)
        
    }
    
    // setup datasource, delegate, seperatorInset
    private func setupTableView() {
        if let tableView = tableView {
            tableView.separatorInset = UIEdgeInsets.zero
            tableView.dataSource = self
            tableView.delegate = self
        }
    }

    private func getCoreDataManager() -> CoreDataManager {
        if let coreDataManager = coreDataManager {
            return coreDataManager
        } else {
            fatalError("in BluetoothPeripheralsViewController, coreDataManager is nil")
        }
    }
    
    /// calls tableView.reloadRows for the row where bluetoothPeripheral is shown
    private func updateRow(for bluetoothPeripheral: BluetoothPeripheral) {
        
        if let index = bluetoothPeripheralManager?.getBluetoothPeripherals().firstIndex(where: {$0.blePeripheral.address == bluetoothPeripheral.blePeripheral.address}) {
            tableView.reloadRows(at: [IndexPath(row: index, section: 0)], with: .none)
        }

    }
    
    /// - sets the delegates of each transmitter to self
    /// - bluetoothPeripheralManager will also still receive delegate calls
    private func initializeBluetoothTransmitterDelegates() {
        
        if let bluetoothPeripheralManager = bluetoothPeripheralManager  {
            
            for bluetoothTransmitter in bluetoothPeripheralManager.getBluetoothTransmitters() {
                
                // assign self as BluetoothTransmitterDelegate
                bluetoothTransmitter.bluetoothTransmitterDelegate = self
                
            }
            
        }

    }
    
}

// MARK: - extensions

// MARK: extension UITableViewDataSource and UITableViewDelegate

extension BluetoothPeripheralsViewController: UITableViewDataSource, UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return bluetoothPeripheralManager?.getBluetoothPeripherals().count ?? 0
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        guard let cell = tableView.dequeueReusableCell(withIdentifier: SettingsTableViewCell.reuseIdentifier, for: indexPath) as? SettingsTableViewCell else { fatalError("Unexpected Table View Cell") }
        
        guard let bluetoothPeripheralManager = bluetoothPeripheralManager else {
            return cell
        }

        // textLabel should be the user defined alias of the BluetoothPeripheral, or if user defined alias == nil, then the devicename

        cell.textLabel?.text = bluetoothPeripheralManager.getBluetoothPeripherals()[indexPath.row].blePeripheral.alias
        if cell.textLabel?.text == nil {
            cell.textLabel?.text = bluetoothPeripheralManager.getBluetoothPeripherals()[indexPath.row].blePeripheral.name
        }
        
        // detail is the connection status
        cell.detailTextLabel?.text = Text_BluetoothPeripheralView.notConnected // start with not connected
        if let bluetoothTransmitter = bluetoothPeripheralManager.getBluetoothTransmitter(for: bluetoothPeripheralManager.getBluetoothPeripherals()[indexPath.row], createANewOneIfNecesssary: false) {
            
            if let connectionStatus = bluetoothTransmitter.getConnectionStatus(), connectionStatus == CBPeripheralState.connected {
                cell.detailTextLabel?.text = Text_BluetoothPeripheralView.connected
            }
            
        }

        // clicking the cell will always open a new screen which allows the user to edit the alert type
        cell.accessoryType = .disclosureIndicator
        
        return cell
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        // only 1 section, namely the list of BluetoothPeripherals
        return 1
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        tableView.deselectRow(at: indexPath, animated: true)
       
        guard let bluetoothPeripheralManager = bluetoothPeripheralManager else {return}
        
        self.performSegue(withIdentifier: BluetoothPeripheralViewController.SegueIdentifiers.BluetoothPeripheralsToBluetoothPeripheralSegueIdentifier.rawValue, sender: bluetoothPeripheralManager.getBluetoothPeripherals()[indexPath.row])

    }
    
}

// MARK: - extension BluetoothTransmitterDelegate

extension BluetoothPeripheralsViewController: BluetoothTransmitterDelegate {
    
    func transmitterNeedsPairing(bluetoothTransmitter: BluetoothTransmitter) {
       
        // forward this call to bluetoothPeripheralManager who will handle it
        bluetoothPeripheralManager?.transmitterNeedsPairing(bluetoothTransmitter: bluetoothTransmitter)
        
    }
    
    func successfullyPaired() {

        // forward this call to bluetoothPeripheralManager who will handle it
        bluetoothPeripheralManager?.successfullyPaired()

    }
    
    func pairingFailed() {

        // forward this call to bluetoothPeripheralManager who will handle it
        bluetoothPeripheralManager?.pairingFailed()

    }
    
    func reset(for bluetoothTransmitter: BluetoothTransmitter, successful: Bool) {
        
        // forward this call to bluetoothPeripheralManager who will handle it
        bluetoothPeripheralManager?.reset(for: bluetoothTransmitter, successful: successful)
        
    }
    
    func error(message: String) {
        
        // forward this call to bluetoothPeripheralManager who will handle it
        bluetoothPeripheralManager?.error(message: message)

    }
    
    func didConnectTo(bluetoothTransmitter: BluetoothTransmitter) {

        // forward this call to bluetoothPeripheralManager who will handle it
        bluetoothPeripheralManager?.didConnectTo(bluetoothTransmitter: bluetoothTransmitter)

        guard let bluetoothPeripheralManager = bluetoothPeripheralManager else {
            fatalError("in BluetoothPeripheralsViewController didConnectTo, bluetoothPeripheralManager is nil")
        }
        
        // row with connection status in the view must be updated
        updateRow(for: bluetoothPeripheralManager.getBluetoothPeripheral(for: bluetoothTransmitter))
        
    }
    
    func didDisconnectFrom(bluetoothTransmitter: BluetoothTransmitter) {

        // forward this call to bluetoothPeripheralManager who will handle it
        bluetoothPeripheralManager?.didDisconnectFrom(bluetoothTransmitter: bluetoothTransmitter)

        guard let bluetoothPeripheralManager = bluetoothPeripheralManager else {
            fatalError("in BluetoothPeripheralsViewController didDisconnectFrom, bluetoothPeripheralManager is nil")
        }

        // row with connection status in the view must be updated
        updateRow(for: bluetoothPeripheralManager.getBluetoothPeripheral(for: bluetoothTransmitter))
        
    }
    
    func deviceDidUpdateBluetoothState(state: CBManagerState, bluetoothTransmitter: BluetoothTransmitter) {

        // forward this call to bluetoothPeripheralManager who will handle it
        bluetoothPeripheralManager?.deviceDidUpdateBluetoothState(state: state, bluetoothTransmitter: bluetoothTransmitter)

        guard let bluetoothPeripheralManager = bluetoothPeripheralManager else {
            fatalError("in BluetoothPeripheralsViewController deviceDidUpdateBluetoothState, bluetoothPeripheralManager is nil")
        }

        // when bluetooth status changes to powered off, the device, if connected, will disconnect, however didDisConnect doesn't get call (looks like an error in iOS) - so let's reload the cell that shows the connection status, this will refresh the cell
        if state == CBManagerState.poweredOff {
            updateRow(for: bluetoothPeripheralManager.getBluetoothPeripheral(for: bluetoothTransmitter))
        }
        
    }
    
}



