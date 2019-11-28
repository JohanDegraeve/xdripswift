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
    private weak var bluetoothPeripheralManager: BluetoothPeripheralManaging?

    /// list of bluetoothPeripheral's
    private var bluetoothPeripherals: [BluetoothPeripheral] = []

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
    private func updateRow(forBluetoothPeripheral bluetoothPeripheral: BluetoothPeripheral) {
        
        if let index = bluetoothPeripherals.firstIndex(of: bluetoothPeripheral) {
            tableView.reloadRows(at: [IndexPath(row: index, section: 0)], with: .none)
        }

    }
    
    /// initializes bluetoothPeripherals
    ///  array
    private func initializeBluetoothPeripherals() {
        
        if let bluetoothPeripheralManager = bluetoothPeripheralManager {
            m5Stacks = bluetoothPeripheralManager.bluetoothPeripherals()
            
            for m5Stack in bluetoothPeripherals {
                bluetoothPeripheralManager.m5StackBluetoothTransmitter(forBluetoothPeripheral: m5Stack, createANewOneIfNecesssary: false)?.m5StackBluetoothTransmitterDelegateVariable = self
            }
            
        } else {// should never happen or it would be a coding error, but let's assign to empty string
            bluetoothPeripherals = []
        }
    }

}

// MARK: - extensions

// MARK: extension UITableViewDataSource and UITableViewDelegate

extension BluetoothPeripheralsViewController: UITableViewDataSource, UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        
        // add 1 for the row that will show help info
        return bluetoothPeripherals.count + 1
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        guard let cell = tableView.dequeueReusableCell(withIdentifier: SettingsTableViewCell.reuseIdentifier, for: indexPath) as? SettingsTableViewCell else { fatalError("Unexpected Table View Cell") }
        
        // the last row is the help info
        if indexPath.row == bluetoothPeripherals.count {
            
            cell.textLabel?.text = Texts_BluetoothPeripheralsView.m5StackSoftWareHelpCellText
            cell.detailTextLabel?.text = nil
            cell.accessoryType = .disclosureIndicator
            return cell
            
        }
        
        // textLabel should be the userdefinedname of the M5Stack, or if userdefinedname == nil, then the address
        cell.textLabel?.text = bluetoothPeripherals[indexPath.row].m5StackName?.userDefinedName
        if cell.textLabel?.text == nil {
            cell.textLabel?.text = bluetoothPeripherals[indexPath.row].address
        }
        
        // detail is the connection status
        cell.detailTextLabel?.text = Text_BluetoothPeripheralView.notConnected // start with not connected
        if let bluetoothTransmitter = bluetoothPeripheralManager?.m5StackBluetoothTransmitter(forBluetoothPeripheral: m5Stacks[indexPath.row], createANewOneIfNecesssary: false) {
            
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
        if indexPath.row == bluetoothPeripherals.count {

            let alert = UIAlertController(title: Texts_HomeView.info, message: Texts_BluetoothPeripheralsView.m5StackSoftWareHelpText + " " + ConstantsM5Stack.githubURLM5Stack, actionHandler: nil)
            
            self.present(alert, animated: true, completion: nil)
            
        } else {

            self.performSegue(withIdentifier: BluetoothPeripheralViewController.SegueIdentifiers.BluetoothPeripheralsToBluetoothPeripheralSegueIdentifier.rawValue, sender: bluetoothPeripherals[indexPath.row])

        }
        
    }
    
}

// MARK: extension M5StackBluetoothDelegate

extension BluetoothPeripheralsViewController: M5StackBluetoothDelegate {
    
    func isAskingForAllParameters(m5Stack: M5Stack) {
        // viewcontroller doesn't use this
    }
    
    func isReadyToReceiveData(m5Stack: M5Stack) {
        // viewcontroller doesn't use this
    }
    
    func newBlePassWord(newBlePassword: String, forM5Stack m5Stack: M5Stack) {
        
        // blePassword is also saved in BluetoothPerpheralManager, tant pis
        m5Stack.blepassword = newBlePassword
        
    }
    
    func authentication(success: Bool, forM5Stack m5Stack: M5Stack) {
        // no further handling, means when this view is open, user won't see that authentication is failing
    }
    
    func blePasswordMissing(forM5Stack m5Stack: M5Stack) {
       // no further handling, means when this view is open, user won't see that ble password is missing
    }
    
    func m5StackResetRequired(forM5Stack m5Stack: M5Stack) {
        // no further handling, means when this view is open, user won't see that reset is required
    }
    
    func didConnect(forM5Stack m5Stack: M5Stack?, address: String?, name: String?, bluetoothTransmitter: M5StackBluetoothTransmitter) {
        
        if let m5Stack = m5Stack {
            updateRow(forM5Stack: m5Stack)
        }
        
    }
    
    func didDisconnect(forM5Stack m5Stack: M5Stack) {
        
        updateRow(forM5Stack: m5Stack)

    }
    
    func deviceDidUpdateBluetoothState(state: CBManagerState, forM5Stack m5Stack: M5Stack) {
        
        // when bluetooth status changes to powered off, the device, if connected, will disconnect, however didDisConnect doesn't get call (looks like an error in iOS) - so let's reload the cell that shows the connection status, this will refresh the cell
        if state == CBManagerState.poweredOff {
            updateRow(forM5Stack: m5Stack)
        }

    }
    
    func error(message: String) {
        // no further handling, means when this view is open, user won't see the error message
    }
    
    
}



