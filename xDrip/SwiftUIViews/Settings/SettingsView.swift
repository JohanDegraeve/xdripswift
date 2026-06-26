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
            title: Texts_SettingsView.screenTitle,
            titleDisplayMode: .large,
            headerView: { AnyView(SettingsAppBannerView()) }
        )
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: SettingsOnlineHelp.open) {
                    Image(systemName: "questionmark.circle")
                }
                .tint(.yellow)
                .accessibilityLabel(Texts_SettingsView.showOnlineHelp)
            }
        }
    }
}

private struct SettingsAppBannerView: View {
    var body: some View {
        HStack(spacing: 18) {
            appIcon

            VStack(alignment: .leading, spacing: 4) {
                Text(ConstantsHomeView.applicationName)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundStyle(Color(.colorPrimary))

                Text(Texts_SettingsView.appBannerVersion(appVersion))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color(.colorSecondary))
            }
        }
        .padding(.vertical, 4)
    }

    private var appIcon: some View {
        Image("AppIconPreview")
            .resizable()
        .frame(width: 58, height: 58)
        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
    }
}

enum SettingsAppInfo {
    static func releaseNotesURL(version: String) -> URL? {
        let releaseURL = ConstantsHomeView.gitHubURL + "/releases/tag/" + version
        let fallbackURL = ConstantsHomeView.gitHubURL + "/releases"

        return URL(string: releaseURL) ?? URL(string: fallbackURL)
    }
}

enum SettingsRootSection: Int, CaseIterable, SettingsProtocol {
    case dataSource
    case glucoseDisplay
    case alertsAndNotifications
    case sharingAndServices
    case about
    case advanced

    var iconSymbolName: String {
        switch self {
        case .dataSource:
            return ConstantsSettingsIcons.dataSourceSettingsIcon
        case .glucoseDisplay:
            return ConstantsSettingsIcons.glucoseDisplaySettingsIcon
        case .alertsAndNotifications:
            return ConstantsSettingsIcons.notificationsSettingsIcon
        case .sharingAndServices:
            return ConstantsSettingsIcons.sharingAndServicesSettingsIcon
        case .about:
            return ConstantsSettingsIcons.infoSettingsIcon
        case .advanced:
            return ConstantsSettingsIcons.developerSettingsIcon
        }
    }

    /// Creates the old Settings section view model for this SwiftUI section.
    /// The SwiftUI list still asks these view models for row text, detail text,
    /// enabled state and row actions so the existing Settings logic stays in place.
    func viewModel(coreDataManager: CoreDataManager?) -> SettingsViewModelProtocol {
        switch self {
        case .dataSource:
            return SettingsViewDataSourceSettingsViewModel(coreDataManager: coreDataManager)
        case .glucoseDisplay:
            return SettingsViewGroupedSettingsViewModel.glucoseDisplay()
        case .alertsAndNotifications:
            return SettingsViewGroupedSettingsViewModel.alertsAndNotifications()
        case .sharingAndServices:
            return SettingsViewGroupedSettingsViewModel.sharingAndServices()
        case .about:
            return SettingsViewInfoViewModel()
        case .advanced:
            return SettingsViewDevelopmentSettingsViewModel()
        }
    }
}

private enum SettingsOnlineHelp {
    static func open() {
        // get the 2 character language code for the App Locale, i.e. "en", "es", "nl", "fr"
        // if the user has the app in a language other than English and they have the "auto translate" option selected, then load the help pages through Google Translate
        // important to check that the URLs actually exist in ConstantsHomeView before trying to open them
        if let languageCode = NSLocale.current.language.languageCode?.identifier, languageCode != ConstantsHomeView.onlineHelpBaseLocale && UserDefaults.standard.translateOnlineHelp {
            guard let url = URL(string: ConstantsHomeView.onlineHelpURLTranslated1 + languageCode + ConstantsHomeView.onlineHelpURLTranslated2) else { return }

            UIApplication.shared.open(url)
        } else {
            // so the user is running the app in English or they don't want to translate so let's just load it directly
            guard let url = URL(string: ConstantsHomeView.onlineHelpURL) else { return }

            UIApplication.shared.open(url)
        }
    }
}

struct SettingsGroupedRow {
    let id: String
    let title: String
    var detail: (() -> String?)? = nil
    let settingsScreen: () -> SettingsScreen
}

