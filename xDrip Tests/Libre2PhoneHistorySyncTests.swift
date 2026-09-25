#if os(iOS)
import CoreData
import WatchConnectivity
import XCTest
@testable import xdrip

/// Hosted tests exercise the actual app model, parent-context saves and acknowledgement path.
@MainActor
final class Libre2PhoneHistorySyncTests: XCTestCase {
    private let uid = Data([1, 2, 3, 4, 5, 6, 7, 8])

    private final class ImportEvents: @unchecked Sendable {
        private let lock = NSLock()
        private var values: [Date?] = []
        var dates: [Date?] {
            lock.lock()
            defer { lock.unlock() }
            return values
        }
        func append(_ date: Date?) {
            lock.lock()
            defer { lock.unlock() }
            values.append(date)
        }
    }

    private func observe(_ sync: Libre2PhoneHistorySync, events: ImportEvents) -> NSObjectProtocol {
        NotificationCenter.default.addObserver(forName: Libre2PhoneHistorySync.didImport, object: sync, queue: .main) {
            events.append($0.userInfo?[Libre2PhoneHistoryUpdate.currentReadingDateKey] as? Date)
        }
    }

    private func fixture() async throws -> (CoreDataManager, Sensor, Libre2HistoryRegistry, Libre2HistoryReading) {
        let manager = CoreDataManager(inMemoryModelName: ConstantsCoreData.modelName)
        let sensor = Sensor(startDate: Date().addingTimeInterval(-3600), nsManagedObjectContext: manager.mainManagedObjectContext)
        let sample = Libre2HistoryReading(sessionID: UUID(), sensorUID: uid, sensorMinute: 100,
                                          date: Date().addingTimeInterval(-600), glucose: 650)
        let registry = Libre2HistoryRegistry(entries: [
            .init(sessionID: sample.sessionID, sensorUID: uid, sensorID: sensor.id,
                  preparedAt: sample.date.addingTimeInterval(-60))
        ]) { _ in }
        try manager.mainManagedObjectContext.save()
        let store = manager.privateManagedObjectContext
        try await store.perform { try store.save() }
        return (manager, sensor, registry, sample)
    }

    private func send(_ batch: Libre2HistoryBatch, to sync: Libre2PhoneHistorySync) async throws -> [String: Any] {
        let message = try batch.dictionary
        return await withCheckedContinuation { continuation in
            XCTAssertTrue(sync.receive(message) { continuation.resume(returning: $0) })
        }
    }

    private struct SavedReading {
        let id: String
        let calculatedValue: Double
        let sensorID: String?
        let backfilledAt: Date?
        let calibrationID: NSManagedObjectID?
        let slope: Double
        let hideSlope: Bool
    }

    private func diskReadings(_ manager: CoreDataManager) throws -> [SavedReading] {
        let context = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        context.persistentStoreCoordinator = manager.privateManagedObjectContext.persistentStoreCoordinator
        return try context.fetch(BgReading.fetchRequest()).map {
            SavedReading(id: $0.id, calculatedValue: $0.calculatedValue, sensorID: $0.sensor?.id,
                         backfilledAt: $0.backfilledAt, calibrationID: $0.calibration?.objectID,
                         slope: $0.calculatedValueSlope, hideSlope: $0.hideSlope)
        }
    }

    func testDuplicateBatchIsAcknowledgedOnlyAfterValuesReachPersistentStore() async throws {
        let (manager, _, registry, sample) = try await fixture()
        let sync = Libre2PhoneHistorySync(coreDataManager: manager, session: .default, registry: registry)
        let batch = Libre2HistoryBatch(readings: [sample])
        for _ in 0..<2 {
            let reply = try await send(batch, to: sync)
            XCTAssertEqual(try Libre2HistoryAcknowledgement.decode(reply).batchID, batch.id)
            let readings = try diskReadings(manager)
            XCTAssertEqual(readings.count, 1)
            XCTAssertEqual(readings.first?.calculatedValue, 650)
            XCTAssertEqual(readings.first?.id, sample.id)
            XCTAssertNotNil(readings.first?.backfilledAt)
            XCTAssertNil(readings.first?.calibrationID)
        }
    }

