//
//  BasalInjectionTests.swift
//  xdripTests
//
//  Created by Paul Plant on 7/9/26.
//  Copyright © 2026 Johan Degraeve. All rights reserved.
//

import XCTest
import UIKit
import SwiftUI
import CoreData
@testable import xdrip

final class BasalInjectionTests: XCTestCase {
    private let date = Date(timeIntervalSince1970: 1_788_804_000)

    /// Use the reported Note verbatim through the same JSON parser and storage path as follower sync.
    @MainActor func testReportedLantusNoteImportsAsBasalInjection() throws {
        let notes = """
        Basal injection: Lantus, 14 U

        ---------
        xDrip4iOS:BasalInjection:eyJpbnN1bGluRGVzY3JpcHRpb24iOiJMYW50dXMiLCJ1bml0cyI6MTQsInZlcnNpb24iOjF9
        """
        let data = try JSONSerialization.data(withJSONObject: [document(notes: notes)])
        let responses = try XCTUnwrap(TreatmentNSResponse.arrayFromData(data))
        XCTAssertEqual(responses.count, 1)
        let response = try XCTUnwrap(responses.first)
        XCTAssertEqual(response.eventType, .BasalInjection)
        let coreDataManager = CoreDataManager(inMemoryModelName: ConstantsCoreData.modelName)
        let entry = try XCTUnwrap(response.asNewTreatmentEntry(nsManagedObjectContext: coreDataManager.mainManagedObjectContext))
        let snapshot = TreatmentSnapshot(treatmentEntry: entry)
        XCTAssertEqual(snapshot.treatmentType, .BasalInjection)
        XCTAssertEqual(snapshot.valueText, "14")
        XCTAssertEqual(snapshot.unitText, "U")
        XCTAssertEqual(entry.notes, "Lantus")
    }

    /// Missing from a bulk download is not enough: only a successful empty exact-id result deletes.
    @MainActor func testRemoteDeletionRequiresConfirmedAbsence() {
        for (body, succeeded, shouldDelete) in [("[]", true, true), ("[]", false, false), ("[{\"_id\":\"still-present\"}]", true, false), ("{}", true, false), ("invalid", true, false)] {
            let coreDataManager = CoreDataManager(inMemoryModelName: ConstantsCoreData.modelName)
            let manager = NightscoutSyncManager(coreDataManager: coreDataManager, messageHandler: nil)
            let remoteID = "6cd9bfc2-1eb0-4fdd-890d-59c47067d9e6"
            let entry = TreatmentEntry(id: remoteID + "-note", date: Date(), value: 14, treatmentType: .BasalInjection, nightscoutEventType: "Note", enteredBy: "Test", notes: "Lantus", nsManagedObjectContext: coreDataManager.mainManagedObjectContext)
            var completed = false
            manager.reconcileRemoteTreatmentDeletions(treatments: [entry], downloaded: [], lookup: { id, finished in
                XCTAssertEqual(id, remoteID)
                finished(Data(body.utf8), succeeded)
            }) { count in
                completed = true
                XCTAssertEqual(count, shouldDelete ? 1 : 0)
            }
            XCTAssertTrue(completed)
            XCTAssertEqual(entry.treatmentdeleted, shouldDelete)
            XCTAssertTrue(entry.uploaded)
        }
    }

    /// Local edits remain authoritative while waiting for confirmation from Nightscout.
    @MainActor func testRemoteDeletionPreservesAnEditMadeDuringLookup() {
        let coreDataManager = CoreDataManager(inMemoryModelName: ConstantsCoreData.modelName)
        let manager = NightscoutSyncManager(coreDataManager: coreDataManager, messageHandler: nil)
        let entry = TreatmentEntry(id: "basal-note", date: Date(), value: 14, treatmentType: .BasalInjection, nightscoutEventType: "Note", enteredBy: "Test", notes: "Lantus", nsManagedObjectContext: coreDataManager.mainManagedObjectContext)
        manager.reconcileRemoteTreatmentDeletions(treatments: [entry], downloaded: [], lookup: { _, finished in
            entry.value = 15
            entry.uploaded = false
            finished(Data("[]".utf8), true)
        }) { count in
            XCTAssertEqual(count, 0)
        }
        XCTAssertFalse(entry.treatmentdeleted)
        XCTAssertFalse(entry.uploaded)
    }

    /// Present records and unsynced local entries do not need a remote absence check.
    @MainActor func testRemoteDeletionDoesNotLookUpPresentOrUnsyncedTreatments() {
        let coreDataManager = CoreDataManager(inMemoryModelName: ConstantsCoreData.modelName)
        let manager = NightscoutSyncManager(coreDataManager: coreDataManager, messageHandler: nil)
        let present = TreatmentEntry(id: "present-note", date: Date(), value: 14, treatmentType: .BasalInjection, nightscoutEventType: "Note", enteredBy: "Test", notes: "Lantus", nsManagedObjectContext: coreDataManager.mainManagedObjectContext)
        let local = TreatmentEntry(date: Date(), value: 14, treatmentType: .BasalInjection, nightscoutEventType: "Note", enteredBy: "Test", notes: "Lantus", nsManagedObjectContext: coreDataManager.mainManagedObjectContext)
        let response = TreatmentNSResponse(id: present.id, createdAt: present.date, eventType: .BasalInjection, nightscoutEventType: "Note", value: 14, valueSecondary: nil, enteredBy: "Test", notes: "Lantus")
        manager.reconcileRemoteTreatmentDeletions(treatments: [present, local], downloaded: [response], lookup: { _, _ in
            XCTFail("No lookup should be needed")
        }) { count in
            XCTAssertEqual(count, 0)
        }
        XCTAssertFalse(present.treatmentdeleted)
        XCTAssertFalse(local.treatmentdeleted)
    }

    func testPayloadRoundTripIgnoresReadableSummary() throws {
        let payload = try XCTUnwrap(BasalInjectionPayload(units: 20, insulinDescription: "Tresiba"))
        let notes = try XCTUnwrap(payload.encodedNotes())
        XCTAssertTrue(notes.hasPrefix("Basal injection: Tresiba, 20 U\n\n---------\n"))
        let changedSummary = notes.replacingOccurrences(of: "Basal injection: Tresiba, 20 U", with: "Texto cambiado: 99 U")
        XCTAssertEqual(BasalInjectionPayload.decode(from: changedSummary), payload)
    }

