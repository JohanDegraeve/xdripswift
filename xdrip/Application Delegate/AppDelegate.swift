import UIKit
import CoreData
import OSLog

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    
    // MARK: - Properties
    
    var window: UIWindow?

    private let quickActionsManager = QuickActionsManager()
    
    /// allow the orientation to be changed as per the settings for each individual view controller
    var restrictRotation:UIInterfaceOrientationMask = .all
    
    private var log = OSLog(subsystem: ConstantsLog.subSystem, category: ConstantsLog.categoryAppDelegate)
    
    private var _gradientLayer = CAGradientLayer()
    private var titleView: UIImageView = UIImageView(image: UIImage(named: "ShuggahTitle")!)
    private var _gradView = UIView()
    private var _view: UIView!
    private var _titleAspect: CGFloat!
    
    // MARK: - Private D.R.Y
    
    private func showCover(flag: Bool) {
        
        // Check we're not trying to add the _gradView twice
        if let _ = _gradView.superview, flag == true { return }
        
        _gradView.frame = _view.frame
        _gradientLayer.frame = _view.frame
        if flag {
            // Just to be sure...
            _gradView.removeFromSuperview()
            NSLayoutConstraint.fixAllSides(of: _gradView, to: _view)
            // Remove and reapply to take care of aspect change with orientation
            _gradView.removeConstraints(_gradView.constraints)
            
            // Assume it's in portrait:
            let _width = NSLayoutConstraint.fix(constraint: .width, of: titleView, toSameOfView: _gradView, multiplier: 0.2)
            let _height = NSLayoutConstraint.fix(constraint: .height, of: titleView, to: .width, ofView: titleView, multiplier: _titleAspect)
            let _centreX = NSLayoutConstraint.fix(constraint: .centerX, of: titleView, toSameOfView: _gradView)
            let _centreY = NSLayoutConstraint.fix(constraint: .centerY, of: titleView, toSameOfView: _gradView)
            NSLayoutConstraint.activate([_centreX, _centreY])
            
        } else if _gradView.superview == nil {
            //It's already off the hierarchy
            return
        }
        
        _gradView.alpha = (!flag).rawCGFloatValue
        _view.addSubview(_gradView)
        UIView.animate(withDuration: 0.2) {
            self._gradView.alpha = flag.rawCGFloatValue
        } completion: { finishedFlag in
            if !flag {
                self._gradView.removeFromSuperview()
            }
        }
        
    }
    
    // MARK: - Application Life Cycle
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        
        trace("in didFinishLaunchingWithOptions", log: log, category: ConstantsLog.categoryAppDelegate, type: .info)
        
        _gradientLayer.colors = [
            UIColor(red: 0.002, green: 0.290, blue: 0.831, alpha: 1.00).cgColor,
            UIColor(red: 0.853, green: 0.908, blue: 0.406, alpha: 1.00).cgColor
        ]
        _view = UIApplication.shared.delegate?.window??.rootViewController?.view
        
        if _view == nil { return true }
        
        // Make sure they're all gone
        //_gradView.removeConstraints(_gradView.constraints)
        // Fix the sides (this accounts for portrait or landscape orientation changes during operation)
        NSLayoutConstraint.fixAllSides(of: _gradView, to: _view)
        _gradientLayer.frame = _view.frame
        _gradientLayer.mask = nil
        _gradView.layer.insertSublayer(_gradientLayer, at: 0)
        titleView.translatesAutoresizingMaskIntoConstraints = false
        titleView.tintColor = .white
        _gradView.addSubview(titleView)
        _titleAspect = titleView.image!.size.height / titleView.image!.size.width
        return true
        
    }

    /// used to allow/prevent the specific views from changing orientation when rotating the device
    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask
    {
        return self.restrictRotation
    }
    
    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
        showCover(flag: true)
    }
    
    func applicationDidEnterBackground(_ application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    }
    
    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
        showCover(flag: false)
    }
    
    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
        showCover(flag: false)
    }
    
    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
        // Saves changes in the application's managed object context before the application terminates.
    }
  
    // Handle Quick Actions
    func application(_ application: UIApplication, performActionFor shortcutItem: UIApplicationShortcutItem, completionHandler: @escaping (Bool) -> Void) {
        if let quickActionType = QuickActionType(rawValue: shortcutItem.type) {
            quickActionsManager.handleQuickAction(quickActionType)
        }
        
        completionHandler(true)
    }
}

