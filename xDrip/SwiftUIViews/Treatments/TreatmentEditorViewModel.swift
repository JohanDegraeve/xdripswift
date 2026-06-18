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

    static let supportedTreatmentTypes: [TreatmentType] = [.Insulin, .Carbs, .Exercise, .BgCheck]

    // MARK: - @Published properties

    @Published var selectedType: TreatmentType
    @Published var selectedDate: Date
    @Published var enteredValue: String
    @Published var enteredByValue: String
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

        if let treatmentToEdit = treatmentToEdit {
            if treatmentToEdit.treatmentType == .BgCheck {
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

    var valuePlaceholder: String {
        if selectedType == .BgCheck {
            return Double(0).mgDlToMmolAndToString(mgDl: UserDefaults.standard.bloodGlucoseUnitIsMgDl)
        }

        return "0"
    }

    var helperText: String? {
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
            alertMessage = TreatmentEditorAlertMessage(title: Texts_Common.warning, message: Texts_TreatmentsView.cannotStoreFutureBGCheck)
        }
    }

    func saveTreatment() -> Bool {
        validateSelectedDateIfNeeded()

        guard let coreDataManager = coreDataManager, let value = normalizedValue(), value > 0 else {
            alertMessage = TreatmentEditorAlertMessage(title: Texts_Common.warning, message: Texts_TreatmentsView.invalidValueMessage)
            return false
        }

        let storedValue = storedValueForCurrentType(value)

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

            let normalizedEnteredByValue = normalizedEnteredByValue()
            if treatmentToEdit.enteredBy != normalizedEnteredByValue {
                treatmentToEdit.enteredBy = normalizedEnteredByValue
                treatmentChanged = true
            }

            if treatmentChanged {
                treatmentToEdit.uploaded = false
                coreDataManager.saveChanges()
                setNightscoutSyncRequiredToTrue()
            }
        } else {
            _ = TreatmentEntry(date: selectedDate, value: storedValue, treatmentType: selectedType, nightscoutEventType: nil, enteredBy: normalizedEnteredByValue(), nsManagedObjectContext: coreDataManager.mainManagedObjectContext)

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

        return try? coreDataManager.mainManagedObjectContext.existingObject(with: treatmentToEditObjectID) as? TreatmentEntry
    }

    private func setNightscoutSyncRequiredToTrue() {
        if (UserDefaults.standard.timeStampLatestNightscoutSyncRequest ?? Date.distantPast).timeIntervalSinceNow < -ConstantsNightscout.minimiumTimeBetweenTwoTreatmentSyncsInSeconds {
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
