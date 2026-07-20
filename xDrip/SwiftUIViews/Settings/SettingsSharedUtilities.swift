//
//  SettingsSharedUtilities.swift
//  xdrip
//
//  Created by Paul Plant on 22/6/26.
//  Copyright © 2026 Johan Degraeve. All rights reserved.
//

import SwiftUI
import UIKit
import MessageUI

/// Storage contract used by the native SwiftUI time-schedule editor.
protocol TimeSchedule {
    func getSchedule() -> [Int]
    func storeSchedule(schedule: [Int])
    func serviceName() -> String
}

// Shared models, routing and row rendering used by the complete Settings flow.
enum SettingsSegueIdentifier: String {
    case settingsToAlertTypeSettings
    case settingsToAlertSettings
    case settingsToM5StackSettings
    case settingsToSchedule
    case settingsToLoopDelaySchedule
}

final class SettingsRouter: ObservableObject {
    @Published var path = [SettingsRoute]()
    @Published var showsTraceEmail = false

    func show(_ destination: SettingsRoute.Destination) {
        path.append(SettingsRoute(destination))
    }

    func closeCurrentView() {
        guard !path.isEmpty else { return }

        path.removeLast()
    }

}

/// Typed destination used by the native Settings NavigationStack.
///
/// Existing settings editors contain closures, Core Data objects and service models which are not
/// Hashable. A route therefore hashes only its stable identity while retaining the typed payload.
struct SettingsRoute: Hashable {
    enum Destination {
        case settingsScreen(SettingsScreen)
        case textEntry(SettingsTextEntryContent)
        case selectionList(SettingsSelectionListContent)
        case datePicker(SettingsDatePickerContent)
        case alertTypes
        case alertTypeEditor(AlertType?, AlertTypesSettingsViewModel)
        case alerts
        case alertEditor(AlertEntryEditorMode, AlertsSettingsViewModel)
        case m5Stack
        case timeSchedule(TimeSchedule)
        case loopDelaySchedule
        case dataManagement(DataManagementFlow)
        case incomingBackup(IncomingBackupRequest)
        case custom(title: String, content: (@escaping () -> Void) -> AnyView)
    }

    let id = UUID()
    let destination: Destination

    init(_ destination: Destination) {
        self.destination = destination
    }

    static func == (lhs: SettingsRoute, rhs: SettingsRoute) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

struct SettingsNavigationActions {
    let push: (_ title: String, _ content: @escaping (_ close: @escaping () -> Void) -> AnyView) -> Void

    /// Pushes a text-entry screen using the shared Settings navigation.
    func pushTextEntry(_ textEntry: SettingsTextEntryContent) {
        push(textEntry.title ?? "") { close in
            AnyView(SettingsTextEntryView(textEntry: textEntry, close: close))
        }
    }

    /// Pushes a list picker inside the Settings navigation stack.
    func pushSelectionList(_ selectionList: SettingsSelectionListContent) {
        push(selectionList.title ?? "") { close in
            AnyView(SettingsSelectionListView(selectionList: selectionList, close: close))
        }
    }

    /// Pushes the date picker used by schedule settings.
    func pushDatePicker(_ datePicker: SettingsDatePickerContent) {
        push(datePicker.title ?? "") { close in
            AnyView(SettingsDatePickerView(datePicker: datePicker, close: close))
        }
    }
}

private struct SettingsNavigationActionsKey: EnvironmentKey {
    static let defaultValue: SettingsNavigationActions? = nil
}

extension EnvironmentValues {
    var settingsNavigationActions: SettingsNavigationActions? {
        get { self[SettingsNavigationActionsKey.self] }
        set { self[SettingsNavigationActionsKey.self] = newValue }
    }
}

@MainActor
final class SettingsListModel: ObservableObject {
    @Published private(set) var reloadToken = UUID()

    let sections: [SettingsSectionModel]

    init(sections: [SettingsSectionModel]) {
        self.sections = sections
    }

    /// Triggers a refresh for rows backed by indexed Settings view models. The scope remains part of
    /// the contract so call sites describe what changed.
    func reload(_ scope: SettingsReloadScope) {
        reloadToken = UUID()
    }
}

struct SettingsSectionModel: Identifiable {
    let id: Int
    let section: () -> SettingsSection

    init(id: Int, section: @escaping () -> SettingsSection) {
        self.id = id
        self.section = section
    }
}

struct SettingsScreen {
    let title: String
    let makeSections: @MainActor (SettingsActionPresenter) -> [SettingsSectionModel]

    /// Describes a pushed Settings screen without coupling it to a specific host.
    /// Future grouped menus can return this from a row action and provide any
    /// mix of existing section providers for the child screen.
    init(
        title: String,
        makeSections: @escaping @MainActor (SettingsActionPresenter) -> [SettingsSectionModel]
    ) {
        self.title = title
        self.makeSections = makeSections
    }

    /// Convenience initializer for the common case where a child Settings screen
    /// is just a title and a list of existing native section providers.
    init(title: String, providers: @escaping () -> [SettingsNativeSectionProvider]) {
        self.init(title: title) { presenter in
            SettingsListFactory.makeSections(providers: providers(), presenter: presenter)
        }
    }
}

struct SettingsSection {
    let title: String?
    let iconSymbolName: String?
    let footer: String?
    let rows: [SettingsRow]

