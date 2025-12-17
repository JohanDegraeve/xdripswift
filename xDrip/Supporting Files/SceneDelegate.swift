//
//  SceneDelegate.swift
//  xdrip
//
//  Created by Paul Plant on 17/10/25.
//  Copyright © 2025 Johan Degraeve. All rights reserved.
//

import UIKit

// Set up the window, load the initial view controller, and handle any quick action used to launch the app
class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    
    /// the quickActionsManager instance needed to process the shortcut items received
    private let quickActionsManager = QuickActionsManager()

    /// Set up the window, load the initial view controller, and handle any quick action used to launch the app
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = (scene as? UIWindowScene) else { return }
        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = UIStoryboard(name: "Main", bundle: nil).instantiateInitialViewController()
        self.window = window
        window.makeKeyAndVisible()
        
        // Set up the window, load the initial view controller, and handle any quick action used to launch the app
        if let type = connectionOptions.shortcutItem?.type, let quickActionType = QuickActionType(rawValue: type) {
            quickActionsManager.handleQuickAction(quickActionType)
        }
    }
    
    /// Set up the window, load the initial view controller, and handle any quick action used to launch the app
    func windowScene(_ windowScene: UIWindowScene, performActionFor shortcutItem: UIApplicationShortcutItem, completionHandler: @escaping (Bool) -> Void) {
        // Set up the window, load the initial view controller, and handle any quick action used to launch the app
        if let quickActionType = QuickActionType(rawValue: shortcutItem.type) {
            quickActionsManager.handleQuickAction(quickActionType)
        }
        completionHandler(true)
    }
}
