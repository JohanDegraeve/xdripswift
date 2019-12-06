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
            guard let vc = segue.destination as? BluetoothPeripheralViewController, let coreDataManager = coreDataManager, let bluetoothPeripheralManager = bluetoothPeripheralManager else {
                fatalError("In BluetoothPeripheralsViewController, prepare for segue, viewcontroller is not M5StackViewController or coreDataManager is nil or bluetoothPeripheralManager is nil" )
            }
            
            vc.configure(bluetoothPeripheral: sender as? BluetoothPeripheral, coreDataManager: coreDataManager, bluetoothPeripheralManager: bluetoothPeripheralManager)
            
        }
    }
    


    // MARK: private helper functions
    
    /// user clicked add button
    private func addButtonAction() {
        
        /// go to screen to add a new M5Stack
        self.performSegue(withIdentifier: BluetoothPeripheralViewController.SegueIdentifiers.BluetoothPeripheralsToBluetoothPeripheralSegueIdentifier.rawValue, sender: nil)

    }
    
    private func setupView() {
        setupTableView()
    }
    
    /// setup datasource, delegate, seperatorInset
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
        
        if let index = bluetoothPeripheralManager.getBluetoothPeripherals().firstIndex(where: {$0.getAddress() == bluetoothPeripheral.getAddress()}) {
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
        
        // add 1 for the row that will show help info
        return bluetoothPeripheralManager.getBluetoothPeripherals().count + 1
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        guard let cell = tableView.dequeueReusableCell(withIdentifier: SettingsTableViewCell.reuseIdentifier, for: indexPath) as? SettingsTableViewCell else { fatalError("Unexpected Table View Cell") }
        
        // the last row is the help info
        if indexPath.row == bluetoothPeripheralManager.getBluetoothPeripherals().count {
            
            cell.textLabel?.text = Texts_BluetoothPeripheralsView.m5StackSoftWareHelpCellText
            cell.detailTextLabel?.text = nil
            cell.accessoryType = .disclosureIndicator
            return cell
            
        }
        
        // textLabel should be the user defined alias of the BluetoothPeripheral, or if user defined alias == nil, then the address
        cell.textLabel?.text = bluetoothPeripheralManager.getBluetoothPeripherals()[indexPath.row].getAlias()
        if cell.textLabel?.text == nil {
            cell.textLabel?.text = bluetoothPeripheralManager.getBluetoothPeripherals()[indexPath.row].getAddress()
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
        // only 1 section, namely the list of M5Stacks
        return 1
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        tableView.deselectRow(at: indexPath, animated: true)
       
        // the last row is the help info
        if indexPath.row == bluetoothPeripheralManager.getBluetoothPeripherals().count {

            let alert = UIAlertController(title: Texts_HomeView.info, message: Texts_BluetoothPeripheralsView.m5StackSoftWareHelpText + " " + ConstantsM5Stack.githubURLM5Stack, actionHandler: nil)
            
            self.present(alert, animated: true, completion: nil)
            
        } else {

            self.performSegue(withIdentifier: BluetoothPeripheralViewController.SegueIdentifiers.BluetoothPeripheralsToBluetoothPeripheralSegueIdentifier.rawValue, sender: bluetoothPeripheralManager.getBluetoothPeripherals()[indexPath.row])

        }
        
    }
    
}

// MARK: extension M5StackBluetoothTransmitterDelegate

extension BluetoothPeripheralsViewController: M5StackBluetoothTransmitterDelegate {

    func isAskingForAllParameters(m5StackBluetoothTransmitter: M5StackBluetoothTransmitter) {
        // viewcontroller doesn't use this
    }
    
    func isReadyToReceiveData(m5StackBluetoothTransmitter: M5StackBluetoothTransmitter) {
        // viewcontroller doesn't use this
    }
    
    func newBlePassWord(newBlePassword: String, m5StackBluetoothTransmitter: M5StackBluetoothTransmitter) {
        
        // blePassword is also saved in BluetoothPeripheralManager, possibly it will be saved two times but that's no issue
        if let m5Stack = bluetoothPeripheralManager.getBluetoothPeripheral(for: m5StackBluetoothTransmitter) as? M5Stack {
            m5Stack.blepassword = newBlePassword
        }
        
    }
    
    func authentication(success: Bool, m5StackBluetoothTransmitter: M5StackBluetoothTransmitter) {
        // no further handling, means when this view is open, user won't see that authentication is failing
    }
    
    func blePasswordMissing(m5StackBluetoothTransmitter: M5StackBluetoothTransmitter) {
       // no further handling, means when this view is open, user won't see that ble password is missing
    }
    
    func m5StackResetRequired(m5StackBluetoothTransmitter: M5StackBluetoothTransmitter) {
        // no further handling, means when this view is open, user won't see that reset is required
    }
    
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
    
    func error(message: String) {
        // no further handling, means when this view is open, user won't see the error message
    }
    
    
}