    init(title: String? = nil, iconSymbolName: String? = nil, footer: String? = nil, rows: [SettingsRow]) {
        self.title = title
        self.iconSymbolName = iconSymbolName
        self.footer = footer
        self.rows = rows
    }
}

struct SettingsRow: Identifiable {
    let id: String
    let title: String
    var detail: String? = nil
    var icon: SettingsIcon? = nil
    var titleColor: Color? = nil
    var detailColor: Color? = nil
    var centerTitle: Bool = false
    var indicator: SettingsIndicator? = nil
    var detailIndicator: SettingsIndicator? = nil
    var accessory: SettingsAccessory = .automatic
    var control: SettingsControl? = nil
    var isEnabled: Bool = true
    var isVisible: Bool = true
    var reloadScope: SettingsReloadScope? = nil
    var accessibility: SettingsAccessibility? = nil
    var action: SettingsRowAction? = nil
}

struct SettingsIcon {
    let symbolName: String
    var color: Color? = nil
    var backgroundColor: Color? = nil
    var accessibilityLabel: String? = nil
}

struct SettingsIndicator {
    let color: Color
    var symbolName: String = "circle.fill"
    var accessibilityLabel: String? = nil
}

enum SettingsAccessory {
    case automatic
    case none
    case disclosure
    case info
    case infoDisclosure
}

enum SettingsControl {
    case toggle(isOn: () -> Bool, setIsOn: (Bool) -> Void, confirmation: ((Bool) -> SettingsToggleConfirmationContent?)? = nil)
    case warningBanner(message: String, severity: SettingsWarningBannerSeverity = .warning)
}

enum SettingsWarningBannerSeverity {
    case caution
    case warning

    var backgroundColor: Color {
        switch self {
        case .caution:
            return ConstantsUI.cautionSectionBackgroundColor
        case .warning:
            return ConstantsUI.warningSectionBackgroundColor
        }
    }

    var indicatorColor: Color {
        return ConstantsUI.warningBannerIndicatorColor
    }
}

struct SettingsAccessibility {
    var label: String? = nil
    var value: String? = nil
    var hint: String? = nil
}

enum SettingsRowAction {
    case textEntry(() -> SettingsTextEntryContent)
    case selectionList(() -> SettingsSelectionListContent)
    case settingsScreen(() -> SettingsScreen)
    case dataManagement(DataManagementFlow)
    case legacy(action: () -> SettingsSelectedRowAction, rowIndex: Int, viewModel: SettingsViewModelProtocol)
    case run(() -> Void)
    case showMessage(title: String, message: String?)
    case sendTraceEmail

    var prefersDisclosure: Bool {
        switch self {
        case .textEntry, .selectionList, .settingsScreen, .dataManagement:
            return true
        case .legacy, .run, .showMessage, .sendTraceEmail:
            return false
        }
    }
}

protocol SettingsNativeSectionProvider: SettingsViewModelProtocol {
    func settingsSection(sectionID: Int) -> SettingsSection
    func settingsSectionTitle() -> String?
    func settingsSectionFooter() -> String?
    func settingsRows(sectionID: Int) -> [SettingsRow]
}

extension SettingsNativeSectionProvider {
    /// Builds the native SwiftUI section from the smaller title, footer and row
    /// hooks below. Most sections can use this as-is, and sections that need
    /// simple show/hide logic can usually override only settingsRows(sectionID:).
    func settingsSection(sectionID: Int) -> SettingsSection {
        SettingsSection(
            title: settingsSectionTitle(),
            footer: settingsSectionFooter(),
            rows: settingsRows(sectionID: sectionID)
        )
    }

    /// Uses the section provider's title by default.
    func settingsSectionTitle() -> String? {
        sectionTitle()
    }

    /// Uses the section provider's footer by default.
    func settingsSectionFooter() -> String? {
        sectionFooter()
    }

}

// These conformances mark Settings view models as participants in the shared row model. Each view
// model declares its rows near the top of the file so section layout is easy to inspect.
extension SettingsViewDataSourceSettingsViewModel: SettingsNativeSectionProvider {}
extension SettingsViewHomeScreenSettingsViewModel: SettingsNativeSectionProvider {}
extension SettingsViewAlertSettingsViewModel: SettingsNativeSectionProvider {}
extension SettingsViewStatisticsSettingsViewModel: SettingsNativeSectionProvider {}
extension SettingsViewNightscoutSettingsViewModel: SettingsNativeSectionProvider {}
extension SettingsViewDexcomShareUploadSettingsViewModel: SettingsNativeSectionProvider {}
extension SettingsViewHealthKitSettingsViewModel: SettingsNativeSectionProvider {}
extension SettingsViewSpeakSettingsViewModel: SettingsNativeSectionProvider {}
extension SettingsViewCalendarEventsSettingsViewModel: SettingsNativeSectionProvider {}
extension SettingsViewContactImageSettingsViewModel: SettingsNativeSectionProvider {}
extension SettingsViewM5StackSettingsViewModel: SettingsNativeSectionProvider {}
extension SettingsViewTraceSettingsViewModel: SettingsNativeSectionProvider {}
extension SettingsViewInfoViewModel: SettingsNativeSectionProvider {}
extension SettingsViewDevelopmentSettingsViewModel: SettingsNativeSectionProvider {}
extension SettingsViewHousekeeperSettingsViewModel: SettingsNativeSectionProvider {}
extension SettingsViewM5StackGeneralSettingsViewModel: SettingsNativeSectionProvider {}
extension SettingsViewM5StackWiFiSettingsViewModel: SettingsNativeSectionProvider {}
extension SettingsViewM5StackBluetoothSettingsViewModel: SettingsNativeSectionProvider {}

enum SettingsReloadScope {
    case all
    case section(Int)
    case row(section: Int, row: Int)
}

final class SettingsActionPresenter: ObservableObject {
    @Published var alert: SettingsAlertContent?
    @Published var textEntry: SettingsTextEntryContent?
    @Published var confirmation: SettingsConfirmationContent?
    @Published var selectionList: SettingsSelectionListContent?
    @Published var datePicker: SettingsDatePickerContent?

