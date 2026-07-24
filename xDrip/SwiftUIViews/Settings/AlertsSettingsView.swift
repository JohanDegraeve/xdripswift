//
//  AlertsSettingsView.swift
//  xdrip
//
//  Created by Paul Plant on 22/6/26.
//  Copyright © 2026 Johan Degraeve. All rights reserved.
//

import CoreData
import os
import SwiftUI

// Rules for which alarms and rows are shown are kept with the list model.
@MainActor
final class AlertsSettingsViewModel: ObservableObject {
    @Published var reloadToken = UUID()

    private let coreDataManager: CoreDataManager
    private let alertEntriesAccessor: AlertEntriesAccessor
    private let alertTypesAccessor: AlertTypesAccessor

    /// Keeps the Core Data accessors inside the list model so it can rebuild alarm groups.
    init(coreDataManager: CoreDataManager) {
        self.coreDataManager = coreDataManager
        self.alertEntriesAccessor = AlertEntriesAccessor(coreDataManager: coreDataManager)
        self.alertTypesAccessor = AlertTypesAccessor(coreDataManager: coreDataManager)
    }

    /// Reads the current alarms grouped by alert kind.
    /// The grouping comes from the accessor and preserves its section order.
    var alertEntriesPerAlertKind: [[AlertEntry]] {
        alertEntriesAccessor.getAllEntriesPerAlertKind(alertTypesAccessor: alertTypesAccessor)
    }

    /// Refreshes the SwiftUI list after an alarm is added, edited or deleted.
    /// The rows are read again from Core Data through AlertEntriesAccessor.
    func reload() {
        reloadToken = UUID()
    }

    /// Returns the visible alarm rows for a section.
    /// If the first alarm for a kind is disabled, only its disabled summary row is shown.
    func rows(for section: Int) -> [AlertEntry] {
        let entries = alertEntriesPerAlertKind[AlertKind.alertKindRawValue(forSection: section)]

        if let firstEntry = entries.first, firstEntry.isDisabled {
            return Array(entries.prefix(1))
        }

        return entries
    }

    /// Returns the section title for an alert kind.
    /// Urgent alert kinds include an exclamation marker in the section header.
    func title(for section: Int) -> String {
        let alertKind = AlertKind(forSection: section)

        return (alertKind?.alertUrgencyType() == .urgent ? "\u{2757}" : "") + (alertKind?.alertTitle() ?? "")
    }

    /// Builds the edit request for the selected alarm row.
    /// Adjacent alarms define the allowed start-time range.
    func editData(section: Int, row: Int) -> AlertEntryEditRequest {
        let mappedSection = AlertKind.alertKindRawValue(forSection: section)
        let entries = alertEntriesPerAlertKind[mappedSection]

        var minimumStart: Int16 = 0
        if row > 0 {
            minimumStart = entries[row - 1].start + 1
        }

        var maximumStart: Int16 = 24 * 60 - 1
        if row < entries.count - 1 {
            maximumStart = entries[row + 1].start - 1
        }

        return AlertEntryEditRequest(
            alertEntry: entries[row],
            minimumStart: minimumStart,
            maximumStart: maximumStart
        )
    }
}

struct AlertEntryEditRequest {
    let alertEntry: AlertEntry
    let minimumStart: Int16
    let maximumStart: Int16
}

struct AlertsSettingsView: View {
    @ObservedObject var viewModel: AlertsSettingsViewModel

    let openAlertEntry: (AlertEntryEditRequest) -> Void

    var body: some View {
        List {
            ForEach(viewModel.alertEntriesPerAlertKind.indices, id: \.self) { section in
                Section(viewModel.title(for: section)) {
                    let rows = viewModel.rows(for: section)
                    ForEach(Array(rows.enumerated()), id: \.element.objectID) { row, alertEntry in
                        AlertEntrySummaryRow(
                            alertEntry: alertEntry,
                            action: {
                                openAlertEntry(viewModel.editData(section: section, row: row))
                            }
                        )
                    }
                }
            }
        }
        .id(viewModel.reloadToken)
        .settingsListStyle(title: Texts_Alerts.alertsScreenTitle, titleDisplayMode: .inline)
    }
}

