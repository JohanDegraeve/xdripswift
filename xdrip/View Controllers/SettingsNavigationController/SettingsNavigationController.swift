import UIKit

// defining this class because I want to be able to setup the uiviewcontrollers that are  managed by this uinavigationcontroller
final class SettingsNavigationController: UINavigationController {
    
    // set the status bar content colour to light to match new darker theme
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
    
    // MARK:- private properties
    
    /// coredatamanager
    private var coreDataManager:CoreDataManager?
    
    /// reference to soundPlayer
    private var soundPlayer:SoundPlayer?
    
    // MARK:- public functions
    
    /// configure
    public func configure(coreDataManager:CoreDataManager, soundPlayer:SoundPlayer) {
        
        self.coreDataManager = coreDataManager
        self.soundPlayer = soundPlayer
        
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
        
    }

}

extension SettingsNavigationController:UINavigationControllerDelegate {
    func navigationController(_ navigationController: UINavigationController, willShow viewController: UIViewController, animated: Bool) {
        
        if let settingsViewController = viewController as? SettingsViewController {
            settingsViewController.configure(coreDataManager: coreDataManager, soundPlayer: soundPlayer)
        }
    }
}