    private let router: SettingsRouter

    init(router: SettingsRouter) {
        self.router = router
    }

    /// Shows the simple message alert requested by a Settings view model.
    func showMessage(title: String, message: String?) {
        alert = SettingsAlertContent(title: title, message: message, actionTitle: Texts_Common.Ok, action: nil)
    }

    /// Pushes a Settings text-entry destination directly.
    func show(textEntry: SettingsTextEntryContent) {
        router.show(.textEntry(textEntry))
    }

    /// Pushes a Settings selection destination directly.
    func show(selectionList: SettingsSelectionListContent) {
        router.show(.selectionList(selectionList))
    }

    /// Pushes a child Settings screen built from existing section providers.
    /// This is what lets us group sections such as Services later without moving
    /// their underlying view model logic.
    func show(settingsScreen: SettingsScreen) {
        router.show(.settingsScreen(settingsScreen))
    }

    /// Pushes one of the native Data Management workflows.
    func show(dataManagementFlow: DataManagementFlow) {
        router.show(.dataManagement(dataManagementFlow))
    }

    /// Converts a SettingsSelectedRowAction into an alert, editor, picker, route or function call.
    func run(
        selectedRowAction: SettingsSelectedRowAction,
        rowIndex: Int,
        sectionIndex: Int,
        viewModel: SettingsViewModelProtocol?,
        reload: @escaping (SettingsReloadScope) -> Void
    ) {
        switch selectedRowAction {
        case .nothing:
            break

        case let .askText(title, message, keyboardType, text, placeholder, fieldTitle, unitText, actionTitle, cancelTitle, actionHandler, cancelHandler, inputValidator):
            router.show(.textEntry(SettingsTextEntryContent(
                title: title,
                message: message,
                keyboardType: keyboardType,
                text: text,
                placeholder: placeholder,
                fieldTitle: fieldTitle,
                unitText: unitText,
                actionTitle: actionTitle ?? Texts_Common.Ok,
                cancelTitle: cancelTitle ?? Texts_Common.Cancel,
                action: { [weak self] enteredText in
                    if let inputValidator = inputValidator, let errorMessage = inputValidator(enteredText) {
                        self?.showMessage(title: Texts_Common.warning, message: errorMessage)
                    } else {
                        actionHandler(enteredText)
                    }

                    self?.reloadIfNeeded(viewModel: viewModel, rowIndex: rowIndex, sectionIndex: sectionIndex, reload: reload)
                },
                cancel: cancelHandler,
                validator: inputValidator
            )))

        case let .callFunction(function):
            function()
            reloadIfNeeded(viewModel: viewModel, rowIndex: rowIndex, sectionIndex: sectionIndex, reload: reload)

        case let .openURL(url):
            UIApplication.shared.open(url)

        case let .selectFromList(title, data, selectedRow, actionTitle, cancelTitle, actionHandler, cancelHandler, didSelectRowHandler):
            router.show(.selectionList(SettingsSelectionListContent(
                title: title,
                data: data,
                selectedRow: selectedRow,
                actionTitle: actionTitle ?? Texts_Common.Ok,
                cancelTitle: cancelTitle ?? Texts_Common.Cancel,
                action: { [weak self] index in
                    actionHandler(index)
                    UserDefaults.standard.updateSnoozeStatus.toggle()
                    self?.reloadIfNeeded(viewModel: viewModel, rowIndex: rowIndex, sectionIndex: sectionIndex, reload: reload)
                },
                cancel: {
                    cancelHandler?()
                    UserDefaults.standard.updateSnoozeStatus.toggle()
                },
                didSelectRow: didSelectRowHandler
            )))

        case let .performSegue(identifier, sender):
            route(identifier: identifier, sender: sender)

        case let .showInfoText(title, message, actionHandler):
            alert = SettingsAlertContent(title: title, message: message, actionTitle: Texts_Common.Ok, action: actionHandler)

        case let .askConfirmation(title, message, actionHandler, cancelHandler):
            confirmation = SettingsConfirmationContent(
                title: title,
                message: message,
                action: { [weak self] in
                    self?.confirmation = nil

                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        actionHandler()
                        self?.reloadIfNeeded(viewModel: viewModel, rowIndex: rowIndex, sectionIndex: sectionIndex, reload: reload)
                    }
                },
                cancel: cancelHandler
            )
        }
    }

    /// Opens a date picker using the same pushed-screen pattern as text and list
    /// editors, so all Settings edit flows behave the same way.
    func show(datePicker: SettingsDatePickerContent) {
        router.show(.datePicker(datePicker))
    }

    func requestTraceEmail() {
        guard MFMailComposeViewController.canSendMail() else {
            showMessage(title: Texts_Common.warning, message: Texts_SettingsView.emailNotConfigured)
            return
        }

        confirmation = SettingsConfirmationContent(
            title: Texts_HomeView.info,
            message: Texts_SettingsView.describeProblem,
            action: { [weak self] in
                self?.confirmation = nil
                self?.router.showsTraceEmail = true
            },
            cancel: nil
        )
    }

