import UIKit

final class BluetoothPeripheralNavigationController: UINavigationController {
    
    // MARK:- private properties
    
    /// reference to coreDataManager
    private var coreDataManager:CoreDataManager?
    
    /// a bluetoothPeripheralManager
    private weak var bluetoothPeripheralManager: BluetoothPeripheralManaging!
    
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
    }
    
}

extension BluetoothPeripheralNavigationController: UINavigationControllerDelegate {
    func navigationController(_ navigationController: UINavigationController, willShow viewController: UIViewController, animated: Bool) {
        
        if let bluetoothPeripheralsViewController = viewController as? BluetoothPeripheralsViewController, let coreDataManager = coreDataManager {
            bluetoothPeripheralsViewController.configure(coreDataManager: coreDataManager, bluetoothPeripheralManager: bluetoothPeripheralManager)
        }
    }
}

