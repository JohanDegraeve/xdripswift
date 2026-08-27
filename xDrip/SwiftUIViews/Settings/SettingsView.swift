//
//  SettingsView.swift
//  xdrip
//
//  Created by Paul Plant on 22/6/26.
//  Copyright © 2026 Johan Degraeve. All rights reserved.
//

import SwiftUI
import UIKit
import MessageUI

// This file is the starting point for the Settings screen.
//
// The important idea is that the Settings menu is now built from small section
// providers. SettingsRootSection defines the
// order of the top-level Settings sections, and each case creates the view model
// that owns that section. The view model then exposes its SwiftUI rows through
// settingsRows(sectionID:), which should be near the top of the view model file so
// the row order, row ids and visibility rules are easy to inspect.
//
// Stable Settings logic remains in the existing view models. Row titles, detail
// text, enabled state and tap actions can come from the indexed
// settingsRowText, detailedText, isEnabled and onRowSelect functions. The
// nativeSettingsRow helper adapts that logic into a SettingsRow.
//
// For new or changed sections, start by editing settingsRows(sectionID:) in the
// relevant view model. Use nativeSettingsRow(...) when the existing row logic
// should be reused. Use a full SettingsRow(...) when a row is easier to describe
// directly, for example when it needs custom visibility,
// indicators, colours, a toggle, a text-entry action or a child Settings screen.
//
// Grouped child screens should be opened with SettingsScreen and the
// .settingsScreen row action. A grouped screen is just a title plus one or more
// existing section providers, so sections like Nightscout, HealthKit or Dexcom
// Share can be moved under a future "Services" menu without moving their actual
// logic out of their current view models.
//
// SettingsSharedUtilities.swift contains the shared row model, rendering code and
// native navigation destinations used throughout the Settings flow.

// MARK: - Navigation

/// Owns the Settings navigation path and the system sheets requested by settings actions.
struct SettingsNavigationView: View {
    @StateObject private var router: SettingsRouter
    @StateObject private var presenter: SettingsActionPresenter
    @StateObject private var listModel: SettingsListModel

    private let coreDataManager: CoreDataManager
    private let soundPlayer: SoundPlayer
    private let incomingBackupRequest: IncomingBackupRequest?
    private let consumeIncomingBackup: (UUID) -> Void

    init(
        coreDataManager: CoreDataManager,
        soundPlayer: SoundPlayer,
        selectedFollowerActions: SelectedFollowerActions,
        incomingBackupRequest: IncomingBackupRequest?,
        consumeIncomingBackup: @escaping (UUID) -> Void
    ) {
        let router = SettingsRouter()
        let presenter = SettingsActionPresenter(router: router)
        let sections = SettingsListFactory.makeRootSections(
            coreDataManager: coreDataManager,
            selectedFollowerActions: selectedFollowerActions,
            presenter: presenter
        )

        self.coreDataManager = coreDataManager
        self.soundPlayer = soundPlayer
        self.incomingBackupRequest = incomingBackupRequest
        self.consumeIncomingBackup = consumeIncomingBackup
        _router = StateObject(wrappedValue: router)
        _presenter = StateObject(wrappedValue: presenter)
        _listModel = StateObject(wrappedValue: SettingsListModel(sections: sections))
    }

    var body: some View {
        navigationContent
        .environment(\.settingsNavigationActions, navigationActions)
        .sheet(isPresented: $router.showsTraceEmail) {
            SettingsTraceMailView(isPresented: $router.showsTraceEmail) {
                presenter.showMessage(title: Texts_Common.warning, message: Texts_SettingsView.failedToSendEmail)
            }
        }
        .tint(ConstantsAppColors.navigationTint)
        .colorScheme(.dark)
        .onAppear {
            UserDefaults.standard.showDeveloperSettings = false
            listModel.reload(.all)
            openIncomingBackupIfNeeded()
        }
        .onChange(of: incomingBackupRequest?.id) { _ in
            openIncomingBackupIfNeeded()
        }
        .onChange(of: router.path) { path in
            if path.isEmpty {
                listModel.reload(.all)
            }
        }
    }

