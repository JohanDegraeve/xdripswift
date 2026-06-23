//
//  SettingsSharedUtilities.swift
//  xdrip
//
//  Created by Paul Plant on 22/6/26.
//  Copyright © 2026 Johan Degraeve. All rights reserved.
//

import SwiftUI
import UIKit

// This file supports the Settings migration from the old UIKit table view controllers
// and view models to SwiftUI. The goal is to keep the existing Settings workflow
// familiar by matching the old row actions, alerts, edit screens and navigation as
// closely as possible while the UI is rebuilt in SwiftUI.
final class SettingsRouter: ObservableObject {
    // UIKit owns the navigation stack, but the row actions now come from SwiftUI.
    // These closures are the small bridge between the old segue-based Settings
    // actions and the new pushed SwiftUI screens.
    var openAlertTypes: (() -> Void)?
    var openAlerts: (() -> Void)?
    var openM5Stack: (() -> Void)?
    var openTimeSchedule: ((TimeSchedule) -> Void)?
    var openLoopDelaySchedule: (() -> Void)?
    var presentShareFile: ((URL) -> Void)?
    var showProgress: ((ProgressBarStatus<URL>?) -> Void)?
}

struct SettingsNavigationActions {
    let push: (_ title: String, _ content: (_ close: @escaping () -> Void) -> AnyView) -> Void

    /// Pushes the SwiftUI text entry replacement for the old UIKit text alert.
    /// The caller only supplies the old alert content and this keeps the new
    /// navigation behaviour consistent across Settings.
    func pushTextEntry(_ textEntry: SettingsTextEntryContent) {
        push(textEntry.title ?? "") { close in
            AnyView(SettingsTextEntryView(textEntry: textEntry, close: close))
        }
    }

    /// Pushes the SwiftUI list picker replacement for the old UIKit picker alert.
    /// This keeps selection screens in the navigation stack instead of presenting
    /// them as bottom sheets.
    func pushSelectionList(_ selectionList: SettingsSelectionListContent) {
        push(selectionList.title ?? "") { close in
            AnyView(SettingsSelectionListView(selectionList: selectionList, close: close))
        }
    }

    /// Pushes the SwiftUI date picker replacement for the old UIKit date picker.
    /// The actual picker view lives in TimeScheduleView because that is the only
    /// Settings flow that currently needs the shared picker screen.
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

extension UIViewController {
    /// Builds the navigation actions used by SwiftUI Settings views when they need
    /// to push another SwiftUI screen from a UIKit navigation controller.
    func settingsNavigationActions() -> SettingsNavigationActions {
        SettingsNavigationActions { [weak self] title, content in
            guard let navigationController = self?.navigationController else { return }

            let viewController = PortraitLockedHostingController(
                rootView: content {
                    navigationController.popViewController(animated: true)
                }
            )
            viewController.title = title
            viewController.navigationItem.largeTitleDisplayMode = .never

            navigationController.pushViewController(viewController, animated: true)
        }
    }

    func pushSettingsTextEntry(_ textEntry: SettingsTextEntryContent) {
        settingsNavigationActions().pushTextEntry(textEntry)
    }

    /// Convenience wrapper for old view models that still have a UIKit controller
    /// reference and need to open the SwiftUI list picker.
    func pushSettingsSelectionList(_ selectionList: SettingsSelectionListContent) {
        settingsNavigationActions().pushSelectionList(selectionList)
    }

    /// Convenience wrapper for old view models that still have a UIKit controller
    /// reference and need to open the SwiftUI date picker.
    func pushSettingsDatePicker(_ datePicker: SettingsDatePickerContent) {
        settingsNavigationActions().pushDatePicker(datePicker)
    }
}

@MainActor
final class SettingsListModel: ObservableObject {
    @Published private(set) var reloadToken = UUID()

    let sections: [SettingsSectionModel]

    init(sections: [SettingsSectionModel]) {
        self.sections = sections
    }

    /// Triggers a SwiftUI refresh for rows backed by the old Settings view models.
    /// The scope is kept so call sites still describe what changed, even though
    /// SwiftUI refreshes the visible list from the same token today.
    func reload(_ scope: SettingsReloadScope) {
        reloadToken = UUID()
        objectWillChange.send()
    }
}

struct SettingsSectionModel: Identifiable {
    let id: Int
    let viewModel: SettingsViewModelProtocol
}

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
    private weak var controller: UIViewController?

    /// Keeps the router and optional UIKit host together so old row actions can
    /// be presented from SwiftUI without changing every Settings view model at once.
    init(router: SettingsRouter, controller: UIViewController? = nil) {
        self.router = router
        self.controller = controller
    }

