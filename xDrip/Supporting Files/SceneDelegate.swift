//
//  SceneDelegate.swift
//  xdrip
//
//  Created by Paul Plant on 17/10/25.
//  Copyright © 2025 Johan Degraeve. All rights reserved.
//

import SwiftUI
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
        window.rootViewController = makeRootViewController()
        self.window = window
        window.makeKeyAndVisible()
        
        // Set up the window, load the initial view controller, and handle any quick action used to launch the app
        if let type = connectionOptions.shortcutItem?.type, let quickActionType = QuickActionType(rawValue: type) {
            quickActionsManager.handleQuickAction(quickActionType)
        }
    }

    /// Creates the native SwiftUI tab shell around the existing Home service coordinator.
    /// The storyboard now constructs only RootViewController; no UIKit tab or navigation
    /// controller participates in the root hierarchy.
    private func makeRootViewController() -> UIViewController {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)

        guard let rootViewController = storyboard.instantiateViewController(
            withIdentifier: "RootViewController"
        ) as? RootViewController else {
            fatalError("The Main storyboard does not contain RootViewController")
        }

        let stateModel = RootTabStateModel()
        let tabTitles = RootTabTitles(
            home: localizedTabTitle(key: "acW-dT-cKf.title", fallback: "Home"),
            treatments: localizedTabTitle(key: "Jgh-Nb-wg6.title", fallback: Texts_TreatmentsView.treatmentsTitle),
            bluetooth: localizedTabTitle(key: "sgT-p5-hUt.title", fallback: "Bluetooth"),
            settings: localizedTabTitle(key: "cPa-gy-q4n.title", fallback: Texts_SettingsView.screenTitle)
        )

        rootViewController.configure(rootTabStateModel: stateModel)

        let hostingController = RootTabHostingController(rootView: RootTabView(
            stateModel: stateModel,
            rootViewController: rootViewController,
            tabTitles: tabTitles
        ))
        hostingController.view.backgroundColor = .black

        return hostingController
    }

    private func localizedTabTitle(key: String, fallback: String) -> String {
        NSLocalizedString(key, tableName: "Main", bundle: .main, value: fallback, comment: "")
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
