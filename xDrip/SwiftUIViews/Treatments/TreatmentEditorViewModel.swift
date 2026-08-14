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

    static let supportedTreatmentTypes: [TreatmentType] = [.Insulin, .Carbs, .Exercise, .BgCheck, .Note]

    // MARK: - @Published properties

    @Published var selectedType: TreatmentType
    @Published var selectedDate: Date
    @Published var enteredValue: String
    @Published var enteredByValue: String
    @Published var enteredNotesValue: String
    @Published var alertMessage: TreatmentEditorAlertMessage?

    // MARK: - private properties

    private let coreDataManager: CoreDataManager?
    private let treatmentToEditObjectID: NSManagedObjectID?
    private let initialTreatmentState: TreatmentEditorInitialState?
    private let log = OSLog(subsystem: ConstantsLog.subSystem, category: ConstantsLog.categoryApplicationDataTreatments)

    // MARK: - initialization

    init(coreDataManager: CoreDataManager?, treatmentToEdit: TreatmentEntry?) {
        self.coreDataManager = coreDataManager
        self.treatmentToEditObjectID = treatmentToEdit?.objectID
        self.initialTreatmentState = treatmentToEdit.map {
            TreatmentEditorInitialState(
                selectedType: $0.treatmentType,
                selectedDate: $0.date,
                storedValue: $0.value,
                enteredBy: $0.enteredBy,
                notes: $0.notes
            )
        }
        self.selectedType = treatmentToEdit?.treatmentType ?? .Carbs
        self.selectedDate = treatmentToEdit?.date ?? Date()
        self.enteredByValue = treatmentToEdit?.enteredBy ?? ConstantsHomeView.applicationName
        self.enteredNotesValue = treatmentToEdit?.notes ?? ""

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
        } else {
            self.enteredValue = ""
        }
    }

    // MARK: - public computed properties

    var isAddMode: Bool {
        treatmentToEditObjectID == nil
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

        return Texts_TreatmentsView.invalidValueMessage
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
        guard selectedType == .BgCheck else {
            return
        }

        if selectedDate > Date() {
            selectedDate = Date()
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

        let normalizedNotesValue = normalizedNotesValue()
        let storedNotesValue = selectedType == .Note ? normalizedNotesValue : nil
        let storedNightscoutEventType = selectedType == .Note ? ConstantsNightscout.noteEventType : nil
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

        if let treatmentToEdit = treatmentToEdit(in: coreDataManager) {
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
                // shareable log; never include the amount, note, entered-by value or server ID.
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
        enteredValue.toDouble()
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
        let storedNotesValue = selectedType == .Note ? normalizedNotesValue() : nil
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
        guard let treatmentToEditObjectID = treatmentToEditObjectID else {
            return nil
        }

        return try? coreDataManager.mainManagedObjectContext
            .existingObject(with: treatmentToEditObjectID) as? TreatmentEntry
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
