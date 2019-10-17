import UIKit
import CoreBluetooth

/// uiviewcontroller to show list of M5Stacks, first uiviewcontroller when clicking the M5Stack tab
final class M5StacksViewController: UIViewController {
    
    // MARK: - IBOutlet's and IBAction's

    @IBOutlet weak var tableView: UITableView!
    
    @IBAction func addButtonAction(_ sender: UIBarButtonItem) {
        addButtonAction()
    }
    
    @IBAction func unwindToM5StacksViewController (segue: UIStoryboardSegue) {
        
        // reinitialise m5Stacks because we're coming back from M5StackViewController where an M5Stack may have been added or deleted
        initializeM5Stacks()

        // reload the table
        tableView.reloadSections(IndexSet(integer: 0), with: .none)
    }
 
    // MARK:- private properties
    
    /// reference to coreDataManager
    private var coreDataManager:CoreDataManager?
    
    /// an m5stackManager
    private weak var m5StackManager: M5StackManaging?

    /// list of M5Stack's
    private var m5Stacks: [M5Stack] = []

    // MARK: public functions
    
    /// configure
    public func configure(coreDataManager: CoreDataManager, m5StackManager: M5StackManaging) {
        
        // initalize private properties
        self.coreDataManager = coreDataManager
        self.m5StackManager = m5StackManager
        initializeM5Stacks()
        
    }

    // MARK: overrides
    
    override func viewDidLoad() {
        
        super.viewDidLoad()
        
        title = Texts_M5StacksView.screenTitle
        
        setupView()
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        
        guard let segueIdentifier = segue.identifier else {
            fatalError("In M5StacksViewController, prepare for segue, Segue had no identifier")
        }
        
        guard let segueIdentifierAsCase = M5StackViewController.SegueIdentifiers(rawValue: segueIdentifier) else {
            fatalError("In M5StacksViewController, segueIdentifierAsCase could not be initialized")
        }
        
        switch segueIdentifierAsCase {
            
        case M5StackViewController.SegueIdentifiers.M5StacksToM5StackSegueIdentifier:
            guard let vc = segue.destination as? M5StackViewController, let coreDataManager = coreDataManager, let m5StackManager = m5StackManager else {
                fatalError("In M5StacksViewController, prepare for segue, viewcontroller is not M5StackViewController or coreDataManager is nil or m5StackManager is nil" )
            }
            
            vc.configure(m5Stack: sender as? M5Stack, coreDataManager: coreDataManager, m5StackManager: m5StackManager)
        }
    }
    


    // MARK: private helper functions
    
    /// user clicked add button
    private func addButtonAction() {
        
        /// go to screen to add a new M5Stack
        self.performSegue(withIdentifier: M5StackViewController.SegueIdentifiers.M5StacksToM5StackSegueIdentifier.rawValue, sender: nil)

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
            fatalError("in M5StacksViewController, coreDataManager is nil")
        }
    }
    
    /// calls tableView.reloadRows for the row where forM5Stack is shown
    private func updateRow(forM5Stack m5Stack: M5Stack) {
        
        if let index = m5Stacks.firstIndex(of: m5Stack) {
            tableView.reloadRows(at: [IndexPath(row: index, section: 0)], with: .none)
        }

    }
    
    /// initializes m5Stacks array
    private func initializeM5Stacks() {
        
        if let m5StackManager = m5StackManager {
            m5Stacks = m5StackManager.m5Stacks()
            
            for m5Stack in m5Stacks {
                m5StackManager.m5StackBluetoothTransmitter(forM5stack: m5Stack, createANewOneIfNecesssary: false)?.m5StackBluetoothTransmitterDelegateVariable = self
            }
            
        } else {// should never happen or it would be a coding error, but let's assign to empty string
            m5Stacks = []
        }
    }

}

// MARK: - UITableViewDataSource and UITableViewDelegate protocol Methods

extension M5StacksViewController: UITableViewDataSource, UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        
        // add 1 for the row that will show help info
        return m5Stacks.count + 1
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        guard let cell = tableView.dequeueReusableCell(withIdentifier: SettingsTableViewCell.reuseIdentifier, for: indexPath) as? SettingsTableViewCell else { fatalError("Unexpected Table View Cell") }
        
        // the last row is the help info
        if indexPath.row == m5Stacks.count {
            
            cell.textLabel?.text = Texts_M5StacksView.m5StackSoftWareHelpCellText
            cell.detailTextLabel?.text = nil
            cell.accessoryType = .disclosureIndicator
            return cell
            
        }
        
        // textLabel should be the userdefinedname of the M5Stack, or if userdefinedname == nil, then the address
        cell.textLabel?.text = m5Stacks[indexPath.row].m5StackName?.userDefinedName
        if cell.textLabel?.text == nil {
            cell.textLabel?.text = m5Stacks[indexPath.row].address
        }
        
        // detail is the connection status
        cell.detailTextLabel?.text = Texts_M5StackView.notConnected // start with not connected
        if let bluetoothTransmitter = m5StackManager?.m5StackBluetoothTransmitter(forM5stack: m5Stacks[indexPath.row], createANewOneIfNecesssary: false) {
            
            if let connectionStatus = bluetoothTransmitter.getConnectionStatus(), connectionStatus == CBPeripheralState.connected {
                cell.detailTextLabel?.text = Texts_M5StackView.connected
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
        if indexPath.row == m5Stacks.count {

            let alert = UIAlertController(title: Texts_HomeView.info, message: Texts_M5StacksView.m5StackSoftWareHelpText + " " + ConstantsM5Stack.githubURLM5Stack, actionHandler: nil)
            
            self.present(alert, animated: true, completion: nil)
            
        } else {

            self.performSegue(withIdentifier: M5StackViewController.SegueIdentifiers.M5StacksToM5StackSegueIdentifier.rawValue, sender: m5Stacks[indexPath.row])

        }
        
    }
    
}

extension M5StacksViewController: M5StackBluetoothDelegate {
    
    func isAskingForAllParameters(m5Stack: M5Stack) {
        // viewcontroller doesn't use this
    }
    
    func isReadyToReceiveData(m5Stack: M5Stack) {
        // viewcontroller doesn't use this
    }
    
    func newBlePassWord(newBlePassword: String, forM5Stack m5Stack: M5Stack) {
        
        // blePassword is also saved in M5StackManager, tant pis
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
    }
    
    func error(message: String) {
        // no further handling, means when this view is open, user won't see the error message
    }
    
    
}



