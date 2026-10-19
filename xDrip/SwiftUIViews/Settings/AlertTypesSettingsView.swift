//
//  AlertTypesSettingsView.swift
//  xdrip
//
//  Created by Paul Plant on 22/6/26.
//  Copyright © 2026 Johan Degraeve. All rights reserved.
//

import SwiftUI
import AudioToolbox

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
                .tint(ConstantsAppColors.toolbarAction)
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
    case repeatSound
    case previewAlert
    case snoozeViaNotification
    case defaultSnoozePeriod
}

@MainActor
final class AlertTypeEditorViewModel: ObservableObject {
    @Published var enabled = ConstantsDefaultAlertTypeSettings.enabled {
        didSet { if enabled != oldValue { stopSoundPlayerIfPlaying() } }
    }
    @Published var name = ConstantsDefaultAlertTypeSettings.name
    @Published var overrideMute = ConstantsDefaultAlertTypeSettings.overrideMute {
        didSet { if overrideMute != oldValue { stopSoundPlayerIfPlaying() } }
    }
    @Published var repeatSound = ConstantsDefaultAlertTypeSettings.repeatSound {
        didSet { if repeatSound != oldValue { stopSoundPlayerIfPlaying() } }
    }
    @Published var snooze = ConstantsDefaultAlertTypeSettings.snooze
    @Published var snoozePeriod = ConstantsDefaultAlertTypeSettings.snoozePeriod
    @Published var vibrate = ConstantsDefaultAlertTypeSettings.vibrate {
        didSet { if vibrate != oldValue { stopSoundPlayerIfPlaying() } }
    }
    @Published var soundName = ConstantsDefaultAlertTypeSettings.soundName {
        didSet { if soundName != oldValue { stopSoundPlayerIfPlaying() } }
    }
    @Published var alert: SettingsAlertContent?
    @Published var confirmation: SettingsConfirmationContent?
    @Published var textEntry: SettingsTextEntryContent?
    @Published var selectionList: SettingsSelectionListContent?

    private var alertType: AlertType?
    private let coreDataManager: CoreDataManager
    private let soundPlayer: SoundPlayer
    @Published private(set) var isPreviewPlaying = false
    private var previewIsPaused = false

    private struct Snapshot: Equatable {
        let enabled: Bool
        let name: String
        let overrideMute: Bool
        let repeatSound: Bool
        let snooze: Bool
        let snoozePeriod: Int16
        let vibrate: Bool
        let soundName: String?
    }

    private var original: Snapshot?

    private var snapshot: Snapshot {
        Snapshot(enabled: enabled, name: name, overrideMute: overrideMute, repeatSound: repeatSound,
                 snooze: snooze, snoozePeriod: snoozePeriod, vibrate: vibrate, soundName: soundName)
    }

    /// Reverted edits must disable Save and restore the normal Back button.
    var hasChanges: Bool { original.map { $0 != snapshot } ?? false }

    var canPreview: Bool { enabled && (soundName != "" || vibrate) }
    private let close: () -> Void

    init(
        alertType: AlertType?,
        coreDataManager: CoreDataManager,
        soundPlayer: SoundPlayer = SoundPlayer(),
        close: @escaping () -> Void
    ) {
        // Keep edits in the draft until Save is tapped.
        self.alertType = alertType
        self.coreDataManager = coreDataManager
        self.soundPlayer = soundPlayer
        self.close = close

        if let alertType {
            enabled = alertType.enabled
            name = alertType.name
            overrideMute = alertType.overridemute
            repeatSound = alertType.repeatSound
            snooze = alertType.snooze
            snoozePeriod = alertType.snoozeperiod
            vibrate = alertType.vibrate
            soundName = alertType.soundname
        }
        original = snapshot
    }

    /// Hides advanced rows when the alert type is disabled.
    var rows: [AlertTypeEditorSetting] {
        guard enabled else { return [.enabled, .name] }
        return AlertTypeEditorSetting.allCases.filter {
            $0 != .repeatSound || (overrideMute && soundName != "")
        }
    }

