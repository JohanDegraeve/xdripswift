import UIKit

final class M5StackNavigationController: UINavigationController {
    
    // MARK:- private properties
    
    /// reference to coreDataManager
    private var coreDataManager:CoreDataManager?
    
    /// an m5stackManager
    private weak var m5StackManager: M5StackManaging?
    
    // MARK:- public functions
    
    /// configure
    public func configure(coreDataManager: CoreDataManager, m5StackManager: M5StackManaging) {
        
        // initalize private properties
        self.coreDataManager = coreDataManager
        self.m5StackManager = m5StackManager
        
    }
    
    // MARK: - overrides
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        delegate = self
    }
    
}

extension M5StackNavigationController: UINavigationControllerDelegate {
    func navigationController(_ navigationController: UINavigationController, willShow viewController: UIViewController, animated: Bool) {
        
        if let m5StacksViewController = viewController as? M5StacksViewController, let coreDataManager = coreDataManager, let m5StackManager = m5StackManager {
            m5StacksViewController.configure(coreDataManager: coreDataManager, m5StackManager: m5StackManager)
        }
    }
}

