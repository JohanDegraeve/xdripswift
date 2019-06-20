import UIKit

// defining this class because I want to be able to setup the uiviewcontrollers that are  managed by this uinavigationcontroller
final class SettingsNavigationController: UINavigationController {
    
    // MARK:- private properties
    
    /// coredatamanager
    private var coreDataManager:CoreDataManager?
    
    /// reference to soundPlayer
    private var soundPlayer:SoundPlayer?
    
    // MARK:- public functions
    
    /// configure
    public func configure(coreDataManager:CoreDataManager?, soundPlayer:SoundPlayer?) {
        
        self.coreDataManager = coreDataManager
        self.soundPlayer = soundPlayer
        
    }
    
    // MARK: - View Life Cycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        delegate = self
    }
    
}

extension SettingsNavigationController:UINavigationControllerDelegate {
    func navigationController(_ navigationController: UINavigationController, willShow viewController: UIViewController, animated: Bool) {
        
        if let settingsViewController = viewController as? SettingsViewController {
            settingsViewController.configure(coreDataManager: coreDataManager, soundPlayer: soundPlayer)
        }
    }
}
