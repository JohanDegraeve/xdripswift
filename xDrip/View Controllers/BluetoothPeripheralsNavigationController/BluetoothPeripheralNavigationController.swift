import UIKit

final class BluetoothPeripheralNavigationController: UINavigationController {
    // set the status bar content colour to light to match new darker theme
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }

    // MARK: - Private Properties

    /// reference to coreDataManager
    private var coreDataManager: CoreDataManager?

    /// a bluetoothPeripheralManager
    private weak var bluetoothPeripheralManager: BluetoothPeripheralManaging!

    /// provider for the current active sensor (injected by RootViewController)
    public weak var sensorProvider: ActiveSensorProviding? {
        didSet {
            installSwiftUIBluetoothPeripheralsRootIfNeeded()
        }
    }
    // MARK: - Public Functions

    /// configure
    public func configure(coreDataManager: CoreDataManager, bluetoothPeripheralManager: BluetoothPeripheralManaging) {
        // initalize private properties
        self.coreDataManager = coreDataManager
        self.bluetoothPeripheralManager = bluetoothPeripheralManager

        installSwiftUIBluetoothPeripheralsRootIfNeeded()
    }

    // MARK: - Overrides

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        // remove titles from tabbar items
        tabBarController?.cleanTitles()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // restrict rotation of this Navigation Controller to just portrait
        (UIApplication.shared.delegate as? AppDelegate)?.restrictRotation = .portrait

        configureNavigationBarAppearance()
    }
}

private extension BluetoothPeripheralNavigationController {
    func configureNavigationBarAppearance() {
        navigationBar.barStyle = .black
        navigationBar.isTranslucent = true
        navigationBar.barTintColor = .black
        navigationBar.tintColor = .yellow
        navigationBar.prefersLargeTitles = true
        navigationBar.titleTextAttributes = [.foregroundColor: UIColor.white]
        navigationBar.largeTitleTextAttributes = [.foregroundColor: UIColor.white]
    }

    func installSwiftUIBluetoothPeripheralsRootIfNeeded() {
        guard let coreDataManager = coreDataManager, let bluetoothPeripheralManager = bluetoothPeripheralManager else {
            return
        }

        if let bluetoothPeripheralsHostingController = viewControllers.first as? BluetoothPeripheralsHostingController {
            bluetoothPeripheralsHostingController.update(sensorProvider: sensorProvider)
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
