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
    public weak var sensorProvider: ActiveSensorProviding? {
        didSet {
            viewControllers.forEach { applyProvider(to: $0) }
            installSwiftUIBluetoothPeripheralsRootIfNeeded()
        }
    }

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

        installSwiftUIBluetoothPeripheralsRootIfNeeded()
        
    }
    
    // MARK: - overrides
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        delegate = self
        // Ensure existing children receive the provider immediately
        viewControllers.forEach { applyProvider(to: $0) }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        // remove titles from tabbar items
        self.tabBarController?.cleanTitles()
        
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    
        // restrict rotation of this Navigation Controller to just portrait
        (UIApplication.shared.delegate as! AppDelegate).restrictRotation = .portrait

        configureNavigationBarAppearance()
        
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

private extension BluetoothPeripheralNavigationController {
    func configureNavigationBarAppearance() {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = ConstantsUI.listBackGroundUIColor
        appearance.shadowColor = nil
        appearance.titleTextAttributes = [.foregroundColor: UIColor.white]
        appearance.largeTitleTextAttributes = [.foregroundColor: UIColor.white]

        navigationBar.barStyle = .black
        navigationBar.isTranslucent = false
        navigationBar.barTintColor = ConstantsUI.listBackGroundUIColor
        navigationBar.tintColor = .yellow
        navigationBar.prefersLargeTitles = true
        navigationBar.titleTextAttributes = [.foregroundColor: UIColor.white]
        navigationBar.largeTitleTextAttributes = [.foregroundColor: UIColor.white]
        navigationBar.standardAppearance = appearance
        navigationBar.scrollEdgeAppearance = appearance
        navigationBar.compactAppearance = appearance
    }

    func installSwiftUIBluetoothPeripheralsRootIfNeeded() {
        guard let coreDataManager = coreDataManager, let bluetoothPeripheralManager = bluetoothPeripheralManager else {
            return
        }

        if viewControllers.first is BluetoothPeripheralsHostingController {
            return
        }

        setViewControllers([
            BluetoothPeripheralsHostingController(
                coreDataManager: coreDataManager,
                bluetoothPeripheralManager: bluetoothPeripheralManager,
                sensorProvider: sensorProvider
            )
        ], animated: false)
    }
}