    @ViewBuilder private var navigationContent: some View {
        if UIDevice.current.userInterfaceIdiom == .pad {
            NavigationSplitView {
                SettingsIPadSidebarView(listModel: listModel, presenter: presenter)
                    .navigationSplitViewColumnWidth(min: 300, ideal: 350, max: 430)
            } detail: {
                NavigationStack(path: $router.path) {
                    SettingsIPadPlaceholderView()
                        .navigationDestination(for: SettingsRoute.self, destination: destination)
                }
            }
            .navigationSplitViewStyle(.balanced)
        } else {
            NavigationStack(path: $router.path) {
                SettingsView(listModel: listModel, presenter: presenter)
                    .navigationDestination(for: SettingsRoute.self, destination: destination)
            }
        }
    }

    /// Replaces any existing Settings path with the restore screen requested by iOS.
    private func openIncomingBackupIfNeeded() {
        guard let incomingBackupRequest else { return }

        router.path = [SettingsRoute(.incomingBackup(incomingBackupRequest))]
    }

    private var navigationActions: SettingsNavigationActions {
        SettingsNavigationActions { title, content in
            router.show(.custom(title: title, content: content))
        }
    }

    @ViewBuilder private func destination(for route: SettingsRoute) -> some View {
        switch route.destination {
        case let .settingsScreen(settingsScreen):
            SettingsScreenDestinationView(settingsScreen: settingsScreen, presenter: presenter)

        case let .textEntry(textEntry):
            SettingsTextEntryView(textEntry: textEntry, close: router.closeCurrentView)

        case let .selectionList(selectionList):
            SettingsSelectionListView(selectionList: selectionList, close: router.closeCurrentView)

        case let .datePicker(datePicker):
            SettingsDatePickerView(datePicker: datePicker, close: router.closeCurrentView)

        case .alertTypes:
            NativeAlertTypesSettingsView(coreDataManager: coreDataManager, router: router)
                .onlineHelp(.alertsAndNotifications)

        case let .alertTypeEditor(alertType, listViewModel):
            AlertTypeEditorView(
                alertType: alertType,
                coreDataManager: coreDataManager,
                soundPlayer: soundPlayer,
                close: {
                    router.closeCurrentView()
                    listViewModel.reload()
                }
            )

        case .alerts:
            NativeAlertsSettingsView(coreDataManager: coreDataManager, router: router)
                .onlineHelp(.alertsAndNotifications)

        case let .alertEditor(mode, listViewModel):
            AlertEntryEditorView(
                mode: mode,
                coreDataManager: coreDataManager,
                close: {
                    router.closeCurrentView()
                    listViewModel.reload()
                },
                openNewAlert: { newMode in
                    router.show(.alertEditor(newMode, listViewModel))
                }
            )

        case .m5Stack:
            SettingsScreenDestinationView(
                settingsScreen: SettingsScreen(title: Texts_SettingsView.m5StackSettingsViewScreenTitle, onlineHelpTopic: .m5Stack) { presenter in
                    SettingsListFactory.makeM5StackSections(presenter: presenter)
                },
                presenter: presenter
            )

        case let .timeSchedule(timeSchedule):
            TimeScheduleView(timeSchedule: timeSchedule)

        case .loopDelaySchedule:
            LoopDelayScheduleView()

        case let .dataManagement(flow):
            DataManagementView(coreDataManager: coreDataManager, flow: flow)
                .navigationTitle(flow.navigationTitle)
                .navigationBarTitleDisplayMode(.large)
                .onlineHelp(.dataManagement)

        case .troubleshootingLog:
            TroubleshootingLogView(coreDataManager: coreDataManager)

        case let .incomingBackup(request):
            DataManagementView(
                coreDataManager: coreDataManager,
                flow: .restore,
                initialBackupURL: request.url,
                initialBackupDidOpen: { consumeIncomingBackup(request.id) }
            )
                .navigationTitle(DataManagementFlow.restore.navigationTitle)
                .navigationBarTitleDisplayMode(.large)
                .onlineHelp(.dataManagement)

        case let .custom(title, content):
            content(router.closeCurrentView)
                .navigationTitle(title)
                .navigationBarTitleDisplayMode(.inline)
        }
    }
}

