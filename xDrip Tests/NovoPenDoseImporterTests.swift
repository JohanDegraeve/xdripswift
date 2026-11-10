//
//  NovoPenDoseImporterTests.swift
//  xdripTests
//
//  Ported from xDrip "OpenNov" by JamOrHam (NightscoutFoundation/xDrip, GPLv3).
//

import CoreData
import XCTest
@testable import xdrip

final class NovoPenDoseImporterTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    // MARK: - Air shots

    /// SaveCompletedTest.isPrimingDoseTest1/2: ten 1.0 U doses one second apart.
    func testAirShotDetection() {
        let t0 = now
        let doses = (0..<10).map { NovoPenDoseRecord(date: t0.addingTimeInterval(Double($0)), units: 1.0, relativeTime: UInt32($0)) }
        let later = t0.addingTimeInterval(3600)
        XCTAssertEqual(NovoPenDoseImporter.airShotRelativeTimes(doses, maxUnits: 2, window: 3, now: later).ignored, [0, 3, 6])
        XCTAssertEqual(NovoPenDoseImporter.airShotRelativeTimes(doses, maxUnits: 2, window: 30, now: later).ignored, [0])
    }

    /// A small newest dose right after an air shot is still a candidate.
    func testCandidateAfterAirShotIsHeldBack() {
        let doses = [dose(-40, 1), dose(-20, 1)]
        let leftOut = NovoPenDoseImporter.airShotRelativeTimes(doses, maxUnits: 2, window: 120, now: now)
        XCTAssertEqual(leftOut.ignored, [doses[0].relativeTime])
        XCTAssertEqual(leftOut.heldBack, [doses[1].relativeTime])
    }

    // MARK: - Import

    @MainActor
    func testCandidateAfterAirShotIsNotImported() throws {
        let (importer, store, defaults) = makeImporter()
        defaults.novoPenIgnoreAirShots = true
        XCTAssertEqual(try importer.importDoses(result([dose(-20, 1), dose(-40, 1)]), kind: .bolus).created, 0)
        XCTAssertEqual(try treatments(store).count, 0)
    }

    @MainActor
    func testImportBolus() throws {
        let (importer, store, _) = makeImporter()
        guard case .segmentData(let report) = try NovoPenMessage.parse(NovoPenFixtures.doseReport).message else { return XCTFail() }
        let records = report.doses.compactMap { $0.record(eventRelativeTime: report.eventRelativeTime, now: now) }
        XCTAssertEqual(try importer.importDoses(result(records), kind: .bolus).created, 2)

        let rows = try treatments(store)
        XCTAssertEqual(rows.map(\.penDoseIdentifier), ["EGDO2U:Open116177:3.0", "EGDO2U:Open331:2.0"])
        let row = try XCTUnwrap(rows.first)
        XCTAssertEqual(row.treatmentType, .Insulin)
        XCTAssertEqual(row.value, 3.0)
        XCTAssertEqual(row.enteredBy, "xDrip4iOS NovoPen")
        XCTAssertEqual(row.notes, "PEN EGDO2U Novo Nordisk A/S NovoPen")
        XCTAssertEqual(row.id, "")
        XCTAssertFalse(row.uploaded)
        XCTAssertEqual(rows[1].treatmentType, .Insulin)
        XCTAssertEqual(rows[1].value, 2.0)
    }

    @MainActor
    func testBolusNotesWithoutModel() throws {
        let (importer, store, _) = makeImporter()
        _ = try importer.importDoses(result([dose(-60, 3)], model: ""), kind: .bolus)
        XCTAssertEqual(try treatments(store).first?.notes, "PEN EGDO2U")
    }

    @MainActor
    func testDoseOlderThanSevenDaysIsNotImported() throws {
        let (importer, store, _) = makeImporter()
        let old = dose(-NovoPenSession.importWindow - 1, 4)
        XCTAssertEqual(try importer.importDoses(result([dose(-60, 3), old]), kind: .bolus).created, 1)
        XCTAssertEqual(try treatments(store).map(\.value), [3])
    }

    @MainActor
    func testReimportIsNoOp() throws {
        let (importer, store, defaults) = makeImporter()
        let read = result([dose(-60, 3)])
        XCTAssertEqual(try importer.importDoses(read, kind: .bolus).created, 1)
        XCTAssertEqual(defaults.nightscoutTreatmentsUpdateCounter, 1)
        XCTAssertEqual(try importer.importDoses(read, kind: .bolus).created, 0)
        XCTAssertEqual(defaults.nightscoutTreatmentsUpdateCounter, 1)
        XCTAssertEqual(try treatments(store).count, 1)
    }

    @MainActor
    func testDeletedDoseIsNotRecreated() throws {
        let (importer, store, _) = makeImporter()
        let read = result([dose(-60, 3)])
        XCTAssertEqual(try importer.importDoses(read, kind: .bolus).created, 1)
        try treatments(store).first?.treatmentdeleted = true
        XCTAssertTrue(store.saveChangesSynchronously())
        XCTAssertEqual(try importer.importDoses(read, kind: .bolus).created, 0)
        XCTAssertEqual(try treatments(store).count, 1)
    }

    /// Rows downloaded from Nightscout have no identifier (reinstall, second phone): match them instead of creating duplicates.
    @MainActor
    func testRowFromNightscoutIsMatchedNotDuplicated() throws {
        let (importer, store, _) = makeImporter()
        let downloaded = storedRow(store, -40, 3)
        XCTAssertEqual(try importer.importDoses(result([dose(-60, 3)]), kind: .bolus).created, 0)
        XCTAssertEqual(try treatments(store).count, 1)
        XCTAssertEqual(downloaded.penDoseIdentifier, "EGDO2U:Open999940:3.0")
    }

    @MainActor
    func testTwoEqualDosesMatchTwoRows() throws {
        let (importer, store, _) = makeImporter()
        _ = storedRow(store, -60, 2)
        _ = storedRow(store, -30, 2)
        XCTAssertEqual(try importer.importDoses(result([dose(-25, 2), dose(-55, 2)]), kind: .bolus).created, 0)
        XCTAssertEqual(try treatments(store).count, 2)
    }

    /// One row cannot stand for two doses: the closer dose claims it, the other is created.
    @MainActor
    func testTwoEqualDosesOneRow() throws {
        let (importer, store, _) = makeImporter()
        let downloaded = storedRow(store, -60, 2)
        XCTAssertEqual(try importer.importDoses(result([dose(-30, 2), dose(-60, 2)]), kind: .bolus).created, 1)
        XCTAssertEqual(try treatments(store).count, 2)
        XCTAssertEqual(downloaded.penDoseIdentifier, "EGDO2U:Open999940:2.0")
    }

    @MainActor
    func testNightscoutSyncRequiredOnlyWhenRowsCreated() throws {
        let (importer, _, defaults) = makeImporter()
        defaults.nightscoutEnabled = true
        let read = result([dose(-60, 3)])
        XCTAssertEqual(try importer.importDoses(read, kind: .bolus).created, 1)
        XCTAssertTrue(defaults.nightscoutSyncRequired)
        defaults.nightscoutSyncRequired = false
        XCTAssertEqual(try importer.importDoses(read, kind: .bolus).created, 0)
        XCTAssertFalse(defaults.nightscoutSyncRequired)
    }

    @MainActor
    func testAirShotIgnored() throws {
        let (importer, store, defaults) = makeImporter()
        defaults.novoPenIgnoreAirShots = true
        XCTAssertEqual(try importer.importDoses(result([dose(-240, 6), dose(-300, 2)]), kind: .bolus).created, 1)
        let rows = try treatments(store)
        XCTAssertEqual(rows.map(\.treatmentType), [.Insulin])
        XCTAssertEqual(rows.map(\.value), [6.0])
    }

    @MainActor
    func testAirShotsKeptWhenSettingOff() throws {
        let (importer, store, _) = makeImporter()
        XCTAssertEqual(try importer.importDoses(result([dose(-240, 6), dose(-300, 2)]), kind: .bolus).created, 2)
        XCTAssertEqual(try treatments(store).map(\.treatmentType), [.Insulin, .Insulin])
    }

    @MainActor
    func testAirShotCandidateIsHeldBack() throws {
        let (importer, store, defaults) = makeImporter()
        defaults.novoPenIgnoreAirShots = true
        XCTAssertEqual(try importer.importDoses(result([dose(-30, 2)]), kind: .bolus), .init(created: 0, heldBack: 1))
        XCTAssertEqual(try treatments(store).count, 0)
    }

    @MainActor
    func testLoneSmallDoseImportedAfterWindow() throws {
        var clock = now
        let (importer, store, defaults) = makeImporter { clock }
        defaults.novoPenIgnoreAirShots = true
        let read = result([dose(-30, 2)])
        XCTAssertEqual(try importer.importDoses(read, kind: .bolus).created, 0)
        clock = now.addingTimeInterval(180)
        XCTAssertEqual(try importer.importDoses(read, kind: .bolus).created, 1)
        XCTAssertEqual(try treatments(store).map(\.treatmentType), [.Insulin])
    }

    @MainActor
    func testBasalWholeUnits() throws {
        let (importer, store, _) = makeImporter()
        XCTAssertEqual(try importer.importDoses(result([dose(-60, 14)]), kind: .basal).created, 1)
        let row = try XCTUnwrap(try treatments(store).first)
        XCTAssertEqual(row.treatmentType, .BasalInjection)
        XCTAssertEqual(row.value, 14)
        XCTAssertEqual(row.notes, "NovoPen EGDO2U")
        let uploaded = row.dictionaryRepresentationForNightscoutUpload()
        XCTAssertEqual(BasalInjectionPayload.decode(from: uploaded["notes"] as? String)?.units, 14)
    }

    @MainActor
    func testFractionalBasalDoseStoredAsNote() throws {
        let (importer, store, _) = makeImporter()
        XCTAssertEqual(try importer.importDoses(result([dose(-60, 7.5)]), kind: .basal).created, 1)
        let row = try XCTUnwrap(try treatments(store).first)
        XCTAssertEqual(row.treatmentType, .Note)
        XCTAssertEqual(row.value, 0)
        XCTAssertTrue(row.notes?.contains("7.5 U") == true, row.notes ?? "nil")
        XCTAssertEqual(row.penDoseIdentifier, "EGDO2U:Open999940:7.5")
        XCTAssertNil(row.dictionaryRepresentationForNightscoutUpload()["insulin"])
    }

    // MARK: - Scan flow

    @MainActor
    func testPenNotAddedImportsNothingAndSaysAddIt() async throws {
        var asked: Bool?
        let (model, store, _) = makeScanModel { isKnown in asked = isKnown("EGDO2U"); return self.result([]) }
        await model.scan()
        XCTAssertEqual(asked, false)
        XCTAssertEqual(try treatments(store).count, 0)
        XCTAssertEqual(model.state, .done(message: String(format: Texts_NovoPen.penNotAdded, "EGDO2U")))
    }

    @MainActor
    func testAddPenStoresKind() async {
        let defaults = UserDefaults(suiteName: #function)!
        defaults.removePersistentDomain(forName: #function)
        var shown: String?
        let provider = NovoPenSettingsProvider(defaults: defaults, readSerial: { self.result([]) })
        provider.storeMessageHandler { title, _ in shown = title }
        await provider.addPen(.basal)
        XCTAssertEqual(defaults.novoPenPenKinds["EGDO2U"], "basal")
        XCTAssertEqual(shown, String(format: Texts_NovoPen.penAdded, "EGDO2U", Texts_NovoPen.penKindBasal))
    }

    @MainActor
    func testKnownPenImportsDirectly() async throws {
        let (model, store, defaults) = makeScanModel { _ in self.result([self.dose(-60, 14)]) }
        defaults.novoPenPenKinds = ["EGDO2U": "basal"]
        await model.scan()
        XCTAssertEqual(model.state, .done(message: "Imported 1 dose"))
        XCTAssertEqual(try treatments(store).map(\.treatmentType), [.BasalInjection])
    }

    @MainActor
    func testIncompleteReadImportsAndSaysScanAgain() async throws {
        let (model, store, defaults) = makeScanModel { _ in self.result([self.dose(-60, 3)], completed: false) }
        defaults.novoPenPenKinds = ["EGDO2U": "bolus"]
        await model.scan()
        XCTAssertEqual(try treatments(store).count, 1)
        guard case .done(let message) = model.state else { return XCTFail("\(model.state)") }
        XCTAssertTrue(message.contains(Texts_NovoPen.readIncomplete), message)
    }

    @MainActor
    func testSkippedCountInMessage() async throws {
        let (model, _, defaults) = makeScanModel { _ in self.result([self.dose(-60, 3)], skipped: 2) }
        defaults.novoPenPenKinds = ["EGDO2U": "bolus"]
        await model.scan()
        guard case .done(let message) = model.state else { return XCTFail("\(model.state)") }
        XCTAssertTrue(message.contains(", skipped 2 error entries"), message)
        XCTAssertFalse(message.contains(Texts_NovoPen.readIncomplete), message)
    }

    @MainActor
    func testHeldBackDoseIsMentioned() async throws {
        let (model, _, defaults) = makeScanModel { _ in self.result([self.dose(-30, 2)]) }
        defaults.novoPenPenKinds = ["EGDO2U": "bolus"]
        defaults.novoPenIgnoreAirShots = true
        await model.scan()
        XCTAssertEqual(model.state, .done(message: "Imported 0 doses\n" + Texts_NovoPen.heldBackAirShot))
    }

    /// A double tap while the pen is being read: one read, no failure.
    @MainActor
    func testSecondScanWhileReadingIsIgnored() async throws {
        var reads = 0
        var resume: CheckedContinuation<Void, Never>?
        let (model, store, defaults) = makeScanModel { @MainActor _ in
            reads += 1
            if reads == 1 { await withCheckedContinuation { resume = $0 } }   // a second read would not hang the test
            return self.result([self.dose(-60, 3)])
        }
        defaults.novoPenPenKinds = ["EGDO2U": "bolus"]
        let first = Task { await model.scan() }
        while resume == nil { await Task.yield() }
        await model.scan()
        XCTAssertEqual(reads, 1)
        XCTAssertEqual(model.state, .idle)
        resume?.resume()
        await first.value
        XCTAssertEqual(model.state, .done(message: "Imported 1 dose"))
        XCTAssertEqual(try treatments(store).count, 1)
    }

    @MainActor
    func testReadErrorShowsScanFailed() async throws {
        let (model, store, _) = makeScanModel { _ in throw NovoPenError.truncated }
        await model.scan()
        XCTAssertEqual(model.state, .done(message: Texts_NovoPen.scanFailed))
        XCTAssertEqual(try treatments(store).count, 0)
        XCTAssertTrue(model.isShowingResult)
        model.isShowingResult = false
        XCTAssertEqual(model.state, .idle)
    }

    @MainActor
    func testCancelledScanReturnsToIdle() async throws {
        let (model, _, _) = makeScanModel { _ in throw CancellationError() }
        await model.scan()
        XCTAssertEqual(model.state, .idle)
    }

    // MARK: - Helpers

    @MainActor
    private func makeImporter(clock: (() -> Date)? = nil, name: String = #function) -> (NovoPenDoseImporter, CoreDataManager, UserDefaults) {
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        addTeardownBlock { defaults.removePersistentDomain(forName: name) }
        let store = CoreDataManager(inMemoryModelName: ConstantsCoreData.modelName)
        let fixed = now
        return (NovoPenDoseImporter(coreDataManager: store, defaults: defaults, now: clock ?? { fixed }), store, defaults)
    }

    /// A dose `offset` seconds from `now`; the relative time stays unique per offset.
    private func dose(_ offset: TimeInterval, _ units: Double) -> NovoPenDoseRecord {
        NovoPenDoseRecord(date: now.addingTimeInterval(offset), units: units, relativeTime: UInt32(1_000_000 + offset))
    }

    private func result(_ doses: [NovoPenDoseRecord], model: String = "Novo Nordisk A/S NovoPen", skipped: Int = 0, completed: Bool = true) -> NovoPenReadResult {
        NovoPenReadResult(serial: "EGDO2U", model: model, doses: doses, skipped: skipped, completed: completed)
    }

    @MainActor
    private func makeScanModel(name: String = #function, read: @escaping (_ isKnown: @escaping (String) -> Bool) async throws -> NovoPenReadResult) -> (NovoPenScanModel, CoreDataManager, UserDefaults) {
        let (importer, store, defaults) = makeImporter(name: name)
        return (NovoPenScanModel(importer: importer, defaults: defaults, read: read), store, defaults)
    }

    /// A pen row as Nightscout downloads it: Nightscout id, no `penDoseIdentifier`.
    @MainActor
    private func storedRow(_ store: CoreDataManager, _ offset: TimeInterval, _ units: Double) -> TreatmentEntry {
        let row = TreatmentEntry(id: UUID().uuidString + TreatmentType.Insulin.idExtension(), date: now.addingTimeInterval(offset), value: units,
                                 treatmentType: .Insulin, nightscoutEventType: "Correction Bolus", enteredBy: NovoPenDoseImporter.enteredBy,
                                 nsManagedObjectContext: store.mainManagedObjectContext)
        XCTAssertTrue(store.saveChangesSynchronously())
        return row
    }

    /// Newest first, as the pen's log.
    @MainActor
    private func treatments(_ store: CoreDataManager) throws -> [TreatmentEntry] {
        let request: NSFetchRequest<TreatmentEntry> = TreatmentEntry.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]
        return try store.mainManagedObjectContext.fetch(request)
    }

    // MARK: - Settings section

    func testAirShotDefaults() {
        let (_, defaults) = makeSettings()
        XCTAssertFalse(defaults.novoPenIgnoreAirShots)
        XCTAssertEqual(defaults.novoPenAirShotMaxUnits, 2.0)
        XCTAssertEqual(defaults.novoPenAirShotWindowMinutes, 2.0)
    }

    func testForgetPenRemovesKind() throws {
        let (provider, defaults) = makeSettings(enabled: true, kinds: ["A1": "bolus", "B2": "basal"])
        let row = try XCTUnwrap(provider.settingsRows(sectionID: 0).first { $0.id == "novoPen.pen.A1" })
        guard case let .menu(options, select)? = row.control else { return XCTFail("pen row is not a menu") }
        XCTAssertEqual(options().map(\.isSelected), [true, false, false])
        select?(1)
        XCTAssertEqual(defaults.novoPenPenKinds, ["A1": "basal", "B2": "basal"])
        select?(2)
        XCTAssertEqual(defaults.novoPenPenKinds, ["B2": "basal"])
    }

    func testRowIds() {
        let (provider, _) = makeSettings(enabled: true, kinds: ["B2": "basal", "A1": "bolus"])
        XCTAssertEqual(provider.settingsRows(sectionID: 0).map(\.id), [
            "novoPen.enabled", "novoPen.ignoreAirShots", "novoPen.airShotMaxUnits", "novoPen.airShotWindow", "novoPen.addPen",
            "novoPen.pen.A1", "novoPen.pen.B2"])
    }

    func testRowsAreHiddenWhileDisabledAndAirShotRowsWhileIgnoreIsOff() {
        let (provider, defaults) = makeSettings(kinds: ["A1": "bolus"])
        var rows = provider.settingsRows(sectionID: 0)
        XCTAssertEqual(rows.filter(\.isVisible).map(\.id), ["novoPen.enabled"])
        XCTAssertNil(provider.sectionFooter())

        defaults.novoPenEnabled = true
        rows = provider.settingsRows(sectionID: 0)
        XCTAssertTrue(rows.allSatisfy(\.isVisible))
        XCTAssertEqual(rows.filter { !$0.isEnabled }.map(\.id), ["novoPen.airShotMaxUnits", "novoPen.airShotWindow"])
        XCTAssertNotNil(provider.sectionFooter())

        defaults.novoPenIgnoreAirShots = true
        XCTAssertTrue(provider.settingsRows(sectionID: 0).allSatisfy(\.isEnabled))
    }

    func testAirShotMenusStoreTheChosenValue() throws {
        let (provider, defaults) = makeSettings(enabled: true)
        let rows = provider.settingsRows(sectionID: 0)
        guard case let .menu(maxOptions, selectMax)? = rows.first(where: { $0.id == "novoPen.airShotMaxUnits" })?.control,
              case let .menu(windowOptions, selectWindow)? = rows.first(where: { $0.id == "novoPen.airShotWindow" })?.control
        else { return XCTFail("air shot rows are not menus") }
        XCTAssertEqual(maxOptions().map(\.isSelected), [false, true, false, false])
        XCTAssertEqual(windowOptions().map(\.isSelected), [false, true, false, false])
        selectMax?(3)
        selectWindow?(2)
        XCTAssertEqual(defaults.novoPenAirShotMaxUnits, 4.0)
        XCTAssertEqual(defaults.novoPenAirShotWindowMinutes, 5.0)
    }

    private func makeSettings(enabled: Bool = false, kinds: [String: String] = [:], name: String = #function) -> (NovoPenSettingsProvider, UserDefaults) {
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        addTeardownBlock { defaults.removePersistentDomain(forName: name) }
        defaults.novoPenEnabled = enabled
        defaults.novoPenPenKinds = kinds
        return (NovoPenSettingsProvider(defaults: defaults), defaults)
    }

    // MARK: - Backup of TreatmentEntry.penDoseIdentifier

    @MainActor
    func testBackupRoundTripKeepsPenDoseIdentifier() async throws {
        let source = CoreDataManager(inMemoryModelName: ConstantsCoreData.modelName)
        let treatment = TreatmentEntry(date: now, value: 3, valueSecondary: 0, treatmentType: .Insulin,
            nightscoutEventType: "Correction Bolus", enteredBy: "xDrip4iOS NovoPen",
            nsManagedObjectContext: source.mainManagedObjectContext)
        treatment.penDoseIdentifier = "SERIAL1:Open331:3.0"
        XCTAssertTrue(source.saveChangesSynchronously())
        let exporter = BackupService(coreDataManager: source)
        let archive = try await exporter.createBackup(options: BackupOptions(
            includesSettings: false, includesAccounts: false, includesBgReadings: false, includesTreatments: true
        ))
        defer { try? FileManager.default.removeItem(at: archive.url) }
        let inspection = try exporter.inspectBackup(at: archive.url)
        XCTAssertEqual(inspection.payload.treatments.first?.penDoseIdentifier, "SERIAL1:Open331:3.0")

        let destination = CoreDataManager(inMemoryModelName: ConstantsCoreData.modelName)
        _ = try await BackupService(coreDataManager: destination).restore(
            inspection: inspection, mode: .keepCurrent, restoresSettings: false, restoredAccountCategories: [])
        let restored = try destination.mainManagedObjectContext.fetch(TreatmentEntry.fetchRequest())
        XCTAssertEqual(restored.count, 1)
        XCTAssertEqual(restored.first?.penDoseIdentifier, "SERIAL1:Open331:3.0")
    }

    func testOldBackupWithoutPenDoseIdentifierDecodes() throws {
        let treatment = BackupTreatment(
            careLinkSourceIdentifier: nil,
            penDoseIdentifier: "SERIAL1:Open0:2.0",
            date: now,
            enteredBy: "xDrip4iOS NovoPen",
            id: "",
            nightscoutEventType: nil,
            notes: nil,
            treatmentDeleted: false,
            treatmentType: TreatmentType.Insulin.rawValue,
            uploaded: false,
            value: 2,
            valueSecondary: 0
        )
        let encoded = try JSONEncoder().encode(treatment)
        XCTAssertEqual(try JSONDecoder().decode(BackupTreatment.self, from: encoded).penDoseIdentifier,
                       "SERIAL1:Open0:2.0")

        var legacyObject = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        legacyObject.removeValue(forKey: "penDoseIdentifier")
        let legacyData = try JSONSerialization.data(withJSONObject: legacyObject)
        XCTAssertNil(try JSONDecoder().decode(BackupTreatment.self, from: legacyData).penDoseIdentifier)
    }
}
