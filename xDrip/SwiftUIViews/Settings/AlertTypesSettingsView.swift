//
//  AlertTypesSettingsView.swift
//  xdrip
//
//  Created by Paul Plant on 22/6/26.
//  Copyright © 2026 Johan Degraeve. All rights reserved.
//

import SwiftUI

// Alert-type Core Data and validation behavior is owned by the list and editor models.
@MainActor
final class AlertTypesSettingsViewModel: ObservableObject {
    @Published var reloadToken = UUID()

    private let coreDataManager: CoreDataManager
    private let alertTypesAccessor: AlertTypesAccessor

    /// Keeps the Core Data accessor inside the SwiftUI list model so the list can
    /// reload itself after child editors make changes.
    init(coreDataManager: CoreDataManager) {
        self.coreDataManager = coreDataManager
        self.alertTypesAccessor = AlertTypesAccessor(coreDataManager: coreDataManager)
    }

    /// Reads the current alert types from Core Data each time the list refreshes.
    /// This keeps the SwiftUI screen in sync with edits made in the pushed editor.
    var alertTypes: [AlertType] {
        alertTypesAccessor.getAllAlertTypes()
    }

    /// Refreshes the SwiftUI list after an alert type is added, edited or deleted.
    /// The list reads directly from Core Data through AlertTypesAccessor.
    func reload() {
        reloadToken = UUID()
    }
}

struct AlertTypesSettingsView: View {
    @ObservedObject var viewModel: AlertTypesSettingsViewModel

    let openAlertType: (AlertType?) -> Void

    var body: some View {
        List {
            Section {
                ForEach(Array(viewModel.alertTypes.enumerated()), id: \.element.objectID) { _, alertType in
                    SettingsStaticRowView(
                        title: alertType.name,
                        detail: alertType.enabled ? nil : ConstantsAlerts.disabledAlertSymbol,
                        isEnabled: true,
                        showsDisclosure: true,
                        action: { openAlertType(alertType) }
                    )
                }
            }
        }
        .id(viewModel.reloadToken)
        .settingsListStyle(title: Texts_AlertTypeSettingsView.alertTypesScreenTitle, titleDisplayMode: .inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    openAlertType(nil)
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
    }
}

enum AlertTypeEditorSetting: Int, CaseIterable {
    case enabled
    case name
    case vibrate
    case soundName
    case overrideMute
    case snoozeViaNotification
    case defaultSnoozePeriod
}

@MainActor
final class AlertTypeEditorViewModel: ObservableObject {
    @Published var enabled = ConstantsDefaultAlertTypeSettings.enabled
    @Published var name = ConstantsDefaultAlertTypeSettings.name
    @Published var overrideMute = ConstantsDefaultAlertTypeSettings.overrideMute
    @Published var snooze = ConstantsDefaultAlertTypeSettings.snooze
    @Published var snoozePeriod = ConstantsDefaultAlertTypeSettings.snoozePeriod
    @Published var vibrate = ConstantsDefaultAlertTypeSettings.vibrate
    @Published var soundName = ConstantsDefaultAlertTypeSettings.soundName
    @Published var alert: SettingsAlertContent?
    @Published var confirmation: SettingsConfirmationContent?
    @Published var textEntry: SettingsTextEntryContent?
    @Published var selectionList: SettingsSelectionListContent?

    private var alertType: AlertType?
    private let coreDataManager: CoreDataManager
    private let soundPlayer: SoundPlayer
    private let close: () -> Void

    init(
        alertType: AlertType?,
        coreDataManager: CoreDataManager,
        soundPlayer: SoundPlayer,
        close: @escaping () -> Void
    ) {
        // Copy the existing alert type into editable SwiftUI state. The original
        // The Core Data object is updated only when Save is tapped.
        self.alertType = alertType
        self.coreDataManager = coreDataManager
        self.soundPlayer = soundPlayer
        self.close = close

        if let alertType {
            enabled = alertType.enabled
            name = alertType.name
            overrideMute = alertType.overridemute
            snooze = alertType.snooze
            snoozePeriod = alertType.snoozeperiod
            vibrate = alertType.vibrate
            soundName = alertType.soundname
        }
    }