    func testLatestImportPrecedesWaitingHistoryAndCoalescesPendingLiveMessages() async throws {
        let wasMaster = UserDefaults.standard.isMaster
        UserDefaults.standard.isMaster = true
        defer { UserDefaults.standard.isMaster = wasMaster }
        let (manager, _, registry, old) = try await fixture()
        let backlog = Libre2HistoryReading(sessionID: old.sessionID, sensorUID: uid, sensorMinute: 101,
            date: old.date.addingTimeInterval(60), glucose: 120)
        let earlier = Libre2HistoryReading(sessionID: old.sessionID, sensorUID: uid, sensorMinute: 109,
            date: Date().addingTimeInterval(-65), glucose: 123)
        let latest = Libre2HistoryReading(sessionID: old.sessionID, sensorUID: uid, sensorMinute: 110,
            date: Date().addingTimeInterval(-5), glucose: 125)
        let sync = Libre2PhoneHistorySync(coreDataManager: manager, session: .default, registry: registry)
        let events = ImportEvents()
        let observer = observe(sync, events: events)
        defer { NotificationCenter.default.removeObserver(observer) }
        let replies = expectation(description: "All queued messages answered")
        replies.expectedFulfillmentCount = 4
        var savedOrder: [String] = []
        for (reading, live) in [(old, false), (backlog, false), (earlier, true), (latest, true)] {
            let batch = Libre2HistoryBatch(readings: [reading])
            let message = try live ? batch.latestDictionary : batch.dictionary
            XCTAssertTrue(sync.receive(message) { reply in
                if reading == earlier {
                    XCTAssertEqual(reply["superseded"] as? Bool, true)
                    XCTAssertNil(reply[Libre2HistoryAcknowledgement.key])
                } else {
                    XCTAssertEqual(try? Libre2HistoryAcknowledgement.decode(reply).batchID, batch.id)
                    savedOrder.append(reading.id)
                    // A reply must follow the durable save, including on the live route.
                    XCTAssertTrue((try? self.diskReadings(manager).contains { $0.id == reading.id }) == true)
                }
                replies.fulfill()
            })
        }
        await fulfillment(of: [replies], timeout: 5)
        XCTAssertEqual(savedOrder, [old.id, latest.id, backlog.id])
        XCTAssertEqual(events.dates.compactMap { $0 }, [latest.date])

        // Normal history later fills the superseded minute and deduplicates the live value.
        _ = try await send(Libre2HistoryBatch(readings: [old, backlog, earlier, latest]), to: sync)
        XCTAssertEqual(try diskReadings(manager).count, 4)
        XCTAssertEqual(events.dates.compactMap { $0 }, [latest.date])
    }

    func testLatestMessageRetainsSensorValidationAndSaveFailureRules() async throws {
        let (manager, _, registry, sample) = try await fixture()
        let batch = Libre2HistoryBatch(readings: [sample])
        let message = try batch.latestDictionary
        for unknownSensor in [true, false] {
            let sync = Libre2PhoneHistorySync(coreDataManager: manager, session: .default,
                registry: unknownSensor ? Libre2HistoryRegistry { _ in } : registry,
                beforeStoreSave: { throw Libre2HistoryError.unavailable })
            let reply: [String: Any] = await withCheckedContinuation { continuation in
                XCTAssertTrue(sync.receive(message) { continuation.resume(returning: $0) })
            }
            XCTAssertNil(reply[Libre2HistoryAcknowledgement.key])
            XCTAssertNotNil(reply["error"])
            XCTAssertTrue(try diskReadings(manager).isEmpty)
        }
    }