    /// Regression for https://github.com/JohanDegraeve/xdripswift/issues/783.
    @MainActor func testFractionalBasalEntrySaveEditPrefillAndNightscoutRoundTrip() throws {
        try withRestoredDefaults {
            let coreDataManager = CoreDataManager(inMemoryModelName: ConstantsCoreData.modelName)
            // UserDefaults.double must also read whole-unit defaults saved by earlier builds.
            UserDefaults.standard.set(20, forKey: "lastBasalInjectionUnits")
            XCTAssertEqual(UserDefaults.standard.lastBasalInjectionUnits, 20)
            for input in ["20.5", "20,5", "0.5"] {
                let units = input == "0.5" ? 0.5 : 20.5
                let draft = TreatmentEditorViewModel(coreDataManager: coreDataManager, treatmentToEdit: nil, initialType: .BasalInjection)
                draft.enteredValue = input
                draft.enteredInsulinDescription = "Tresiba"
                XCTAssertTrue(draft.canSaveTreatment)
                XCTAssertNil(draft.helperText)
                XCTAssertTrue(draft.saveTreatment())
                XCTAssertEqual(UserDefaults.standard.lastBasalInjectionUnits, units)
                let prefilled = TreatmentEditorViewModel(coreDataManager: coreDataManager, treatmentToEdit: nil, initialType: .BasalInjection)
                XCTAssertEqual(prefilled.enteredValue, units.stringWithoutTrailingZeroes)
                XCTAssertTrue(prefilled.didPrefillBasalInjection)
                let saved = try XCTUnwrap(TreatmentEntryAccessor(coreDataManager: coreDataManager).getLatestTreatments(howOld: nil).first)
                XCTAssertEqual(saved.value, units)
                XCTAssertEqual(TreatmentSnapshot(treatmentEntry: saved).valueText, units.stringWithoutTrailingZeroes)
                var upload = saved.dictionaryRepresentationForNightscoutUpload()
                for key in ["insulin", "rate", "absolute", "duration"] {
                    XCTAssertNil(upload[key])
                }
                upload["_id"] = "fractional-basal"
                let response = try XCTUnwrap(TreatmentNSResponse.fromNightscout(dictionary: upload as NSDictionary).first)
                XCTAssertEqual(response.eventType, .BasalInjection)
                XCTAssertEqual(response.value, units)
                let notes = try XCTUnwrap(upload["notes"] as? String)
                XCTAssertTrue(notes.hasPrefix("Basal injection: Tresiba, \(units.stringWithoutTrailingZeroes) U\n"))
                XCTAssertEqual(BasalInjectionPayload.decode(from: notes)?.units, units)
                let editor = TreatmentEditorViewModel(coreDataManager: coreDataManager, treatmentToEdit: saved)
                XCTAssertEqual(editor.enteredValue, units.stringWithoutTrailingZeroes)
                XCTAssertFalse(editor.canSaveTreatment)
                editor.enteredValue = "21.5"
                XCTAssertTrue(editor.saveTreatment())
                XCTAssertEqual(saved.value, 21.5)
                XCTAssertEqual(UserDefaults.standard.lastBasalInjectionUnits, 21.5)
            }
        }
    }

