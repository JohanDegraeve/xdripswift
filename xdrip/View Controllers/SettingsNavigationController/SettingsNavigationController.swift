import UIKit

// defining this class because I want to be able to setup the uiviewcontrollers that are  managed by this uinavigationcontroller
final class SettingsNavigationController: UINavigationController {
    
    // MARK:- properties
    
    // coredatamanager
    private var coreDataManager:CoreDataManager?
    
    // MARK:- public functions
    public func configure(coreDataManager:CoreDataManager?) {
        self.coreDataManager = coreDataManager
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
            settingsViewController.configure(coreDataManager: coreDataManager)
        }
    }
}