    func testFinalSaveFailureWithholdsAcknowledgementAndDuplicateRetryStillSaves() async throws {
        let (manager, _, registry, sample) = try await fixture()
        let failing = Libre2PhoneHistorySync(coreDataManager: manager, session: .default, registry: registry,
            beforeStoreSave: { throw Libre2HistoryError.unavailable })
        let batch = Libre2HistoryBatch(readings: [sample])
        let failedReply = try await send(batch, to: failing)
        XCTAssertNil(failedReply[Libre2HistoryAcknowledgement.key])
        XCTAssertNotNil(failedReply["error"])
        XCTAssertTrue(try diskReadings(manager).isEmpty)

        let retry = Libre2PhoneHistorySync(coreDataManager: manager, session: .default, registry: registry)
        let reply = try await send(batch, to: retry)
        XCTAssertEqual(try Libre2HistoryAcknowledgement.decode(reply).batchID, batch.id)
        XCTAssertEqual(try diskReadings(manager).count, 1)
    }

    func testDelayedReadingsRemainAttachedToOriginalEndedSensor() async throws {
        let (manager, original, registry, sample) = try await fixture()
        original.endDate = Date().addingTimeInterval(-300)
        _ = Sensor(startDate: Date().addingTimeInterval(-240), nsManagedObjectContext: manager.mainManagedObjectContext)
        let sync = Libre2PhoneHistorySync(coreDataManager: manager, session: .default, registry: registry)
        _ = try await send(Libre2HistoryBatch(readings: [sample]), to: sync)
        XCTAssertEqual(try diskReadings(manager).first?.sensorID, original.id)
    }

    func testUnknownSessionDoesNotImportOrAcknowledge() async throws {
        let (manager, _, _, sample) = try await fixture()
        let sync = Libre2PhoneHistorySync(coreDataManager: manager, session: .default,
                                         registry: Libre2HistoryRegistry { _ in })
        let reply = try await send(Libre2HistoryBatch(readings: [sample]), to: sync)
        XCTAssertNil(reply[Libre2HistoryAcknowledgement.key])
        XCTAssertEqual(try Libre2HistoryRejection.decode(reply).readingIDs, [sample.id])
        XCTAssertTrue(try diskReadings(manager).isEmpty)
    }

    func testDeletedSensorInMixedBatchDoesNotBlockReplacementSensorUpload() async throws {
        let (manager, original, registry, old) = try await fixture()
        let replacement = Sensor(startDate: Date().addingTimeInterval(-3600), nsManagedObjectContext: manager.mainManagedObjectContext)
        let sample = Libre2HistoryReading(sessionID: UUID(), sensorUID: Data(repeating: 9, count: 8),
            sensorMinute: 100, date: old.date, glucose: 120)
        let mappings = Libre2HistoryRegistry(entries: registry.entries + [
            .init(sessionID: sample.sessionID, sensorUID: sample.sensorUID, sensorID: replacement.id,
                  preparedAt: sample.date.addingTimeInterval(-60))
        ]) { _ in }
        manager.mainManagedObjectContext.delete(original)
        try manager.mainManagedObjectContext.save()
        let store = manager.privateManagedObjectContext
        try await store.perform { try store.save() }
        let sync = Libre2PhoneHistorySync(coreDataManager: manager, session: .default, registry: mappings)
        let queue = Libre2HistoryQueue { _ in }
        try queue.append(old)
        try queue.append(sample)
        let mixed = try XCTUnwrap(queue.nextBatch())
        let reply = try await send(mixed, to: sync)
        XCTAssertNil(reply[Libre2HistoryAcknowledgement.key])
        XCTAssertTrue(try diskReadings(manager).isEmpty)
        let rejection = try Libre2HistoryRejection.decode(reply)
        XCTAssertEqual(rejection.batchID, mixed.id)
        XCTAssertEqual(rejection.readingIDs, [old.id])
        try queue.retainUnresolved(rejection)
        let next = try XCTUnwrap(queue.nextBatch())
        XCTAssertEqual(next.readings, [sample])
        let saved = try await send(next, to: sync)
        try queue.acknowledge(Libre2HistoryAcknowledgement.decode(saved))
        XCTAssertEqual(try diskReadings(manager).first?.sensorID, replacement.id)
        XCTAssertNil(try queue.nextBatch())
        XCTAssertEqual(queue.state.unresolved, [old])
    }

