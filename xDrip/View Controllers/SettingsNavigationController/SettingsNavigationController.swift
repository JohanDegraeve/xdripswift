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
        
        // make sure that the developer settings are hidden when the navigation controller is loaded
        // this is needed in case the app was previously force-closed (or crashed) before the timer had a chance to hide them again
        UserDefaults.standard.showDeveloperSettings = false
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        // remove titles from tabbar items
        self.tabBarController?.cleanTitles()
        
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    
        // restrict rotation of this Navigation Controller to just portrait
        (UIApplication.shared.delegate as? AppDelegate)?.restrictRotation = .portrait
        
        if let navigationBar = navigationBar as UINavigationBar? {
            navigationBar.barStyle = .black
            navigationBar.isTranslucent = true
            navigationBar.barTintColor = .black
            navigationBar.tintColor = .yellow
            navigationBar.prefersLargeTitles = true
            navigationBar.titleTextAttributes = [.foregroundColor: UIColor.white]
            navigationBar.largeTitleTextAttributes = [.foregroundColor: UIColor.white]
        }
        
    }

}

private extension SettingsNavigationController {
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