private struct AlertEntrySummaryRow: View {
    let alertEntry: AlertEntry
    let action: () -> Void

    var body: some View {
        SettingsStaticRowView(
            title: title,
            detail: nil,
            isEnabled: true,
            showsDisclosure: true,
            titleColor: alertEntry.isDisabled ? Color(.colorTertiary) : nil,
            action: action
        )
    }

    /// Builds the summary text shown in the alarm list.
    /// Combines start time, values, trigger values and alert type name into one title.
    private var title: String {
        guard !alertEntry.isDisabled else {
            return ConstantsAlerts.disabledAlertSymbol + " " + Texts_Common.disabled
        }

        guard let alertKind = AlertKind(rawValue: Int(alertEntry.alertkind)) else {
            return ""
        }

        let separator = " \u{00B7} "
        var text = Int(alertEntry.start).convertMinutesToTimeAsString()
        text += separator

        if alertEntry.alertType.enabled && alertKind.needsAlertValue() {
            text += alertKind.valueIsABgValue()
                ? Double(alertEntry.value).mgDlToMmolAndToString(mgDl: UserDefaults.standard.bloodGlucoseUnitIsMgDl)
                : alertEntry.value.description

            if alertKind.needsAlertTriggerValue() {
                switch alertKind {
                case .fastdrop:
                    text += " (<"
                case .fastrise:
                    text += " (>"
                default:
                    break
                }

                text += alertKind.valueIsABgValue()
                    ? Double(alertEntry.triggerValue).mgDlToMmolAndToString(mgDl: UserDefaults.standard.bloodGlucoseUnitIsMgDl)
                    : alertEntry.triggerValue.description
                text += ")"
            }

            text += separator
        }

        text += alertEntry.alertType.name + (alertEntry.alertType.enabled ? "" : ConstantsAlerts.disabledAlertSymbolStringToAppend)

        return text
    }
}

enum AlertEntryEditorSetting: Int, CaseIterable {
    case isDisabled
    case start
    case alertType
    case value
    case triggerValue
}

@MainActor
final class AlertEntryEditorViewModel: ObservableObject {
    @Published var isDisabled: Bool
    @Published var start: Int16
    @Published var value: Int16
    @Published var triggerValue: Int16
    @Published var alertKind: Int16
    @Published var alertType: AlertType
    @Published var textEntry: SettingsTextEntryContent?
    @Published var selectionList: SettingsSelectionListContent?
    @Published var datePicker: SettingsDatePickerContent?
    @Published var confirmation: SettingsConfirmationContent?

    let minimumStart: Int16
    let maximumStart: Int16
    let mode: AlertEntryEditorMode

    private let original: AlertEntrySnapshot
    private let coreDataManager: CoreDataManager
    private let close: () -> Void
    private let log = OSLog(subsystem: ConstantsLog.subSystem, category: ConstantsLog.categoryApplicationDataAlertEntries)

