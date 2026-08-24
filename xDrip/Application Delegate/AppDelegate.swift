import UIKit
import OSLog

class AppDelegate: UIResponder, UIApplicationDelegate {
    
    // MARK: - Properties
    
    /// the quickActionsManager instance needed to process the shortcut items received
    private let quickActionsManager = QuickActionsManager()
    
    /// Orientations currently allowed by the active SwiftUI tab.
    static var supportedOrientations: UIInterfaceOrientationMask = .portrait
    
    private var log = OSLog(subsystem: ConstantsLog.subSystem, category: ConstantsLog.categoryAppDelegate)
    
    // MARK: - Application Life Cycle
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        trace("****************************************", log: log, category: ConstantsLog.categoryAppDelegate, type: .info)
        trace("*** in didFinishLaunchingWithOptions ***", log: log, category: ConstantsLog.categoryAppDelegate, type: .info)
        trace("****************************************", log: log, category: ConstantsLog.categoryAppDelegate, type: .info)

        if let shortcutItem = launchOptions?[.shortcutItem] as? UIApplicationShortcutItem,
           let quickActionType = QuickActionType(rawValue: shortcutItem.type) {
            quickActionsManager.handleQuickAction(quickActionType)
        }

        return true
    }

    /// used to allow/prevent the specific views from changing orientation when rotating the device
    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask
    {
        return AppDelegate.supportedOrientations
    }
    
    // Handle Quick Actions
    func application(_ application: UIApplication, performActionFor shortcutItem: UIApplicationShortcutItem, completionHandler: @escaping (Bool) -> Void) {
        if let quickActionType = QuickActionType(rawValue: shortcutItem.type) {
            quickActionsManager.handleQuickAction(quickActionType)
        }
        
        completionHandler(true)
    }
    
}
