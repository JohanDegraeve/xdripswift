import UIKit

final class M5StackNavigationController: UINavigationController {
    
    // MARK:- private properties
    
    // MARK:- public functions
    
    /// configure
    public func configure() {
        // not configuring anything now but I expect something will need to be configured
        
    }
    
    // MARK: - View Life Cycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        delegate = self
    }
    
}

extension M5StackNavigationController: UINavigationControllerDelegate {
    func navigationController(_ navigationController: UINavigationController, willShow viewController: UIViewController, animated: Bool) {
        
        if let m5StackNavigationController = viewController as? M5StackNavigationController {
            m5StackNavigationController.configure()
        }
    }
}