    init(
        mode: AlertEntryEditorMode,
        coreDataManager: CoreDataManager,
        close: @escaping () -> Void
    ) {
        // Copy the selected alarm into editable SwiftUI state. The Core Data object
        // is left untouched until Save, which keeps Cancel/back behaviour predictable.
        self.mode = mode
        self.coreDataManager = coreDataManager
        self.close = close

        switch mode {
        case let .edit(alertEntry, minimumStart, maximumStart):
            self.isDisabled = alertEntry.isDisabled
            self.start = alertEntry.start
            self.value = alertEntry.value
            self.triggerValue = alertEntry.triggerValue
            self.alertKind = alertEntry.alertkind
            self.alertType = alertEntry.alertType
            self.minimumStart = minimumStart
            self.maximumStart = maximumStart
            self.original = AlertEntrySnapshot(
                isDisabled: alertEntry.isDisabled,
                start: alertEntry.start,
                value: alertEntry.value,
                triggerValue: alertEntry.triggerValue,
                alertKind: alertEntry.alertkind,
                alertTypeName: alertEntry.alertType.name
            )

        case let .new(alertKind, minimumStart, maximumStart):
            let defaultAlertType = AlertTypesAccessor(coreDataManager: coreDataManager).getDefaultAlertType()

            self.isDisabled = false
            self.start = minimumStart
            self.value = Int16(alertKind.defaultAlertValue())
            self.triggerValue = Int16(alertKind.defaultAlertTriggerValue())
            self.alertKind = Int16(alertKind.rawValue)
            self.alertType = defaultAlertType
            self.minimumStart = minimumStart
            self.maximumStart = maximumStart
            self.original = AlertEntrySnapshot(
                isDisabled: false,
                start: minimumStart,
                value: Int16(alertKind.defaultAlertValue()),
                triggerValue: Int16(alertKind.defaultAlertTriggerValue()),
                alertKind: Int16(alertKind.rawValue),
                alertTypeName: defaultAlertType.name
            )
        }
    }

    /// Returns the rows that should be visible for the current alarm state.
    /// Disabled alarms show only the enabled switch; trigger rows appear only where required.
    var rows: [AlertEntryEditorSetting] {
        if isDisabled {
            return [.isDisabled]
        }

        if alertKindValue.needsAlertValue() || alertType.enabled {
            if alertKindValue.needsAlertTriggerValue() {
                return AlertEntryEditorSetting.allCases
            }

            return [.isDisabled, .start, .alertType, .value]
        }

        return [.isDisabled, .start, .alertType]
    }

    /// Returns the navigation title for the editor.
    /// Existing alarms use just the alert name; new alarms include the Add prefix.
    var title: String {
        switch mode {
        case .edit:
            return alertKindValue.alertTitle()
        case .new:
            return Texts_Common.add + " " + alertKindValue.alertTitle()
        }
    }

    /// Save is only enabled for edited alarms when something has changed.
    var canSave: Bool {
        switch mode {
        case .edit:
            return hasChanges
        case .new:
            return true
        }
    }

    /// Existing alarms can only be deleted when they are not the midnight base row
    /// and there are no unsaved edits.
    var canDelete: Bool {
        guard case .edit = mode else { return false }

        return start != 0 && !hasChanges
    }

    /// Allows adding another alarm after the current one only when the current
    /// editor has no unsaved changes.
    var canAdd: Bool {
        guard case .edit = mode else { return false }

        return !hasChanges
    }

    /// Writes the editor values back to Core Data or creates a new AlertEntry.
    /// Missed-reading alarms still toggle the existing UserDefaults flag used by
    /// the rest of the app.
    func save() {
        switch mode {
        case let .edit(alertEntry, _, _):
            updateAllEntriesForCurrentKindDisabledState()

            alertEntry.alertkind = alertKind
            alertEntry.alertType = alertType
            alertEntry.start = start
            alertEntry.value = value
            alertEntry.triggerValue = triggerValue
            coreDataManager.saveChanges()

            if alertEntry.alertkind == AlertKind.missedreading.rawValue {
                UserDefaults.standard.missedReadingAlertChanged = true
            }

        case .new:
            _ = AlertEntry(
                isDisabled: isDisabled,
                value: Int(value),
                triggerValue: Int(triggerValue),
                alertKind: alertKindValue,
                start: Int(start),
                alertType: alertType,
                nsManagedObjectContext: coreDataManager.mainManagedObjectContext
            )
            coreDataManager.saveChanges()
        }

        close()
    }

    /// Shows the delete confirmation before removing an existing alarm entry.
    func requestDelete() {
        guard case let .edit(alertEntry, _, _) = mode else {
            close()
            return
        }

        confirmation = SettingsConfirmationContent(
            title: Texts_Alerts.confirmDeletionAlert,
            message: nil,
            action: { [weak self] in
                guard let self else { return }

                self.coreDataManager.mainManagedObjectContext.delete(alertEntry)
                self.coreDataManager.saveChanges()
                self.close()
            },
            cancel: nil
        )
    }

