import UIKit
import CoreBluetooth

/// uiviewcontroller to show list of BluetoothPeripherals, first uiviewcontroller when clicking the BluetoothPeripheral tab
final class BluetoothPeripheralsViewController: UIViewController {
    
    // MARK: - IBOutlet's and IBAction's

    @IBOutlet weak var tableView: UITableView!
    
    @IBAction func addButtonAction(_ sender: UIBarButtonItem) {
        addButtonAction()
    }
    
    @IBAction func unwindToBluetoothPeripheralsViewController (segue: UIStoryboardSegue) {
        
        // reinitialise bluetoothPeripherals because we're coming back from BluetoothPeripheralViewController where a BluetoothPeripheral may have been added or deleted
        initializeBluetoothPeripherals()

        // reload the table
        tableView.reloadSections(IndexSet(integer: 0), with: .none)
    }
 
    // MARK:- private properties
    
    /// reference to coreDataManager
    private var coreDataManager:CoreDataManager?
    
    /// a bluetoothPeripheralManager
    private weak var bluetoothPeripheralManager: BluetoothPeripheralManaging!
    
    // MARK: public functions
    
    /// configure
    public func configure(coreDataManager: CoreDataManager, bluetoothPeripheralManager: BluetoothPeripheralManaging) {
        
        // initalize private properties
        self.coreDataManager = coreDataManager
        self.bluetoothPeripheralManager = bluetoothPeripheralManager
        initializeBluetoothPeripherals()
        
    }

    // MARK: overrides
    
    override func viewDidLoad() {
        
        super.viewDidLoad()
        
        title = Texts_BluetoothPeripheralsView.screenTitle
        
        setupView()
        
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
            
            vc.configure(bluetoothPeripheral: sender as? BluetoothPeripheral, coreDataManager: coreDataManager, bluetoothPeripheralManager: bluetoothPeripheralManager, expectedBluetoothPeripheralType: expectedBluetoothPeripheralType)
            
        }
    }
    


    // MARK: private helper functions
    
    /// user clicked add button
    private func addButtonAction() {
        
        // first user needs to select category of bluetoothperipheral
        
        // configure PickerViewData to select category
        let pickerViewData = PickerViewData (withMainTitle: nil, withSubTitle: Texts_BluetoothPeripheralsView.selectCategory, withData: BluetoothPeripheralCategory.listOfCategories(), selectedRow: nil, withPriority: nil, actionButtonText: nil, cancelButtonText: nil, onActionClick: {(_ categoryIndex: Int) in
                
            // user select category, now user needs to select type of bluetoothperipheral
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
    
    private func setupView() {
        setupTableView()
    }
    
    // setup datasource, delegate, seperatorInset
    private func setupTableView() {
        if let tableView = tableView {
            // insert slightly the separator text so that it doesn't touch the safe area limit
            tableView.separatorInset = UIEdgeInsets(top: 0, left: 10, bottom: 0, right: 0)
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
        
        if let index = bluetoothPeripheralManager.getBluetoothPeripherals().firstIndex(where: {$0.blePeripheral.address == bluetoothPeripheral.blePeripheral.address}) {
            tableView.reloadRows(at: [IndexPath(row: index, section: 0)], with: .none)
        }

    }
    
    /// initializes bluetoothPeripherals
    /// - sets the delegates of each transmitter to self
    private func initializeBluetoothPeripherals() {
        
        for bluetoothtTransmitter in bluetoothPeripheralManager.getBluetoothTransmitters() {
            
            bluetoothtTransmitter.variableBluetoothTransmitterDelegate = self
            
        }
        
    }
    
}

// MARK: - extensions

// MARK: extension UITableViewDataSource and UITableViewDelegate

extension BluetoothPeripheralsViewController: UITableViewDataSource, UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return bluetoothPeripheralManager.getBluetoothPeripherals().count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        guard let cell = tableView.dequeueReusableCell(withIdentifier: SettingsTableViewCell.reuseIdentifier, for: indexPath) as? SettingsTableViewCell else { fatalError("Unexpected Table View Cell") }
        
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
       
        self.performSegue(withIdentifier: BluetoothPeripheralViewController.SegueIdentifiers.BluetoothPeripheralsToBluetoothPeripheralSegueIdentifier.rawValue, sender: bluetoothPeripheralManager.getBluetoothPeripherals()[indexPath.row])

    }
    
}

// MARK: - extension BluetoothTransmitterDelegate

extension BluetoothPeripheralsViewController: BluetoothTransmitterDelegate {
    
    func didConnectTo(bluetoothTransmitter: BluetoothTransmitter) {
        
        updateRow(for: bluetoothPeripheralManager.getBluetoothPeripheral(for: bluetoothTransmitter))
        
    }
    
    func didDisconnectFrom(bluetoothTransmitter: BluetoothTransmitter) {
        
        updateRow(for: bluetoothPeripheralManager.getBluetoothPeripheral(for: bluetoothTransmitter))
        
    }
    
    func deviceDidUpdateBluetoothState(state: CBManagerState, bluetoothTransmitter: BluetoothTransmitter) {
        
        // when bluetooth status changes to powered off, the device, if connected, will disconnect, however didDisConnect doesn't get call (looks like an error in iOS) - so let's reload the cell that shows the connection status, this will refresh the cell
        if state == CBManagerState.poweredOff {
            updateRow(for: bluetoothPeripheralManager.getBluetoothPeripheral(for: bluetoothTransmitter))
        }
        
    }
    
}



