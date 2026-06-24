//
//  SettingsView.swift
//  xdrip
//
//  Created by Paul Plant on 22/6/26.
//  Copyright © 2026 Johan Degraeve. All rights reserved.
//

import SwiftUI
import UIKit

// This file is the starting point for the SwiftUI Settings screen.
//
// The important idea is that the Settings menu is now built from small section
// providers instead of directly from a table view. SettingsRootSection defines the
// order of the top-level Settings sections, and each case creates the view model
// that owns that section. The view model then exposes its SwiftUI rows through
// settingsRows(sectionID:), which should be near the top of the view model file so
// the row order, row ids and visibility rules are easy to inspect.
//
// Most of the old Settings logic still lives in the existing view models. Row
// titles, detail text, enabled state and tap actions can still come from the old
// settingsRowText, detailedText, isEnabled and onRowSelect functions. The
// nativeSettingsRow helper in SettingsSharedUtilities.swift adapts that existing
// logic into a SwiftUI SettingsRow. This means we can rearrange and group the
// Settings menu without rewriting stable feature logic unless we actually need to.
//
// For new or changed sections, start by editing settingsRows(sectionID:) in the
// relevant view model. Use nativeSettingsRow(...) when the existing row logic
// should be reused. Use a full SettingsRow(...) when the row is now easier to
// describe directly in SwiftUI, for example when it needs custom visibility,
// indicators, colours, a toggle, a text-entry action or a child Settings screen.
//
// Grouped child screens should be opened with SettingsScreen and the
// .settingsScreen row action. A grouped screen is just a title plus one or more
// existing section providers, so sections like Nightscout, HealthKit or Dexcom
// Share can be moved under a future "Services" menu without moving their actual
// logic out of their current view models.
//
// SettingsSharedUtilities.swift contains the shared row model, rendering code,
// navigation bridge and old UIKit-action adapters. SettingsViewController.swift
// owns the UIKit hosting controller and connects the SwiftUI settings screen back
// into the existing navigation stack.
struct SettingsView: View {
    @ObservedObject var listModel: SettingsListModel
    @ObservedObject var presenter: SettingsActionPresenter

    var body: some View {
        SettingsListView(
            listModel: listModel,
            presenter: presenter,
            title: Texts_SettingsView.screenTitle
        )
    }
}

enum SettingsRootSection: Int, CaseIterable, SettingsProtocol {
    case help
    case dataSource
    case general
    case homescreen
    case alarms
    case statistics
    case nightscout
    case dexcom
    case healthkit
    case speak
    case appleWatch
    case calendarEvents
    case contactImage
    case M5stack
    case trace
    case info
    case developer

    /// Creates the old Settings section view model for this SwiftUI section.
    /// The SwiftUI list still asks these view models for row text, detail text,
    /// enabled state and row actions so the existing Settings logic stays in place.
    func viewModel(coreDataManager: CoreDataManager?) -> SettingsViewModelProtocol {
        switch self {
        case .help:
            return SettingsViewHelpSettingsViewModel()
        case .dataSource:
            return SettingsViewDataSourceSettingsViewModel(coreDataManager: coreDataManager)
        case .general:
            return SettingsViewNotificationsSettingsViewModel()
        case .homescreen:
            return SettingsViewHomeScreenSettingsViewModel()
        case .alarms:
            return SettingsViewAlertSettingsViewModel()
        case .statistics:
            return SettingsViewStatisticsSettingsViewModel()
        case .nightscout:
            return SettingsViewNightscoutSettingsViewModel()
        case .dexcom:
            return SettingsViewDexcomShareUploadSettingsViewModel()
        case .healthkit:
            return SettingsViewHealthKitSettingsViewModel()
        case .speak:
            return SettingsViewSpeakSettingsViewModel()
        case .appleWatch:
            return SettingsViewAppleWatchSettingsViewModel()
        case .calendarEvents:
            return SettingsViewCalendarEventsSettingsViewModel()
        case .contactImage:
            return SettingsViewContactImageSettingsViewModel()
        case .M5stack:
            return SettingsViewM5StackSettingsViewModel()
        case .trace:
            return SettingsViewTraceSettingsViewModel()
        case .info:
            return SettingsViewInfoViewModel()
        case .developer:
            return SettingsViewDevelopmentSettingsViewModel()
        }
    }
}