    /// Creates the editor mode for adding a new alarm after the current start time.
    /// The caller pushes a second editor so the add flow slides in like the edit flow.
    func newAlertMode() -> AlertEntryEditorMode? {
        guard case .edit = mode else { return nil }

        guard let alertKind = AlertKind(rawValue: Int(alertKind)) else { return nil }

        return .new(
            alertKind: alertKind,
            minimumStart: start + 1,
            maximumStart: maximumStart
        )
    }

    /// Opens the pushed editor for rows that need extra input, such as the start
    /// time, value, trigger value or alert type.
    func select(_ setting: AlertEntryEditorSetting) {
        switch setting {
        case .isDisabled:
            break

        case .start:
            guard start != 0 else { return }

            let midnight = Date().toMidnight()
            datePicker = SettingsDatePickerContent(
                title: alertKindValue.alertTitle(),
                subtitle: Texts_Alerts.alertStart,
                mode: .time,
                date: Date(timeInterval: TimeInterval(Double(start) * 60.0), since: midnight),
                minimumDate: Date(timeInterval: TimeInterval(Double(minimumStart) * 60.0), since: midnight),
                maximumDate: Date(timeInterval: TimeInterval(Double(maximumStart) * 60.0), since: midnight),
                okTitle: Texts_Common.Ok,
                cancelTitle: Texts_Common.Cancel,
                ok: { [weak self] date in
                    self?.start = Int16(date.minutesSinceMidNightLocalTime())
                },
                cancel: nil
            )

        case .value:
            textEntry = makeValueTextEntry(
                title: alertKindValue.alertTitle(),
                message: Texts_Alerts.changeAlertValue,
                currentValue: value,
                update: { [weak self] newValue in
                    self?.value = newValue
                },
                isTriggerValue: false
            )

        case .triggerValue:
            textEntry = makeValueTextEntry(
                title: alertKindValue.alertTitle(),
                message: triggerValueText,
                currentValue: triggerValue,
                update: { [weak self] newValue in
                    self?.triggerValue = newValue
                },
                isTriggerValue: true
            )

        case .alertType:
            showAlertTypeSelection()
        }
    }

    /// Returns the localized row title for the current editor setting.
    func title(for setting: AlertEntryEditorSetting) -> String {
        switch setting {
        case .isDisabled:
            return Texts_Common.enabled
        case .start:
            return Texts_Alerts.alertStart
        case .alertType:
            return Texts_Alerts.alerttype
        case .value:
            return Texts_Alerts.alertValue
        case .triggerValue:
            return triggerValueText
        }
    }

    /// Returns the right-hand detail text for rows that show the current alarm value.
    func detail(for setting: AlertEntryEditorSetting) -> String? {
        switch setting {
        case .isDisabled:
            return isDisabled ? ConstantsAlerts.disabledAlertSymbol : nil
        case .start:
            return Int(start).convertMinutesToTimeAsString()
        case .alertType:
            return format(alertType: alertType)
        case .value:
            return formatted(value: value)
        case .triggerValue:
            return formatted(value: triggerValue)
        }
    }

    private var alertKindValue: AlertKind {
        guard let alertKindValue = AlertKind(rawValue: Int(alertKind)) else {
            fatalError("AlertEntryEditorState could not create AlertKind from the stored value")
        }

        return alertKindValue
    }

    /// Compares the current editor state with the original alarm so toolbar buttons
    /// can apply the enable and disable rules.
    private var hasChanges: Bool {
        isDisabled != original.isDisabled ||
            start != original.start ||
            value != original.value ||
            triggerValue != original.triggerValue ||
            alertKind != original.alertKind ||
            alertType.name != original.alertTypeName
    }

    /// Returns the correct trigger value label for fast drop and fast rise alarms.
    private var triggerValueText: String {
        switch alertKindValue {
        case .fastdrop:
            return Texts_Alerts.alertWhenBelowValue
        case .fastrise:
            return Texts_Alerts.alertWhenAboveValue
        default:
            return ""
        }
    }