    @MainActor func testBasalFieldRejectsExtraDecimalsBeforeChangingVisibleText() {
        var boundText = "4.5"
        let field = UITextField()
        field.text = boundText
        let coordinator = BasalDoseTextField.Coordinator(text: Binding(get: { boundText }, set: { boundText = $0 }))
        field.delegate = coordinator
        field.addTarget(coordinator, action: #selector(BasalDoseTextField.Coordinator.textDidChange(_:)), for: .editingChanged)

        // UIKit asks the delegate before applying typing, deletion or a selected-range paste.
        func edit(_ range: NSRange, _ replacement: String) -> Bool {
            let accepted = field.delegate!.textField!(field, shouldChangeCharactersIn: range, replacementString: replacement)
            if accepted {
                field.text = (field.text! as NSString).replacingCharacters(in: range, with: replacement)
                field.sendActions(for: .editingChanged)
            }
            return accepted
        }

        XCTAssertFalse(edit(NSRange(location: 3, length: 0), "3"))
        XCTAssertEqual(field.text, "4.5")
        XCTAssertEqual(boundText, "4.5")
        for pasted in ["4.23", "6.45", "6,45", "4..5", "4,5.0", "4e2", "abc", "-1", "150.5", "151", "999"] {
            XCTAssertFalse(edit(NSRange(location: 0, length: 3), pasted))
            XCTAssertEqual(field.text, "4.5")
            XCTAssertEqual(boundText, "4.5")
        }
        XCTAssertTrue(edit(NSRange(location: 2, length: 1), "0")) // Replace selected digit.
        XCTAssertEqual(boundText, "4.0")
        XCTAssertTrue(edit(NSRange(location: 2, length: 1), "")) // Delete fraction.
        XCTAssertEqual(boundText, "4.")
        XCTAssertTrue(edit(NSRange(location: 2, length: 0), "5"))
        XCTAssertEqual(boundText, "4.5")
        XCTAssertTrue(edit(NSRange(location: 0, length: 3), ""))
        XCTAssertEqual(boundText, "")
        XCTAssertTrue(edit(NSRange(location: 0, length: 0), ","))
        XCTAssertTrue(edit(NSRange(location: 1, length: 0), "5"))
        XCTAssertEqual(boundText, ",5")
        XCTAssertFalse(edit(NSRange(location: 2, length: 0), "3"))
        XCTAssertEqual(field.text, ",5")
        XCTAssertEqual(boundText, ",5")
        XCTAssertTrue(edit(NSRange(location: 0, length: 2), "6,5"))
        XCTAssertEqual(boundText, "6,5")
        XCTAssertTrue(edit(NSRange(location: 0, length: 3), "150"))
        XCTAssertFalse(edit(NSRange(location: 3, length: 0), "1"))
        XCTAssertEqual(field.text, "150")
        XCTAssertTrue(edit(NSRange(location: 3, length: 0), "."))
        XCTAssertFalse(edit(NSRange(location: 4, length: 0), "5"))
        XCTAssertEqual(boundText, "150.")
        XCTAssertTrue(edit(NSRange(location: 4, length: 0), "0"))
        XCTAssertEqual(boundText, "150.0")
        XCTAssertTrue(edit(NSRange(location: 0, length: 5), "0"))
        XCTAssertEqual(boundText, "0")
    }

    @MainActor func testBasalRejectsFinerThanHalfUnitsWithoutRoundingOrChangingSavedDose() throws {
        try withRestoredDefaults {
            let coreDataManager = CoreDataManager(inMemoryModelName: ConstantsCoreData.modelName)
            UserDefaults.standard.lastBasalInjectionUnits = 4.5
            let draft = TreatmentEditorViewModel(coreDataManager: coreDataManager, treatmentToEdit: nil, initialType: .BasalInjection)
            draft.enteredInsulinDescription = "Tresiba"
            for input in ["4.23", "4,23", "6.4", "6,4", "0.25", "4.5001", "150.5", "151", "0", "-0.5"] {
                draft.enteredValue = input
                XCTAssertFalse(draft.canSaveTreatment, input)
                XCTAssertEqual(draft.helperText, Texts_TreatmentsView.invalidBasalInjectionValueMessage)
                XCTAssertFalse(draft.saveTreatment(), input)
                XCTAssertTrue(coreDataManager.mainManagedObjectContext.insertedObjects.isEmpty)
                XCTAssertEqual(UserDefaults.standard.lastBasalInjectionUnits, 4.5)
            }
            for input in ["4", "4.0", "4.5", "4,5", "0.5", "149.5", "150", "150.0"] {
                draft.enteredValue = input
                XCTAssertTrue(draft.canSaveTreatment, input)
                XCTAssertNil(draft.helperText)
            }
            draft.enteredValue = "4.5"
            XCTAssertTrue(draft.saveTreatment())
            let saved = try XCTUnwrap(TreatmentEntryAccessor(coreDataManager: coreDataManager).getLatestTreatments(howOld: nil).first)
            let editor = TreatmentEditorViewModel(coreDataManager: coreDataManager, treatmentToEdit: saved)
            editor.enteredValue = "6.4"
            XCTAssertFalse(editor.canSaveTreatment)
            XCTAssertFalse(editor.saveTreatment())
            XCTAssertEqual(saved.value, 4.5)
            // Bolus retains its existing decimal precision.
            let bolus = TreatmentEditorViewModel(coreDataManager: coreDataManager, treatmentToEdit: nil, initialType: .Insulin)
            for input in ["4.23", "6.4"] {
                bolus.enteredValue = input
                XCTAssertTrue(bolus.canSaveTreatment)
                XCTAssertTrue(bolus.saveTreatment())
            }
        }
    }

    func testEntryLimitDoesNotDiscardHistoricalNightscoutDoses() throws {
        // The 150 U limit applies to manual entry. Existing Notes still need to import unchanged.
        let notes = envelope(#"{"version":1,"units":200,"insulinDescription":"Tresiba"}"#)
        XCTAssertEqual(BasalInjectionPayload.decode(from: notes)?.units, 200)
        XCTAssertEqual(TreatmentNSResponse.fromNightscout(dictionary: document(notes: notes)).first?.value, 200)
    }

    func testInvalidBasalDosesAreRejected() {
        for units in [0.0, -1, 4.23, 6.4, 0.25, .nan, .infinity, -.infinity] {
            XCTAssertNil(BasalInjectionPayload(units: units, insulinDescription: "Tresiba"))
        }
    }

    func testMalformedFutureAndInvalidDosePayloadsRemainNotes() throws {
        let invalidNotes = [
            "Basal injection: Tresiba, 20 U",
            BasalInjectionPayload.prefix + "invalid",
            envelope(#"{"version":2,"units":20,"insulinDescription":"Tresiba"}"#),
            envelope(#"{"version":1,"units":4.23,"insulinDescription":"Tresiba"}"#),
            envelope(#"{"version":1,"units":6.4,"insulinDescription":"Tresiba"}"#),
            envelope(#"{"version":1,"units":0,"insulinDescription":"Tresiba"}"#)
        ]
        for notes in invalidNotes {
            XCTAssertNil(BasalInjectionPayload.decode(from: notes))
            let responses = TreatmentNSResponse.fromNightscout(dictionary: document(notes: notes))
            XCTAssertEqual(responses.count, 1)
            XCTAssertEqual(responses.first?.eventType, .Note)
            XCTAssertEqual(responses.first?.notes, notes)
        }
    }

    func testRecognisedNoteProducesOnlyOneInjectionEvenWithNumericFields() throws {
        let notes = try XCTUnwrap(BasalInjectionPayload(units: 20, insulinDescription: "Tresiba")?.encodedNotes())
        let input = document(notes: notes).mutableCopy() as! NSMutableDictionary
        input["insulin"] = 20
        input["carbs"] = 10
        let responses = TreatmentNSResponse.fromNightscout(dictionary: input)
        XCTAssertEqual(responses.count, 1)
        XCTAssertEqual(responses.first?.eventType, .BasalInjection)
        XCTAssertEqual(responses.first?.value, 20)
        XCTAssertEqual(responses.first?.notes, "Tresiba")
        XCTAssertEqual(responses.first?.id, "basaltest-note")
    }

    @MainActor func testUploadRoundTripOmitsActiveInsulinAndPumpBasalFields() throws {
        let coreDataManager = CoreDataManager(inMemoryModelName: ConstantsCoreData.modelName)
        let entry = TreatmentEntry(date: date, value: 20, treatmentType: .BasalInjection, nightscoutEventType: nil, enteredBy: "Test", notes: "Tresiba", nsManagedObjectContext: coreDataManager.mainManagedObjectContext)
        var upload = entry.dictionaryRepresentationForNightscoutUpload()
        XCTAssertEqual(upload["eventType"] as? String, "Note")
        for key in ["insulin", "rate", "absolute", "duration"] {
            XCTAssertNil(upload[key], "Basal injection must omit \(key)")
        }
        upload["_id"] = "basaltest"
        let response = try XCTUnwrap(TreatmentNSResponse.fromNightscout(dictionary: upload as NSDictionary).first)
        XCTAssertTrue(response.matchesTreatmentEntry(entry))
        XCTAssertEqual(response.eventType, .BasalInjection)
    }

    @MainActor func testDraftDefaultsRequireSaveAndRemainEditable() throws {
        try withRestoredDefaults {
            UserDefaults.standard.lastBasalInjectionUnits = 20
            UserDefaults.standard.lastBasalInjectionInsulinDescription = "Tresiba"
            let coreDataManager = CoreDataManager(inMemoryModelName: ConstantsCoreData.modelName)
            let draft = TreatmentEditorViewModel(coreDataManager: coreDataManager, treatmentToEdit: nil, initialType: .BasalInjection)
            XCTAssertTrue(draft.didPrefillBasalInjection)
            XCTAssertEqual(draft.enteredValue, "20")
            XCTAssertEqual(draft.enteredInsulinDescription, "Tresiba")
            draft.enteredValue = "22"
            draft.enteredInsulinDescription = "Lantus"
            XCTAssertEqual(UserDefaults.standard.lastBasalInjectionUnits, 20)
            XCTAssertEqual(UserDefaults.standard.lastBasalInjectionInsulinDescription, "Tresiba")
            XCTAssertTrue(draft.saveTreatment())
            XCTAssertEqual(UserDefaults.standard.lastBasalInjectionUnits, 22)
            XCTAssertEqual(UserDefaults.standard.lastBasalInjectionInsulinDescription, "Lantus")
            let saved = try XCTUnwrap(TreatmentEntryAccessor(coreDataManager: coreDataManager).getLatestTreatments(howOld: nil).first)
            XCTAssertEqual(saved.treatmentType, .BasalInjection)
            XCTAssertEqual(saved.value, 22)
            XCTAssertEqual(saved.notes, "Lantus")
        }
    }

    @MainActor func testInvalidDraftAndFailedSaveDoNotReplaceDefaults() throws {
        withRestoredDefaults {
            UserDefaults.standard.lastBasalInjectionUnits = 20
            let draft = TreatmentEditorViewModel(coreDataManager: nil, treatmentToEdit: nil, initialType: .BasalInjection)
            draft.enteredInsulinDescription = "Tresiba"
            for input in ["0", "-1", "nan", "inf"] {
                draft.enteredValue = input
                XCTAssertFalse(draft.canSaveTreatment)
            }
            draft.enteredValue = "22.5"
            XCTAssertTrue(draft.canSaveTreatment)
            XCTAssertFalse(draft.saveTreatment())
            XCTAssertEqual(UserDefaults.standard.lastBasalInjectionUnits, 20)
        }
    }

    @MainActor func testEditUsesSavedInjectionAndDetectsDescriptionOnlyChanges() throws {
        withRestoredDefaults {
            UserDefaults.standard.lastBasalInjectionUnits = 30
            UserDefaults.standard.lastBasalInjectionInsulinDescription = "Lantus"
            let coreDataManager = CoreDataManager(inMemoryModelName: ConstantsCoreData.modelName)
            let entry = TreatmentEntry(date: date, value: 20, treatmentType: .BasalInjection, nightscoutEventType: "Note", enteredBy: "Test", notes: "Tresiba", nsManagedObjectContext: coreDataManager.mainManagedObjectContext)
            XCTAssertTrue(coreDataManager.saveChanges())
            let editor = TreatmentEditorViewModel(coreDataManager: coreDataManager, treatmentToEdit: entry)
            XCTAssertFalse(editor.didPrefillBasalInjection)
            XCTAssertEqual(editor.enteredValue, "20")
            XCTAssertEqual(editor.enteredInsulinDescription, "Tresiba")
            XCTAssertFalse(editor.canSaveTreatment)
            editor.enteredInsulinDescription = "Toujeo"
            XCTAssertTrue(editor.canSaveTreatment)
            XCTAssertTrue(editor.saveTreatment())
            XCTAssertEqual(entry.notes, "Toujeo")
            XCTAssertEqual(UserDefaults.standard.lastBasalInjectionInsulinDescription, "Toujeo")
        }
    }

    @MainActor func testInjectionHasIndependentListFilterAndEditablePresentation() async throws {
        await withRestoredDefaults {
            let coreDataManager = CoreDataManager(inMemoryModelName: ConstantsCoreData.modelName)
            let injection = TreatmentEntry(date: Date(), value: 20, treatmentType: .BasalInjection, nightscoutEventType: "Note", enteredBy: "Test", notes: "Tresiba", nsManagedObjectContext: coreDataManager.mainManagedObjectContext)
            _ = TreatmentEntry(date: Date(), value: 0, treatmentType: .Note, nightscoutEventType: "Note", enteredBy: "Test", notes: "Ordinary note", nsManagedObjectContext: coreDataManager.mainManagedObjectContext)
            XCTAssertTrue(coreDataManager.saveChanges())
            UserDefaults.standard.showNoteTreatmentsInList = false
            UserDefaults.standard.showBasalInjectionTreatmentsInList = true
            let model = TreatmentsViewModel(coreDataManager: coreDataManager)
            model.reloadTreatments()
            await model.reloadTask?.value
            XCTAssertEqual(model.filteredTreatments.map(\.treatmentType), [.BasalInjection])
            let snapshot = TreatmentSnapshot(treatmentEntry: injection)
            XCTAssertTrue(snapshot.isEditable)
            XCTAssertEqual(snapshot.valueText, "20")
            XCTAssertEqual(snapshot.unitText, "U")
            XCTAssertNil(snapshot.secondaryText)
            XCTAssertEqual(snapshot.iconSystemName, "arrowtriangle.down.fill")
            model.toggleBasalInjectionFilter()
            XCTAssertTrue(model.filteredTreatments.isEmpty)
            model.toggleNoteFilter()
            XCTAssertEqual(model.filteredTreatments.map(\.treatmentType), [.Note])
        }
    }

    @MainActor func testChartKeepsInjectionBelowBolusAndOutsideNoteSeries() async throws {
        let coreDataManager = CoreDataManager(inMemoryModelName: ConstantsCoreData.modelName)
        let treatmentDate = Date().addingTimeInterval(-60)
        _ = TreatmentEntry(date: treatmentDate, value: 3, treatmentType: .Insulin, nightscoutEventType: nil, enteredBy: "Test", nsManagedObjectContext: coreDataManager.mainManagedObjectContext)
        _ = TreatmentEntry(date: treatmentDate, value: 20, treatmentType: .BasalInjection, nightscoutEventType: "Note", enteredBy: "Test", notes: "Tresiba", nsManagedObjectContext: coreDataManager.mainManagedObjectContext)
        XCTAssertTrue(coreDataManager.saveChanges())
        let syncManager = NightscoutSyncManager(coreDataManager: coreDataManager, messageHandler: nil)
        let chart = GlucoseChartStateManager(coreDataManager: coreDataManager, nightscoutSyncManager: syncManager)
        let state: GlucoseChartState = await withCheckedContinuation { continuation in
            chart.updateState(endDate: Date(), startDate: treatmentDate.addingTimeInterval(-3600), forceReset: true, showTreatments: true) {
                continuation.resume(returning: $0)
            }
        }
        let injection = try XCTUnwrap(state.treatmentPoints.basalInjections.first)
        let bolus = try XCTUnwrap(state.treatmentPoints.boluses.first)
        XCTAssertEqual(state.treatmentPoints.basalInjections.count, 1)
        XCTAssertTrue(state.treatmentPoints.notes.isEmpty)
        XCTAssertLessThan(injection.yValue, bolus.yValue)
        XCTAssertEqual(injection.label, "20")
        XCTAssertEqual(bolus.label, "3")
        XCTAssertEqual(injection.notes, "Tresiba")

        // Exercise the incremental range merge as well as the initial chart load.
        let scrolled: GlucoseChartState = await withCheckedContinuation { continuation in
            chart.updateState(endDate: Date(), startDate: treatmentDate.addingTimeInterval(-7200), showTreatments: true) {
                continuation.resume(returning: $0)
            }
        }
        XCTAssertEqual(scrolled.treatmentPoints.basalInjections.count, 1)
    }

    @MainActor func testRecoveryImporterRecognisesInjectionAndDoesNotDuplicateIt() async throws {
        let defaults = UserDefaults.standard
        let keys = ["nightscoutUrl", "nightscoutPort"]
        let previous = keys.map { defaults.object(forKey: $0) }
        defer {
            for (key, value) in zip(keys, previous) {
                if let value { defaults.set(value, forKey: key) }
                else { defaults.removeObject(forKey: key) }
            }
        }
        defaults.nightscoutUrl = "https://basal-injection-tests.invalid"
        defaults.nightscoutPort = 0
        let coreDataManager = CoreDataManager(inMemoryModelName: ConstantsCoreData.modelName)
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [BasalInjectionTestURLProtocol.self]
        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel() }
        let importer = NightscoutImportService(coreDataManager: coreDataManager, session: session)
        let timestamp = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-09-07T20:00:00Z"))
        let interval = DateInterval(start: timestamp.addingTimeInterval(-60), end: timestamp.addingTimeInterval(60))
        let first = try await importer.mergeTreatments(in: interval)
        XCTAssertEqual(first.treatmentsAdded, 1)
        let second = try await importer.mergeTreatments(in: interval)
        XCTAssertEqual(second.treatmentsAdded, 0)
        let treatments = TreatmentEntryAccessor(coreDataManager: coreDataManager).getLatestTreatments(howOld: nil)
        XCTAssertEqual(treatments.count, 1)
        XCTAssertEqual(treatments.first?.treatmentType, .BasalInjection)
        XCTAssertEqual(treatments.first?.value, 20.5)
        XCTAssertEqual(treatments.first?.notes, "Tresiba")
    }

    @MainActor func testBasalInjectionRequiresBothFieldsBeforeSaving() {
        withRestoredDefaults {
            let coreDataManager = CoreDataManager(inMemoryModelName: ConstantsCoreData.modelName)
            let draft = TreatmentEditorViewModel(coreDataManager: coreDataManager, treatmentToEdit: nil, initialType: .BasalInjection)
            draft.enteredValue = "20"
            for description in ["", "   ", "\n"] {
                draft.enteredInsulinDescription = description
                XCTAssertFalse(draft.canSaveTreatment)
                XCTAssertFalse(draft.saveTreatment())
            }
            draft.enteredInsulinDescription = "Tresiba"
            draft.enteredValue = ""
            XCTAssertFalse(draft.canSaveTreatment)
            draft.enteredValue = "20"
            XCTAssertTrue(draft.canSaveTreatment)
        }
    }

    func testNativeTreatmentSymbolsExistInFilledAndUnfilledForms() {
        for symbol in [GlucoseChartTreatmentStyle.bolusSymbol, GlucoseChartTreatmentStyle.carbsSymbol, GlucoseChartTreatmentStyle.basalInjectionSymbol, GlucoseChartTreatmentStyle.bgCheckSymbol, GlucoseChartTreatmentStyle.noteSymbol] {
            XCTAssertNotNil(UIImage(systemName: symbol), symbol)
            let unfilled = symbol.replacingOccurrences(of: ".fill", with: "")
            XCTAssertNotNil(UIImage(systemName: unfilled), unfilled)
        }
    }

    @MainActor func testEditingAfterTemporaryObjectIDChangesDoesNotInsertTreatment() throws {
        try withRestoredDefaults {
            UserDefaults.standard.nightscoutEnabled = false
            let coreDataManager = CoreDataManager(inMemoryModelName: ConstantsCoreData.modelName)
            let entry = TreatmentEntry(date: Date(), value: 20, treatmentType: .BasalInjection, nightscoutEventType: "Note", enteredBy: "Test", notes: "Tresiba", nsManagedObjectContext: coreDataManager.mainManagedObjectContext)
            XCTAssertTrue(entry.objectID.isTemporaryID)
            let editor = TreatmentEditorViewModel(coreDataManager: coreDataManager, treatmentToEdit: entry)

            // A treatment can be shown while its parent-context save is still pending. Reproduce
            // the identity promotion after the editor has captured the original temporary ID.
            try coreDataManager.mainManagedObjectContext.obtainPermanentIDs(for: [entry])
            XCTAssertFalse(entry.objectID.isTemporaryID)
            XCTAssertTrue(coreDataManager.saveChangesSynchronously())
            editor.enteredValue = "22"
            XCTAssertTrue(editor.saveTreatment())
            let entries = TreatmentEntryAccessor(coreDataManager: coreDataManager).getLatestTreatments(howOld: nil)
            XCTAssertEqual(entries.count, 1)
            XCTAssertEqual(entry.value, 22)
        }
    }

    @MainActor func testTreatmentListPublishesPermanentIDsForPendingLocalEntries() async throws {
        let coreDataManager = CoreDataManager(inMemoryModelName: ConstantsCoreData.modelName)
        let entry = TreatmentEntry(date: Date(), value: 20, treatmentType: .BasalInjection, nightscoutEventType: nil, enteredBy: "Test", notes: "Tresiba", nsManagedObjectContext: coreDataManager.mainManagedObjectContext)
        XCTAssertTrue(entry.objectID.isTemporaryID)
        let model = TreatmentsViewModel(coreDataManager: coreDataManager)
        model.reloadTreatments()
        await model.reloadTask?.value
        XCTAssertFalse(entry.objectID.isTemporaryID)
        XCTAssertTrue(coreDataManager.saveChangesSynchronously())
        let resolved = TreatmentEntryAccessor(coreDataManager: coreDataManager).getTreatment(objectID: entry.objectID)
        XCTAssertTrue(resolved === entry)
    }

    @MainActor func testDeletedEditTargetCannotBecomeANewTreatment() {
        let coreDataManager = CoreDataManager(inMemoryModelName: ConstantsCoreData.modelName)
        let entry = TreatmentEntry(date: Date(), value: 3, treatmentType: .Insulin, nightscoutEventType: nil, enteredBy: "Test", nsManagedObjectContext: coreDataManager.mainManagedObjectContext)
        let editor = TreatmentEditorViewModel(coreDataManager: coreDataManager, treatmentToEdit: entry)
        coreDataManager.mainManagedObjectContext.delete(entry)
        XCTAssertTrue(coreDataManager.saveChangesSynchronously())
        editor.enteredValue = "4"
        XCTAssertFalse(editor.isAddMode)
        XCTAssertFalse(editor.saveTreatment())
        XCTAssertTrue(TreatmentEntryAccessor(coreDataManager: coreDataManager).getLatestTreatments(howOld: nil).isEmpty)
    }

    @MainActor func testLocalEditUpdatesOneRecordForEveryEditableTreatmentType() throws {
        try withRestoredDefaults {
            UserDefaults.standard.nightscoutEnabled = false
            for type in TreatmentEditorViewModel.supportedTreatmentTypes {
                let coreDataManager = CoreDataManager(inMemoryModelName: ConstantsCoreData.modelName)
                let entry = TreatmentEntry(date: Date(), value: 20, treatmentType: type, nightscoutEventType: nil, enteredBy: "Test", notes: type == .BasalInjection ? "Tresiba" : "Original", nsManagedObjectContext: coreDataManager.mainManagedObjectContext)
                let editor = TreatmentEditorViewModel(coreDataManager: coreDataManager, treatmentToEdit: entry)
                try coreDataManager.mainManagedObjectContext.obtainPermanentIDs(for: [entry])
                XCTAssertTrue(coreDataManager.saveChangesSynchronously())
                editor.enteredValue = "22"
                editor.enteredNotesValue = "Edited"
                XCTAssertTrue(editor.saveTreatment(), type.asString())
                let records = TreatmentEntryAccessor(coreDataManager: coreDataManager).getLatestTreatments(howOld: nil)
                XCTAssertEqual(records.count, 1, type.asString())
                XCTAssertTrue(records.first === entry, type.asString())
            }
        }
    }

    @MainActor func testTreatmentDatePickerLimitsFutureEntry() {
        for type in TreatmentEditorViewModel.supportedTreatmentTypes {
            let editor = TreatmentEditorViewModel(coreDataManager: nil, treatmentToEdit: nil, initialType: type)
            editor.enteredValue = "20"
            editor.enteredInsulinDescription = "Tresiba"
            editor.enteredNotesValue = "Note"
            let expectedLimit: TimeInterval = type == .BgCheck ? 0 : 3600
            XCTAssertEqual(editor.latestSelectableDate.timeIntervalSinceNow, expectedLimit, accuracy: 1)
            editor.selectedDate = Date().addingTimeInterval(7200)
            XCTAssertFalse(editor.canSaveTreatment)
            editor.validateSelectedDateIfNeeded()
            XCTAssertLessThanOrEqual(editor.selectedDate.timeIntervalSinceNow, expectedLimit)
            XCTAssertTrue(editor.canSaveTreatment)
            if type != .BgCheck {
                editor.selectedDate = Date().addingTimeInterval(3599)
                XCTAssertTrue(editor.canSaveTreatment)
            }
        }
    }

    func testDoseSymbolSizingInterpolatesAndClamps() {
        for range in [GlucoseChartTreatmentStyle.bolusSymbolSizing, GlucoseChartTreatmentStyle.carbsSymbolSizing] {
            XCTAssertEqual(range.size(for: range.minimumValue), range.minimumSize)
            XCTAssertEqual(range.size(for: range.maximumValue), range.maximumSize)
            XCTAssertEqual(range.size(for: 0), range.minimumSize)
            XCTAssertEqual(range.size(for: range.maximumValue * 10), range.maximumSize)
            XCTAssertEqual(range.size(for: (range.minimumValue + range.maximumValue) / 2), (range.minimumSize + range.maximumSize) / 2, accuracy: 0.0001)
            let lower = range.minimumValue + (range.maximumValue - range.minimumValue) * 0.25
            let upper = range.minimumValue + (range.maximumValue - range.minimumValue) * 0.75
            XCTAssertLessThan(range.size(for: lower), range.size(for: upper))
            XCTAssertEqual(range.size(for: .nan), range.minimumSize)
        }
    }

    func testNoteChartLabelsAreCompactWithoutChangingTheirContent() {
        XCTAssertNil(GlucoseChartTreatmentStyle.noteLabel(nil))
        XCTAssertNil(GlucoseChartTreatmentStyle.noteLabel("  \n "))
        XCTAssertEqual(GlucoseChartTreatmentStyle.noteLabel("  Before\n breakfast  "), "Before breakfast")
        let exact = String(repeating: "a", count: GlucoseChartTreatmentStyle.noteLabelCharacterLimit)
        XCTAssertEqual(GlucoseChartTreatmentStyle.noteLabel(exact), exact)
        let longNote = String(repeating: "👨‍👩‍👧‍👦", count: 25)
        let label = GlucoseChartTreatmentStyle.noteLabel(longNote)
        XCTAssertEqual(label?.count, GlucoseChartTreatmentStyle.noteLabelCharacterLimit)
        XCTAssertTrue(label?.hasSuffix("…") == true)
        XCTAssertEqual(longNote.count, 25)
    }

    /// A busy SQLite queue must not make unrelated defaults callbacks wait or request a reload.
    @MainActor func testUnrelatedDefaultsDoNotReloadTreatmentsWhileStoreIsBusy() async {
        let coreDataManager = CoreDataManager(inMemoryModelName: ConstantsCoreData.modelName)
        let model = TreatmentsViewModel(coreDataManager: coreDataManager)
        let entered = expectation(description: "Private context held")
        let release = DispatchSemaphore(value: 0)
        let context = coreDataManager.privateManagedObjectContext
        DispatchQueue.global().async {
            context.performAndWait {
                entered.fulfill()
                XCTAssertEqual(release.wait(timeout: .now() + 5), .success, "Main must release the store before its safety timeout")
            }
        }
        await fulfillment(of: [entered], timeout: 2)
        defer { release.signal() }
        for _ in 0..<100 {
            model.handleUserDefaultsDidChange()
        }
        XCTAssertNil(model.reloadTask, "Presentation changes must not schedule any database fetch")
        // This also exercises the real refresh path while the store is blocked. Main must stay
        // available to release the store rather than waiting synchronously inside reloadTreatments.
        let requestedAt = Date()
        model.reloadTreatments()
        XCTAssertLessThan(Date().timeIntervalSince(requestedAt), 1)
        let mainResponded = expectation(description: "Main remains responsive")
        DispatchQueue.main.async { mainResponded.fulfill() }
        await fulfillment(of: [mainResponded], timeout: 1)
        release.signal()
        await model.reloadTask?.value
    }

    @MainActor func testTreatmentCounterReloadsButFiltersReuseSnapshots() async {
        await withRestoredDefaults {
            let coreDataManager = CoreDataManager(inMemoryModelName: ConstantsCoreData.modelName)
            let model = TreatmentsViewModel(coreDataManager: coreDataManager)
            _ = TreatmentEntry(date: Date(), value: 20, treatmentType: .Note, nightscoutEventType: nil, enteredBy: "Test", nsManagedObjectContext: coreDataManager.mainManagedObjectContext)
            UserDefaults.standard.nightscoutTreatmentsUpdateCounter += 1
            model.handleUserDefaultsDidChange()
            await model.reloadTask?.value
            XCTAssertEqual(model.filteredTreatments.count, 1)
            UserDefaults.standard.showNoteTreatmentsInList = false
            model.handleUserDefaultsDidChange()
            XCTAssertTrue(model.filteredTreatments.isEmpty)
        }
    }

    /// Checking parent registrations distinguishes a bounded store query from fetching all history
    /// and filtering afterwards, even when both implementations display the same rows.
    @MainActor func testTreatmentFetchOnlyMaterialisesSelectedCalendarDay() async throws {
        let coreDataManager = CoreDataManager(inMemoryModelName: ConstantsCoreData.modelName)
        let main = coreDataManager.mainManagedObjectContext
        let start = Calendar.current.startOfDay(for: Date())
        let end = try XCTUnwrap(Calendar.current.date(byAdding: .day, value: 1, to: start))
        for date in [start.addingTimeInterval(-1), start, end.addingTimeInterval(-1), end] {
            _ = TreatmentEntry(date: date, value: 20, treatmentType: .Note, nightscoutEventType: nil, enteredBy: "Test", nsManagedObjectContext: main)
        }
        XCTAssertTrue(coreDataManager.saveChangesSynchronously())
        main.reset()
        let context = coreDataManager.privateManagedObjectContext
        context.performAndWait {
            context.reset()
            context.retainsRegisteredObjects = true
        }
        let model = TreatmentsViewModel(coreDataManager: coreDataManager)
        model.reloadTreatments()
        await model.reloadTask?.value
        XCTAssertEqual(model.filteredTreatments.map(\.date), [end.addingTimeInterval(-1), start])
        XCTAssertTrue(main.registeredObjects.isEmpty, "Private snapshots must not load managed objects on main")
        let dates = await context.perform {
            context.registeredObjects.compactMap { ($0 as? TreatmentEntry)?.date }
        }
        XCTAssertEqual(dates.count, 2)
        XCTAssertTrue(dates.allSatisfy { $0 >= start && $0 < end })
    }

    @MainActor func testNewerDayLoadWinsAndPendingMoveAndDeletionArePreserved() async throws {
        let coreDataManager = CoreDataManager(inMemoryModelName: ConstantsCoreData.modelName)
        let main = coreDataManager.mainManagedObjectContext
        let today = Calendar.current.startOfDay(for: Date())
        let yesterday = try XCTUnwrap(Calendar.current.date(byAdding: .day, value: -1, to: today))
        let moved = TreatmentEntry(date: today, value: 1, treatmentType: .Note, nightscoutEventType: nil, enteredBy: "Test", nsManagedObjectContext: main)
        let deleted = TreatmentEntry(date: today, value: 2, treatmentType: .Note, nightscoutEventType: nil, enteredBy: "Test", nsManagedObjectContext: main)
        XCTAssertTrue(coreDataManager.saveChangesSynchronously())
        moved.date = yesterday
        main.delete(deleted)
        let model = TreatmentsViewModel(coreDataManager: coreDataManager)
        model.reloadTreatments()
        let olderLoad = model.reloadTask
        model.selectedDateChanged(yesterday)
        await olderLoad?.value
        await model.reloadTask?.value
        XCTAssertEqual(model.filteredTreatments.map(\.objectID), [moved.objectID])
        XCTAssertEqual(model.filteredTreatments.first?.date, yesterday)
    }

    /// The previous import blocks main on the same queue which this test deliberately holds.
    /// Releasing it from main proves the real import suspends rather than synchronously waiting.
    @MainActor func testNightscoutImportWaitsOffMainAndDoesNotDuplicateExistingOrPendingIDs() async throws {
        try await withRestoredDefaults {
            UserDefaults.standard.nightscoutEnabled = true
            UserDefaults.standard.therapyDataSourceType = .nightscout
            let coreDataManager = CoreDataManager(inMemoryModelName: ConstantsCoreData.modelName)
            let main = coreDataManager.mainManagedObjectContext
            let manager = NightscoutSyncManager(coreDataManager: coreDataManager, messageHandler: nil)
            let old = TreatmentEntry(id: "old-note", date: Date(timeIntervalSinceNow: -86400 * 20), value: 1, treatmentType: .Note, nightscoutEventType: nil, enteredBy: "Test", nsManagedObjectContext: main)
            old.treatmentdeleted = true
            XCTAssertTrue(coreDataManager.saveChangesSynchronously())
            // This entry is visible only on main. It must still suppress a duplicate import.
            _ = TreatmentEntry(id: "pending-note", date: Date(), value: 2, treatmentType: .Note, nightscoutEventType: nil, enteredBy: "Test", nsManagedObjectContext: main)
            let responses = ["old-note", "pending-note", "new-note", "new-note"].map {
                TreatmentNSResponse(id: $0, createdAt: Date(), eventType: .Note, nightscoutEventType: nil, value: 3, valueSecondary: nil, enteredBy: "Test", notes: "Imported")
            }
            let entered = expectation(description: "Import store held")
            let release = DispatchSemaphore(value: 0)
            let context = coreDataManager.privateManagedObjectContext
            DispatchQueue.global().async {
                context.performAndWait {
                    entered.fulfill()
                    XCTAssertEqual(release.wait(timeout: .now() + 5), .success, "Main must release the store before its safety timeout")
                }
            }
            await fulfillment(of: [entered], timeout: 2)
            defer { release.signal() }
            let requestedAt = Date()
            let task = Task { try await manager.newTreatmentsIfRequired(treatmentNSResponses: responses) }
            await Task.yield()
            XCTAssertLessThan(Date().timeIntervalSince(requestedAt), 1)
            let mainResponded = expectation(description: "Main responds during import")
            DispatchQueue.main.async { mainResponded.fulfill() }
            await fulfillment(of: [mainResponded], timeout: 1)
            release.signal()
            let count = try await task.value
            XCTAssertEqual(count, 1)
            let entries = TreatmentEntryAccessor(coreDataManager: coreDataManager).getLatestTreatments(howOld: nil)
            XCTAssertEqual(entries.count, 3)
            XCTAssertEqual(Set(entries.map(\.id)), ["old-note", "pending-note", "new-note"])
            XCTAssertTrue(old.treatmentdeleted)
        }
    }

    @MainActor func testNightscoutImportRejectsSourceChangeWhileLookupIsPending() async throws {
        try await withRestoredDefaults {
            UserDefaults.standard.nightscoutEnabled = true
            UserDefaults.standard.therapyDataSourceType = .nightscout
            let coreDataManager = CoreDataManager(inMemoryModelName: ConstantsCoreData.modelName)
            let manager = NightscoutSyncManager(coreDataManager: coreDataManager, messageHandler: nil)
            let entered = expectation(description: "Lookup held")
            let release = DispatchSemaphore(value: 0)
            let context = coreDataManager.privateManagedObjectContext
            DispatchQueue.global().async {
                context.performAndWait {
                    entered.fulfill()
                    XCTAssertEqual(release.wait(timeout: .now() + 5), .success, "Main must release the store before its safety timeout")
                }
            }
            await fulfillment(of: [entered], timeout: 2)
            defer { release.signal() }
            let response = TreatmentNSResponse(id: "new-note", createdAt: Date(), eventType: .Note, nightscoutEventType: nil, value: 1, valueSecondary: nil, enteredBy: "Test", notes: nil)
            let task = Task { try await manager.newTreatmentsIfRequired(treatmentNSResponses: [response]) }
            // Allow the import to capture its source and suspend at the private-context lookup.
            await Task.yield()
            UserDefaults.standard.therapyDataSourceType = .none
            release.signal()
            do {
                _ = try await task.value
                XCTFail("A disabled import must not create treatments from an older request")
            } catch is CancellationError {
                XCTAssertTrue(coreDataManager.mainManagedObjectContext.insertedObjects.isEmpty)
            }
        }
    }

    /// The server can change before the HTTP response arrives, not only during the ID lookup.
    @MainActor func testNightscoutImportRejectsResponseFromPreviousSource() async throws {
        try await withRestoredDefaults {
            UserDefaults.standard.nightscoutEnabled = true
            UserDefaults.standard.therapyDataSourceType = .nightscout
            UserDefaults.standard.nightscoutUrl = "https://current.invalid"
            UserDefaults.standard.nightscoutPort = 443
            let coreDataManager = CoreDataManager(inMemoryModelName: ConstantsCoreData.modelName)
            let manager = NightscoutSyncManager(coreDataManager: coreDataManager, messageHandler: nil)
            let response = TreatmentNSResponse(id: "previous-source-note", createdAt: Date(), eventType: .Note, nightscoutEventType: nil, value: 1, valueSecondary: nil, enteredBy: "Test", notes: nil)
            do {
                _ = try await manager.newTreatmentsIfRequired(treatmentNSResponses: [response], sourceURL: "https://previous.invalid", sourcePort: 443)
                XCTFail("A previous server's response must not be imported under the current source")
            } catch is CancellationError {
                XCTAssertTrue(coreDataManager.mainManagedObjectContext.insertedObjects.isEmpty)
            }
        }
    }

    @MainActor func testSavedLocalTreatmentKeepsOneEditableSnapshot() async throws {
        let coreDataManager = CoreDataManager(inMemoryModelName: ConstantsCoreData.modelName)
        let entry = TreatmentEntry(date: Date(), value: 20, treatmentType: .BasalInjection, nightscoutEventType: nil, enteredBy: "Test", nsManagedObjectContext: coreDataManager.mainManagedObjectContext)
        XCTAssertTrue(coreDataManager.saveChanges())
        let model = TreatmentsViewModel(coreDataManager: coreDataManager)
        model.reloadTreatments()
        await model.reloadTask?.value
        XCTAssertEqual(model.filteredTreatments.count, 1)
        let snapshot = try XCTUnwrap(model.filteredTreatments.first)
        XCTAssertFalse(snapshot.objectID.isTemporaryID)
        XCTAssertNotNil(TreatmentEntryAccessor(coreDataManager: coreDataManager).getTreatment(objectID: snapshot.objectID))
    }

    /// A second response can finish its lookup before the first response has saved its inserts.
    /// Exercise the caller's save as well, so clearing main's insertedObjects cannot hide a duplicate.
    @MainActor func testOverlappingNightscoutImportsDoNotDuplicateSavedInsertions() async throws {
        try await withRestoredDefaults {
            UserDefaults.standard.nightscoutEnabled = true
            UserDefaults.standard.therapyDataSourceType = .nightscout
            let coreDataManager = CoreDataManager(inMemoryModelName: ConstantsCoreData.modelName)
            let manager = NightscoutSyncManager(coreDataManager: coreDataManager, messageHandler: nil)
            let response = TreatmentNSResponse(id: "same-note", createdAt: Date(), eventType: .Note, nightscoutEventType: nil, value: 1, valueSecondary: nil, enteredBy: "Test", notes: nil)
            let first = Task { @MainActor in
                let count = try await manager.newTreatmentsIfRequired(treatmentNSResponses: [response])
                XCTAssertTrue(coreDataManager.saveChanges())
                return count
            }
            let second = Task { try await manager.newTreatmentsIfRequired(treatmentNSResponses: [response]) }
            let counts = try await [first.value, second.value]
            XCTAssertEqual(counts.reduce(0, +), 1)
            XCTAssertEqual(TreatmentEntryAccessor(coreDataManager: coreDataManager).getLatestTreatments(howOld: nil).count, 1)
        }
    }

    /// Use the incident's treatment volume in a real SQLite store, with a small selected day.
    /// This exercises the app methods rather than a separate approximation of their SQL queries.
    @MainActor func testLargeSQLiteHistoryLoadsOneDayAndImportsWithoutDuplicates() async throws {
        try await withRestoredDefaults {
            UserDefaults.standard.nightscoutEnabled = true
            UserDefaults.standard.therapyDataSourceType = .nightscout
            UserDefaults.standard.showNoteTreatmentsInList = true
            let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(at: directory) }
            let coreDataManager = try CoreDataManager(testModelName: ConstantsCoreData.modelName, persistentStoreURL: directory.appendingPathComponent("treatments.sqlite"))
            defer { try? coreDataManager.disconnectPersistentStoresForTesting() }
            let main = coreDataManager.mainManagedObjectContext
            let context = coreDataManager.privateManagedObjectContext
            let start = Calendar.current.startOfDay(for: Date())
            for index in 0..<43_106 {
                let date = index < 154 ? start.addingTimeInterval(Double(index)) : start.addingTimeInterval(-Double(index))
                _ = TreatmentEntry(id: "history-\(index)-note", date: date, value: 1, treatmentType: .Note, nightscoutEventType: nil, enteredBy: "Test", nsManagedObjectContext: main)
            }
            XCTAssertTrue(coreDataManager.saveChangesSynchronously())
            main.reset()
            context.performAndWait { context.reset() }
            let model = TreatmentsViewModel(coreDataManager: coreDataManager)
            model.reloadTreatments()
            await model.reloadTask?.value
            XCTAssertEqual(model.filteredTreatments.count, 154)
            XCTAssertTrue(main.registeredObjects.isEmpty)

            let manager = NightscoutSyncManager(coreDataManager: coreDataManager, messageHandler: nil)
            // Include IDs far outside the latest-50 upload list, plus a duplicated new response.
            let ids = (1000..<1236).map { "history-\($0)-note" } + ["new-note", "new-note"]
            let responses = ids.map { TreatmentNSResponse(id: $0, createdAt: Date(), eventType: .Note, nightscoutEventType: nil, value: 1, valueSecondary: nil, enteredBy: "Test", notes: nil) }
            let added = try await manager.newTreatmentsIfRequired(treatmentNSResponses: responses)
            XCTAssertEqual(added, 1)
            XCTAssertEqual(main.insertedObjects.count, 1)
            XCTAssertTrue(coreDataManager.saveChangesSynchronously())
            let count = try await context.perform {
                try context.count(for: TreatmentEntry.fetchRequest())
            }
            XCTAssertEqual(count, 43_107)
        }
    }

    private func envelope(_ json: String) -> String {
        BasalInjectionPayload.prefix + Data(json.utf8).base64EncodedString()
    }

    private func document(notes: String) -> NSDictionary {
        ["_id": "basaltest", "created_at": "2026-09-07T20:00:00Z", "eventType": "Note", "notes": notes]
    }

    @MainActor private func withRestoredDefaults(_ body: () async throws -> Void) async rethrows {
        let defaults = UserDefaults.standard
        let keys = ["nightscoutEnabled", "showBasalInjectionTreatmentsInList", "showNoteTreatmentsInList", "nightscoutTreatmentsUpdateCounter", "therapyDataSourceType", "nightscoutUrl", "nightscoutPort"]
        let previous = keys.map { defaults.object(forKey: $0) }
        defer {
            for (key, value) in zip(keys, previous) {
                if let value { defaults.set(value, forKey: key) }
                else { defaults.removeObject(forKey: key) }
            }
        }
        try await body()
    }

    /// Keep tests isolated from the simulator's saved treatment and sync preferences.
    @MainActor private func withRestoredDefaults(_ body: () throws -> Void) rethrows {
        let defaults = UserDefaults.standard
        let keys = ["nightscoutEnabled", "lastBasalInjectionUnits", "lastBasalInjectionInsulinDescription", "showBasalInjectionTreatmentsInList", "showNoteTreatmentsInList", "timeStampLatestNightscoutSyncRequest", "nightscoutSyncRequired"]
        let previous = keys.map { defaults.object(forKey: $0) }
        defer {
            for (key, value) in zip(keys, previous) {
                if let value { defaults.set(value, forKey: key) }
                else { defaults.removeObject(forKey: key) }
            }
        }
        try body()
    }
}

/// Serves a fixed treatment response without contacting a Nightscout server.
private final class BasalInjectionTestURLProtocol: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        let notes = BasalInjectionPayload(units: 20.5, insulinDescription: "Tresiba")!.encodedNotes()!
        let data = try! JSONSerialization.data(withJSONObject: [["_id": "basaltest", "created_at": "2026-09-07T20:00:00Z", "eventType": "Note", "notes": notes, "insulin": 20] as [String: Any]])
        let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}
