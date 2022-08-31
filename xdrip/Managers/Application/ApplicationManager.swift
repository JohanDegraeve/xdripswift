import UIKit

/// class defines methods to allow running of closures when app comes to foreground or to background
class ApplicationManager {

    // MARK: - private properties
    
    /// list of closures to run when app enters background
    private var closuresToRunWhenAppDidEnterBackground = [String : (() -> ())]()
    
    /// list of closures to run when app enters background
    private var closuresToRunWhenAppWillEnterForeground = [String : (() -> ())]()
    
    /// list of closures to run when app will terminate
    private var closuresToRunWhenAppWillTerminate = [String : (() -> ())]()
    
    // MARK: - public properties
    
    /// access to shared instance of ApplicationManager
    static let shared = ApplicationManager()
    
    // MARK: - initializer
    
    /// init is private, to avoid creation
    private init() {
        
        // setup notification handling
        setupNotificationHandling()
        
        // add here to closures to update UserDefaults.standard.appInForeGround
        
        closuresToRunWhenAppWillEnterForeground[UserDefaults.Key.appInForeGround.rawValue] = {
            UserDefaults.standard.appInForeGround = true
        }
        closuresToRunWhenAppDidEnterBackground[UserDefaults.Key.appInForeGround.rawValue] = {
            UserDefaults.standard.appInForeGround = false
        }
        
    }
    
    // MARK: - public functions
    
    /// adds closure to run identified by key, when app moved to background
    ///
    /// closures are stored in a dictionary, key is the identifier
    func addClosureToRunWhenAppDidEnterBackground(key:String, closure:@escaping () -> ()) {
        closuresToRunWhenAppDidEnterBackground[key] = closure
    }
    
    /// adds closure to run identified by key, when app moved to foreground
    ///
    /// closures are stored in a dictionary, key is the identifier
    func addClosureToRunWhenAppWillEnterForeground(key:String, closure:@escaping () -> ()) {
        closuresToRunWhenAppWillEnterForeground[key] = closure
    }
    
    /// adds closure to run identified by key, when app will terminate
    ///
    /// closures are stored in a dictionary, key is the identifier
    func addClosureToRunWhenAppWillTerminate(key:String, closure:@escaping () -> ()) {
        closuresToRunWhenAppWillTerminate[key] = closure
    }
    
    /// removes closure to run identified by key, when app moved to background
    ///
    /// closures are stored in a dictionary, key is the identifier
    func removeClosureToRunWhenAppDidEnterBackground(key:String) {
        closuresToRunWhenAppDidEnterBackground[key] = nil
    }
    
    /// removes closure to run identified by key, when app moved to foreground
    ///
    /// closures are stored in a dictionary, key is the identifier
    func removeClosureToRunWhenAppWillEnterForeground(key:String) {
        closuresToRunWhenAppWillEnterForeground[key] = nil
    }
    
    /// removes closure to run identified by key, when app will terminate
    ///
    /// closures are stored in a dictionary, key is the identifier
    func removeClosureToRunWhenAppWillTerminate(key:String) {
        closuresToRunWhenAppWillTerminate[key] = nil
    }
    
    // MARK: - private helper functions
    
    private func setupNotificationHandling() {
        
        /// define notification center
        let notificationCenter = NotificationCenter.default
        
        /// add observer for did enter background
        notificationCenter.addObserver(self, selector: #selector(runWhenAppDidEnterBackground(_:)), name: UIApplication.didEnterBackgroundNotification, object: nil)
        
        /// add observer for will enter foreground
        notificationCenter.addObserver(self, selector: #selector(runWhenAppWillEnterForeground(_:)), name: UIApplication.willEnterForegroundNotification, object: nil)
        
        /// add observer for will terminate
        notificationCenter.addObserver(self, selector: #selector(runWhenAppWillTerminate(_:)), name: UIApplication.willTerminateNotification, object: nil)
        
    }
    
    @objc private func runWhenAppDidEnterBackground(_ : Notification) {
        // run the closures
        for closure in closuresToRunWhenAppDidEnterBackground {
            closure.value()
        }
    }

    @objc private func runWhenAppWillEnterForeground(_ : Notification) {
        // run the closures
        for closure in closuresToRunWhenAppWillEnterForeground {
            closure.value()
        }
    }

    @objc private func runWhenAppWillTerminate(_ : Notification) {
        // run the closures
        for closure in closuresToRunWhenAppWillTerminate {
            closure.value()
        }
    }
}
