//
//  SettingsView.swift
//  xdrip
//
//  Created by Paul Plant on 22/6/26.
//  Copyright © 2026 Johan Degraeve. All rights reserved.
//

import SwiftUI
import UIKit

// This is the SwiftUI version of the main Settings screen. It still uses the old
// section view models for the actual Settings logic, but renders the rows and
// routes the actions through the new shared SwiftUI helpers.
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

            return SettingsSectionModel(id: section.rawValue, viewModel: viewModel)
        }
    }

    /// Builds the M5Stack child sections using the same old view model bridge as
    /// the main Settings list.
    static func makeM5StackSections(presenter: SettingsActionPresenter) -> [SettingsSectionModel] {
        M5StackSettingsSection.allCases.map { section in
            let viewModel = section.viewModel(coreDataManager: nil)
            configure(viewModel: viewModel, presenter: presenter)

            return SettingsSectionModel(id: section.rawValue, viewModel: viewModel)
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

struct M5StackSettingsView: View {
    @ObservedObject var listModel: SettingsListModel
    @ObservedObject var presenter: SettingsActionPresenter

    var body: some View {
        SettingsListView(
            listModel: listModel,
            presenter: presenter,
            title: Texts_SettingsView.m5StackSettingsViewScreenTitle
        )
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