/// Calm detail placeholder shown before an iPad Settings category is selected.
private struct SettingsIPadPlaceholderView: View {
    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "gearshape.2")
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(Color(.colorTertiary))

            Text(Texts_SettingsView.screenTitle)
                .font(.title2.weight(.semibold))
                .foregroundStyle(Color(.colorPrimary))

            Text(Texts_SettingsView.selectCategory)
                .font(.body)
                .foregroundStyle(Color(.colorSecondary))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ConstantsUI.listBackGroundColor.ignoresSafeArea())
        .accessibilityElement(children: .combine)
    }
}

/// Adds iPad navigation chrome around the unchanged Settings list. Row construction and styling
/// remain shared with iPhone so the split view cannot introduce platform-specific value colors.
private struct SettingsIPadSidebarView: View {
    @ObservedObject var listModel: SettingsListModel
    @ObservedObject var presenter: SettingsActionPresenter

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Text(Texts_SettingsView.screenTitle)
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(Color(.colorPrimary))

                Spacer()

                OnlineHelpButton(topic: .settings)
                    .font(.title3)
                    .frame(width: 44, height: 44)
                    .buttonStyle(.plain)
                    .foregroundStyle(ConstantsAppColors.toolbarAction)
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 4)

            SettingsView(listModel: listModel, presenter: presenter)
                .frame(maxWidth: 780)
                .frame(maxWidth: .infinity)
        }
        .background(ConstantsUI.listBackGroundColor.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
    }

}

/// Creates a fresh list model for one grouped child Settings screen.
private struct SettingsScreenDestinationView: View {
    @StateObject private var listModel: SettingsListModel
    @ObservedObject private var presenter: SettingsActionPresenter
    private let title: String
    private let onlineHelpTopic: OnlineHelpTopic?
    private let toolbarActions: @MainActor () -> [SettingsToolbarAction]

    init(settingsScreen: SettingsScreen, presenter: SettingsActionPresenter) {
        self.presenter = presenter
        self.title = settingsScreen.title
        self.onlineHelpTopic = settingsScreen.onlineHelpTopic
        self.toolbarActions = settingsScreen.toolbarActions
        _listModel = StateObject(wrappedValue: SettingsListModel(
            sections: settingsScreen.makeSections(presenter)
        ))
    }

    var body: some View {
        SettingsListView(
            listModel: listModel,
            presenter: presenter,
            title: title,
            titleDisplayMode: .large,
            showsSectionHeaders: true
        )
        .onAppear {
            listModel.reload(.all)
        }
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                if let onlineHelpTopic {
                    OnlineHelpButton(topic: onlineHelpTopic)
                }

                ForEach(toolbarActions()) { action in
                    Button(action: action.action) {
                        Image(systemName: action.symbolName)
                    }
                    .tint(action.tint)
                    .disabled(!action.isEnabled())
                    .accessibilityLabel(action.title)
                }
            }
        }
    }
}

// MARK: - Native Destinations

/// Bridges the existing alert-type manager into its native SwiftUI destination.
private struct NativeAlertTypesSettingsView: View {
    @StateObject private var viewModel: AlertTypesSettingsViewModel
    @ObservedObject private var router: SettingsRouter

    init(coreDataManager: CoreDataManager, router: SettingsRouter) {
        self.router = router
        _viewModel = StateObject(wrappedValue: AlertTypesSettingsViewModel(coreDataManager: coreDataManager))
    }

    var body: some View {
        AlertTypesSettingsView(viewModel: viewModel) { alertType in
            router.show(.alertTypeEditor(alertType, viewModel))
        }
        .onAppear(perform: viewModel.reload)
    }
}