    func testUnknownSessionInMixedBatchRejectsOnlyUnmatchedReadings() async throws {
        let (manager, _, registry, known) = try await fixture()
        let unknown = Libre2HistoryReading(sessionID: UUID(), sensorUID: Data(repeating: 9, count: 8),
            sensorMinute: 100, date: known.date, glucose: 120)
        let sync = Libre2PhoneHistorySync(coreDataManager: manager, session: .default, registry: registry)
        let reply = try await send(Libre2HistoryBatch(readings: [unknown, known]), to: sync)
        XCTAssertNil(reply[Libre2HistoryAcknowledgement.key])
        XCTAssertEqual(try Libre2HistoryRejection.decode(reply).readingIDs, [unknown.id])
        XCTAssertTrue(try diskReadings(manager).isEmpty)
        let saved = try await send(Libre2HistoryBatch(readings: [known]), to: sync)
        XCTAssertNotNil(saved[Libre2HistoryAcknowledgement.key])
        XCTAssertEqual(try diskReadings(manager).count, 1)
    }

    func testPhoneOverlapIsPreservedButDistinctWatchMinutesAreNotSuppressed() async throws {
        let (manager, sensor, registry, sample) = try await fixture()
        let phone = BgReading(timeStamp: sample.date, sensor: sensor, calibration: nil, rawData: 120,
                              deviceName: "Libre 2", nsManagedObjectContext: manager.mainManagedObjectContext)
        phone.calculatedValue = 120
        try manager.mainManagedObjectContext.save()
        let second = Libre2HistoryReading(sessionID: sample.sessionID, sensorUID: uid, sensorMinute: 101,
                                          date: sample.date.addingTimeInterval(60), glucose: 125)
        let third = Libre2HistoryReading(sessionID: sample.sessionID, sensorUID: uid, sensorMinute: 102,
                                         date: sample.date.addingTimeInterval(80), glucose: 126)
        let sync = Libre2PhoneHistorySync(coreDataManager: manager, session: .default, registry: registry)
        let batch = Libre2HistoryBatch(readings: [sample, second, third])
        _ = try await send(batch, to: sync)
        let readings = try diskReadings(manager)
        XCTAssertEqual(readings.count, 3)
        XCTAssertEqual(readings.first(where: { $0.id == phone.id })?.calculatedValue, 120)
        XCTAssertNil(readings.first(where: { $0.id == sample.id }))
        XCTAssertNotNil(readings.first(where: { $0.id == second.id }))
        XCTAssertNotNil(readings.first(where: { $0.id == third.id }))
    }

    func testCurrentImportPublishesOnceAfterSaveAndDoesNotMarkImmediateDeliveryAsBackfill() async throws {
        let wasMaster = UserDefaults.standard.isMaster
        UserDefaults.standard.isMaster = true
        defer { UserDefaults.standard.isMaster = wasMaster }
        let (manager, _, registry, old) = try await fixture()
        let sample = Libre2HistoryReading(sessionID: old.sessionID, sensorUID: uid, sensorMinute: 110,
                                          date: Date().addingTimeInterval(-5), glucose: 125)
        let sync = Libre2PhoneHistorySync(coreDataManager: manager, session: .default, registry: registry)
        let events = ImportEvents()
        let observer = observe(sync, events: events)
        defer { NotificationCenter.default.removeObserver(observer) }
        let batch = Libre2HistoryBatch(readings: [old, sample])
        _ = try await send(batch, to: sync)
        XCTAssertEqual(events.dates.count, 1)
        XCTAssertEqual(events.dates[0], sample.date)
        let saved = try diskReadings(manager)
        XCTAssertNotNil(saved.first(where: { $0.id == old.id })?.backfilledAt)
        XCTAssertNil(saved.first(where: { $0.id == sample.id })?.backfilledAt)
        _ = try await send(batch, to: sync)
        XCTAssertEqual(events.dates.count, 2)
        XCTAssertNil(events.dates[1])
    }