/// SettingsViewGroupedSettingsViewModel creates the new parent sections in the
/// Settings menu. Each row opens a child SettingsScreen made from existing
/// section providers, so the old feature logic stays in the original view model.
struct SettingsViewGroupedSettingsViewModel: SettingsViewModelProtocol, SettingsNativeSectionProvider {
    private let title: String
    private let rows: [SettingsGroupedRow]

    static func glucoseDisplay() -> SettingsViewGroupedSettingsViewModel {
        SettingsViewGroupedSettingsViewModel(
            title: Texts_SettingsView.glucoseDisplaySectionTitle,
            rows: [
                SettingsGroupedRow(
                    id: "glucoseDisplay.homeScreen",
                    title: Texts_SettingsView.sectionTitleHomeScreen,
                    settingsScreen: {
                        SettingsScreen(
                            title: Texts_SettingsView.sectionTitleHomeScreen,
                            providers: { [SettingsViewHomeScreenSettingsViewModel(rowGroup: .homeScreen)] }
                        )
                    }
                ),
                SettingsGroupedRow(
                    id: "glucoseDisplay.glucoseRanges",
                    title: Texts_SettingsView.glucoseRangesSectionTitle,
                    settingsScreen: {
                        SettingsScreen(
                            title: Texts_SettingsView.glucoseRangesSectionTitle,
                            providers: { [SettingsViewHomeScreenSettingsViewModel(rowGroup: .glucoseRanges)] }
                        )
                    }
                ),
                SettingsGroupedRow(
                    id: "glucoseDisplay.statistics",
                    title: Texts_SettingsView.sectionTitleStatistics,
                    settingsScreen: {
                        SettingsScreen(
                            title: Texts_SettingsView.sectionTitleStatistics,
                            providers: { [SettingsViewStatisticsSettingsViewModel()] }
                        )
                    }
                )
            ]
        )
    }

    static func alertsAndNotifications() -> SettingsViewGroupedSettingsViewModel {
        SettingsViewGroupedSettingsViewModel(
            title: Texts_SettingsView.alertsAndNotificationsSectionTitle,
            rows: [
                SettingsGroupedRow(
                    id: "alertsAndNotifications.notifications",
                    title: Texts_SettingsView.sectionTitleNotifications,
                    settingsScreen: {
                        SettingsScreen(
                            title: Texts_SettingsView.sectionTitleNotifications,
                            providers: { [SettingsViewNotificationsSettingsViewModel()] }
                        )
                    }
                ),
                SettingsGroupedRow(
                    id: "alertsAndNotifications.alerts",
                    title: Texts_SettingsView.sectionTitleAlerting,
                    settingsScreen: {
                        SettingsScreen(
                            title: Texts_SettingsView.sectionTitleAlerting,
                            providers: { [SettingsViewAlertSettingsViewModel()] }
                        )
                    }
                )
            ]
        )
    }