    /// Hides advanced rows when the alert type is disabled.
    var rows: [AlertTypeEditorSetting] {
        enabled ? AlertTypeEditorSetting.allCases : [.enabled, .name]
    }

    /// Alert types that are still used by alarms cannot be deleted.
    /// Alert types that are still referenced by alarms remain protected.
    var canDelete: Bool {
        guard let alertType else { return false }

        return (alertType.alertEntries?.count ?? 0) == 0
    }

    /// Validates the alert type name, writes the edited values to Core Data and
    /// closes the editor. New alert types are created with the same defaults as the
    /// standard Settings defaults.
    func save() {
        let alertTypesAccessor = AlertTypesAccessor(coreDataManager: coreDataManager)
        for storedAlertType in alertTypesAccessor.getAllAlertTypes() {
            if storedAlertType.name == name && (alertType == nil || storedAlertType != alertType) {
                alert = SettingsAlertContent(
                    title: Texts_Common.warning,
                    message: Texts_AlertTypeSettingsView.alertTypeNameAlreadyExistsMessage,
                    actionTitle: Texts_Common.Ok,
                    action: nil
                )
                return
            }
        }

        if let alertType {
            alertType.name = name
            alertType.enabled = enabled
            alertType.overridemute = overrideMute
            alertType.snooze = snooze
            alertType.snoozeperiod = snoozePeriod
            alertType.vibrate = vibrate
            alertType.soundname = soundName
        } else {
            alertType = AlertType(
                enabled: enabled,
                name: name,
                overrideMute: overrideMute,
                snooze: snooze,
                snoozePeriod: Int(snoozePeriod),
                vibrate: vibrate,
                soundName: soundName,
                alertEntries: nil,
                nsManagedObjectContext: coreDataManager.mainManagedObjectContext
            )
        }

        coreDataManager.saveChanges()
        close()
    }

    /// Shows the delete confirmation before removing an unused alert type from Core Data.
    func requestDelete() {
        guard let alertType else {
            close()
            return
        }

        confirmation = SettingsConfirmationContent(
            title: Texts_AlertTypeSettingsView.confirmDeletionAlertType + alertType.name + "?",
            message: nil,
            action: { [weak self] in
                guard let self else { return }

                self.coreDataManager.mainManagedObjectContext.delete(alertType)
                self.coreDataManager.saveChanges()
                self.close()
            },
            cancel: nil
        )
    }

    /// Opens the pushed editor or picker for rows that need extra input.
    /// Toggle rows update their state directly and do not need any action here.
    func select(_ setting: AlertTypeEditorSetting) {
        switch setting {
        case .name:
            textEntry = SettingsTextEntryContent(
                title: Texts_AlertTypeSettingsView.alertTypeName,
                message: Texts_AlertTypeSettingsView.alertTypeGiveAName,
                keyboardType: .alphabet,
                text: name,
                placeholder: nil,
                fieldTitle: nil,
                unitText: nil,
                actionTitle: Texts_Common.Ok,
                cancelTitle: Texts_Common.Cancel,
                action: { [weak self] text in
                    self?.name = text
                },
                cancel: nil,
                validator: nil
            )

        case .defaultSnoozePeriod:
            showSnoozePeriodSelection()

        case .soundName:
            showSoundSelection()

        case .enabled, .vibrate, .overrideMute, .snoozeViaNotification:
            break
        }
    }