/// Bridges the existing alert manager into its native SwiftUI destination.
private struct NativeAlertsSettingsView: View {
    @StateObject private var viewModel: AlertsSettingsViewModel
    @ObservedObject private var router: SettingsRouter

    init(coreDataManager: CoreDataManager, router: SettingsRouter) {
        self.router = router
        _viewModel = StateObject(wrappedValue: AlertsSettingsViewModel(coreDataManager: coreDataManager))
    }

    var body: some View {
        AlertsSettingsView(viewModel: viewModel) { request in
            router.show(.alertEditor(.edit(
                alertEntry: request.alertEntry,
                minimumStart: request.minimumStart,
                maximumStart: request.maximumStart
            ), viewModel))
        }
        .onAppear(perform: viewModel.reload)
    }
}

// MARK: - System Presentation

/// SwiftUI adapter for the system mail composer used to send trace files.
private struct SettingsTraceMailView: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    let onFailure: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(isPresented: $isPresented, onFailure: onFailure)
    }

    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let mailViewController = MFMailComposeViewController()
        mailViewController.mailComposeDelegate = context.coordinator
        mailViewController.setToRecipients([ConstantsTrace.traceFileDestinationAddress])
        mailViewController.setMessageBody(Texts_SettingsView.emailbodyText, isHTML: true)

        let traceFiles = Trace.getTraceFilesInData()
        for (index, traceFile) in traceFiles.0.enumerated() {
            mailViewController.addAttachmentData(
                traceFile as Data,
                mimeType: "text/txt",
                fileName: traceFiles.1[index]
            )
        }

        let appInfo = Trace.getAppInfoFileAsData()
        if let appInfoData = appInfo.0 {
            mailViewController.addAttachmentData(
                appInfoData as Data,
                mimeType: "text/txt",
                fileName: appInfo.1
            )
        }

        return mailViewController
    }

    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) {}

    final class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        @Binding private var isPresented: Bool
        private let onFailure: () -> Void

        init(isPresented: Binding<Bool>, onFailure: @escaping () -> Void) {
            _isPresented = isPresented
            self.onFailure = onFailure
        }

        func mailComposeController(
            _ controller: MFMailComposeViewController,
            didFinishWith result: MFMailComposeResult,
            error: Error?
        ) {
            isPresented = false

            if result == .failed || error != nil {
                onFailure()
            }
        }
    }
}

// MARK: - Root Settings View

/// Displays the root Settings sections supplied by `SettingsListModel`.
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
        .onlineHelp(.settings)
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
    case dataManagement
    case troubleshooting
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
        case .dataManagement:
            return "externaldrive.badge.timemachine"
        case .troubleshooting:
            return ConstantsSettingsIcons.troubleshootingSettingsIcon
        case .about:
            return ConstantsSettingsIcons.infoSettingsIcon
        case .advanced:
            return ConstantsSettingsIcons.developerSettingsIcon
        }
    }

    /// Creates the Settings view model for this root section.
    func viewModel(coreDataManager: CoreDataManager?) -> SettingsViewModelProtocol {
        viewModel(coreDataManager: coreDataManager, selectedFollowerActions: .none)
    }

    func viewModel(
        coreDataManager: CoreDataManager?,
        selectedFollowerActions: SelectedFollowerActions = .none
    ) -> SettingsViewModelProtocol {
        switch self {
        case .dataSource:
            return SettingsViewDataSourceSettingsViewModel(
                coreDataManager: coreDataManager,
                selectedFollowerActions: selectedFollowerActions
            )
        case .glucoseDisplay:
            return SettingsViewGroupedSettingsViewModel.glucoseDisplay()
        case .alertsAndNotifications:
            return SettingsViewGroupedSettingsViewModel.alertsAndNotifications()
        case .sharingAndServices:
            return SettingsViewGroupedSettingsViewModel.sharingAndServices()
        case .dataManagement:
            return SettingsViewDataManagementSettingsViewModel(coreDataManager: coreDataManager)
        case .troubleshooting:
            // Consumer troubleshooting remains visible in the root menu. Developer e-mail reports
            // are intentionally exposed only by Show Advanced in the Advanced Settings section.
            return SettingsViewTraceSettingsViewModel(rowGroup: .troubleshooting)
        case .about:
            return SettingsViewInfoViewModel()
        case .advanced:
            return SettingsViewDevelopmentSettingsViewModel()
        }
    }
}

