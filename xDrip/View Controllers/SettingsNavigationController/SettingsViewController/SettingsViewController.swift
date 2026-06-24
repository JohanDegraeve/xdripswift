//
//  SettingsViewController.swift
//  xdrip
//
//  Created by Johan Degraeve.
//  Copyright © 2026 Johan Degraeve. All rights reserved.
//

import SwiftUI
import UIKit

/// Retained only because the storyboard still creates this initial child before SwiftUI is installed.
final class SettingsViewController: UIViewController {}

extension SettingsViewController {
    public enum SegueIdentifiers: String {
        case settingsToAlertTypeSettings
        case settingsToAlertSettings
        case settingsToM5StackSettings
        case settingsToSchedule
        case settingsToLoopDelaySchedule
    }
}

final class SettingsHostingController: PortraitLockedHostingController<AnyView> {
    private let router: SettingsRouter
    private let presenter: SettingsActionPresenter
    private let listModel: SettingsListModel
    private let coreDataManager: CoreDataManager?
    private let soundPlayer: SoundPlayer?
    private var progressBar: ProgressBarViewController?

    init(coreDataManager: CoreDataManager?, soundPlayer: SoundPlayer?) {
        let router = SettingsRouter()
        let presenter = SettingsActionPresenter(router: router)
        let sections = SettingsListFactory.makeRootSections(
            coreDataManager: coreDataManager,
            presenter: presenter
        )
        let listModel = SettingsListModel(sections: sections)

        self.router = router
        self.presenter = presenter
        self.listModel = listModel
        self.coreDataManager = coreDataManager
        self.soundPlayer = soundPlayer

        super.init(rootView: AnyView(SettingsView(listModel: listModel, presenter: presenter)))

        title = Texts_SettingsView.screenTitle
        navigationItem.largeTitleDisplayMode = .automatic

        presenter.attach(controller: self)
        attachControllerToViewModels()
        configureRouter()
    }

    @objc required dynamic init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

private extension SettingsHostingController {
    /// Gives the old Settings view models a UIKit controller and reload callbacks.
    /// This keeps their existing message, reload and navigation hooks working while
    /// the rows are rendered by SwiftUI.
    func attachControllerToViewModels() {
        SettingsListFactory.attach(controller: self, sections: listModel.sections, listModel: listModel)
    }

    /// Connects router closures to the UIKit hosting controller so old segue-style
    /// Settings actions can push the correct SwiftUI child view.
    func configureRouter() {
        router.openAlertTypes = { [weak self] in
            self?.openAlertTypes()
        }

        router.openAlerts = { [weak self] in
            self?.openAlerts()
        }

        router.openM5Stack = { [weak self] in
            self?.openM5Stack()
        }

        router.openTimeSchedule = { [weak self] timeSchedule in
            self?.openTimeSchedule(timeSchedule)
        }

        router.openLoopDelaySchedule = { [weak self] in
            self?.openLoopDelaySchedule()
        }

        router.presentShareFile = { [weak self] url in
            self?.presentShareFile(url)
        }

        router.showProgress = { [weak self] progress in
            self?.showProgress(progress)
        }
    }

    /// Opens the alert type Settings flow using the new SwiftUI hosting controller.
    func openAlertTypes() {
        guard let coreDataManager = coreDataManager, let soundPlayer = soundPlayer else { return }

        let viewController = AlertTypesSettingsHostingController(
            coreDataManager: coreDataManager,
            soundPlayer: soundPlayer
        )
        navigationController?.pushViewController(viewController, animated: true)
    }

    /// Opens the alarm Settings flow using the new SwiftUI hosting controller.
    func openAlerts() {
        guard let coreDataManager = coreDataManager else { return }

        let viewController = AlertsSettingsHostingController(coreDataManager: coreDataManager)
        navigationController?.pushViewController(viewController, animated: true)
    }

    /// Builds the M5Stack child Settings list and pushes it as a SwiftUI screen.
    /// This mirrors the main Settings setup because M5Stack is still made from
    /// several old section view models.
    func openM5Stack() {
        let screen = SettingsScreen(title: Texts_SettingsView.m5StackSettingsViewScreenTitle) { presenter in
            SettingsListFactory.makeM5StackSections(presenter: presenter)
        }

        pushSettingsScreen(screen, parentRouter: router)
    }

    /// Opens the SwiftUI schedule editor for rows that still pass a TimeSchedule
    /// through the old SettingsSelectedRowAction sender.
    func openTimeSchedule(_ timeSchedule: TimeSchedule) {
        let viewController = TimeScheduleHostingController(timeSchedule: timeSchedule)
        navigationController?.pushViewController(viewController, animated: true)
    }

    /// Opens the loop delay editor and injects the shared Settings navigation
    /// actions so its child editors push from the side like the rest of Settings.
    func openLoopDelaySchedule() {
        let viewController = PortraitLockedHostingController(rootView: AnyView(LoopDelayScheduleView()))
        viewController.title = Texts_SettingsView.loopDelaysScreenTitle
        viewController.navigationItem.largeTitleDisplayMode = .automatic
        viewController.rootView = AnyView(LoopDelayScheduleView()
            .environment(\.settingsNavigationActions, viewController.settingsNavigationActions())
        )

        navigationController?.pushViewController(viewController, animated: true)
    }

    /// Presents the standard iOS share sheet for files created by Settings actions.
    func presentShareFile(_ url: URL) {
        let activityViewController = UIActivityViewController(activityItems: [url], applicationActivities: [])
        present(activityViewController, animated: true)
    }

    /// Shows, updates or hides the old progress overlay while a Settings action is
    /// exporting a file. The progress controller is kept because the old export
    /// code already reports ProgressBarStatus values.
    func showProgress(_ progress: ProgressBarStatus<URL>?) {
        if progressBar == nil {
            let progressBar = ProgressBarViewController()
            progressBar.start(onParent: self)
            self.progressBar = progressBar
        }

        guard let progress else {
            progressBar?.end()
            progressBar = nil
            return
        }

        progressBar?.update(status: progress)

        if progress.complete {
            progressBar = nil
        }
    }
}