    /// Applies the enabled/disabled state to all alarms of the same kind.
    /// This setting applies to the complete alarm group.
    private func updateAllEntriesForCurrentKindDisabledState() {
        let context = coreDataManager.mainManagedObjectContext
        let fetchRequest: NSFetchRequest<AlertEntry> = AlertEntry.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "alertkind = %i", alertKind)

        do {
            let entries = try context.fetch(fetchRequest)
            for entry in entries {
                entry.isDisabled = isDisabled
            }
        } catch {
            trace("in updateAllEntriesForCurrentKindDisabledState, failed to fetch AlertEntries: %{public}@", log: log, category: ConstantsLog.categoryApplicationDataAlertEntries, type: .error, error.localizedDescription)
        }
    }

    /// Builds the text editor for alarm values and trigger values.
    /// Converts mmol/L input back to mg/dL before
    /// storing because AlertEntry values are persisted in mg/dL.
    private func makeValueTextEntry(
        title: String,
        message: String,
        currentValue: Int16,
        update: @escaping (Int16) -> Void,
        isTriggerValue: Bool
    ) -> SettingsTextEntryContent {
        let valueIsBg = alertKindValue.valueIsABgValue()
        let isMgDl = UserDefaults.standard.bloodGlucoseUnitIsMgDl
        let keyboardType: SettingsKeyboardType = valueIsBg && !isMgDl ? .decimalPad : .numberPad

        return SettingsTextEntryContent(
            title: title,
            message: message,
            keyboardType: keyboardType,
            text: Double(currentValue).mgDlToMmolAndToString(mgDl: isMgDl || !valueIsBg),
            placeholder: nil,
            fieldTitle: nil,
            unitText: alertKindValue.valueUnitText(transmitterType: UserDefaults.standard.cgmTransmitterType).toNilIfLength0(),
            actionTitle: Texts_Common.Ok,
            cancelTitle: Texts_Common.Cancel,
            action: { text in
                guard var newValue = text.toDouble() else { return }

                var newValueIsValid = true
                if valueIsBg {
                    newValue = newValue.mmolToMgdl(mgDl: isMgDl)
                    newValueIsValid = isTriggerValue
                        ? newValue > ConstantsCalibrationAlgorithms.minimumBgReadingCalculatedValue && newValue < ConstantsCalibrationAlgorithms.maximumBgReadingCalculatedValue
                        : newValue > 0.0 && newValue < ConstantsCalibrationAlgorithms.maximumBgReadingCalculatedValue
                }

                if newValue < 32767.0, newValueIsValid {
                    update(Int16(newValue))
                }
            },
            cancel: nil,
            validator: nil
        )
    }

    /// Opens the alert type picker and stores the selected AlertType object.
    /// Disabled alert types remain visible with their disabled marker.
    private func showAlertTypeSelection() {
        let allAlertTypes = AlertTypesAccessor(coreDataManager: coreDataManager).getAllAlertTypes()
        let names = allAlertTypes.map(format(alertType:))
        let selectedRow = names.firstIndex(of: format(alertType: alertType)) ?? 0

        selectionList = SettingsSelectionListContent(
            title: Texts_Alerts.alerttype,
            data: names,
            selectedRow: selectedRow,
            actionTitle: Texts_Common.Ok,
            cancelTitle: Texts_Common.Cancel,
            action: { [weak self] index in
                self?.alertType = allAlertTypes[index]
            },
            cancel: {},
            didSelectRow: nil
        )
    }

    /// Formats alert type names for rows and pickers, including the disabled marker
    /// used by Settings rows and pickers.
    private func format(alertType: AlertType) -> String {
        alertType.name + (alertType.enabled ? "" : ConstantsAlerts.disabledAlertSymbolStringToAppend)
    }

    /// Formats alarm values with the correct unit text and glucose unit conversion.
    private func formatted(value: Int16) -> String {
        let unitText = alertKindValue.valueUnitText(transmitterType: UserDefaults.standard.cgmTransmitterType)

        if !unitText.isEmpty {
            if alertKindValue.valueIsABgValue() {
                return Double(value).mgDlToMmolAndToString(mgDl: UserDefaults.standard.bloodGlucoseUnitIsMgDl) + " " + unitText
            }

            return value.description + " " + unitText
        }

        return value.description
    }
}