    func testSaveFailureCannotAnnounceCurrentReadingAndRetryCan() async throws {
        let wasMaster = UserDefaults.standard.isMaster
        UserDefaults.standard.isMaster = true
        defer { UserDefaults.standard.isMaster = wasMaster }
        let (manager, _, registry, old) = try await fixture()
        let sample = Libre2HistoryReading(sessionID: old.sessionID, sensorUID: uid, sensorMinute: 110,
                                          date: Date().addingTimeInterval(-10), glucose: 125)
        let sync = Libre2PhoneHistorySync(coreDataManager: manager, session: .default, registry: registry,
            beforeStoreSave: { throw Libre2HistoryError.unavailable })
        let events = ImportEvents()
        let observer = observe(sync, events: events)
        defer { NotificationCenter.default.removeObserver(observer) }
        let batch = Libre2HistoryBatch(readings: [sample])
        let failed = try await send(batch, to: sync)
        XCTAssertNotNil(failed["error"])
        XCTAssertTrue(events.dates.isEmpty)
        let retry = Libre2PhoneHistorySync(coreDataManager: manager, session: .default, registry: registry)
        let retryObserver = observe(retry, events: events)
        defer { NotificationCenter.default.removeObserver(retryObserver) }
        _ = try await send(batch, to: retry)
        XCTAssertEqual(events.dates.count, 1)
        XCTAssertEqual(events.dates[0], sample.date)
    }

    func testStaleEndedSensorAndSupersededReadingsOnlyRefreshHistory() async throws {
        let wasMaster = UserDefaults.standard.isMaster
        UserDefaults.standard.isMaster = true
        defer { UserDefaults.standard.isMaster = wasMaster }
        let (manager, sensor, registry, old) = try await fixture()
        let sync = Libre2PhoneHistorySync(coreDataManager: manager, session: .default, registry: registry)
        let events = ImportEvents()
        let observer = observe(sync, events: events)
        defer { NotificationCenter.default.removeObserver(observer) }
        _ = try await send(Libre2HistoryBatch(readings: [old]), to: sync)

        let phone = BgReading(timeStamp: Date(), sensor: sensor, calibration: nil, rawData: 130,
                              deviceName: "Libre 2", nsManagedObjectContext: manager.mainManagedObjectContext)
        phone.calculatedValue = 130
        let superseded = Libre2HistoryReading(sessionID: old.sessionID, sensorUID: uid, sensorMinute: 109,
                                              date: Date().addingTimeInterval(-60), glucose: 125)
        _ = try await send(Libre2HistoryBatch(readings: [superseded]), to: sync)
        manager.mainManagedObjectContext.delete(phone)
        sensor.endDate = Date()
        let ended = Libre2HistoryReading(sessionID: old.sessionID, sensorUID: uid, sensorMinute: 110,
                                         date: Date().addingTimeInterval(-5), glucose: 126)
        _ = try await send(Libre2HistoryBatch(readings: [ended]), to: sync)
        XCTAssertEqual(events.dates.count, 3)
        XCTAssertTrue(events.dates.allSatisfy { $0 == nil })
    }

    func testUnsortedImportStoresSlopesAndRepairsExistingPhoneSuccessor() async throws {
        let (manager, sensor, registry, first) = try await fixture()
        let second = Libre2HistoryReading(sessionID: first.sessionID, sensorUID: uid, sensorMinute: 101,
            date: first.date.addingTimeInterval(60), glucose: 125)
        let phone = BgReading(timeStamp: first.date.addingTimeInterval(120), sensor: sensor, calibration: nil,
            rawData: 130, deviceName: "Libre 2", nsManagedObjectContext: manager.mainManagedObjectContext)
        phone.calculatedValue = 130
        phone.hideSlope = true
        try manager.mainManagedObjectContext.save()
        let sync = Libre2PhoneHistorySync(coreDataManager: manager, session: .default, registry: registry)
        let batch = Libre2HistoryBatch(readings: [second, first])
        for _ in 0..<2 {
            _ = try await send(batch, to: sync)
            let saved = try diskReadings(manager)
            XCTAssertEqual(saved.count, 3)
            XCTAssertTrue(try XCTUnwrap(saved.first { $0.id == first.id }).hideSlope)
            let middle = try XCTUnwrap(saved.first { $0.id == second.id })
            XCTAssertFalse(middle.hideSlope)
            XCTAssertEqual(middle.slope, (125 - 650) / 60_000.0, accuracy: 0.00000001)
            let successor = try XCTUnwrap(saved.first { $0.id == phone.id })
            XCTAssertFalse(successor.hideSlope)
            XCTAssertEqual(successor.slope, 5 / 60_000.0, accuracy: 0.00000001)
        }
    }