    /// Returns the localized row title for the editor setting.
    /// Keeping this in the view model gives every row the same derived title.
    func title(for setting: AlertTypeEditorSetting) -> String {
        switch setting {
        case .enabled:
            return Texts_AlertTypeSettingsView.alertTypeEnabled
        case .name:
            return Texts_AlertTypeSettingsView.alertTypeName
        case .vibrate:
            return Texts_AlertTypeSettingsView.alertTypeVibrate
        case .soundName:
            return Texts_AlertTypeSettingsView.alertTypeSound
        case .overrideMute:
            return Texts_AlertTypeSettingsView.alertTypeOverrideMute
        case .snoozeViaNotification:
            return Texts_AlertTypeSettingsView.alertTypeSnoozeViaNotification
        case .defaultSnoozePeriod:
            return Texts_AlertTypeSettingsView.alertTypeDefaultSnoozePeriod
        }
    }

    /// Returns the right-hand detail text for rows that show a current value.
    /// The sound row distinguishes nil, empty and named sounds.
    func detail(for setting: AlertTypeEditorSetting) -> String? {
        switch setting {
        case .enabled:
            return enabled ? nil : ConstantsAlerts.disabledAlertSymbol
        case .name:
            return name
        case .soundName:
            if let soundName {
                return soundName.isEmpty ? Texts_AlertTypeSettingsView.alertTypeNoSound : soundName
            }

            return Texts_AlertTypeSettingsView.alertTypeDefaultIOSSound
        case .defaultSnoozePeriod:
            return snoozePeriodLabel
        case .vibrate, .overrideMute, .snoozeViaNotification:
            return nil
        }
    }

    /// Builds the sound picker and plays preview sounds as the user moves through
    /// the list. The first two rows represent no sound and the default iOS sound.
    private func showSoundSelection() {
        var sounds = ConstantsSounds.allSoundsBySoundNameAndFileName()
        sounds.soundNames.insert(Texts_AlertTypeSettingsView.alertTypeDefaultIOSSound, at: 0)
        sounds.soundNames.insert(Texts_AlertTypeSettingsView.alertTypeNoSound, at: 0)

        var selectedRow = 0
        if soundName == nil {
            selectedRow = 1
        } else {
            for (index, soundNameInList) in sounds.soundNames.enumerated() where soundNameInList == soundName {
                selectedRow = index
                break
            }
        }

        selectionList = SettingsSelectionListContent(
            title: Texts_AlertTypeSettingsView.alertTypePickSoundName,
            data: sounds.soundNames,
            selectedRow: selectedRow,
            actionTitle: Texts_Common.Ok,
            cancelTitle: Texts_Common.Cancel,
            action: { [weak self] index in
                guard let self else { return }

                self.stopSoundPlayerIfPlaying()

                if index == 1 {
                    self.soundName = nil
                } else if index == 0 {
                    self.soundName = ""
                } else {
                    self.soundName = sounds.soundNames[index]
                }
            },
            cancel: { [weak self] in
                self?.stopSoundPlayerIfPlaying()
            },
            didSelectRow: { [weak self] index in
                guard let self else { return }

                self.stopSoundPlayerIfPlaying()
                if index > 1 {
                    self.soundPlayer.playSound(soundFileName: sounds.fileNames[index - 2])
                }
            }
        )
    }

    /// Opens the fixed snooze-duration picker. Snooze periods must always come
    /// from ConstantsAlerts so alert types cannot store unsupported free-entry
    /// values.
    private func showSnoozePeriodSelection() {
        let selectedRow = snoozePeriodSelectedRow

        selectionList = SettingsSelectionListContent(
            title: Texts_AlertTypeSettingsView.alertTypeDefaultSnoozePeriod,
            data: ConstantsAlerts.snoozeValueStrings,
            selectedRow: selectedRow,
            actionTitle: Texts_Common.Ok,
            cancelTitle: Texts_Common.Cancel,
            action: { [weak self] index in
                guard ConstantsAlerts.snoozeValueMinutes.indices.contains(index) else { return }

                self?.snoozePeriod = Int16(ConstantsAlerts.snoozeValueMinutes[index])
            },
            cancel: nil,
            didSelectRow: nil
        )
    }

