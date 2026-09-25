import XCTest
@testable import xdrip

final class Libre2HistoryTests: XCTestCase {
    private let sessionID = UUID()
    private let uid = Data([1, 2, 3, 4, 5, 6, 7, 8])
    private let now = Date().addingTimeInterval(-600)

    private func reading(_ minute: UInt16 = 100, session: UUID? = nil, glucose: Double = 120) -> Libre2HistoryReading {
        Libre2HistoryReading(sessionID: session ?? sessionID, sensorUID: uid, sensorMinute: minute,
                             date: now.addingTimeInterval(Double(Int(minute) - 100) * 60), glucose: glucose)
    }

    func testBackgroundReservationSurvivesRestartWithoutAcknowledgingReadings() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("queue.json")
        let queue = try Libre2HistoryQueue(url: url)
        try queue.append(reading())
        let batch = try XCTUnwrap(queue.nextBatch())
        XCTAssertTrue(try queue.reserveBackgroundTransfer(batchID: batch.id, at: now))
        let restarted = try Libre2HistoryQueue(url: url)
        XCTAssertEqual(restarted.state.pending, [reading()])
        XCTAssertEqual(restarted.state.batch, batch)
        XCTAssertFalse(restarted.canRetryBackgroundTransfer(at: now.addingTimeInterval(299)))
        XCTAssertTrue(restarted.canRetryBackgroundTransfer(at: now.addingTimeInterval(300)))
    }

    func testBackgroundReservationFailureAndStaleBatchCannotChangeJournal() throws {
        var fail = false
        let queue = Libre2HistoryQueue { _ in if fail { throw Libre2HistoryError.unavailable } }
        try queue.append(reading())
        let batch = try XCTUnwrap(queue.nextBatch())
        let before = queue.state
        XCTAssertThrowsError(try queue.reserveBackgroundTransfer(batchID: UUID(), at: now))
        fail = true
        XCTAssertThrowsError(try queue.reserveBackgroundTransfer(batchID: batch.id, at: now))
        XCTAssertEqual(queue.state, before)
        fail = false
        XCTAssertTrue(try queue.reserveBackgroundTransfer(batchID: batch.id, at: now))
        fail = true
        XCTAssertThrowsError(try queue.acknowledge(Libre2HistoryAcknowledgement(batch: batch)))
        XCTAssertEqual(queue.state.lastBackgroundSubmission, now)
        XCTAssertEqual(queue.state.pending, before.pending)
    }

    func testResolvingBatchReleasesReservationButStaleResponsesCannotReleaseTheNextOne() throws {
        for reject in [false, true] {
            let queue = Libre2HistoryQueue { _ in }
            try queue.append(reading())
            let first = try XCTUnwrap(queue.nextBatch())
            XCTAssertTrue(try queue.reserveBackgroundTransfer(batchID: first.id, at: now))
            try queue.append(reading(101))
            if reject {
                try queue.retainUnresolved(.init(batchID: first.id, readingIDs: first.readings.map(\.id)))
            } else {
                try queue.acknowledge(Libre2HistoryAcknowledgement(batch: first))
            }
            XCTAssertNil(queue.state.lastBackgroundSubmission)
            let next = try XCTUnwrap(queue.nextBatch())
            XCTAssertTrue(try queue.reserveBackgroundTransfer(batchID: next.id, at: now))
            XCTAssertThrowsError(try queue.acknowledge(Libre2HistoryAcknowledgement(batch: first)))
            XCTAssertEqual(queue.state.batch, next)
            XCTAssertEqual(queue.state.lastBackgroundSubmission, now)
        }
    }

    func testUnsubmittedBatchAndClockCorrectionDoNotStrandBackgroundRetries() throws {
        let queue = Libre2HistoryQueue { _ in }
        try queue.append(reading())
        let batch = try XCTUnwrap(queue.nextBatch())
        let restored = Libre2HistoryQueue(state: try JSONDecoder().decode(Libre2HistoryQueue.State.self,
            from: JSONEncoder().encode(queue.state))) { _ in }
        XCTAssertTrue(restored.canRetryBackgroundTransfer(at: now))
        XCTAssertTrue(try restored.reserveBackgroundTransfer(batchID: batch.id, at: now))
        let corrected = now.addingTimeInterval(-3600)
        XCTAssertTrue(try restored.reserveBackgroundTransfer(batchID: batch.id, at: corrected))
        XCTAssertFalse(restored.canRetryBackgroundTransfer(at: corrected.addingTimeInterval(1)))
    }

    func testBatchRoundTripContainsConvertedValueWithoutDisplayClamping() throws {
        let batch = Libre2HistoryBatch(readings: [reading(glucose: 650)])
        XCTAssertEqual(try Libre2HistoryBatch.decode(batch.dictionary), batch)
        let data = try XCTUnwrap(batch.dictionary[Libre2HistoryBatch.key] as? Data)
        let text = try XCTUnwrap(String(data: data, encoding: .utf8))
        XCTAssertFalse(text.contains("unlock"))
        XCTAssertFalse(text.contains("calibration"))
    }

    func testInvalidReadingsAndOversizedBatchesAreRejected() throws {
        for glucose in [0, -1, .nan, .infinity, 3000.0] {
            XCTAssertThrowsError(try reading(glucose: glucose).validate())
        }
        XCTAssertThrowsError(try Libre2HistoryBatch(readings: []).validate())
        XCTAssertThrowsError(try Libre2HistoryBatch(readings: (100...220).map { reading(UInt16($0)) }).validate())
        XCTAssertThrowsError(try Libre2HistoryBatch(readings: [reading(), reading()]).validate())
        XCTAssertThrowsError(try Libre2HistoryBatch.decode([Libre2HistoryBatch.key: Data(count: 100_001)]))
        let future = Libre2HistoryReading(sessionID: sessionID, sensorUID: uid, sensorMinute: 100,
                                         date: Date().addingTimeInterval(600), glucose: 100)
        XCTAssertThrowsError(try future.validate())
    }

    func testLatestMessageUsesTheExistingValidatedBatchFormat() throws {
        let batch = Libre2HistoryBatch(readings: [reading()])
        let message = try batch.latestDictionary
        XCTAssertEqual(message[Libre2HistoryBatch.latestKey] as? Bool, true)
        XCTAssertEqual(try Libre2HistoryBatch.decode(message), batch)
        XCTAssertThrowsError(try Libre2HistoryBatch(readings: [reading(), reading(101)]).latestDictionary)
        var invalid = try Libre2HistoryBatch(readings: [reading(), reading(101)]).dictionary
        invalid[Libre2HistoryBatch.latestKey] = true
        XCTAssertThrowsError(try Libre2HistoryBatch.decode(invalid))
        invalid = try batch.dictionary
        invalid[Libre2HistoryBatch.latestKey] = "true"
        XCTAssertThrowsError(try Libre2HistoryBatch.decode(invalid))
    }

    func testLatestAcknowledgementCannotRemoveDurableHistory() throws {
        let queue = Libre2HistoryQueue { _ in }
        try queue.append(reading())
        let history = try XCTUnwrap(queue.nextBatch())
        let latest = Libre2HistoryBatch(readings: history.readings)
        XCTAssertThrowsError(try queue.acknowledge(Libre2HistoryAcknowledgement(batch: latest)))
        XCTAssertEqual(queue.state.batch, history)
        XCTAssertEqual(queue.state.pending, history.readings)
    }

    func testAppendFailureDoesNotAdvanceMinuteOrLoseRetry() throws {
        var fail = true
        let queue = Libre2HistoryQueue { _ in if fail { throw Libre2HistoryError.unavailable } }
        XCTAssertThrowsError(try queue.append(reading()))
        XCTAssertTrue(queue.state.pending.isEmpty)
        XCTAssertTrue(queue.state.lastCollectedMinute.isEmpty)
        fail = false
        try queue.append(reading())
        XCTAssertEqual(queue.state.pending.count, 1)
    }

    func testBatchIsPersistedBeforeItCanBeSent() throws {
        var disk = Libre2HistoryQueue.State()
        let queue = Libre2HistoryQueue { disk = $0 }
        try queue.append(reading())
        let batch = try XCTUnwrap(queue.nextBatch())
        XCTAssertEqual(disk.batch, batch)
        let restarted = Libre2HistoryQueue(state: disk) { disk = $0 }
        XCTAssertEqual(try restarted.nextBatch(), batch)
    }

    func testFailedBatchPersistenceDoesNotExposeAnUntrackedTransfer() throws {
        var fail = false
        let queue = Libre2HistoryQueue { _ in if fail { throw Libre2HistoryError.unavailable } }
        try queue.append(reading())
        fail = true
        XCTAssertThrowsError(try queue.nextBatch())
        XCTAssertNil(queue.state.batch)
        XCTAssertEqual(queue.state.pending.count, 1)
    }

    func testAcknowledgementOnlyRemovesItsImmutableBatch() throws {
        let queue = Libre2HistoryQueue { _ in }
        try queue.append(reading())
        let first = try XCTUnwrap(queue.nextBatch())
        try queue.append(reading(101))
        XCTAssertEqual(try queue.nextBatch(), first)
        try queue.acknowledge(Libre2HistoryAcknowledgement(batch: first))
        XCTAssertEqual(queue.state.pending, [reading(101)])
        let second = try XCTUnwrap(queue.nextBatch())
        XCTAssertThrowsError(try queue.acknowledge(Libre2HistoryAcknowledgement(batch: first)))
        XCTAssertEqual(try queue.nextBatch(), second)
    }

    func testAcknowledgementMustMatchBothBatchIDAndReadingIDs() throws {
        let queue = Libre2HistoryQueue { _ in }
        try queue.append(reading())
        let batch = try XCTUnwrap(queue.nextBatch())
        let malformed: [String: Any] = ["batchID": batch.id.uuidString, "readingIDs": ["unrelated"]]
        let ack = try JSONDecoder().decode(Libre2HistoryAcknowledgement.self,
                                           from: JSONSerialization.data(withJSONObject: malformed))
        XCTAssertThrowsError(try queue.acknowledge(ack))
        XCTAssertEqual(queue.state.pending.count, 1)
    }

    func testAcknowledgementSaveFailureKeepsReadingsForRetry() throws {
        var fail = false
        let queue = Libre2HistoryQueue { _ in if fail { throw Libre2HistoryError.unavailable } }
        try queue.append(reading())
        let batch = try XCTUnwrap(queue.nextBatch())
        fail = true
        XCTAssertThrowsError(try queue.acknowledge(Libre2HistoryAcknowledgement(batch: batch)))
        XCTAssertEqual(queue.state.batch, batch)
        XCTAssertEqual(queue.state.pending.count, 1)
    }

    func testSameSensorMinuteIsNotRecollectedAfterAcknowledgementOrHandoff() throws {
        var disk = Libre2HistoryQueue.State()
        let queue = Libre2HistoryQueue { disk = $0 }
        try queue.append(reading())
        try queue.acknowledge(Libre2HistoryAcknowledgement(batch: XCTUnwrap(queue.nextBatch())))
        let restarted = Libre2HistoryQueue(state: disk) { disk = $0 }
        try restarted.append(reading(session: UUID()))
        try restarted.append(reading(99))
        XCTAssertTrue(restarted.state.pending.isEmpty)
        try restarted.append(reading(101, session: UUID()))
        XCTAssertEqual(restarted.state.pending.count, 1)
    }

    func testLargeOfflineQueueDrainsInBoundedBatchesWithoutDroppingData() throws {
        let queue = Libre2HistoryQueue { _ in }
        let start = Date().addingTimeInterval(-30_000)
        for minute in 100..<401 {
            try queue.append(Libre2HistoryReading(sessionID: sessionID, sensorUID: uid, sensorMinute: UInt16(minute),
                date: start.addingTimeInterval(Double(minute) * 60), glucose: 100))
        }
        var counts: [Int] = []
        while let batch = try queue.nextBatch() {
            counts.append(batch.readings.count)
            try queue.acknowledge(Libre2HistoryAcknowledgement(batch: batch))
        }
        XCTAssertEqual(counts, [120, 120, 61])
    }

    func testFileRoundTripAndCorruptionNeverSilentlyClearsOutbox() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("queue.json")
        let queue = try Libre2HistoryQueue(url: url)
        try queue.append(reading())
        let batch = try queue.nextBatch()
        XCTAssertEqual(try Libre2HistoryQueue(url: url).nextBatch(), batch)
        let corrupt = Data("broken".utf8)
        try corrupt.write(to: url)
        XCTAssertThrowsError(try Libre2HistoryQueue(url: url))
        XCTAssertEqual(try Data(contentsOf: url), corrupt)
    }

    func testRegistryRetainsOriginalSensorAcrossReplacementAndRejectsUnknownSession() throws {
        let old = Libre2HistoryRegistry.Entry(sessionID: sessionID, sensorUID: uid,
                                              sensorID: "original-phone-sensor", preparedAt: now)
        let replacement = Libre2HistoryRegistry.Entry(sessionID: UUID(), sensorUID: Data(repeating: 9, count: 8),
                                                      sensorID: "replacement", preparedAt: Date())
        let registry = Libre2HistoryRegistry(entries: [old, replacement]) { _ in }
        XCTAssertEqual(try registry.sensorID(for: reading()), "original-phone-sensor")
        XCTAssertThrowsError(try registry.sensorID(for: reading(session: UUID())))
        let wrongUID = Libre2HistoryReading(sessionID: sessionID, sensorUID: replacement.sensorUID,
                                            sensorMinute: 100, date: now, glucose: 100)
        XCTAssertThrowsError(try registry.sensorID(for: wrongUID))
        XCTAssertThrowsError(try registry.sensorID(for: reading(90)))
    }

    func testSensorRejectionIsSeparateFromASaveAcknowledgement() throws {
        let batch = Libre2HistoryBatch(readings: [reading()])
        let rejection = Libre2HistoryRejection(batchID: batch.id, readingIDs: [reading().id])
        let dictionary = try rejection.dictionary
        XCTAssertNil(dictionary[Libre2HistoryAcknowledgement.key])
        XCTAssertNotNil(dictionary["error"]) // Older Watch builds retain their batch and report the error.
        let decoded = try Libre2HistoryRejection.decode(dictionary)
        XCTAssertEqual(decoded.batchID, batch.id)
        XCTAssertEqual(decoded.readingIDs, [reading().id])
        XCTAssertThrowsError(try Libre2HistoryRejection.decode([Libre2HistoryRejection.key: Data(count: 100_001)]))
    }

    func testRejectedOldSensorDoesNotBlockMixedBatchOrNewReadings() throws {
        let queue = Libre2HistoryQueue { _ in }
        let old = reading()
        let replacement = Libre2HistoryReading(sessionID: UUID(), sensorUID: Data(repeating: 9, count: 8),
            sensorMinute: 100, date: now, glucose: 110)
        try queue.append(old)
        try queue.append(replacement)
        let first = try XCTUnwrap(queue.nextBatch())
        let later = reading(101, session: UUID())
        try queue.append(later)
        let rejection = Libre2HistoryRejection(batchID: first.id, readingIDs: [old.id])
        try queue.retainUnresolved(rejection)
        XCTAssertEqual(queue.state.unresolved, [old])
        XCTAssertEqual(queue.state.pending, [replacement, later])
        let next = try XCTUnwrap(queue.nextBatch())
        XCTAssertNotEqual(next.id, first.id)
        XCTAssertEqual(next.readings, queue.state.pending)
        XCTAssertThrowsError(try queue.retainUnresolved(rejection))
        XCTAssertThrowsError(try queue.acknowledge(Libre2HistoryAcknowledgement(batch: first)))
        XCTAssertEqual(try queue.nextBatch(), next)
        try queue.acknowledge(Libre2HistoryAcknowledgement(batch: next))
        XCTAssertNil(try queue.nextBatch())
        XCTAssertEqual(queue.state.unresolved, [old])
    }

    func testRejectionMustIdentifyANonemptyUniqueSubsetOfTheCurrentBatch() throws {
        let queue = Libre2HistoryQueue { _ in }
        try queue.append(reading())
        let batch = try XCTUnwrap(queue.nextBatch())
        for ids in [[], [reading().id, reading().id], [reading(101).id]] {
            XCTAssertThrowsError(try queue.retainUnresolved(.init(batchID: batch.id, readingIDs: ids)))
            XCTAssertEqual(queue.state.batch, batch)
            XCTAssertTrue(queue.state.unresolved.isEmpty)
        }
        XCTAssertThrowsError(try queue.retainUnresolved(.init(batchID: UUID(), readingIDs: [reading().id])))
    }

    func testFailedRejectionPersistenceKeepsTheOriginalBatchAndReadings() throws {
        var fail = false
        let queue = Libre2HistoryQueue { _ in if fail { throw Libre2HistoryError.unavailable } }
        try queue.append(reading())
        let batch = try XCTUnwrap(queue.nextBatch())
        fail = true
        XCTAssertThrowsError(try queue.retainUnresolved(.init(batchID: batch.id, readingIDs: [reading().id])))
        XCTAssertEqual(queue.state.batch, batch)
        XCTAssertEqual(queue.state.pending, [reading()])
        XCTAssertTrue(queue.state.unresolved.isEmpty)
        fail = false
        try queue.retainUnresolved(.init(batchID: batch.id, readingIDs: [reading().id]))
        XCTAssertNil(try queue.nextBatch())
        XCTAssertEqual(queue.state.unresolved, [reading()])
        try queue.append(reading()) // Retaining separately must not reset duplicate detection.
        XCTAssertTrue(queue.state.pending.isEmpty)
        try queue.append(reading(101))
        XCTAssertEqual(try queue.nextBatch()?.readings, [reading(101)])
    }

    func testUnresolvedReadingsSurviveRestartWithoutBlockingPendingData() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("queue.json")
        let queue = try Libre2HistoryQueue(url: url)
        try queue.append(reading())
        let batch = try XCTUnwrap(queue.nextBatch())
        try queue.append(reading(101))
        try queue.retainUnresolved(.init(batchID: batch.id, readingIDs: [reading().id]))
        let restarted = try Libre2HistoryQueue(url: url)
        XCTAssertEqual(restarted.state.unresolved, [reading()])
        XCTAssertEqual(try restarted.nextBatch()?.readings, [reading(101)])
    }

    func testCleanupMessagesRoundTripAndRejectMalformedPayloads() throws {
        let readings = Libre2UnresolvedReadings(id: UUID(), count: 12)
        XCTAssertEqual(try Libre2UnresolvedReadings.decode(readings.dictionary), readings)
        for request in [Libre2HistoryCleanupRequest.inspect, .delete(readings)] {
            XCTAssertEqual(try Libre2HistoryCleanupRequest.decode(request.dictionary), request)
        }
        XCTAssertThrowsError(try Libre2HistoryCleanupRequest.decode([:]))
        XCTAssertThrowsError(try Libre2HistoryCleanupRequest.decode([Libre2HistoryCleanupRequest.key: Data(count: 1_001)]))
        XCTAssertThrowsError(try Libre2UnresolvedReadings.decode([:]))
        XCTAssertThrowsError(try Libre2UnresolvedReadings.decode(Libre2UnresolvedReadings(id: UUID(), count: -1).dictionary))
    }

    func testDeletionPreservesPendingBatchAndDuplicateDetectionAcrossRestart() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("queue.json")
        let queue = try Libre2HistoryQueue(url: url)
        try queue.append(reading())
        let first = try XCTUnwrap(queue.nextBatch())
        try queue.retainUnresolved(.init(batchID: first.id, readingIDs: [reading().id]))
        let confirmed = queue.unresolvedReadings
        try queue.append(reading(101)) // Ordinary collection does not invalidate the confirmation.
        let pending = try queue.nextBatch()
        let minutes = queue.state.lastCollectedMinute
        try queue.deleteUnresolved(confirmed)
        let restarted = try Libre2HistoryQueue(url: url)
        XCTAssertTrue(restarted.state.unresolved.isEmpty)
        XCTAssertEqual(restarted.state.pending, [reading(101)])
        XCTAssertEqual(restarted.state.batch, pending)
        XCTAssertEqual(restarted.state.lastCollectedMinute, minutes)
        try restarted.append(reading())
        XCTAssertEqual(restarted.state.pending, [reading(101)])
        XCTAssertThrowsError(try queue.deleteUnresolved(confirmed)) // Lost-reply retry cannot repeat deletion.
    }

    func testNewUnresolvedReadingsInvalidateAnEarlierConfirmation() throws {
        let queue = Libre2HistoryQueue { _ in }
        let confirmed = queue.unresolvedReadings
        try queue.append(reading())
        let batch = try XCTUnwrap(queue.nextBatch())
        try queue.retainUnresolved(.init(batchID: batch.id, readingIDs: [reading().id]))
        let before = queue.state
        XCTAssertNotEqual(queue.unresolvedReadings.id, confirmed.id)
        XCTAssertThrowsError(try queue.deleteUnresolved(confirmed))
        XCTAssertEqual(queue.state, before)
        // A matching count is insufficient, as is a matching revision with the wrong count.
        XCTAssertThrowsError(try queue.deleteUnresolved(.init(id: confirmed.id, count: 1)))
        XCTAssertThrowsError(try queue.deleteUnresolved(.init(id: queue.unresolvedReadings.id, count: 2)))
        XCTAssertEqual(queue.state, before)
    }

    func testRestartRejectsAStaleConfirmationWithoutLosingReadings() throws {
        var state = Libre2HistoryQueue.State()
        state.unresolved = [reading()]
        let queue = Libre2HistoryQueue(state: state) { _ in }
        let restarted = Libre2HistoryQueue(state: state) { _ in }
        XCTAssertThrowsError(try restarted.deleteUnresolved(queue.unresolvedReadings))
        XCTAssertEqual(restarted.state, state)
    }

    func testFailedDeletionPersistenceRetainsReadingsAndConfirmation() throws {
        var disk = Libre2HistoryQueue.State()
        disk.unresolved = [reading()]
        var fail = true
        let queue = Libre2HistoryQueue(state: disk) {
            if fail { throw Libre2HistoryError.unavailable }
            disk = $0
        }
        let confirmed = queue.unresolvedReadings
        XCTAssertThrowsError(try queue.deleteUnresolved(confirmed))
        XCTAssertEqual(queue.state, disk)
        XCTAssertEqual(queue.state.unresolved, [reading()])
        XCTAssertEqual(queue.unresolvedReadings, confirmed)
        fail = false
        try queue.deleteUnresolved(confirmed)
        XCTAssertTrue(disk.unresolved.isEmpty)
    }

    func testFullQueueRetainsUnacknowledgedReadingsAndDoesNotAdvanceDeduplication() throws {
        let sample = reading()
        var state = Libre2HistoryQueue.State()
        state.unresolved = Array(repeating: sample, count: Libre2HistoryQueue.maximumStoredReadings)
        let queue = Libre2HistoryQueue(state: state) { _ in XCTFail("Full queue must not be saved") }
        XCTAssertThrowsError(try queue.append(reading(101)))
        XCTAssertEqual(queue.state, state)
    }
}

final class Libre2PhoneHistoryUpdateTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)
    private let maximumAge: TimeInterval = 240

    func testFreshValuesAdvanceButDuplicatesAndOlderValuesDoNotRepeatAlerts() {
        var update = Libre2PhoneHistoryUpdate()
        let first = now.addingTimeInterval(-60)
        XCTAssertEqual(update.consume(first, maximumAge: maximumAge, now: now), first)
        XCTAssertNil(update.consume(first, maximumAge: maximumAge, now: now))
        XCTAssertNil(update.consume(first.addingTimeInterval(-60), maximumAge: maximumAge, now: now))
        XCTAssertEqual(update.consume(now, maximumAge: maximumAge, now: now), now)
    }

    func testStaleAbsentAndFutureValuesDoNotConsumeTheNextCurrentValue() {
        var update = Libre2PhoneHistoryUpdate()
        for rejected in [nil, now.addingTimeInterval(-240), now.addingTimeInterval(-3600),
                         now.addingTimeInterval(1), Date(timeIntervalSince1970: .infinity)] {
            XCTAssertNil(update.consume(rejected, maximumAge: maximumAge, now: now))
        }
        XCTAssertEqual(update.consume(now, maximumAge: maximumAge, now: now), now)
    }

    func testFreshnessUsesMeasurementTimeNotDeliveryTime() {
        var update = Libre2PhoneHistoryUpdate()
        let date = now.addingTimeInterval(-239)
        XCTAssertEqual(update.consume(date, maximumAge: maximumAge, now: now), date)
        var delayed = Libre2PhoneHistoryUpdate()
        XCTAssertNil(delayed.consume(date, maximumAge: maximumAge, now: now.addingTimeInterval(2)))
    }
}
