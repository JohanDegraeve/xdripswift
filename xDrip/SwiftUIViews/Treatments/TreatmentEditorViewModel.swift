//
//  TreatmentEditorViewModel.swift
//  xdrip
//
//  Created by Paul Plant on 18/6/26.
//  Copyright © 2026 Johan Degraeve. All rights reserved.
//

import Foundation
import CoreData
import OSLog

@MainActor final class TreatmentEditorViewModel: ObservableObject {
    // MARK: - public static properties

    /// Permit a small amount of advance entry without allowing accidental future-day treatments.
    static let maximumFutureTreatmentInterval: TimeInterval = 60 * 60

    static let supportedTreatmentTypes: [TreatmentType] = [.Insulin, .Carbs, .BgCheck, .Exercise, .BasalInjection, .Note]

    // MARK: - @Published properties

    @Published var selectedType: TreatmentType
    @Published var selectedDate: Date
    @Published var enteredValue: String
    @Published var enteredByValue: String
    @Published var enteredNotesValue: String
    @Published var enteredInsulinDescription: String
    @Published var alertMessage: TreatmentEditorAlertMessage?

    /// Only show the copied-values footer when both fields were prefilled for a new injection.
    let didPrefillBasalInjection: Bool

    // MARK: - private properties

    private let coreDataManager: CoreDataManager?
    // Keep the main-context object for the lifetime of this editor. Its objectID may change
    // from temporary to permanent while the parent context saves a newly added treatment.
    private let originalTreatment: TreatmentEntry?
    private let initialTreatmentState: TreatmentEditorInitialState?
    private let log = OSLog(subsystem: ConstantsLog.subSystem, category: ConstantsLog.categoryApplicationDataTreatments)

    // MARK: - initialization

    init(coreDataManager: CoreDataManager?, treatmentToEdit: TreatmentEntry?, initialType: TreatmentType = .Carbs) {
        self.didPrefillBasalInjection = treatmentToEdit == nil && initialType == .BasalInjection
            && UserDefaults.standard.lastBasalInjectionUnits > 0
            && !UserDefaults.standard.lastBasalInjectionInsulinDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        self.coreDataManager = coreDataManager
        self.originalTreatment = treatmentToEdit
        self.initialTreatmentState = treatmentToEdit.map {
            TreatmentEditorInitialState(
                selectedType: $0.treatmentType,
                selectedDate: $0.date,
                storedValue: $0.value,
                enteredBy: $0.enteredBy,
                notes: $0.notes
            )
        }
        self.selectedType = treatmentToEdit?.treatmentType ?? initialType
        self.selectedDate = treatmentToEdit?.date ?? Date()
        self.enteredByValue = treatmentToEdit?.enteredBy ?? ConstantsHomeView.applicationName
        self.enteredNotesValue = treatmentToEdit?.notes ?? ""
        // Editing always uses the saved treatment. Defaults only prefill a new injection draft.
        self.enteredInsulinDescription = treatmentToEdit?.notes ?? (initialType == .BasalInjection ? UserDefaults.standard.lastBasalInjectionInsulinDescription : "")

        if let treatmentToEdit = treatmentToEdit {
            if treatmentToEdit.treatmentType == .Note {
                self.enteredValue = ""
            } else if treatmentToEdit.treatmentType == .BgCheck {
                self.enteredValue = treatmentToEdit.value.mgDlToMmolAndToString(
                    mgDl: UserDefaults.standard.bloodGlucoseUnitIsMgDl
                )
            } else {
                self.enteredValue = treatmentToEdit.value.stringWithoutTrailingZeroes
            }
        } else if initialType == .BasalInjection, UserDefaults.standard.lastBasalInjectionUnits > 0 {
            self.enteredValue = String(UserDefaults.standard.lastBasalInjectionUnits)
        } else {
            self.enteredValue = ""
        }
    }

    // MARK: - public computed properties

    var isAddMode: Bool {
        originalTreatment == nil
    }

    /// BG checks are measurements and retain their existing no-future rule.
    var latestSelectableDate: Date {
        Date().addingTimeInterval(selectedType == .BgCheck ? 0 : Self.maximumFutureTreatmentInterval)
    }

    var navigationTitle: String {
        isAddMode ? Texts_TreatmentsView.addTreatmentTitle : Texts_TreatmentsView.editTreatmentTitle
    }

    var unitText: String {
        selectedType.unit()
    }

    var showsNumericValueEditor: Bool {
        selectedType != .Note
    }

    var showsNotesEditor: Bool {
        selectedType == .Note
    }

    var valuePlaceholder: String {
        if selectedType == .BgCheck {
            return Double(0).mgDlToMmolAndToString(mgDl: UserDefaults.standard.bloodGlucoseUnitIsMgDl)
        }

        return "0"
    }

    var helperText: String? {
        if selectedType == .Note {
            return normalizedNotesValue() == nil && !enteredNotesValue.isEmpty ? Texts_TreatmentsView.invalidNoteMessage : nil
        }

        if let value = normalizedValue(), value > 0 {
            return nil
        }

        if enteredValue.isEmpty {
            return nil
        }

        return selectedType == .BasalInjection ? Texts_TreatmentsView.invalidBasalInjectionValueMessage : Texts_TreatmentsView.invalidValueMessage
    }