    /// Stores the current UIKit host so old Settings actions can still push
    /// SwiftUI replacement screens through the existing navigation controller.
    func attach(controller: UIViewController) {
        self.controller = controller
    }

    /// Shows the simple message alert used by many of the old Settings view models.
    func showMessage(title: String, message: String?) {
        alert = SettingsAlertContent(title: title, message: message, actionTitle: Texts_Common.Ok, action: nil)
    }

    /// Converts a SettingsSelectedRowAction from the old view models into the
    /// equivalent SwiftUI alert, pushed editor, picker, segue route, or function call.
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
            controller?.pushSettingsTextEntry(SettingsTextEntryContent(
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
            ))

        case let .callFunction(function):
            function()
            reloadIfNeeded(viewModel: viewModel, rowIndex: rowIndex, sectionIndex: sectionIndex, reload: reload)

        case let .callFunctionAndShareFile(function):
            function { [weak self] progress in
                self?.router.showProgress?(progress)

                if let fileURL = progress?.data, progress?.complete == true {
                    DispatchQueue.main.async {
                        self?.router.presentShareFile?(fileURL)
                    }
                }
            }
            reloadIfNeeded(viewModel: viewModel, rowIndex: rowIndex, sectionIndex: sectionIndex, reload: reload)

        case let .selectFromList(title, data, selectedRow, actionTitle, cancelTitle, actionHandler, cancelHandler, didSelectRowHandler):
            controller?.pushSettingsSelectionList(SettingsSelectionListContent(
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
            ))

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
        controller?.pushSettingsDatePicker(datePicker)
    }

    /// Applies the refresh rule from the old view model after a row action finishes.
    /// Some rows only need their section refreshed, while others still ask for the
    /// full Settings list to be rebuilt.
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

    /// Maps the old storyboard segue identifiers to the SwiftUI routes now handled
    /// by SettingsRouter. This keeps the old view models from knowing about SwiftUI.
    private func route(identifier: String, sender: Any?) {
        switch identifier {
        case SettingsViewController.SegueIdentifiers.settingsToAlertTypeSettings.rawValue:
            router.openAlertTypes?()
        case SettingsViewController.SegueIdentifiers.settingsToAlertSettings.rawValue:
            router.openAlerts?()
        case SettingsViewController.SegueIdentifiers.settingsToM5StackSettings.rawValue:
            router.openM5Stack?()
        case SettingsViewController.SegueIdentifiers.settingsToSchedule.rawValue:
            if let timeSchedule = sender as? TimeSchedule {
                router.openTimeSchedule?(timeSchedule)
            }
        case SettingsViewController.SegueIdentifiers.settingsToLoopDelaySchedule.rawValue:
            router.openLoopDelaySchedule?()
        default:
            controller?.performSegue(withIdentifier: identifier, sender: sender)
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
    let keyboardType: UIKeyboardType?
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

struct SettingsConfirmationContent: Identifiable {
    let id = UUID()
    let title: String?
    let message: String?
    let action: () -> Void
    let cancel: (() -> Void)?
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

    var body: some View {
        List {
            ForEach(listModel.sections) { section in
                SettingsSectionView(
                    section: section,
                    presenter: presenter,
                    reload: listModel.reload
                )
                .id("\(section.id)-\(listModel.reloadToken)")
            }
        }
        .settingsListStyle(title: title)
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
    /// Adds a small coloured SF Symbol dot before the row title.
    /// This is used when the old Settings row text included a status marker, but
    /// the SwiftUI row should draw that marker instead of storing it in the text.
    let indicatorColor: Color?
    /// Adds a small coloured SF Symbol dot before the row detail text.
    /// This is for rows where the status belongs with the value on the right,
    /// such as the follower service status.
    let detailIndicatorColor: Color?
    let action: () -> Void

    init(
        title: String,
        detail: String?,
        isEnabled: Bool,
        showsDisclosure: Bool,
        showsInfoButton: Bool = false,
        titleColor: Color? = nil,
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
        self.indicatorColor = indicatorColor
        self.detailIndicatorColor = detailIndicatorColor
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
                    indicatorColor: indicatorColor,
                    detailIndicatorColor: detailIndicatorColor
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
    @ObservedObject var presenter: SettingsActionPresenter
    let reload: (SettingsReloadScope) -> Void

    var body: some View {
        Section {
            ForEach(0..<section.viewModel.numberOfRows(), id: \.self) { rowIndex in
                SettingsRowView(
                    rowIndex: rowIndex,
                    sectionIndex: section.id,
                    viewModel: section.viewModel,
                    presenter: presenter,
                    reload: reload
                )
            }
        } header: {
            if let title = section.viewModel.sectionTitle() {
                Text(title)
                    .foregroundStyle(Color(ConstantsUI.tableViewHeaderTextColor))
            }
        } footer: {
            if let footer = section.viewModel.sectionFooter() {
                Text(footer)
                    .foregroundStyle(Color(.colorSecondary))
            }
        }
    }
}

private struct SettingsRowView: View {
    let rowIndex: Int
    let sectionIndex: Int
    let viewModel: SettingsViewModelProtocol
    @ObservedObject var presenter: SettingsActionPresenter
    let reload: (SettingsReloadScope) -> Void

    var body: some View {
        if let switchAdapter = SettingsSwitchAdapter(viewModel: viewModel, rowIndex: rowIndex) {
            Toggle(isOn: Binding(
                get: { switchAdapter.isOn },
                set: { setSwitch(switchAdapter, isOn: $0) }
            )) {
                SettingsRowTextView(
                    title: viewModel.settingsRowText(index: rowIndex),
                    detail: viewModel.detailedText(index: rowIndex),
                    isEnabled: isEnabled,
                    indicatorColor: indicatorColor,
                    detailIndicatorColor: detailIndicatorColor
                )
            }
            .tint(.green)
            .disabled(!isEnabled)
        } else {
            SettingsStaticRowView(
                title: viewModel.settingsRowText(index: rowIndex),
                detail: viewModel.detailedText(index: rowIndex),
                isEnabled: isEnabled,
                showsDisclosure: isEnabled && (accessoryType == .disclosureIndicator || accessoryType == .detailDisclosureButton),
                showsInfoButton: isEnabled && (accessoryType == .detailButton || accessoryType == .detailDisclosureButton),
                indicatorColor: indicatorColor,
                detailIndicatorColor: detailIndicatorColor,
                action: selectRow
            )
        }
    }

    private var isEnabled: Bool {
        viewModel.isEnabled(index: rowIndex)
    }

    private var accessoryType: UITableViewCell.AccessoryType {
        viewModel.accessoryType(index: rowIndex)
    }

    /// Gets the optional title-side indicator colour for rows that need a dot
    /// before the row name. The row text stays clean and the SwiftUI view decides
    /// how the marker is drawn.
    private var indicatorColor: Color? {
        guard let homeScreenViewModel = viewModel as? SettingsViewHomeScreenSettingsViewModel,
              let color = homeScreenViewModel.rowIndicatorColor(index: rowIndex) else {
            return nil
        }

        return Color(color)
    }

    /// Gets the optional detail-side indicator colour for rows that need a dot
    /// before the value on the right. This keeps status symbols out of the detail
    /// string while preserving the old row meaning.
    private var detailIndicatorColor: Color? {
        guard let dataSourceViewModel = viewModel as? SettingsViewDataSourceSettingsViewModel,
              let color = dataSourceViewModel.followerServiceStatusIndicatorColor(index: rowIndex) else {
            return nil
        }

        return Color(color)
    }

    /// Applies a SwiftUI Toggle change through the old UISwitch adapter and then
    /// refreshes the same scope the old row would have refreshed.
    private func setSwitch(_ switchAdapter: SettingsSwitchAdapter, isOn: Bool) {
        switchAdapter.setIsOn(isOn)
        reload(viewModel.completeSettingsViewRefreshNeeded(index: rowIndex) ? .all : .section(sectionIndex))
    }

    /// Runs the old view-model row action through SettingsActionPresenter so the
    /// SwiftUI row keeps the previous action, alert and navigation behaviour.
    private func selectRow() {
        presenter.run(
            selectedRowAction: viewModel.onRowSelect(index: rowIndex),
            rowIndex: rowIndex,
            sectionIndex: sectionIndex,
            viewModel: viewModel,
            reload: reload
        )
    }
}

struct SettingsRowTextView: View {
    let title: String
    let detail: String?
    let isEnabled: Bool
    let titleColor: Color?
    /// Draws a small dot before the title when a row needs a visual range/status marker.
    let indicatorColor: Color?
    /// Draws a small dot before the detail value when the marker belongs with the value.
    let detailIndicatorColor: Color?

    init(title: String, detail: String?, isEnabled: Bool, titleColor: Color? = nil, indicatorColor: Color? = nil, detailIndicatorColor: Color? = nil) {
        self.title = title
        self.detail = detail
        self.isEnabled = isEnabled
        self.titleColor = titleColor
        self.indicatorColor = indicatorColor
        self.detailIndicatorColor = detailIndicatorColor
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 7) {
                if let indicatorColor {
                    Image(systemName: "circle.fill")
                        .font(.caption2)
                        .foregroundStyle(isEnabled ? indicatorColor : .gray)
                }

                Text(title)
                    .foregroundStyle(titleColor ?? (isEnabled ? Color(.colorPrimary) : .gray))
                    .lineLimit(2)
                    .minimumScaleFactor(0.75)
                    .frame(alignment: .leading)
            }

            Spacer(minLength: 8)

            if let detail, !detail.isEmpty {
                HStack(spacing: 5) {
                    if let detailIndicatorColor {
                        Image(systemName: "circle.fill")
                            .font(.caption2)
                            .foregroundStyle(isEnabled ? detailIndicatorColor : .gray)
                    }

                    Text(detail)
                        .foregroundStyle(isEnabled ? Color(.colorTertiary) : .gray)
                        .lineLimit(1)
                        .multilineTextAlignment(.trailing)
                        .frame(alignment: .trailing)
                }
                .layoutPriority(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct SettingsDisclosureIndicator: View {
    var body: some View {
        Image(systemName: "chevron.right")
            .font(.footnote.weight(.semibold))
            .foregroundStyle(Color(ConstantsUI.disclosureIndicatorColor))
    }
}

struct SettingsInfoIndicator: View {
    var body: some View {
        Image(systemName: "info.circle")
            .font(.body)
            .foregroundStyle(Color(ConstantsUI.disclosureIndicatorColor))
    }
}

struct SettingsSwitchAdapter {
    private let makeSwitch: () -> UISwitch?

    /// Wraps the UISwitch returned by an old Settings view model so SwiftUI can
    /// render it as a Toggle while still using the original switch action closure.
    init?(viewModel: SettingsViewModelProtocol, rowIndex: Int) {
        guard viewModel.uiView(index: rowIndex) is UISwitch else {
            return nil
        }

        makeSwitch = {
            viewModel.uiView(index: rowIndex) as? UISwitch
        }
    }

    var isOn: Bool {
        makeSwitch()?.isOn ?? false
    }

    /// Updates the old UISwitch and sends its value changed action so existing
    /// Settings logic continues to run unchanged.
    func setIsOn(_ isOn: Bool) {
        guard let uiSwitch = makeSwitch() else { return }
        uiSwitch.setOn(isOn, animated: false)
        uiSwitch.sendActions(for: .valueChanged)
    }
}

extension View {
    /// Applies the standard Settings list appearance used by all migrated screens.
    func settingsListStyle(title: String) -> some View {
        self
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(ConstantsUI.listBackGroundColor)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .colorScheme(.dark)
    }

    /// Adds alert and confirmation handling for rows backed by SettingsActionPresenter.
    func settingsPresentation(presenter: SettingsActionPresenter) -> some View {
        modifier(SettingsPresentationModifier(presenter: presenter))
    }

    /// Adds pushed edit screens for text, selection and date picker requests.
    /// This replaces the old modal popup flow with the same navigation pattern
    /// across the migrated Settings screens.
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
                        primaryButton: .default(Text(Texts_Common.Ok), action: confirmation.action),
                        secondaryButton: .cancel(Text(Texts_Common.Cancel)) {
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

    /// Watches for new editor content and immediately pushes the matching Settings
    /// edit screen through the hosting navigation controller.
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

    /// Starts the pushed text editor with the value supplied by the old row action.
    init(textEntry: SettingsTextEntryContent, close: @escaping () -> Void) {
        self.textEntry = textEntry
        self.close = close
        _value = State(initialValue: textEntry.text ?? "")
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
                            .keyboardType(textEntry.keyboardType ?? .default)
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
                    .keyboardType(textEntry.keyboardType ?? .default)
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
            }
        }
        .onDisappear {
            guard !didComplete else { return }

            textEntry.cancel?()
        }
        .colorScheme(.dark)
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

    /// Starts the pushed picker on the same selected row the old picker would show.
    init(selectionList: SettingsSelectionListContent, close: @escaping () -> Void) {
        self.selectionList = selectionList
        self.close = close
        _selectedRow = State(initialValue: selectionList.selectedRow ?? 0)
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
                }
                .buttonStyle(.plain)
            }
        }
        .settingsListStyle(title: selectionList.title ?? "")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button(selectionList.actionTitle) {
                    didComplete = true
                    selectionList.action(selectedRow)
                    close()
                }
            }
        }
        .onDisappear {
            guard !didComplete else { return }

            selectionList.cancel?()
        }
    }

    /// Updates the selected row and runs the old did-select preview callback if one
    /// was supplied by the original Settings action.
    private func select(index: Int) {
        selectedRow = index
        selectionList.didSelectRow?(index)
    }
}
