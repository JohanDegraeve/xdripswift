//
//  TreatmentsNavigationController.swift
//  xdrip
//
//  Created by Paul Plant on 18/6/26.
//  Copyright © 2026 Johan Degraeve. All rights reserved.
//

import UIKit

final class TreatmentsNavigationController: UINavigationController {

    // set the status bar content colour to light to match new darker theme
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }

    // MARK: - private properties

    /// reference to coreDataManager
    private var coreDataManager: CoreDataManager!

    // MARK: - public functions

    /// configure
    public func configure(coreDataManager: CoreDataManager) {
        self.coreDataManager = coreDataManager

        installSwiftUITreatmentsRootIfNeeded()
    }

    // MARK: - overrides

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        // remove titles from tabbar items
        self.tabBarController?.cleanTitles()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // restrict rotation of this Navigation Controller to just portrait
        (UIApplication.shared.delegate as! AppDelegate).restrictRotation = .portrait

        if let navigationBar = navigationBar as UINavigationBar? {
            navigationBar.barStyle = .black
            navigationBar.isTranslucent = true
            navigationBar.barTintColor = .black
            navigationBar.prefersLargeTitles = true
            navigationBar.titleTextAttributes = [NSAttributedString.Key.foregroundColor: UIColor.white]
            navigationBar.largeTitleTextAttributes = [NSAttributedString.Key.foregroundColor: UIColor.white]
        }
    }

    // MARK: - private functions

    private func installSwiftUITreatmentsRootIfNeeded() {
        guard let coreDataManager = coreDataManager else {
            return
        }

        if viewControllers.first is TreatmentsHostingController {
            return
        }

        setViewControllers([TreatmentsHostingController(coreDataManager: coreDataManager)], animated: false)
    }
}
