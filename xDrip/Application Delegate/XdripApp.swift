//
//  XdripApp.swift
//  xdrip
//
//  Created by Paul Plant on 12/7/26.
//  Copyright © 2026 Johan Degraeve. All rights reserved.
//

import SwiftUI

/// SwiftUI application entry point.
///
/// RootApplicationCoordinator owns the long-lived application services, while RootTabView owns
/// all root presentation and navigation. AppDelegate remains attached only for iOS callbacks that
/// do not yet have a SwiftUI equivalent, such as supported orientations and Home Screen actions.
@main @MainActor struct XdripApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var stateModel: RootTabStateModel

    private let applicationCoordinator: RootApplicationCoordinator
    private let tabTitles: RootTabTitles

    init() {
        let applicationCoordinator = RootApplicationCoordinator()
        let stateModel = RootTabStateModel()

        self.applicationCoordinator = applicationCoordinator
        self.tabTitles = RootTabTitles(
            home: NSLocalizedString("rootTab.home", tableName: "RootTab", bundle: .main, value: "Home", comment: "Home tab title."),
            treatments: NSLocalizedString("rootTab.treatments", tableName: "RootTab", bundle: .main, value: "Treatments", comment: "Treatments tab title."),
            devices: NSLocalizedString("rootTab.devices", tableName: "RootTab", bundle: .main, value: "Devices", comment: "Devices tab title."),
            settings: NSLocalizedString("rootTab.settings", tableName: "RootTab", bundle: .main, value: "Settings", comment: "Settings tab title.")
        )
        _stateModel = StateObject(wrappedValue: stateModel)

        applicationCoordinator.start(rootTabStateModel: stateModel)
    }

    var body: some Scene {
        WindowGroup {
            RootTabView(
                stateModel: stateModel,
                applicationCoordinator: applicationCoordinator,
                tabTitles: tabTitles
            )
            .onOpenURL(perform: stateModel.receiveIncomingBackup)
        }
    }
}