    /// Applies the view model's refresh rule after a row action finishes.
    private func reloadIfNeeded(
        viewModel: SettingsViewModelProtocol?,
        rowIndex: Int,
        sectionIndex: Int,
        reload: @escaping (SettingsReloadScope) -> Void
    ) {
        guard let viewModel = viewModel else {
            reload(.section(sectionIndex))
            return
        }

        reload(viewModel.completeSettingsViewRefreshNeeded(index: rowIndex) ? .all : .section(sectionIndex))
    }

    /// Maps identifiers emitted by Settings view models to typed navigation routes.
    private func route(identifier: String, sender: Any?) {
        switch identifier {
        case SettingsSegueIdentifier.settingsToAlertTypeSettings.rawValue:
            router.show(.alertTypes)
        case SettingsSegueIdentifier.settingsToAlertSettings.rawValue:
            router.show(.alerts)
        case SettingsSegueIdentifier.settingsToM5StackSettings.rawValue:
            router.show(.m5Stack)
        case SettingsSegueIdentifier.settingsToSchedule.rawValue:
            if let timeSchedule = sender as? TimeSchedule {
                router.show(.timeSchedule(timeSchedule))
            }
        case SettingsSegueIdentifier.settingsToLoopDelaySchedule.rawValue:
            router.show(.loopDelaySchedule)
        default:
            break
        }
    }
}

struct SettingsAlertContent: Identifiable {
    let id = UUID()
    let title: String
    let message: String?
    let actionTitle: String
    let action: (() -> Void)?
}

struct SettingsTextEntryContent: Identifiable {
    let id = UUID()
    let title: String?
    let message: String?
    let keyboardType: SettingsKeyboardType?
    let text: String?
    let placeholder: String?
    let fieldTitle: String?
    let unitText: String?
    let actionTitle: String
    let cancelTitle: String
    let action: (String) -> Void
    let cancel: (() -> Void)?
    let validator: ((String) -> String?)?
}

private extension SettingsKeyboardType {
    var uiKeyboardType: UIKeyboardType {
        switch self {
        case .default:
            return .default
        case .alphabet:
            return .alphabet
        case .numberPad:
            return .numberPad
        case .decimalPad:
            return .decimalPad
        case .URL:
            return .URL
        }
    }
}

struct SettingsConfirmationContent: Identifiable {
    let id = UUID()
    let title: String?
    let message: String?
    let action: () -> Void
    let cancel: (() -> Void)?
    var actionTitle: String = Texts_Common.Ok
    var cancelTitle: String = Texts_Common.Cancel
}

struct SettingsSelectionListContent: Identifiable {
    let id = UUID()
    let title: String?
    let data: [String]
    let selectedRow: Int?
    let actionTitle: String
    let cancelTitle: String
    let action: (Int) -> Void
    let cancel: (() -> Void)?
    let didSelectRow: ((Int) -> Void)?
}

struct SettingsDatePickerContent: Identifiable {
    let id = UUID()
    let title: String?
    let subtitle: String?
    let mode: UIDatePicker.Mode
    let date: Date
    let minimumDate: Date?
    let maximumDate: Date?
    let okTitle: String
    let cancelTitle: String
    let ok: (Date) -> Void
    let cancel: (() -> Void)?
}

struct SettingsListView: View {
    @ObservedObject var listModel: SettingsListModel
    @ObservedObject var presenter: SettingsActionPresenter

    let title: String
    var titleDisplayMode: NavigationBarItem.TitleDisplayMode = .large
    var showsSectionHeaders = true
    var headerView: (() -> AnyView)? = nil

    var body: some View {
        List {
            if let headerView {
                Section {
                    headerView()
                }
            }

            ForEach(listModel.sections) { section in
                SettingsSectionView(
                    section: section,
                    reloadToken: listModel.reloadToken,
                    presenter: presenter,
                    reload: listModel.reload,
                    showsSectionHeader: showsSectionHeaders
                )
            }
        }
        .settingsListStyle(title: title, titleDisplayMode: titleDisplayMode)
        .settingsPresentation(presenter: presenter)
    }
}

struct SettingsStaticRowView: View {
    let title: String
    let detail: String?
    let isEnabled: Bool
    let showsDisclosure: Bool
    let showsInfoButton: Bool
    let titleColor: Color?
    let detailColor: Color?
    let centerTitle: Bool
    let icon: SettingsIcon?
    /// Adds a small colored SF Symbol dot before the row title.
    let indicator: SettingsIndicator?
    /// Adds a small coloured SF Symbol dot before the row detail text.
    /// This is for rows where the status belongs with the value on the right,
    /// such as the follower service status.
    let detailIndicator: SettingsIndicator?
    let action: () -> Void

