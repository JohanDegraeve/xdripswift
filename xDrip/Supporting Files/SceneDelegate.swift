//
//  SceneDelegate.swift
//  xdrip
//
//  Created by Paul Plant on 17/10/25.
//  Copyright © 2025 Johan Degraeve. All rights reserved.
//

import UIKit

// added to fix the "UIScene lifecycle will soon be required. Failure to adopt will result in an assert in the future." debugger warning since iOS26/Xcode26
class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = (scene as? UIWindowScene) else { return }
        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = UIStoryboard(name: "Main", bundle: nil).instantiateInitialViewController()
        self.window = window
        window.makeKeyAndVisible()
    }
}