    /// Alert types that are still used by alarms cannot be deleted.
    var canDelete: Bool {
        guard let alertType else { return false }

        return (alertType.alertEntries?.count ?? 0) == 0
    }

    /// Validates the alert type name, writes the edited values to Core Data and
    /// closes the editor. New alert types are created with the same defaults as the
    /// standard Settings defaults.
    func save() {
        guard hasChanges else { return }
        stopSoundPlayerIfPlaying()
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
            alertType.repeatSound = repeatSound
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
                nsManagedObjectContext: coreDataManager.mainManagedObjectContext,
                repeatSound: repeatSound
            )
        }

        coreDataManager.saveChanges()
        original = snapshot
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

        case .soundName:
            showSoundSelection()

        case .previewAlert:
            togglePreview()

        case .enabled, .vibrate, .overrideMute, .repeatSound, .snoozeViaNotification, .defaultSnoozePeriod:
            break
        }
    }

    /// Returns the localized row title for the editor setting.
    /// Keeping this in the view model gives every row the same derived title.
    func title(for setting: AlertTypeEditorSetting) -> String {
        switch setting {
        case .enabled:
            return Texts_Common.enable
        case .name:
            return Texts_AlertTypeSettingsView.alertTypeName
        case .vibrate:
            return Texts_AlertTypeSettingsView.alertTypeVibrate
        case .soundName:
            return Texts_AlertTypeSettingsView.alertTypeSound
        case .previewAlert:
            return Texts_AlertTypeSettingsView.previewAlert
        case .repeatSound:
            return Texts_AlertTypeSettingsView.alertTypeRepeatSound
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
        case .vibrate, .overrideMute, .repeatSound, .previewAlert, .snoozeViaNotification:
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

    /// Adapts the stored minute value to the fixed native menu-picker options.
    var snoozePeriodPickerIndex: Int {
        get { snoozePeriodSelectedRow }
        set {
            guard ConstantsAlerts.snoozeValueMinutes.indices.contains(newValue) else { return }
            snoozePeriod = Int16(ConstantsAlerts.snoozeValueMinutes[newValue])
        }
    }

    /// Preview the draft using a separate player so real alarm audio remains independent.
    func togglePreview() {
        guard canPreview else { return }
        if isPreviewPlaying {
            soundPlayer.pausePlaying()
            isPreviewPlaying = false
            previewIsPaused = true
            return
        }
        if previewIsPaused {
            previewIsPaused = false
            isPreviewPlaying = true
            soundPlayer.resumePlaying()
            return
        }

        stopSoundPlayerIfPlaying()
        if vibrate { AudioServicesPlaySystemSound(kSystemSoundID_Vibrate) }
        guard soundName != "" else { return }
        let sounds = ConstantsSounds.allSoundsBySoundNameAndFileName()
        let fileName = sounds.soundNames.firstIndex(where: { $0 == soundName }).map { sounds.fileNames[$0] } ?? "xdripalert.aif"
        isPreviewPlaying = true
        let repeatVibration: (() -> Void)? = vibrate ? { [weak self] in
            if self?.vibrate == true { AudioServicesPlaySystemSound(kSystemSoundID_Vibrate) }
        } : nil
        soundPlayer.playSound(soundFileName: fileName, repeatSound: overrideMute && repeatSound, repeatVibration: repeatVibration) { [weak self] in
            self?.isPreviewPlaying = false
            self?.previewIsPaused = false
        }
    }

    /// Stops a preview sound before another sound is played or the picker closes.
    func stopSoundPlayerIfPlaying() {
        soundPlayer.stopPlaying()
        isPreviewPlaying = false
        previewIsPaused = false
    }
}

struct AlertTypeEditorView: View {
    @StateObject private var viewModel: AlertTypeEditorViewModel
    @State private var showsUnsavedChanges = false
    private let close: () -> Void

    init(
        alertType: AlertType?,
        coreDataManager: CoreDataManager,
        close: @escaping () -> Void
    ) {
        self.close = close
        // The editor owns its view model so pushed screens keep their in-progress
        // edits even while selection and text-entry child screens are opened.
        _viewModel = StateObject(wrappedValue: AlertTypeEditorViewModel(
            alertType: alertType,
            coreDataManager: coreDataManager,
            close: close
        ))
    }

    var body: some View {
        List {
            Section {
                row(for: .enabled)
                row(for: .name)
            }
            if viewModel.enabled {
                Section(header: Text(Texts_AlertTypeSettingsView.alertTypeSound)) {
                    ForEach(viewModel.rows.filter { [.vibrate, .soundName, .overrideMute, .repeatSound, .previewAlert].contains($0) }, id: \.rawValue) { setting in
                        row(for: setting)
                    }
                }
                Section(header: Text(Texts_Alerts.snooze)) {
                    row(for: .snoozeViaNotification)
                    row(for: .defaultSnoozePeriod)
                }
            }
        }
        .onDisappear { viewModel.stopSoundPlayerIfPlaying() }
        .settingsListStyle(title: Texts_AlertTypeSettingsView.editAlertTypeScreenTitle, titleDisplayMode: .inline)
        // Replace Back while there are unsaved changes so swiping cannot discard the draft.
        .navigationBarBackButtonHidden(viewModel.hasChanges)
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarLeading) {
                if viewModel.hasChanges {
                    Button {
                        showsUnsavedChanges = true
                    } label: {
                        Image(systemName: "chevron.backward")
                    }
                    .accessibilityLabel(Texts_Common.back)
                    .alert(isPresented: $showsUnsavedChanges) {
                        Alert(
                            title: Text(Texts_Common.unsavedChanges),
                            primaryButton: .default(Text(Texts_Common.save), action: viewModel.save),
                            secondaryButton: .destructive(Text(Texts_Common.discardChanges), action: {
                                viewModel.stopSoundPlayerIfPlaying()
                                close()
                            })
                        )
                    }
                }
                Button(role: .destructive, action: viewModel.requestDelete) {
                    Image(systemName: "trash")
                }
                .tint(ConstantsAppColors.toolbarDestructiveAction)
                .disabled(!viewModel.canDelete)
            }

            ToolbarItem(placement: .navigationBarTrailing) {
                Button(Texts_Common.save, action: viewModel.save)
                    .tint(ConstantsAppColors.toolbarAction)
                    .disabled(!viewModel.hasChanges)
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
    /// Toggle rows bind directly to editor state. Value rows use the pushed Settings
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

        case .repeatSound:
            Toggle(isOn: $viewModel.repeatSound) {
                SettingsRowTextView(title: viewModel.title(for: setting), detail: nil, isEnabled: true)
            }
            .tint(.green)

        case .previewAlert:
            SettingsStaticRowView(
                title: viewModel.title(for: setting),
                detail: nil,
                isEnabled: viewModel.canPreview,
                showsDisclosure: false,
                titleColor: .accentColor,
                icon: SettingsIcon(symbolName: viewModel.isPreviewPlaying ? "pause.fill" : "play.fill", color: .accentColor),
                action: viewModel.togglePreview
            )

        case .snoozeViaNotification:
            Toggle(isOn: $viewModel.snooze) {
                SettingsRowTextView(title: viewModel.title(for: setting), detail: nil, isEnabled: true)
            }
            .tint(.green)

        case .defaultSnoozePeriod:
            Menu {
                ForEach(ConstantsAlerts.snoozeValueStrings.indices, id: \.self) { index in
                    Button {
                        viewModel.snoozePeriodPickerIndex = index
                    } label: {
                        if viewModel.snoozePeriodPickerIndex == index {
                            Label(ConstantsAlerts.snoozeValueStrings[index], systemImage: "checkmark")
                        } else {
                            Text(ConstantsAlerts.snoozeValueStrings[index])
                        }
                    }
                }
            } label: {
                HStack(spacing: 8) {
                    Text(viewModel.title(for: setting))
                        .foregroundStyle(ConstantsAppColors.rowTitleText)
                    Spacer(minLength: 8)
                    Text(ConstantsAlerts.snoozeValueStrings[viewModel.snoozePeriodPickerIndex])
                        .foregroundStyle(ConstantsAppColors.rowDetailText)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(ConstantsAppColors.rowDetailText)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

        case .name, .soundName:
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