    var canSaveTreatment: Bool {
        guard currentInputIsValid else {
            return false
        }

        if isAddMode {
            return true
        }

        return treatmentHasChanges
    }

    // MARK: - public functions

    func validateSelectedDateIfNeeded() {
        let latestDate = latestSelectableDate
        guard selectedDate > latestDate else { return }

        // Also enforce the picker bound for restored drafts and direct save calls.
        selectedDate = latestDate
        if selectedType == .BgCheck {
            alertMessage = TreatmentEditorAlertMessage(
                title: Texts_Common.warning,
                message: Texts_TreatmentsView.cannotStoreFutureBGCheck
            )
        }
    }

    func saveTreatment() -> Bool {
        validateSelectedDateIfNeeded()

        guard let coreDataManager = coreDataManager else {
            return false
        }

        // The toolbar and save path share the same requirement. Whitespace is not an insulin type.
        guard selectedType != .BasalInjection || normalizedInsulinDescription() != nil else { return false }

        let normalizedNotesValue = normalizedNotesValue()
        let storedNotesValue = selectedType == .BasalInjection ? normalizedInsulinDescription() : (selectedType == .Note ? normalizedNotesValue : nil)
        let storedNightscoutEventType = selectedType == .Note || selectedType == .BasalInjection ? ConstantsNightscout.noteEventType : nil
        let storedValue: Double

        if selectedType == .Note {
            guard normalizedNotesValue != nil else {
                alertMessage = TreatmentEditorAlertMessage(
                    title: Texts_Common.warning,
                    message: Texts_TreatmentsView.invalidNoteMessage
                )
                return false
            }

            storedValue = 0
        } else {
            guard let value = normalizedValue(), value > 0 else {
                alertMessage = TreatmentEditorAlertMessage(
                    title: Texts_Common.warning,
                    message: Texts_TreatmentsView.invalidValueMessage
                )
                return false
            }

            storedValue = storedValueForCurrentType(value)
        }

        let treatmentToEdit = treatmentToEdit(in: coreDataManager)
        // An edit whose target was deleted or detached must never fall through to insertion.
        guard isAddMode || treatmentToEdit != nil else { return false }

        if let treatmentToEdit {
            var treatmentChanged = false

            if treatmentToEdit.value != storedValue {
                treatmentToEdit.value = storedValue
                treatmentChanged = true
            }

            if treatmentToEdit.date != selectedDate {
                treatmentToEdit.date = selectedDate
                treatmentChanged = true
            }

            if treatmentToEdit.treatmentType != selectedType {
                treatmentToEdit.treatmentType = selectedType
                treatmentChanged = true
            }

            if treatmentToEdit.nightscoutEventType != storedNightscoutEventType {
                treatmentToEdit.nightscoutEventType = storedNightscoutEventType
                treatmentChanged = true
            }

            let normalizedEnteredByValue = normalizedEnteredByValue()
            if treatmentToEdit.enteredBy != normalizedEnteredByValue {
                treatmentToEdit.enteredBy = normalizedEnteredByValue
                treatmentChanged = true
            }

            if treatmentToEdit.notes != storedNotesValue {
                treatmentToEdit.notes = storedNotesValue
                treatmentChanged = true
            }

            if treatmentChanged {
                treatmentToEdit.uploaded = false
                guard coreDataManager.saveChanges() else {
                    trace("failed to save an edited treatment", log: log, category: ConstantsLog.categoryApplicationDataTreatments, type: .error)
                    return false
                }

                // A treatment edit is an explicit user-provoked data change. Keep the developer
                // trace useful while attaching only the controlled type and treatment date to the
                // shareable log. Never include the amount, note, entered-by value or server ID.
                trace(
                    "edited %{public}@ treatment at %{public}@",
                    log: log,
                    category: ConstantsLog.categoryApplicationDataTreatments,
                    type: .info,
                    troubleshooting: .standard(.treatment(.edited(
                        kind: TroubleshootingTreatmentKind(selectedType),
                        treatmentAt: selectedDate
                    ))),
                    selectedType.asString(),
                    selectedDate.description
                )
                setNightscoutSyncRequiredToTrue()
            }
        } else {
            _ = TreatmentEntry(
                date: selectedDate,
                value: storedValue,
                treatmentType: selectedType,
                nightscoutEventType: storedNightscoutEventType,
                enteredBy: normalizedEnteredByValue(),
                notes: storedNotesValue,
                nsManagedObjectContext: coreDataManager.mainManagedObjectContext
            )

            guard coreDataManager.saveChanges() else {
                trace("failed to save a new treatment", log: log, category: ConstantsLog.categoryApplicationDataTreatments, type: .error)
                return false
            }

            trace(
                "added %{public}@ treatment at %{public}@",
                log: log,
                category: ConstantsLog.categoryApplicationDataTreatments,
                type: .info,
                troubleshooting: .standard(.treatment(.added(
                    kind: TroubleshootingTreatmentKind(selectedType),
                    treatmentAt: selectedDate
                ))),
                selectedType.asString(),
                selectedDate.description
            )
            setNightscoutSyncRequiredToTrue()
        }

        // Only a successful explicit save updates the next draft. Cancel and failed saves must
        // leave these preferences alone, and editing a bolus must never replace the basal defaults.
        if selectedType == .BasalInjection, let units = Int(exactly: storedValue) {
            UserDefaults.standard.lastBasalInjectionUnits = units
            UserDefaults.standard.lastBasalInjectionInsulinDescription = storedNotesValue ?? ""
        }

        return true
    }

