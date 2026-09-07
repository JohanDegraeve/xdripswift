//
//  BasalInjectionTests.swift
//  xdripTests
//
//  Created by Paul Plant on 7/9/26.
//  Copyright © 2026 Johan Degraeve. All rights reserved.
//

import XCTest
import UIKit
@testable import xdrip

final class BasalInjectionTests: XCTestCase {
    private let date = Date(timeIntervalSince1970: 1_788_804_000)

    func testPayloadRoundTripIgnoresReadableSummary() throws {
        let payload = try XCTUnwrap(BasalInjectionPayload(units: 20, insulinDescription: "Tresiba"))
        let notes = try XCTUnwrap(payload.encodedNotes())
        XCTAssertTrue(notes.hasPrefix("Basal injection: Tresiba, 20 U\n\n---------\n"))
        let changedSummary = notes.replacingOccurrences(of: "Basal injection: Tresiba, 20 U", with: "Texto cambiado: 99 U")
        XCTAssertEqual(BasalInjectionPayload.decode(from: changedSummary), payload)
    }

    func testFractionalNonFiniteAndNonPositiveDosesAreRejected() {
        for units in [0.0, -1, 20.5, .nan, .infinity, Double.greatestFiniteMagnitude] {
            XCTAssertNil(BasalInjectionPayload(units: units, insulinDescription: "Tresiba"))
        }
    }

    func testMalformedFutureAndFractionalPayloadsRemainNotes() throws {
        let invalidNotes = [
            "Basal injection: Tresiba, 20 U",
            BasalInjectionPayload.prefix + "invalid",
            envelope(#"{"version":2,"units":20,"insulinDescription":"Tresiba"}"#),
            envelope(#"{"version":1,"units":20.5,"insulinDescription":"Tresiba"}"#),
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

    @MainActor func testFractionalDraftAndFailedSaveDoNotReplaceDefaults() throws {
        withRestoredDefaults {
            UserDefaults.standard.lastBasalInjectionUnits = 20
            let draft = TreatmentEditorViewModel(coreDataManager: nil, treatmentToEdit: nil, initialType: .BasalInjection)
            for input in ["20.5", "0", "-1"] {
                draft.enteredValue = input
                XCTAssertFalse(draft.canSaveTreatment)
            }
            draft.enteredValue = "22"
            draft.enteredInsulinDescription = "Tresiba"
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

    @MainActor func testInjectionHasIndependentListFilterAndEditablePresentation() throws {
        withRestoredDefaults {
            let coreDataManager = CoreDataManager(inMemoryModelName: ConstantsCoreData.modelName)
            let injection = TreatmentEntry(date: Date(), value: 20, treatmentType: .BasalInjection, nightscoutEventType: "Note", enteredBy: "Test", notes: "Tresiba", nsManagedObjectContext: coreDataManager.mainManagedObjectContext)
            _ = TreatmentEntry(date: Date(), value: 0, treatmentType: .Note, nightscoutEventType: "Note", enteredBy: "Test", notes: "Ordinary note", nsManagedObjectContext: coreDataManager.mainManagedObjectContext)
            XCTAssertTrue(coreDataManager.saveChanges())
            UserDefaults.standard.showNoteTreatmentsInList = false
            UserDefaults.standard.showBasalInjectionTreatmentsInList = true
            let model = TreatmentsViewModel(coreDataManager: coreDataManager)
            model.reloadTreatments()
            XCTAssertEqual(model.filteredTreatments.map(\.treatmentType), [.BasalInjection])
            let snapshot = TreatmentSnapshot(treatmentEntry: injection)
            XCTAssertTrue(snapshot.isEditable)
            XCTAssertEqual(snapshot.valueText, "20")
            XCTAssertEqual(snapshot.unitText, "U")
            XCTAssertNil(snapshot.secondaryText)
            XCTAssertEqual(snapshot.iconSystemName, "arrowtriangle.down.2.fill")
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
        XCTAssertEqual(treatments.first?.value, 20)
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

    @MainActor func testTreatmentListPublishesPermanentIDsForPendingLocalEntries() throws {
        let coreDataManager = CoreDataManager(inMemoryModelName: ConstantsCoreData.modelName)
        let entry = TreatmentEntry(date: Date(), value: 20, treatmentType: .BasalInjection, nightscoutEventType: nil, enteredBy: "Test", notes: "Tresiba", nsManagedObjectContext: coreDataManager.mainManagedObjectContext)
        XCTAssertTrue(entry.objectID.isTemporaryID)
        let model = TreatmentsViewModel(coreDataManager: coreDataManager)
        model.reloadTreatments()
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

    private func envelope(_ json: String) -> String {
        BasalInjectionPayload.prefix + Data(json.utf8).base64EncodedString()
    }

    private func document(notes: String) -> NSDictionary {
        ["_id": "basaltest", "created_at": "2026-09-07T20:00:00Z", "eventType": "Note", "notes": notes]
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
        let notes = BasalInjectionPayload(units: 20, insulinDescription: "Tresiba")!.encodedNotes()!
        let data = try! JSONSerialization.data(withJSONObject: [["_id": "basaltest", "created_at": "2026-09-07T20:00:00Z", "eventType": "Note", "notes": notes, "insulin": 20] as [String: Any]])
        let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}