enum AlertEntryEditorMode {
    case edit(alertEntry: AlertEntry, minimumStart: Int16, maximumStart: Int16)
    case new(alertKind: AlertKind, minimumStart: Int16, maximumStart: Int16)
}

private struct AlertEntrySnapshot {
    let isDisabled: Bool
    let start: Int16
    let value: Int16
    let triggerValue: Int16
    let alertKind: Int16
    let alertTypeName: String
}

struct AlertEntryEditorView: View {
    @StateObject private var viewModel: AlertEntryEditorViewModel

    let openNewAlert: (AlertEntryEditorMode) -> Void

    init(
        mode: AlertEntryEditorMode,
        coreDataManager: CoreDataManager,
        close: @escaping () -> Void,
        openNewAlert: @escaping (AlertEntryEditorMode) -> Void
    ) {
        // The pushed editor owns its view model so local edits survive while child
        // pickers and text-entry screens are pushed on top.
        _viewModel = StateObject(wrappedValue: AlertEntryEditorViewModel(
            mode: mode,
            coreDataManager: coreDataManager,
            close: close
        ))
        self.openNewAlert = openNewAlert
    }

    var body: some View {
        List {
            Section {
                ForEach(viewModel.rows, id: \.rawValue) { setting in
                    row(for: setting)
                }
            }
        }
        .settingsListStyle(title: viewModel.title, titleDisplayMode: .inline)
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                Button {
                    if let mode = viewModel.newAlertMode() {
                        openNewAlert(mode)
                    }
                } label: {
                    Image(systemName: "plus")
                }
                .disabled(!viewModel.canAdd)

                Button(Texts_Common.Ok, action: viewModel.save)
                    .disabled(!viewModel.canSave)
            }

            ToolbarItem(placement: .navigationBarLeading) {
                Button(role: .destructive, action: viewModel.requestDelete) {
                    Image(systemName: "trash")
                }
                .disabled(!viewModel.canDelete)
            }
        }
        .settingsPushPresentation(
            textEntry: $viewModel.textEntry,
            selectionList: $viewModel.selectionList,
            datePicker: $viewModel.datePicker
        )
        .alert(item: $viewModel.confirmation) { confirmation in
            Alert(
                title: Text(confirmation.title ?? ""),
                message: confirmation.message.map { Text($0) },
                primaryButton: .destructive(Text(Texts_Common.delete), action: confirmation.action),
                secondaryButton: .cancel(Text(Texts_Common.Cancel)) {
                    confirmation.cancel?()
                }
            )
        }
    }

    /// Builds the SwiftUI row for each alarm editor setting.
    /// Toggle rows update editor state directly; value rows open the pushed
    /// shared Settings editors.
    @ViewBuilder
    private func row(for setting: AlertEntryEditorSetting) -> some View {
        switch setting {
        case .isDisabled:
            Toggle(isOn: Binding(
                get: { !viewModel.isDisabled },
                set: { viewModel.isDisabled = !$0 }
            )) {
                SettingsRowTextView(title: viewModel.title(for: setting), detail: viewModel.detail(for: setting), isEnabled: true)
            }
            .tint(.green)

        case .start:
            SettingsStaticRowView(
                title: viewModel.title(for: setting),
                detail: viewModel.detail(for: setting),
                isEnabled: viewModel.start != 0,
                showsDisclosure: viewModel.start != 0,
                action: { viewModel.select(setting) }
            )

        case .alertType, .value, .triggerValue:
            SettingsStaticRowView(
                title: viewModel.title(for: setting),
                detail: viewModel.detail(for: setting),
                isEnabled: true,
                showsDisclosure: true,
                action: { viewModel.select(setting) }
            )
        }
    }
}