struct SettingsGroupedRow {
    let id: String
    let title: String
    var isVisible: Bool = true
    var isEnabled: (() -> Bool)? = nil
    var detail: (() -> String?)? = nil
    var detailColor: (() -> Color?)? = nil
    var detailIndicator: (() -> SettingsIndicator?)? = nil
    let settingsScreen: () -> SettingsScreen
}

/// Creates parent Settings sections whose rows open grouped child sections.
struct SettingsViewGroupedSettingsViewModel: SettingsViewModelProtocol, SettingsNativeSectionProvider {
    private let title: String
    private let rows: [SettingsGroupedRow]
    private let leadingRows: () -> [SettingsRow]

    init(title: String, rows: [SettingsGroupedRow], leadingRows: @escaping () -> [SettingsRow] = { [] }) {
        self.title = title
        self.rows = rows.filter(\.isVisible)
        self.leadingRows = leadingRows
    }

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
                            onlineHelpTopic: .glucoseDisplay,
                            providers: {
                                [
                                    SettingsViewHomeScreenSettingsViewModel(rowGroup: .mainChart),
                                    SettingsViewHomeScreenSettingsViewModel(rowGroup: .miniChart),
                                    SettingsViewHomeScreenSettingsViewModel(rowGroup: .sensorLifetime),
                                    SettingsViewHomeScreenSettingsViewModel(rowGroup: .screenLock)
                                ]
                            }
                        )
                    }
                ),
                SettingsGroupedRow(
                    id: "glucoseDisplay.glucoseRanges",
                    title: Texts_SettingsView.glucoseRangesSectionTitle,
                    settingsScreen: {
                        SettingsScreen(
                            title: Texts_SettingsView.glucoseRangesSectionTitle,
                            onlineHelpTopic: .glucoseDisplay,
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
                            onlineHelpTopic: .glucoseDisplay,
                            providers: { [SettingsViewStatisticsSettingsViewModel()] }
                        )
                    }
                )
            ],
            leadingRows: {
                [
                    SettingsRow(
                        id: "display.bloodGlucoseUnit",
                        title: Texts_SettingsView.labelSelectBgUnit,
                        detail: UserDefaults.standard.bloodGlucoseUnitIsMgDl ? Texts_Common.mgdl : Texts_Common.mmol,
                        accessory: .none,
                        control: .menu(options: {
                            [
                                SettingsMenuOption(title: Texts_Common.mgdl, isSelected: UserDefaults.standard.bloodGlucoseUnitIsMgDl),
                                SettingsMenuOption(title: Texts_Common.mmol, isSelected: !UserDefaults.standard.bloodGlucoseUnitIsMgDl)
                            ]
                        }),
                        reloadScope: .all,
                        action: .run {
                            UserDefaults.standard.bloodGlucoseUnitIsMgDl.toggle()
                        }
                    )
                ]
            }
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
                            onlineHelpTopic: .alertsAndNotifications,
                            providers: {
                                [
                                    SettingsViewNotificationsSettingsViewModel(),
                                    SettingsViewNotificationsSettingsViewModel(rowGroup: .appBadge),
                                    SettingsViewNotificationsSettingsViewModel(rowGroup: .liveActivities),
                                    SettingsViewNotificationsSettingsViewModel(rowGroup: .carPlay)
                                ]
                            }
                        )
                    }
                ),
                SettingsGroupedRow(
                    id: "alertsAndNotifications.alerts",
                    title: Texts_SettingsView.sectionTitleAlerting,
                    settingsScreen: {
                        SettingsScreen(
                            title: Texts_SettingsView.sectionTitleAlerting,
                            onlineHelpTopic: .alertsAndNotifications,
                            providers: {
                                [
                                    SettingsViewAlertSettingsViewModel(rowGroup: .alertTypes),
                                    SettingsViewAlertSettingsViewModel(rowGroup: .alerts),
                                    SettingsViewAlertSettingsViewModel(rowGroup: .sensorHealth),
                                    SettingsViewAlertSettingsViewModel(rowGroup: .volumeTests)
                                ]
                            }
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
                        groupedStatusDetail(isEnabled: UserDefaults.standard.nightscoutEnabled)
                    },
                    detailIndicator: {
                        nightscoutConnectionIndicator()
                    },
                    settingsScreen: {
                        SettingsScreen(
                            title: Texts_SettingsView.sectionTitleNightscout,
                            onlineHelpTopic: .nightscoutService,
                            providers: {
                                [
                                    SettingsViewNightscoutSettingsViewModel(rowGroup: .nightscout),
                                    SettingsViewNightscoutSettingsViewModel(rowGroup: .connectionSettings),
                                    SettingsViewNightscoutSettingsViewModel(rowGroup: .actions),
                                    SettingsViewNightscoutSettingsViewModel(rowGroup: .uploadSchedule)
                                ]
                            }
                        )
                    }
                ),
                SettingsGroupedRow(
                    id: "sharingServices.dexcomShare",
                    title: Texts_SettingsView.sectionTitleDexcomShareUpload,
                    detail: {
                        groupedStatusDetail(isEnabled: UserDefaults.standard.uploadReadingstoDexcomShare)
                    },
                    settingsScreen: {
                        SettingsScreen(
                            title: Texts_SettingsView.sectionTitleDexcomShareUpload,
                            onlineHelpTopic: .dexcomShareService,
                            providers: { [SettingsViewDexcomShareUploadSettingsViewModel()] }
                        )
                    }
                ),
                SettingsGroupedRow(
                    id: "sharingServices.healthKit",
                    title: Texts_SettingsView.sectionTitleHealthKit,
                    detail: {
                        groupedStatusDetail(isEnabled: UserDefaults.standard.storeReadingsInHealthkit)
                    },
                    settingsScreen: {
                        SettingsScreen(
                            title: Texts_SettingsView.sectionTitleHealthKit,
                            onlineHelpTopic: .appleHealth,
                            providers: { [SettingsViewHealthKitSettingsViewModel()] }
                        )
                    }
                ),
                SettingsGroupedRow(
                    id: "sharingServices.calendarEvents",
                    title: Texts_SettingsView.calendarEventsSectionTitle,
                    isEnabled: {
                        calendarShareRowIsEnabled()
                    },
                    detail: {
                        calendarShareStatusDetail()
                    },
                    detailIndicator: {
                        calendarShareStatusIndicator()
                    },
                    settingsScreen: {
                        SettingsScreen(
                            title: Texts_SettingsView.calendarEventsSectionTitle,
                            onlineHelpTopic: .calendarShare,
                            providers: {
                                [
                                    SettingsViewCalendarEventsSettingsViewModel(rowGroup: .connection),
                                    SettingsViewCalendarEventsSettingsViewModel(rowGroup: .status),
                                    SettingsViewCalendarEventsSettingsViewModel(rowGroup: .preview),
                                    SettingsViewCalendarEventsSettingsViewModel(rowGroup: .settings)
                                ]
                            }
                        )
                    }
                ),
                SettingsGroupedRow(
                    id: "sharingServices.contactImage",
                    title: Texts_SettingsView.contactImageSectionTitle,
                    detail: {
                        groupedStatusDetail(isEnabled: UserDefaults.standard.enableContactImage)
                    },
                    settingsScreen: {
                        SettingsScreen(
                            title: Texts_SettingsView.contactImageSectionTitle,
                            onlineHelpTopic: .contactImage,
                            providers: { [SettingsViewContactImageSettingsViewModel()] }
                        )
                    }
                ),
                SettingsGroupedRow(
                    id: "sharingServices.osAidLoopShare",
                    title: Texts_SettingsView.osAidLoopShareSectionTitle,
                    // Releaser builds with Loop share disabled should not show this feature at all.
                    isVisible: !Bundle.main.disableLoopShare,
                    detail: {
                        guard UserDefaults.standard.canConfigureOSAidSharing else {
                            return Texts_Common.disabled
                        }
                        let shareType = UserDefaults.standard.loopShareType
                        return shareType == .disabled ? nil : shareType.description
                    },
                    settingsScreen: {
                        SettingsScreen(
                            title: Texts_SettingsView.osAidLoopShareSectionTitle,
                            onlineHelpTopic: .osAidShare,
                            providers: {
                                [
                                    SettingsViewDevelopmentSettingsViewModel(rowGroup: .osAidLoopShare),
                                    SettingsViewDevelopmentSettingsViewModel(rowGroup: .osAidLoopShareWarning)
                                ]
                            }
                        )
                    }
                ),
                SettingsGroupedRow(
                    id: "sharingServices.speakReadings",
                    title: Texts_SettingsView.sectionTitleSpeak,
                    detail: {
                        groupedStatusDetail(isEnabled: UserDefaults.standard.speakReadings)
                    },
                    settingsScreen: {
                        SettingsScreen(
                            title: Texts_SettingsView.sectionTitleSpeak,
                            onlineHelpTopic: .speakGlucose,
                            providers: { [SettingsViewSpeakSettingsViewModel()] }
                        )
                    }
                ),
                SettingsGroupedRow(
                    id: "sharingServices.m5Stack",
                    title: "M5Stack",
                    settingsScreen: {
                        SettingsScreen(title: "M5Stack", onlineHelpTopic: .m5Stack) { presenter in
                            SettingsListFactory.makeM5StackSections(presenter: presenter)
                        }
                    }
                )
            ]
        )
    }

    /// Shows an enabled summary while leaving disabled parent rows uncluttered.
    private static func groupedStatusDetail(isEnabled: Bool) -> String? {
        isEnabled ? Texts_Common.enabled : nil
    }

    /// Adds the same last-known-good Nightscout connection marker used in the
    /// Nightscout child screen, but only when the parent row is showing Enabled.
    private static func nightscoutConnectionIndicator() -> SettingsIndicator? {
        guard UserDefaults.standard.nightscoutEnabled,
              let lastConnection = UserDefaults.standard.timeStampOfLastFollowerConnection else {
            return nil
        }

        guard lastConnection > .distantPast else {
            return SettingsIndicator(color: ConstantsAppColors.urgent)
        }

        let connectionIsRecent = lastConnection > Date().addingTimeInterval(-Double(ConstantsFollower.secondsUntilFollowerDisconnectWarningNightscout))
        return SettingsIndicator(color: connectionIsRecent ? ConstantsAppColors.normal : ConstantsAppColors.urgent)
    }

    /// Shows why Calendar Share is unavailable in Calendar Follow mode, otherwise the share status.
    private static func calendarShareStatusDetail() -> String? {
        guard calendarShareRowIsEnabled() else { return Texts_Common.disabled }
        guard UserDefaults.standard.createCalendarEvent else { return nil }
        return calendarShareStatus().description
    }

    /// Adds the same status dot used by the Calendar Share child status row.
    private static func calendarShareStatusIndicator() -> SettingsIndicator? {
        guard calendarShareRowIsEnabled() else { return nil }
        guard UserDefaults.standard.createCalendarEvent else { return nil }

        switch calendarShareStatus() {
        case .active:
            return SettingsIndicator(color: .green)
        case .waiting:
            return SettingsIndicator(color: .yellow)
        case .noData:
            return SettingsIndicator(color: .gray)
        case .stale:
            return SettingsIndicator(color: .orange)
        case .error:
            return SettingsIndicator(color: .red)
        case .notConfigured:
            return SettingsIndicator(color: .gray)
        }
    }

    private static func calendarShareRowIsEnabled() -> Bool {
        !(UserDefaults.standard.followerDataSourceType == .calendar && !UserDefaults.standard.isMaster)
    }

    private static func calendarShareStatus() -> CalendarShareStatus {
        guard UserDefaults.standard.calenderId != nil else { return .notConfigured }
        return CalendarShareStatus(rawValue: UserDefaults.standard.calendarShareStatus) ?? .notConfigured
    }

    func sectionTitle() -> String? {
        title
    }

    func settingsRows(sectionID: Int) -> [SettingsRow] {
        leadingRows() + rows.map { row in
            SettingsRow(
                id: row.id,
                title: row.title,
                detail: row.detail?(),
                detailColor: row.detailColor?(),
                detailIndicator: row.detailIndicator?(),
                accessory: .disclosure,
                isEnabled: row.isEnabled?() ?? true,
                action: .settingsScreen(row.settingsScreen)
            )
        }
    }

    func settingsRowText(index: Int) -> String {
        rows[index].title
    }

    func accessoryType(index: Int) -> SettingsAccessory {
        .disclosure
    }

    func detailedText(index: Int) -> String? {
        rows[index].detail?()
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


    func storeRowReloadClosure(rowReloadClosure: @escaping ((Int) -> Void)) {}
}