    static func sharingAndServices() -> SettingsViewGroupedSettingsViewModel {
        SettingsViewGroupedSettingsViewModel(
            title: Texts_SettingsView.sharingAndServicesSectionTitle,
            rows: [
                SettingsGroupedRow(
                    id: "sharingServices.nightscout",
                    title: Texts_SettingsView.sectionTitleNightscout,
                    detail: {
                        UserDefaults.standard.nightscoutEnabled ? Texts_Common.enabled : Texts_Common.disabled
                    },
                    settingsScreen: {
                        SettingsScreen(
                            title: Texts_SettingsView.sectionTitleNightscout,
                            providers: { [SettingsViewNightscoutSettingsViewModel()] }
                        )
                    }
                ),
                SettingsGroupedRow(
                    id: "sharingServices.dexcomShare",
                    title: Texts_SettingsView.sectionTitleDexcomShareUpload,
                    detail: {
                        UserDefaults.standard.uploadReadingstoDexcomShare ? Texts_Common.enabled : Texts_Common.disabled
                    },
                    settingsScreen: {
                        SettingsScreen(
                            title: Texts_SettingsView.sectionTitleDexcomShareUpload,
                            providers: { [SettingsViewDexcomShareUploadSettingsViewModel()] }
                        )
                    }
                ),
                SettingsGroupedRow(
                    id: "sharingServices.healthKit",
                    title: Texts_SettingsView.sectionTitleHealthKit,
                    detail: {
                        UserDefaults.standard.storeReadingsInHealthkit ? Texts_Common.enabled : Texts_Common.disabled
                    },
                    settingsScreen: {
                        SettingsScreen(
                            title: Texts_SettingsView.sectionTitleHealthKit,
                            providers: { [SettingsViewHealthKitSettingsViewModel()] }
                        )
                    }
                ),
                SettingsGroupedRow(
                    id: "sharingServices.calendarEvents",
                    title: Texts_SettingsView.calendarEventsSectionTitle,
                    detail: {
                        UserDefaults.standard.createCalendarEvent ? Texts_Common.enabled : Texts_Common.disabled
                    },
                    settingsScreen: {
                        SettingsScreen(
                            title: Texts_SettingsView.calendarEventsSectionTitle,
                            providers: { [SettingsViewCalendarEventsSettingsViewModel()] }
                        )
                    }
                ),
                SettingsGroupedRow(
                    id: "sharingServices.contactImage",
                    title: Texts_SettingsView.contactImageSectionTitle,
                    detail: {
                        UserDefaults.standard.enableContactImage ? Texts_Common.enabled : Texts_Common.disabled
                    },
                    settingsScreen: {
                        SettingsScreen(
                            title: Texts_SettingsView.contactImageSectionTitle,
                            providers: { [SettingsViewContactImageSettingsViewModel()] }
                        )
                    }
                ),
                SettingsGroupedRow(
                    id: "sharingServices.osAidLoopShare",
                    title: Texts_SettingsView.osAidLoopShareSectionTitle,
                    detail: {
                        UserDefaults.standard.loopShareType.description
                    },
                    settingsScreen: {
                        SettingsScreen(
                            title: Texts_SettingsView.osAidLoopShareSectionTitle,
                            providers: { [SettingsViewDevelopmentSettingsViewModel(rowGroup: .osAidLoopShare)] }
                        )
                    }
                ),
                SettingsGroupedRow(
                    id: "sharingServices.speakReadings",
                    title: Texts_SettingsView.sectionTitleSpeak,
                    detail: {
                        UserDefaults.standard.speakReadings ? Texts_Common.enabled : Texts_Common.disabled
                    },
                    settingsScreen: {
                        SettingsScreen(
                            title: Texts_SettingsView.sectionTitleSpeak,
                            providers: { [SettingsViewSpeakSettingsViewModel()] }
                        )
                    }
                ),
                SettingsGroupedRow(
                    id: "sharingServices.m5Stack",
                    title: "M5Stack",
                    settingsScreen: {
                        SettingsScreen(title: "M5Stack") { presenter in
                            SettingsListFactory.makeM5StackSections(presenter: presenter)
                        }
                    }
                )
            ]
        )
    }

    func sectionTitle() -> String? {
        title
    }

    func settingsRows(sectionID: Int) -> [SettingsRow] {
        rows.map { row in
            SettingsRow(
                id: row.id,
                title: row.title,
                detail: row.detail?(),
                accessory: .disclosure,
                action: .settingsScreen(row.settingsScreen)
            )
        }
    }

    func settingsRowText(index: Int) -> String {
        rows[index].title
    }

    func accessoryType(index: Int) -> UITableViewCell.AccessoryType {
        .disclosureIndicator
    }

    func detailedText(index: Int) -> String? {
        rows[index].detail?()
    }

    func uiView(index: Int) -> UIView? {
        nil
    }

    func numberOfRows() -> Int {
        rows.count
    }

    func onRowSelect(index: Int) -> SettingsSelectedRowAction {
        .nothing
    }

    func isEnabled(index: Int) -> Bool {
        true
    }

    func completeSettingsViewRefreshNeeded(index: Int) -> Bool {
        false
    }

    func storeMessageHandler(messageHandler: @escaping ((String, String) -> Void)) {}

    func storeUIViewController(uIViewController: UIViewController) {}

    func storeRowReloadClosure(rowReloadClosure: @escaping ((Int) -> Void)) {}
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

                let settingsSection = nativeProvider.settingsSection(sectionID: section.rawValue)

                return SettingsSection(
                    title: settingsSection.title,
                    iconSymbolName: section.iconSymbolName,
                    footer: settingsSection.footer,
                    rows: settingsSection.rows
                )
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
