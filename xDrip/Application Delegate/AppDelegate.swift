import UIKit
import OSLog

class AppDelegate: UIResponder, UIApplicationDelegate {
    
    // MARK: - Properties
    
    /// Orientations currently allowed by the active SwiftUI tab.
    static var supportedOrientations: UIInterfaceOrientationMask = .portrait
    
    private var log = OSLog(subsystem: ConstantsLog.subSystem, category: ConstantsLog.categoryAppDelegate)
    
    // MARK: - Application Life Cycle
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        trace("****************************************", log: log, category: ConstantsLog.categoryAppDelegate, type: .info)
        trace("*** in didFinishLaunchingWithOptions ***", log: log, category: ConstantsLog.categoryAppDelegate, type: .info)
        trace("****************************************", log: log, category: ConstantsLog.categoryAppDelegate, type: .info)

        return true
    }

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        // SwiftUI's scene lifecycle delivers Home Screen actions to a scene delegate,
        // not the legacy application-delegate launch/shortcut callbacks.
        let configuration = connectingSceneSession.configuration
        configuration.delegateClass = QuickActionsSceneDelegate.self
        return configuration
    }

    /// used to allow/prevent the specific views from changing orientation when rotating the device
    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask
    {
        return AppDelegate.supportedOrientations
    }
    
}

/// Receives shortcuts while SwiftUI continues to own the scene's window and content.
final class QuickActionsSceneDelegate: NSObject, UIWindowSceneDelegate {
    private let quickActionsManager = QuickActionsManager()

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        // A shortcut that launches the app arrives with the scene connection.
        if let shortcutItem = connectionOptions.shortcutItem,
           let quickActionType = QuickActionType(rawValue: shortcutItem.type) {
            quickActionsManager.handleQuickAction(quickActionType)
        }
    }

    func windowScene(_ windowScene: UIWindowScene, performActionFor shortcutItem: UIApplicationShortcutItem, completionHandler: @escaping (Bool) -> Void) {
        // An existing scene receives the action directly when the app resumes.
        if let quickActionType = QuickActionType(rawValue: shortcutItem.type) {
            quickActionsManager.handleQuickAction(quickActionType)
            completionHandler(true)
        } else {
            completionHandler(false)
        }
    }
}