    /// Shows the same localized text in the detail row as the picker uses in its
    /// option list. If an older unsupported value is still present, display the
    /// nearest supported value that will be selected when the picker opens.
    private var snoozePeriodLabel: String {
        ConstantsAlerts.snoozeValueStrings[snoozePeriodSelectedRow]
    }

    /// Maps the stored snooze period onto the reduced supported list. This mirrors
    /// the Core Data migration rule: round down to the nearest supported duration,
    /// except values below the minimum are clamped to the first option.
    private var snoozePeriodSelectedRow: Int {
        let currentValue = Int(snoozePeriod)

        if let exactIndex = ConstantsAlerts.snoozeValueMinutes.firstIndex(of: currentValue) {
            return exactIndex
        }

        if let lowerIndex = ConstantsAlerts.snoozeValueMinutes.lastIndex(where: { $0 <= currentValue }) {
            return lowerIndex
        }

        return 0
    }

    /// Stops a preview sound before another sound is played or the picker closes.
    private func stopSoundPlayerIfPlaying() {
        if soundPlayer.isPlaying() {
            soundPlayer.stopPlaying()
        }
    }
}

struct AlertTypeEditorView: View {
    @StateObject private var viewModel: AlertTypeEditorViewModel

    init(
        alertType: AlertType?,
        coreDataManager: CoreDataManager,
        soundPlayer: SoundPlayer,
        close: @escaping () -> Void
    ) {
        // The editor owns its view model so pushed screens keep their in-progress
        // edits even while selection and text-entry child screens are opened.
        _viewModel = StateObject(wrappedValue: AlertTypeEditorViewModel(
            alertType: alertType,
            coreDataManager: coreDataManager,
            soundPlayer: soundPlayer,
            close: close
        ))
    }

    var body: some View {
        List {
            Section {
                ForEach(viewModel.rows, id: \.rawValue) { setting in
                    row(for: setting)
                }
            }
        }
        .settingsListStyle(title: Texts_AlertTypeSettingsView.editAlertTypeScreenTitle, titleDisplayMode: .inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(role: .destructive, action: viewModel.requestDelete) {
                    Image(systemName: "trash")
                }
                .disabled(!viewModel.canDelete)
            }

            ToolbarItem(placement: .navigationBarTrailing) {
                Button(Texts_Common.Ok, action: viewModel.save)
            }
        }
        .alert(item: $viewModel.alert) { alert in
            Alert(
                title: Text(alert.title),
                message: alert.message.map { Text($0) },
                dismissButton: .default(Text(alert.actionTitle)) {
                    alert.action?()
                }
            )
        }
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
        .settingsPushPresentation(
            textEntry: $viewModel.textEntry,
            selectionList: $viewModel.selectionList
        )
    }

    /// Builds the SwiftUI row for each alert type editor setting.
    /// Toggle rows bind directly to editor state; value rows use the pushed Settings
    /// editors so all Settings value rows use the same navigation behavior.
    @ViewBuilder
    private func row(for setting: AlertTypeEditorSetting) -> some View {
        switch setting {
        case .enabled:
            Toggle(isOn: $viewModel.enabled) {
                SettingsRowTextView(title: viewModel.title(for: setting), detail: viewModel.detail(for: setting), isEnabled: true)
            }
            .tint(.green)

        case .vibrate:
            Toggle(isOn: $viewModel.vibrate) {
                SettingsRowTextView(title: viewModel.title(for: setting), detail: nil, isEnabled: true)
            }
            .tint(.green)

        case .overrideMute:
            Toggle(isOn: $viewModel.overrideMute) {
                SettingsRowTextView(title: viewModel.title(for: setting), detail: nil, isEnabled: true)
            }
            .tint(.green)

        case .snoozeViaNotification:
            Toggle(isOn: $viewModel.snooze) {
                SettingsRowTextView(title: viewModel.title(for: setting), detail: nil, isEnabled: true)
            }
            .tint(.green)

        case .name, .soundName, .defaultSnoozePeriod:
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