    init(
        title: String,
        detail: String?,
        isEnabled: Bool,
        showsDisclosure: Bool,
        showsInfoButton: Bool = false,
        titleColor: Color? = nil,
        detailColor: Color? = nil,
        centerTitle: Bool = false,
        icon: SettingsIcon? = nil,
        indicator: SettingsIndicator? = nil,
        detailIndicator: SettingsIndicator? = nil,
        indicatorColor: Color? = nil,
        detailIndicatorColor: Color? = nil,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.detail = detail
        self.isEnabled = isEnabled
        self.showsDisclosure = showsDisclosure
        self.showsInfoButton = showsInfoButton
        self.titleColor = titleColor
        self.detailColor = detailColor
        self.centerTitle = centerTitle
        self.icon = icon
        self.indicator = indicator ?? indicatorColor.map { SettingsIndicator(color: $0) }
        self.detailIndicator = detailIndicator ?? detailIndicatorColor.map { SettingsIndicator(color: $0) }
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                SettingsRowTextView(
                    title: title,
                    detail: detail,
                    isEnabled: isEnabled,
                    titleColor: titleColor,
                    detailColor: detailColor,
                    centerTitle: centerTitle,
                    icon: icon,
                    indicator: indicator,
                    detailIndicator: detailIndicator
                )

                if isEnabled {
                    if showsInfoButton {
                        SettingsInfoIndicator()
                    }

                    if showsDisclosure {
                        SettingsDisclosureIndicator()
                    }
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
    }
}

private struct SettingsSectionView: View {
    let section: SettingsSectionModel
    let reloadToken: UUID
    @ObservedObject var presenter: SettingsActionPresenter
    let reload: (SettingsReloadScope) -> Void
    let showsSectionHeader: Bool

    var body: some View {
        let _ = reloadToken

        SettingsNativeSectionView(
            sectionID: section.id,
            section: section.section(),
            presenter: presenter,
            reload: reload,
            showsSectionHeader: showsSectionHeader
        )
    }
}

private struct SettingsNativeSectionView: View {
    let sectionID: Int
    let section: SettingsSection
    @ObservedObject var presenter: SettingsActionPresenter
    let reload: (SettingsReloadScope) -> Void
    let showsSectionHeader: Bool

    private var visibleRows: [SettingsRow] {
        section.rows.filter(\.isVisible)
    }

    @ViewBuilder
    var body: some View {
        if !visibleRows.isEmpty {
            Section {
                ForEach(visibleRows) { row in
                    SettingsNativeRowView(
                        sectionID: sectionID,
                        row: row,
                        presenter: presenter,
                        reload: reload
                    )
                }
            } header: {
                if showsSectionHeader, let title = section.title {
                    HStack(spacing: 6) {
                        if let iconSymbolName = section.iconSymbolName {
                            Image(systemName: iconSymbolName)
                                .foregroundStyle(ConstantsUI.settingsSectionHeaderIconColor)
                        }

                        Text(title)
                            .foregroundStyle(ConstantsUI.tableViewHeaderTextColor)
                    }
                }
            } footer: {
                if let footer = section.footer {
                    Text(footer)
                        .foregroundStyle(ConstantsUI.listSectionFooterTextColor)
                        .padding(.bottom, ConstantsUI.listSectionFooterBottomPadding)
                }
            }
        }
    }
}

private struct SettingsNativeRowView: View {
    let sectionID: Int
    let row: SettingsRow
    @ObservedObject var presenter: SettingsActionPresenter
    let reload: (SettingsReloadScope) -> Void

    var body: some View {
        switch row.control {
        case let .some(.warningBanner(message, severity)):
            SettingsWarningBannerView(title: row.title, message: message, indicatorColor: severity.indicatorColor)
                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                .listRowBackground(severity.backgroundColor)

        case let .some(.toggle(isOn, setIsOn, confirmation)):
            Toggle(isOn: Binding(
                get: isOn,
                set: { newValue in
                    if let confirmationContent = confirmation?(newValue) {
                        presenter.confirmation = SettingsConfirmationContent(
                            title: confirmationContent.title,
                            message: confirmationContent.message,
                            action: {
                                presenter.confirmation = nil
                                setIsOn(newValue)
                                reload(row.reloadScope ?? .section(sectionID))
                            },
                            cancel: {
                                presenter.confirmation = nil
                                reload(row.reloadScope ?? .section(sectionID))
                            },
                            actionTitle: confirmationContent.actionTitle,
                            cancelTitle: confirmationContent.cancelTitle
                        )
                    } else {
                        setIsOn(newValue)
                        reload(row.reloadScope ?? .section(sectionID))
                    }
                }
            )) {
                rowText
            }
            .tint(.green)
            .disabled(!row.isEnabled)

        case .none:
            SettingsStaticRowView(
                title: row.title,
                detail: row.detail,
                isEnabled: row.isEnabled,
                showsDisclosure: showsDisclosure,
                showsInfoButton: showsInfoButton,
                titleColor: row.titleColor,
                detailColor: row.detailColor,
                centerTitle: row.centerTitle,
                icon: row.icon,
                indicator: row.indicator,
                detailIndicator: row.detailIndicator,
                action: selectRow
            )
        }
    }

    private var rowText: some View {
        SettingsRowTextView(
            title: row.title,
            detail: row.detail,
            isEnabled: row.isEnabled,
            titleColor: row.titleColor,
            detailColor: row.detailColor,
            centerTitle: row.centerTitle,
            icon: row.icon,
            indicator: row.indicator,
            detailIndicator: row.detailIndicator
        )
    }

    private var showsDisclosure: Bool {
        guard row.isEnabled else { return false }

        switch row.accessory {
        case .automatic:
            return row.action?.prefersDisclosure ?? false
        case .disclosure:
            return true
        case .infoDisclosure:
            return true
        case .none, .info:
            return false
        }
    }

