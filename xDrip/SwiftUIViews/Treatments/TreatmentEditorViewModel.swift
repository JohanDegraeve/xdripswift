//
//  TreatmentEditorViewModel.swift
//  xdrip
//
//  Created by Paul Plant on 18/6/26.
//  Copyright © 2026 Johan Degraeve. All rights reserved.
//

import Foundation
import CoreData

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

    // MARK: - initialization

    init(coreDataManager: CoreDataManager?, treatmentToEdit: TreatmentEntry?) {
        self.coreDataManager = coreDataManager
        self.treatmentToEditObjectID = treatmentToEdit?.objectID
        self.selectedType = treatmentToEdit?.treatmentType ?? .Carbs
        self.selectedDate = treatmentToEdit?.date ?? Date()
        self.enteredByValue = treatmentToEdit?.enteredBy ?? ConstantsHomeView.applicationName
        self.enteredNotesValue = treatmentToEdit?.notes ?? ""

        if let treatmentToEdit = treatmentToEdit {
            if treatmentToEdit.treatmentType == .Note {
                self.enteredValue = ""
            } else if treatmentToEdit.treatmentType == .BgCheck {
                self.enteredValue = treatmentToEdit.value
                    .mgDlToMmol(mgDl: UserDefaults.standard.bloodGlucoseUnitIsMgDl)
                    .bgValueRounded(mgDl: UserDefaults.standard.bloodGlucoseUnitIsMgDl)
                    .stringWithoutTrailingZeroes
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
                coreDataManager.saveChanges()
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

            coreDataManager.saveChanges()
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

        coreDataManager.saveChanges()
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

struct TreatmentEditorAlertMessage: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}