@MainActor
enum SettingsListFactory {
    /// Builds the root Settings sections and connects each view model to the presenter.
    static func makeRootSections(
        coreDataManager: CoreDataManager?,
        selectedFollowerActions: SelectedFollowerActions,
        presenter: SettingsActionPresenter
    ) -> [SettingsSectionModel] {
        SettingsRootSection.allCases.flatMap { section -> [SettingsSectionModel] in
            let viewModel = section.viewModel(
                coreDataManager: coreDataManager,
                selectedFollowerActions: selectedFollowerActions
            )

            configure(viewModel: viewModel, presenter: presenter)

            if let dataSourceViewModel = viewModel as? SettingsViewDataSourceSettingsViewModel {
                let sectionIDBase = section.rawValue * 10

                return (0 ..< 2).map { offset in
                    let sectionID = sectionIDBase + offset

                    return SettingsSectionModel(id: sectionID) {
                        let settingsSection = dataSourceViewModel.settingsSections(sectionIDBase: sectionIDBase)[offset]

                        return SettingsSection(
                            title: settingsSection.title,
                            iconSymbolName: offset == 0 ? section.iconSymbolName : nil,
                            footer: settingsSection.footer,
                            rows: settingsSection.rows
                        )
                    }
                }
            }

            let sectionID = section.rawValue * 10

            return [SettingsSectionModel(id: sectionID) {
                guard let nativeProvider = viewModel as? SettingsNativeSectionProvider else {
                    fatalError("Settings view model must provide a native Settings section")
                }

                let settingsSection = nativeProvider.settingsSection(sectionID: sectionID)

                return SettingsSection(
                    title: settingsSection.title,
                    iconSymbolName: section.iconSymbolName,
                    footer: settingsSection.footer,
                    rows: settingsSection.rows
                )
            }]
        }
    }

    /// Builds the M5Stack child sections from their existing section providers.
    static func makeM5StackSections(presenter: SettingsActionPresenter) -> [SettingsSectionModel] {
        M5StackSettingsSection.allCases.map { section in
            let viewModel = section.viewModel(coreDataManager: nil)
            configure(viewModel: viewModel, presenter: presenter)

            return SettingsSectionModel(id: section.rawValue) {
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

            return SettingsSectionModel(id: offset) {
                viewModel.settingsSection(sectionID: offset)
            }
        }
    }

    /// Connects view-model message and row-reload callbacks to the Settings presenter.
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

    /// Creates the M5Stack Settings view model for the selected subsection.
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
