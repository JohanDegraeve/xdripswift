import UIKit

final class BluetoothPeripheralNavigationController: UINavigationController {
    
    // set the status bar content colour to light to match new darker theme
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
    
    // MARK:- private properties
    
    /// reference to coreDataManager
    private var coreDataManager:CoreDataManager?
    
    /// a bluetoothPeripheralManager
    private weak var bluetoothPeripheralManager: BluetoothPeripheralManaging!

    /// provider for the current active sensor (injected by RootViewController)
    public weak var sensorProvider: ActiveSensorProviding?

    // Apply the provider to any child VC that can accept it
    private func applyProvider(to viewController: UIViewController) {
        if let bluetoothPeripheralViewController = viewController as? BluetoothPeripheralViewController {
            bluetoothPeripheralViewController.sensorProvider = sensorProvider
            // Immediately refresh so the row isn't blank until the first timer tick
            DispatchQueue.main.async {
                bluetoothPeripheralViewController.updateTransmitterReadSuccess()
                bluetoothPeripheralViewController.tableView.reloadSections(IndexSet(integer: 0), with: .none)
            }
        }
    }
    
    // MARK:- public functions
    
    /// configure
    public func configure(coreDataManager: CoreDataManager, bluetoothPeripheralManager: BluetoothPeripheralManaging) {
        
        // initalize private properties
        self.coreDataManager = coreDataManager
        self.bluetoothPeripheralManager = bluetoothPeripheralManager
        
    }
    
    // MARK: - overrides
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        delegate = self
        // Ensure existing children receive the provider immediately
        viewControllers.forEach { applyProvider(to: $0) }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        
        // remove titles from tabbar items
        self.tabBarController?.cleanTitles()
        
    }
    
    override func viewWillAppear(_ animated: Bool) {
    
        // restrict rotation of this Navigation Controller to just portrait
        (UIApplication.shared.delegate as! AppDelegate).restrictRotation = .portrait
        
    }
    
}

extension BluetoothPeripheralNavigationController: UINavigationControllerDelegate {
    func navigationController(_ navigationController: UINavigationController, willShow viewController: UIViewController, animated: Bool) {
        
        if let bluetoothPeripheralsViewController = viewController as? BluetoothPeripheralsViewController, let coreDataManager = coreDataManager {
            bluetoothPeripheralsViewController.configure(coreDataManager: coreDataManager, bluetoothPeripheralManager: bluetoothPeripheralManager)
        }
        // Forward the provider to detail controller(s)
        applyProvider(to: viewController)
    }
}