@MainActor
enum SettingsListFactory {
    /// Builds the main Settings sections and wires each old view model into the
    /// SwiftUI presenter before the list is shown.
    static func makeRootSections(
        coreDataManager: CoreDataManager?,
        presenter: SettingsActionPresenter
    ) -> [SettingsSectionModel] {
        SettingsRootSection.allCases.map { section in
            let viewModel = section.viewModel(coreDataManager: coreDataManager)
            configure(viewModel: viewModel, presenter: presenter)

            return SettingsSectionModel(id: section.rawValue, viewModel: viewModel) {
                guard let nativeProvider = viewModel as? SettingsNativeSectionProvider else {
                    fatalError("Settings view model must provide a native Settings section")
                }

                return nativeProvider.settingsSection(sectionID: section.rawValue)
            }
        }
    }

    /// Builds the M5Stack child sections using the same old view model bridge as
    /// the main Settings list.
    static func makeM5StackSections(presenter: SettingsActionPresenter) -> [SettingsSectionModel] {
        M5StackSettingsSection.allCases.map { section in
            let viewModel = section.viewModel(coreDataManager: nil)
            configure(viewModel: viewModel, presenter: presenter)

            return SettingsSectionModel(id: section.rawValue, viewModel: viewModel) {
                guard let nativeProvider = viewModel as? SettingsNativeSectionProvider else {
                    fatalError("M5Stack Settings view model must provide a native Settings section")
                }

                return nativeProvider.settingsSection(sectionID: section.rawValue)
            }
        }
    }

    /// Builds section models from existing native section providers. This is the
    /// common path for grouped Settings screens, where a simple parent row can
    /// open one or more existing sections without moving their logic.
    static func makeSections(
        providers: [SettingsNativeSectionProvider],
        presenter: SettingsActionPresenter
    ) -> [SettingsSectionModel] {
        providers.enumerated().map { offset, viewModel in
            configure(viewModel: viewModel, presenter: presenter)

            return SettingsSectionModel(id: offset, viewModel: viewModel) {
                viewModel.settingsSection(sectionID: offset)
            }
        }
    }

    /// Gives all legacy-backed section view models the UIKit host and reload
    /// closures they still expect while their rows are rendered in SwiftUI.
    static func attach(
        controller: UIViewController,
        sections: [SettingsSectionModel],
        listModel: SettingsListModel
    ) {
        sections.forEach { section in
            guard let viewModel = section.legacyViewModel else { return }

            viewModel.storeUIViewController(uIViewController: controller)
            viewModel.storeRowReloadClosure { row in
                DispatchQueue.main.async {
                    listModel.reload(.row(section: section.id, row: row))
                }
            }
            viewModel.storeSectionReloadClosure {
                DispatchQueue.main.async {
                    listModel.reload(.section(section.id))
                }
            }
        }
    }

    /// Connects callbacks from the old Settings view models to the SwiftUI presenter.
    /// This replaces the old table view reload/message calls with SwiftUI refreshes
    /// and SwiftUI alerts.
    static func configure(viewModel: SettingsViewModelProtocol, presenter: SettingsActionPresenter) {
        viewModel.storeMessageHandler { title, message in
            DispatchQueue.main.async {
                presenter.showMessage(title: title, message: message)
            }
        }

        viewModel.storeRowReloadClosure { _ in
            DispatchQueue.main.async {
                presenter.objectWillChange.send()
            }
        }

        viewModel.storeSectionReloadClosure {
            DispatchQueue.main.async {
                presenter.objectWillChange.send()
            }
        }
    }
}

enum M5StackSettingsSection: Int, CaseIterable, SettingsProtocol {
    case general
    case wifi
    case bluetooth

    /// Creates the old M5Stack Settings view model for the selected subsection.
    /// The unused Core Data parameter is kept so this enum still matches SettingsProtocol.
    func viewModel(coreDataManager: CoreDataManager?) -> SettingsViewModelProtocol {
        switch self {
        case .general:
            return SettingsViewM5StackGeneralSettingsViewModel()
        case .wifi:
            return SettingsViewM5StackWiFiSettingsViewModel()
        case .bluetooth:
            return SettingsViewM5StackBluetoothSettingsViewModel()
        }
    }
}
