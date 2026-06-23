import UIKit

// defining this class because I want to be able to setup the uiviewcontrollers that are  managed by this uinavigationcontroller
final class SettingsNavigationController: UINavigationController {
    
    // set the status bar content colour to light to match new darker theme
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .portrait
    }

    override var preferredInterfaceOrientationForPresentation: UIInterfaceOrientation {
        return .portrait
    }
    
    // MARK:- private properties
    
    /// coredatamanager
    private var coreDataManager:CoreDataManager?
    
    /// reference to soundPlayer
    private var soundPlayer:SoundPlayer?
    
    // MARK:- public functions
    
    /// Stores the dependencies needed by the SwiftUI Settings root and installs it
    /// once RootViewController has finished wiring the tab.
    public func configure(coreDataManager:CoreDataManager, soundPlayer:SoundPlayer) {
        
        self.coreDataManager = coreDataManager
        self.soundPlayer = soundPlayer

        installSwiftUISettingsRootIfNeeded()
        
    }
    
    // MARK: - View Life Cycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        delegate = self
        
        // make sure that the developer settings are hidden when the navigation controller is loaded
        // this is needed in case the app was previously force-closed (or crashed) before the timer had a chance to hide them again
        UserDefaults.standard.showDeveloperSettings = false
    }
    
    override func viewDidAppear(_ animated: Bool) {
        
        // remove titles from tabbar items
        self.tabBarController?.cleanTitles()
        
    }
    
    override func viewWillAppear(_ animated: Bool) {
    
        // restrict rotation of this Navigation Controller to just portrait
        (UIApplication.shared.delegate as! AppDelegate).restrictRotation = .portrait

        configureNavigationBarAppearance()
        
    }

}

extension SettingsNavigationController:UINavigationControllerDelegate {
    func navigationController(_ navigationController: UINavigationController, willShow viewController: UIViewController, animated: Bool) {
    }
}

private extension SettingsNavigationController {
    /// Applies the dark navigation bar used by the SwiftUI Settings host.
    /// Keeping this in the navigation controller makes pushed Settings screens
    /// inherit the same appearance.
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
        navigationBar.prefersLargeTitles = false
        navigationBar.titleTextAttributes = [.foregroundColor: UIColor.white]
        navigationBar.largeTitleTextAttributes = [.foregroundColor: UIColor.white]
        navigationBar.standardAppearance = appearance
        navigationBar.scrollEdgeAppearance = appearance
        navigationBar.compactAppearance = appearance
    }

    /// Replaces the storyboard Settings child with the SwiftUI Settings root once
    /// the dependencies have been provided by RootViewController.
    func installSwiftUISettingsRootIfNeeded() {
        guard coreDataManager != nil, soundPlayer != nil else {
            return
        }

        if viewControllers.first is SettingsHostingController {
            return
        }

        setViewControllers([
            SettingsHostingController(coreDataManager: coreDataManager, soundPlayer: soundPlayer)
        ], animated: false)
    }
}