    private var showsInfoButton: Bool {
        guard row.isEnabled else { return false }

        if case .info = row.accessory {
            return true
        }

        if case .infoDisclosure = row.accessory {
            return true
        }

        return false
    }

    private func selectRow() {
        guard row.isEnabled else { return }

        switch row.action {
        case let .textEntry(textEntry):
            presenter.show(textEntry: textEntry())
        case let .selectionList(selectionList):
            presenter.show(selectionList: selectionList())
        case let .settingsScreen(settingsScreen):
            presenter.show(settingsScreen: settingsScreen())
        case let .dataManagement(flow):
            presenter.show(dataManagementFlow: flow)
        case let .legacy(action, rowIndex, viewModel):
            presenter.run(
                selectedRowAction: action(),
                rowIndex: rowIndex,
                sectionIndex: sectionID,
                viewModel: viewModel,
                reload: reload
            )
        case let .run(action):
            action()
            reload(row.reloadScope ?? .section(sectionID))
        case let .showMessage(title, message):
            presenter.showMessage(title: title, message: message)
        case .sendTraceEmail:
            presenter.requestTraceEmail()
        case nil:
            break
        }
    }
}

private struct SettingsWarningBannerView: View {
    let title: String
    let message: String
    let indicatorColor: Color

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title2)
                .foregroundStyle(indicatorColor)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.red)

                Text(message)
                    .font(.caption)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 4)
    }
}

extension SettingsViewModelProtocol {
    /// Builds a row from indexed view-model logic with explicit identity and visibility.
    func nativeSettingsRow(
        id: String,
        index: Int,
        sectionID: Int,
        isVisible: Bool = true
    ) -> SettingsRow {
        nativeSettingsRow(id: Optional(id), index: index, sectionID: sectionID, isVisible: isVisible)
    }

    /// Builds one row from the indexed title, detail, state and action methods.
    private func nativeSettingsRow(
        id: String? = nil,
        index: Int,
        sectionID: Int,
        isVisible: Bool = true
    ) -> SettingsRow {
        let accessoryType = accessoryType(index: index)
        let isEnabled = isEnabled(index: index)
        let reloadScope: SettingsReloadScope? = completeSettingsViewRefreshNeeded(index: index) ? .all : nil

        if let toggle = settingsToggle(index: index) {
            return SettingsRow(
                id: id ?? "\(sectionID).\(index)",
                title: settingsRowText(index: index),
                detail: detailedText(index: index),
                indicator: nativeIndicator(index: index),
                detailIndicator: nativeDetailIndicator(index: index),
                accessory: accessoryType,
                control: .toggle(
                    isOn: toggle.isOn,
                    setIsOn: toggle.setIsOn,
                    confirmation: toggle.confirmation
                ),
                isEnabled: isEnabled,
                isVisible: isVisible,
                reloadScope: reloadScope
            )
        }

        return SettingsRow(
            id: id ?? "\(sectionID).\(index)",
            title: settingsRowText(index: index),
            detail: detailedText(index: index),
            indicator: nativeIndicator(index: index),
            detailIndicator: nativeDetailIndicator(index: index),
            accessory: accessoryType,
            isEnabled: isEnabled,
            isVisible: isVisible,
            reloadScope: reloadScope,
            action: isEnabled ? .legacy(action: { onRowSelect(index: index) }, rowIndex: index, viewModel: self) : nil
        )
    }

    /// Returns the optional colored marker shown before the title.
    private func nativeIndicator(index: Int) -> SettingsIndicator? {
        if let indicator = rowIndicator(index: index) {
            return indicator
        }

        guard let homeScreenViewModel = self as? SettingsViewHomeScreenSettingsViewModel,
              let color = homeScreenViewModel.rowIndicatorColor(index: index) else {
            return nil
        }

        return SettingsIndicator(color: color)
    }

    /// Returns the optional colored marker shown before the detail.
    private func nativeDetailIndicator(index: Int) -> SettingsIndicator? {
        guard let dataSourceViewModel = self as? SettingsViewDataSourceSettingsViewModel,
              let color = dataSourceViewModel.followerServiceStatusIndicatorColor(index: index) else {
            return nil
        }

        return SettingsIndicator(color: color)
    }
}

struct SettingsRowTextView: View {
    let title: String
    let detail: String?
    let isEnabled: Bool
    let titleColor: Color?
    let detailColor: Color?
    let centerTitle: Bool
    let icon: SettingsIcon?
    /// Draws a small dot before the title when a row needs a visual range/status marker.
    let indicator: SettingsIndicator?
    /// Draws a small dot before the detail value when the marker belongs with the value.
    let detailIndicator: SettingsIndicator?

    init(
        title: String,
        detail: String?,
        isEnabled: Bool,
        titleColor: Color? = nil,
        detailColor: Color? = nil,
        centerTitle: Bool = false,
        icon: SettingsIcon? = nil,
        indicator: SettingsIndicator? = nil,
        detailIndicator: SettingsIndicator? = nil,
        indicatorColor: Color? = nil,
        detailIndicatorColor: Color? = nil
    ) {
        self.title = title
        self.detail = detail
        self.isEnabled = isEnabled
        self.titleColor = titleColor
        self.detailColor = detailColor
        self.centerTitle = centerTitle
        self.icon = icon
        self.indicator = indicator ?? indicatorColor.map { SettingsIndicator(color: $0) }
        self.detailIndicator = detailIndicator ?? detailIndicatorColor.map { SettingsIndicator(color: $0) }
    }