    func deleteTreatment() -> Bool {
        guard let coreDataManager = coreDataManager, let treatmentToEdit = treatmentToEdit(in: coreDataManager) else {
            return false
        }

        treatmentToEdit.treatmentdeleted = true
        treatmentToEdit.uploaded = false

        guard coreDataManager.saveChanges() else {
            trace("failed to save a deleted treatment", log: log, category: ConstantsLog.categoryApplicationDataTreatments, type: .error)
            return false
        }

        trace(
            "deleted %{public}@ treatment at %{public}@",
            log: log,
            category: ConstantsLog.categoryApplicationDataTreatments,
            type: .info,
            troubleshooting: .standard(.treatment(.deleted(
                kind: TroubleshootingTreatmentKind(treatmentToEdit.treatmentType),
                treatmentAt: treatmentToEdit.date
            ))),
            treatmentToEdit.treatmentType.asString(),
            treatmentToEdit.date.description
        )
        setNightscoutSyncRequiredToTrue()

        return true
    }

    // MARK: - private functions

    private func normalizedValue() -> Double? {
        guard let value = enteredValue.toDouble(), value.isFinite else { return nil }
        // A number pad helps entry, but pasted values still need whole-unit validation.
        if selectedType == .BasalInjection, Int(exactly: value) == nil { return nil }
        return value
    }

    private func normalizedInsulinDescription() -> String? {
        enteredInsulinDescription.trimmingCharacters(in: .whitespacesAndNewlines).toNilIfLength0()
    }

    private func normalizedEnteredByValue() -> String? {
        enteredByValue.toNilIfLength0()
    }

    private func normalizedNotesValue() -> String? {
        let trimmedNotes = enteredNotesValue.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedNotes.isEmpty ? nil : trimmedNotes
    }

    private func storedValueForCurrentType(_ value: Double) -> Double {
        if selectedType == .BgCheck {
            return value
                .mmolToMgdl(mgDl: UserDefaults.standard.bloodGlucoseUnitIsMgDl)
                .bgValueRounded(mgDl: UserDefaults.standard.bloodGlucoseUnitIsMgDl)
        }

        return value
    }

    private var currentInputIsValid: Bool {
        guard selectedDate <= latestSelectableDate else { return false }

        if selectedType == .BasalInjection, normalizedInsulinDescription() == nil {
            return false
        }

        if selectedType == .Note {
            return normalizedNotesValue() != nil
        }

        guard let value = normalizedValue() else {
            return false
        }

        return value > 0
    }

    private var treatmentHasChanges: Bool {
        guard let initialTreatmentState else {
            return true
        }

        return currentStoredState() != initialTreatmentState
    }

    private func currentStoredState() -> TreatmentEditorInitialState? {
        let storedNotesValue = selectedType == .BasalInjection ? normalizedInsulinDescription() : (selectedType == .Note ? normalizedNotesValue() : nil)
        let storedValue: Double

        if selectedType == .Note {
            storedValue = 0
        } else {
            guard let value = normalizedValue(), value > 0 else {
                return nil
            }

            storedValue = storedValueForCurrentType(value)
        }

        return TreatmentEditorInitialState(
            selectedType: selectedType,
            selectedDate: selectedDate,
            storedValue: storedValue,
            enteredBy: normalizedEnteredByValue(),
            notes: storedNotesValue
        )
    }

    private func treatmentToEdit(in coreDataManager: CoreDataManager) -> TreatmentEntry? {
        guard let originalTreatment,
              originalTreatment.managedObjectContext === coreDataManager.mainManagedObjectContext,
              !originalTreatment.isDeleted,
              !originalTreatment.treatmentdeleted else {
            return nil
        }

        return originalTreatment
    }

    private func setNightscoutSyncRequiredToTrue() {
        let latestSyncRequestDate = UserDefaults.standard.timeStampLatestNightscoutSyncRequest ?? Date.distantPast

        if latestSyncRequestDate.timeIntervalSinceNow <
            -ConstantsNightscout.minimiumTimeBetweenTwoTreatmentSyncsInSeconds {
            UserDefaults.standard.timeStampLatestNightscoutSyncRequest = .now
            UserDefaults.standard.nightscoutSyncRequired = true
        }
    }
}

private struct TreatmentEditorInitialState: Equatable {
    let selectedType: TreatmentType
    let selectedDate: Date
    let storedValue: Double
    let enteredBy: String?
    let notes: String?
}

struct TreatmentEditorAlertMessage: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}