    func testSlopeCalculationRespectsSensorIdentityGapsAndSuppressedReadings() async throws {
        let (manager, sensor, _, sample) = try await fixture()
        let context = manager.mainManagedObjectContext
        let other = Sensor(startDate: sample.date, nsManagedObjectContext: context)
        func row(_ seconds: Double, _ value: Double, _ owner: Sensor) -> BgReading {
            let reading = BgReading(timeStamp: sample.date.addingTimeInterval(seconds), sensor: owner,
                calibration: nil, rawData: value, deviceName: "Libre 2", nsManagedObjectContext: context)
            reading.calculatedValue = value
            return reading
        }
        _ = row(0, 100, sensor)
        let suppressed = row(30, 250, sensor)
        suppressed.isSuppressedByFiveMinuteCadence = true
        _ = row(50, 300, other)
        let visible = row(60, 106, sensor)
        let gap = row(60 + 22 * 60, 120, sensor)
        _ = try Libre2PhoneReadingProcessing.updateSlopes(sensorIDs: [sensor.id], from: sample.date,
            to: gap.timeStamp, context: context)
        XCTAssertEqual(visible.calculatedValueSlope, 6 / 60_000.0, accuracy: 0.00000001)
        XCTAssertFalse(visible.hideSlope)
        XCTAssertEqual(gap.calculatedValueSlope, 0)
        XCTAssertTrue(gap.hideSlope)
        XCTAssertTrue(try Libre2PhoneReadingProcessing.updateSlopes(sensorIDs: [sensor.id], from: sample.date,
            to: gap.timeStamp, context: context).isEmpty)
    }

    func testCurrentReadingRecheckRejectsSuppressedSupersededFutureAndEndedSensorValues() async throws {
        let wasMaster = UserDefaults.standard.isMaster
        UserDefaults.standard.isMaster = true
        defer { UserDefaults.standard.isMaster = wasMaster }
        let (manager, sensor, _, _) = try await fixture()
        let now = Date()
        let reading = BgReading(timeStamp: now.addingTimeInterval(-10), sensor: sensor, calibration: nil,
            rawData: 120, deviceName: "Libre 2 Watch", nsManagedObjectContext: manager.mainManagedObjectContext)
        reading.calculatedValue = 120
        XCTAssertTrue(Libre2PhoneReadingProcessing.isCurrentReading(reading.timeStamp, coreDataManager: manager, now: now))
        reading.isSuppressedByFiveMinuteCadence = true
        XCTAssertFalse(Libre2PhoneReadingProcessing.isCurrentReading(reading.timeStamp, coreDataManager: manager, now: now))
        reading.isSuppressedByFiveMinuteCadence = false
        XCTAssertFalse(Libre2PhoneReadingProcessing.isCurrentReading(now.addingTimeInterval(-60), coreDataManager: manager, now: now))
        XCTAssertFalse(Libre2PhoneReadingProcessing.isCurrentReading(reading.timeStamp, coreDataManager: manager,
            now: now.addingTimeInterval(600)))
        reading.timeStamp = now.addingTimeInterval(60)
        XCTAssertFalse(Libre2PhoneReadingProcessing.isCurrentReading(reading.timeStamp, coreDataManager: manager, now: now))
        reading.timeStamp = now.addingTimeInterval(-10)
        sensor.endDate = now
        XCTAssertFalse(Libre2PhoneReadingProcessing.isCurrentReading(reading.timeStamp, coreDataManager: manager, now: now))
    }

}
#endif