    var body: some View {
        if centerTitle {
            Text(title)
                .foregroundStyle(titleColor ?? (isEnabled ? Color(.colorPrimary) : .gray))
                .lineLimit(2)
                .minimumScaleFactor(0.75)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, alignment: .center)
        } else {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                HStack(alignment: .center, spacing: 7) {
                    if let icon {
                        SettingsRowIconView(icon: icon, isEnabled: isEnabled)
                    }

                    if let indicator {
                        Image(systemName: indicator.symbolName)
                            .font(.caption2)
                            .foregroundStyle(isEnabled ? indicator.color : .gray)
                            .accessibilityLabel(indicator.accessibilityLabel ?? "")
                    }

                    Text(title)
                        .foregroundStyle(titleColor ?? (isEnabled ? Color(.colorPrimary) : .gray))
                        .lineLimit(2)
                        .minimumScaleFactor(0.75)
                        .frame(alignment: .leading)
                }
                .layoutPriority(1)

                Spacer(minLength: 8)

                if let detail {
                    HStack(spacing: 5) {
                        if let detailIndicator {
                            Image(systemName: detailIndicator.symbolName)
                                .font(.caption2)
                                .foregroundStyle(isEnabled ? detailIndicator.color : .gray)
                                .accessibilityLabel(detailIndicator.accessibilityLabel ?? "")
                        }

                        Text(detail)
                            .foregroundStyle(isEnabled ? (detailColor ?? Color(.colorTertiary)) : .gray)
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .multilineTextAlignment(.trailing)
                            .frame(alignment: .trailing)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct SettingsDisclosureIndicator: View {
    var body: some View {
        Image(systemName: "chevron.right")
            .font(.footnote.weight(.semibold))
            .foregroundStyle(ConstantsUI.disclosureIndicatorColor)
    }
}

private struct SettingsRowIconView: View {
    let icon: SettingsIcon
    let isEnabled: Bool

    var body: some View {
        Group {
            if let backgroundColor = icon.backgroundColor {
                Image(systemName: icon.symbolName)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(isEnabled ? (icon.color ?? Color(.colorPrimary)) : .gray)
                    .frame(width: 24, height: 24)
                    .background(
                        Circle()
                            .fill(isEnabled ? backgroundColor : Color.gray.opacity(0.2))
                    )
            } else {
                Image(systemName: icon.symbolName)
                    .font(.body)
                    .foregroundStyle(isEnabled ? (icon.color ?? Color(.colorPrimary)) : .gray)
            }
        }
        .accessibilityLabel(icon.accessibilityLabel ?? "")
    }
}

struct SettingsInfoIndicator: View {
    var body: some View {
        Image(systemName: "info.circle")
            .font(.body)
            .foregroundStyle(ConstantsUI.disclosureIndicatorColor)
    }
}

extension View {
    /// Applies the standard appearance used by all Settings lists.
    func settingsListStyle(title: String, titleDisplayMode: NavigationBarItem.TitleDisplayMode = .large) -> some View {
        self
            .listStyle(.insetGrouped)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(titleDisplayMode)
            .colorScheme(.dark)
    }

    /// Adds alert and confirmation handling for rows backed by SettingsActionPresenter.
    func settingsPresentation(presenter: SettingsActionPresenter) -> some View {
        modifier(SettingsPresentationModifier(presenter: presenter))
    }

    /// Adds pushed edit screens for text, selection and date picker requests.
    func settingsPushPresentation(
        textEntry: Binding<SettingsTextEntryContent?> = .constant(nil),
        selectionList: Binding<SettingsSelectionListContent?> = .constant(nil),
        datePicker: Binding<SettingsDatePickerContent?> = .constant(nil)
    ) -> some View {
        modifier(SettingsPushPresentationModifier(
            textEntry: textEntry,
            selectionList: selectionList,
            datePicker: datePicker
        ))
    }
}

private struct SettingsPresentationModifier: ViewModifier {
    @ObservedObject var presenter: SettingsActionPresenter

    /// Presents the alert state exposed by SettingsActionPresenter.
    /// SwiftUI only allows one alert modifier per view path here, so message and
    /// confirmation alerts are combined into a single binding below.
    func body(content: Content) -> some View {
        content
            .alert(item: presentedAlertBinding) { presentedAlert in
                switch presentedAlert {
                case let .message(alert):
                    return Alert(
                        title: Text(alert.title),
                        message: alert.message.map { Text($0) },
                        dismissButton: .default(Text(alert.actionTitle)) {
                            alert.action?()
                        }
                    )
                case let .confirmation(confirmation):
                    return Alert(
                        title: Text(confirmation.title ?? ""),
                        message: confirmation.message.map { Text($0) },
                        primaryButton: .default(Text(confirmation.actionTitle), action: confirmation.action),
                        secondaryButton: .cancel(Text(confirmation.cancelTitle)) {
                            confirmation.cancel?()
                        }
                    )
                }
            }
    }

    /// Combines message alerts and confirmation alerts into one SwiftUI alert binding.
    /// Clearing is deferred because SwiftUI warns if the presenter publishes changes
    /// while the alert binding is being updated.
    private var presentedAlertBinding: Binding<SettingsPresentedAlertContent?> {
        Binding {
            if let confirmation = presenter.confirmation {
                return .confirmation(confirmation)
            }

            if let alert = presenter.alert {
                return .message(alert)
            }

            return nil
        } set: { presentedAlert in
            guard presentedAlert == nil else { return }

            DispatchQueue.main.async {
                presenter.alert = nil
                presenter.confirmation = nil
            }
        }
    }
}

private enum SettingsPresentedAlertContent: Identifiable, Equatable {
    case message(SettingsAlertContent)
    case confirmation(SettingsConfirmationContent)

    var id: UUID {
        switch self {
        case let .message(alert):
            return alert.id
        case let .confirmation(confirmation):
            return confirmation.id
        }
    }

    static func == (lhs: SettingsPresentedAlertContent, rhs: SettingsPresentedAlertContent) -> Bool {
        lhs.id == rhs.id
    }
}

private struct SettingsPushPresentationModifier: ViewModifier {
    @Environment(\.settingsNavigationActions) private var navigationActions

    @Binding var textEntry: SettingsTextEntryContent?
    @Binding var selectionList: SettingsSelectionListContent?
    @Binding var datePicker: SettingsDatePickerContent?

    /// Watches for new editor content and pushes the matching native Settings destination.
    func body(content: Content) -> some View {
        content
            .onChange(of: textEntry?.id) { _ in
                guard let textEntry else { return }

                navigationActions?.pushTextEntry(textEntry)
                self.textEntry = nil
            }
            .onChange(of: selectionList?.id) { _ in
                guard let selectionList else { return }

                navigationActions?.pushSelectionList(selectionList)
                self.selectionList = nil
            }
            .onChange(of: datePicker?.id) { _ in
                guard let datePicker else { return }

                navigationActions?.pushDatePicker(datePicker)
                self.datePicker = nil
            }
    }
}

struct SettingsTextEntryView: View {
    @State private var value: String
    @State private var validationMessage: String?
    @State private var didComplete = false

    let textEntry: SettingsTextEntryContent
    let close: () -> Void
    private let initialValue: String

    /// Starts the text editor with the value supplied by the row action.
    init(textEntry: SettingsTextEntryContent, close: @escaping () -> Void) {
        self.textEntry = textEntry
        self.close = close
        let initialValue = textEntry.text ?? ""
        self.initialValue = initialValue
        _value = State(initialValue: initialValue)
    }

    var body: some View {
        Form {
            if let message = textEntry.message, !message.isEmpty {
                Text(message)
                    .foregroundStyle(Color(.colorSecondary))
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let fieldTitle = textEntry.fieldTitle ?? (textEntry.unitText == nil ? nil : Texts_Common.value) {
                LabeledContent(fieldTitle) {
                    HStack(spacing: 6) {
                        TextField(textEntry.placeholder ?? "", text: $value)
                            .keyboardType(textEntry.keyboardType?.uiKeyboardType ?? .default)
                            .multilineTextAlignment(.trailing)
                            .frame(minWidth: 70, idealWidth: 90, maxWidth: 120)

                        if let unitText = textEntry.unitText {
                            Text(unitText)
                                .foregroundStyle(Color(.colorTertiary))
                        }
                    }
                }
            } else {
                TextField(textEntry.placeholder ?? "", text: $value)
                    .keyboardType(textEntry.keyboardType?.uiKeyboardType ?? .default)
            }

            if let validationMessage {
                Text(validationMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .scrollContentBackground(.hidden)
        .background(ConstantsUI.listBackGroundColor)
        .navigationTitle(textEntry.title ?? "")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button(textEntry.actionTitle) {
                    submit()
                }
                .disabled(!hasModifiedValue)
            }
        }
        .onDisappear {
            guard !didComplete else { return }

            textEntry.cancel?()
        }
        .colorScheme(.dark)
    }

    private var hasModifiedValue: Bool {
        if initialValue.isEmpty {
            return !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }

        return value != initialValue
    }

    /// Validates and commits the text entry. Validation errors stay on the pushed
    /// screen; successful entries call the original action and close the screen.
    private func submit() {
        if let validator = textEntry.validator, let message = validator(value) {
            validationMessage = message
            return
        }

        didComplete = true
        textEntry.action(value)
        close()
    }
}

struct SettingsSelectionListView: View {
    @State private var selectedRow: Int
    @State private var didComplete = false

    let selectionList: SettingsSelectionListContent
    let close: () -> Void
    private let initialSelectedRow: Int

    /// Starts the picker on the supplied selected row.
    init(selectionList: SettingsSelectionListContent, close: @escaping () -> Void) {
        self.selectionList = selectionList
        self.close = close
        let initialSelectedRow = selectionList.selectedRow ?? 0
        self.initialSelectedRow = initialSelectedRow
        _selectedRow = State(initialValue: initialSelectedRow)
    }

    var body: some View {
        List {
            ForEach(selectionList.data.indices, id: \.self) { index in
                Button {
                    select(index: index)
                } label: {
                    HStack {
                        Text(selectionList.data[index])
                            .foregroundStyle(Color(.colorPrimary))
                        Spacer()
                        if selectedRow == index {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.green)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .settingsListStyle(title: selectionList.title ?? "")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button(selectionList.actionTitle) {
                    didComplete = true
                    selectionList.action(selectedRow)
                    close()
                }
                .disabled(selectedRow == initialSelectedRow)
            }
        }
        .onDisappear {
            guard !didComplete else { return }

            selectionList.cancel?()
        }
    }

    /// Updates the selected row and runs its optional preview callback.
    private func select(index: Int) {
        selectedRow = index
        selectionList.didSelectRow?(index)
    }
}
