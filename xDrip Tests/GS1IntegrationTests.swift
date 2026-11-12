import Foundation
import XCTest
import CoreData
@testable import xdrip

final class GS1IntegrationTests: XCTestCase {
    private let baseTime = Date(timeIntervalSince1970: 1_790_000_000)
    private func folder() throws -> URL {
        let value = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: value, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: value) }
        return value
    }
    private func sample(_ index: Int, tail: Int, chemical: Int = 100) -> GS1RawSample {
        .init(index: index, rawTemperature: 320, impedance: 80, chemicalSignal: chemical, opaqueStatus: 0, remaining: tail-index, addedSeconds: 0)
    }
    private func session(_ folder: URL, identity: String = "GS1-CN|ABCD802J|11:22:33:44:55:66|fixture-UUID") throws -> GS1Session {
        try GS1Session(identity: identity, sensitivity: 1.27, storage: folder)
    }
    private func feed(_ session: GS1Session, through index: Int) throws -> [GS1Session.Reading] {
        let received = baseTime.addingTimeInterval(Double(index)*60)
        return try session.ingest((session.nextIndex...index).map { sample($0, tail: index) }, received: received, now: received)
    }
    func testCheckpointAndFullJournalReplayHaveIdenticalCoreState() throws {
        let base = try folder(), first = try session(base)
        _ = try feed(first, through: 120)
        let saved = try XCTUnwrap(first.journal.loadCheckpoint())
        let restored = try session(base)
        XCTAssertEqual(restored.nextIndex, 121)
        XCTAssertEqual(restored.start, first.start)
        let replayBase = try folder()
        let replayDirectory = replayBase.appendingPathComponent(first.journal.directory.lastPathComponent)
        try FileManager.default.copyItem(at: first.journal.directory, to: replayDirectory)
        try FileManager.default.removeItem(at: replayDirectory.appendingPathComponent("checkpoint.json"))
        let replayed = try session(replayBase)
        XCTAssertEqual(replayed.nextIndex, restored.nextIndex)
        let received = baseTime.addingTimeInterval(121*60)
        _ = try restored.ingest([sample(121, tail: 121)], received: received, now: received)
        let checkpointFromRestore = try XCTUnwrap(restored.journal.loadCheckpoint()).core
        // Replay and restore use separate stores; both process the same next minute.
        _ = try replayed.ingest([sample(121, tail: 121)], received: received, now: received)
        XCTAssertEqual(try XCTUnwrap(replayed.journal.loadCheckpoint()).core, checkpointFromRestore)
        XCTAssertEqual(saved.start, baseTime)
    }
    func testCheckpointWithInconsistentStartCannotReanchorSession() throws {
        let base = try folder(), original = try session(base)
        _ = try feed(original, through: 70)
        let saved = try XCTUnwrap(original.journal.loadCheckpoint())
        try original.journal.saveCheckpoint(core: saved.core, index: saved.index, start: baseTime.addingTimeInterval(1800), confirmed: true)
        let restored = try session(base)
        XCTAssertEqual(restored.start, baseTime)
        XCTAssertEqual(restored.nextIndex, 71)
    }

    func testCorruptCheckpointReplaysContiguousJournal() throws {
        let base = try folder(), original = try session(base)
        _ = try feed(original, through: 70)
        try Data("broken".utf8).write(to: original.journal.directory.appendingPathComponent("checkpoint.json"))
        let replay = try session(base)
        XCTAssertEqual(replay.nextIndex, 71)
        XCTAssertEqual(replay.start, baseTime)
        XCTAssertTrue(replay.startConfirmed)
    }
    func testCorruptOrPartialJournalCannotPublishOrRestore() throws {
        let base = try folder(), original = try session(base)
        _ = try feed(original, through: 3)
        let url = original.journal.directory.appendingPathComponent("source.jsonl")
        var data = try Data(contentsOf: url); data.append(Data("partial".utf8)); try data.write(to: url)
        XCTAssertThrowsError(try session(base))
    }
    func testIdentityCodeMACAndUUIDEachIsolateState() throws {
        let base = try folder()
        let id = try GS1CNIdentity(sensorCode: "ABCD802J", mac: GS1MAC("11:22:33:44:55:66"))
        let uuid = UUID()
        let original = try session(base, identity: id.checkpointIdentity(peripheralID: uuid))
        _ = try feed(original, through: 3)
        let changedCode = try GS1CNIdentity(sensorCode: "46HU804E", mac: id.mac)
        let changedMAC = try GS1CNIdentity(sensorCode: id.sensorCode, mac: GS1MAC("11:22:33:44:55:67"))
        for key in [changedCode.checkpointIdentity(peripheralID: uuid), changedMAC.checkpointIdentity(peripheralID: uuid), id.checkpointIdentity(peripheralID: UUID())] {
            XCTAssertEqual(try session(base, identity: key).nextIndex, 1)
        }
    }
    func testGapRequestsEarliestMissingMinuteWithoutAdvancing() throws {
        let value = try session(folder())
        XCTAssertTrue(try value.ingest([sample(4, tail: 4)], received: baseTime, now: baseTime).isEmpty)
        XCTAssertEqual(value.nextIndex, 1)
        XCTAssertFalse(value.historyReady)
        XCTAssertNil(value.start)
    }
    func testDuplicateNeverReanchorsAndConflictIsRejected() throws {
        let value = try session(folder())
        _ = try feed(value, through: 2)
        let start = value.start, originalDate = value.journal.records[1].timestamp
        let later = baseTime.addingTimeInterval(300)
        XCTAssertTrue(try value.ingest([sample(2, tail: 2)], received: later, now: later).isEmpty)
        XCTAssertEqual(value.start, start)
        XCTAssertEqual(value.journal.records[1].timestamp, originalDate)
        XCTAssertThrowsError(try value.ingest([sample(2, tail: 2, chemical: 101)], received: later, now: later))
        XCTAssertEqual(value.nextIndex, 3)
    }
    func testJournalAheadRetryUsesOriginalSignalAndTimestamp() throws {
        let value = try session(folder())
        let persisted = GS1SourceRecord(sample(1, tail: 1), received: baseTime.addingTimeInterval(60))
        try value.journal.append(persisted) // Simulates append completing before core/checkpoint.
        let later = baseTime.addingTimeInterval(120)
        XCTAssertThrowsError(try value.ingest([sample(1, tail: 1, chemical: 101)], received: later, now: later))
        XCTAssertEqual(value.nextIndex, 1)
        _ = try value.ingest([sample(1, tail: 1)], received: later, now: later)
        XCTAssertEqual(value.start, baseTime)
        XCTAssertEqual(value.journal.records.count, 1)
        XCTAssertEqual(value.journal.records[0], persisted)
    }
    func testClockJumpAndFutureReceiptDoNotAdvance() throws {
        let value = try session(folder())
        _ = try feed(value, through: 2)
        let jump = baseTime.addingTimeInterval(3600)
        XCTAssertThrowsError(try value.ingest([sample(3, tail: 3)], received: jump, now: jump))
        XCTAssertEqual(value.nextIndex, 3)
        XCTAssertEqual(value.journal.records.count, 2)
        XCTAssertThrowsError(try value.ingest([sample(3, tail: 3)], received: jump, now: jump.addingTimeInterval(-10)))
    }
    func testDelayedTailIsRejectedWithoutMovingTheJournalAndFreshHistoryRecovers() throws {
        let value = try session(folder())
        _ = try feed(value, through: 64)
        let originalRecords = value.journal.records
        let delayedReceipt = baseTime.addingTimeInterval(68 * 60 + 1)
        XCTAssertThrowsError(try value.ingest([sample(65, tail: 65)], received: delayedReceipt, now: delayedReceipt))
        guard case .anchor(let index, let delta)? = value.timelineIssue else {
            return XCTFail("Delayed receipt must identify the anchor mismatch")
        }
        XCTAssertEqual(index, 65)
        XCTAssertEqual(delta, 181, accuracy: 0.001)
        XCTAssertEqual(value.timelineIssue?.canRetry, true)
        XCTAssertEqual(value.nextIndex, 65)
        XCTAssertEqual(value.start, baseTime)
        XCTAssertEqual(value.journal.records, originalRecords)

        // Re-read the missing minute as history; its original event is already stale.
        let freshReceipt = baseTime.addingTimeInterval(68 * 60 + 2)
        XCTAssertTrue(try value.ingest((65...68).map { sample($0, tail: 68) },
            received: freshReceipt, now: freshReceipt).isEmpty)
        XCTAssertNil(value.timelineIssue)
        XCTAssertEqual(value.nextIndex, 69)
        XCTAssertEqual(Array(value.journal.records.prefix(64)), originalRecords)
        XCTAssertEqual(value.journal.records[64].timestamp, baseTime.addingTimeInterval(65 * 60 + 2))
        let recovered = try feed(value, through: 70)
        XCTAssertEqual(recovered.map(\.index), [70])
        XCTAssertEqual(recovered.first?.date, baseTime.addingTimeInterval(70 * 60))
        XCTAssertEqual(value.start, baseTime)
        XCTAssertEqual(value.nextIndex, 71)
    }

    func testTimelineFailureKeepsTheAcceptedBatchPrefixAndRestartReplaysOnlyThatPrefix() throws {
        let base = try folder(), original = try session(base)
        _ = try feed(original, through: 64)
        let received = baseTime.addingTimeInterval(68 * 60 + 1)
        let prefix = sample(65, tail: 68)
        let delayedTail = sample(66, tail: 66)
        XCTAssertThrowsError(try original.ingest([prefix, delayedTail], received: received, now: received))
        XCTAssertEqual(original.timelineIssue?.canRetry, true)
        XCTAssertEqual(original.nextIndex, 66)
        XCTAssertEqual(original.journal.records.count, 65)
        XCTAssertEqual(original.journal.records.last?.timestamp, baseTime.addingTimeInterval(65 * 60 + 1))
        XCTAssertEqual(try XCTUnwrap(original.journal.loadCheckpoint()).index, 64)

        let restored = try session(base)
        XCTAssertEqual(restored.nextIndex, 66)
        XCTAssertEqual(restored.start, baseTime)
        XCTAssertEqual(restored.journal.records, original.journal.records)
        let freshReceipt = baseTime.addingTimeInterval(68 * 60 + 2)
        XCTAssertTrue(try restored.ingest((66...68).map { sample($0, tail: 68) },
            received: freshReceipt, now: freshReceipt).isEmpty)
        XCTAssertEqual(restored.nextIndex, 69)
        XCTAssertEqual(restored.journal.records[64].timestamp, baseTime.addingTimeInterval(65 * 60 + 1))
        XCTAssertEqual(try feed(restored, through: 70).map(\.index), [70])
        XCTAssertEqual(restored.start, baseTime)
    }

    func testPositiveAddedSecondsCanCauseRetryableNonMonotonicTimeWithoutResettingTheSession() throws {
        let value = try session(folder())
        _ = try feed(value, through: 10)
        let received = baseTime.addingTimeInterval(12 * 60)
        let collapsed = [11, 12].map {
            GS1RawSample(index: $0, rawTemperature: 320, impedance: 80, chemicalSignal: 100,
                opaqueStatus: 0, remaining: 12 - $0, addedSeconds: 60)
        }
        XCTAssertThrowsError(try value.ingest(collapsed, received: received, now: received))
        guard case .nonMonotonic(let index, let delta)? = value.timelineIssue else {
            return XCTFail("Equal receipt-derived timestamps must retain the ordering failure")
        }
        XCTAssertEqual(index, 12)
        XCTAssertEqual(delta, 0, accuracy: 0.001)
        XCTAssertEqual(value.timelineIssue?.canRetry, true)
        XCTAssertEqual(value.nextIndex, 12)
        XCTAssertEqual(value.journal.records.count, 11)
        XCTAssertEqual(value.start, baseTime)
        let retryReceipt = received.addingTimeInterval(1)
        XCTAssertTrue(try value.ingest([sample(12, tail: 12)], received: retryReceipt, now: retryReceipt).isEmpty)
        XCTAssertNil(value.timelineIssue)
        XCTAssertEqual(value.nextIndex, 13)
        XCTAssertEqual(value.start, baseTime)
    }

    func testInvalidClockAndRecordReasonsAreTerminalAndReplaceAnEarlierRetryableIssue() throws {
        let value = try session(folder())
        _ = try feed(value, through: 2)
        let delayed = baseTime.addingTimeInterval(3 * 60 + 121)
        XCTAssertThrowsError(try value.ingest([sample(3, tail: 3)], received: delayed, now: delayed))
        XCTAssertEqual(value.timelineIssue?.canRetry, true)
        XCTAssertThrowsError(try value.ingest([sample(3, tail: 3)], received: delayed, now: delayed.addingTimeInterval(-6)))
        guard case .invalidClock? = value.timelineIssue else {
            return XCTFail("A stale retryable reason must not mask an invalid receive clock")
        }
        XCTAssertEqual(value.timelineIssue?.canRetry, false)
        XCTAssertEqual(value.nextIndex, 3)
        XCTAssertEqual(value.journal.records.count, 2)
        XCTAssertEqual(value.start, baseTime)

        for interval in [Double.nan, .infinity, -.infinity] {
            let invalidDate = Date(timeIntervalSince1970: interval)
            for (received, now) in [(invalidDate, baseTime), (baseTime, invalidDate)] {
                XCTAssertThrowsError(try value.ingest([sample(3, tail: 3)], received: received, now: now))
                guard case .invalidClock? = value.timelineIssue else {
                    return XCTFail("Non-finite receive and current clocks must remain terminal")
                }
                XCTAssertEqual(value.timelineIssue?.canRetry, false)
                XCTAssertEqual(value.timelineIssue?.diagnostic, "invalid receive clock")
                XCTAssertEqual(value.nextIndex, 3)
                XCTAssertEqual(value.journal.records.count, 2)
            }
        }

        let first = try session(folder())
        let received = Date(timeIntervalSince1970: 946_771_200)
        XCTAssertThrowsError(try first.ingest([sample(1, tail: 2001)], received: received, now: received))
        guard case .invalidRecord? = first.timelineIssue else {
            return XCTFail("A historical event before the valid epoch must remain terminal")
        }
        XCTAssertEqual(first.timelineIssue?.canRetry, false)
        XCTAssertEqual(first.nextIndex, 1)
        XCTAssertTrue(first.journal.records.isEmpty)
        XCTAssertNil(first.start)
    }
    func testHistoricalAndWarmupSamplesNeverBecomeFreshGlucose() throws {
        let warmup = try session(folder())
        XCTAssertTrue(try feed(warmup, through: 59).isEmpty)
        let historical = try session(folder())
        let received = baseTime.addingTimeInterval(120*60)
        XCTAssertTrue(try historical.ingest((1...100).map { sample($0, tail: 120) }, received: received, now: received).isEmpty)
        XCTAssertFalse(historical.historyReady)
        let stale = try session(folder())
        XCTAssertTrue(try stale.ingest((1...120).map { sample($0, tail: 120) }, received: received, now: received.addingTimeInterval(300)).isEmpty)
    }
    func testFactoryWarmupLifetimeAndFreshnessBoundaries() {
        let date = baseTime.addingTimeInterval(3600)
        XCTAssertTrue(GS1Policy.mayPublish(index: 60, timestamp: date, start: baseTime, now: date, live: true, confirmed: true))
        XCTAssertFalse(GS1Policy.mayPublish(index: 59, timestamp: date, start: baseTime, now: date, live: true, confirmed: true))
        XCTAssertFalse(GS1Policy.mayPublish(index: 60, timestamp: date, start: baseTime, now: date.addingTimeInterval(-1), live: true, confirmed: true))
        XCTAssertFalse(GS1Policy.mayPublish(index: 60, timestamp: date, start: baseTime, now: date.addingTimeInterval(121), live: true, confirmed: true))
        XCTAssertFalse(GS1Policy.mayPublish(index: 60, timestamp: date, start: baseTime, now: date, live: false, confirmed: true))
        XCTAssertFalse(GS1Policy.mayPublish(index: 20160, timestamp: baseTime.addingTimeInterval(GS1Policy.lifetime), start: baseTime, now: baseTime.addingTimeInterval(GS1Policy.lifetime), live: true, confirmed: true))
    }
    func testZeroSignalHasNoRawFallback() throws {
        let value = try session(folder()), received = baseTime.addingTimeInterval(120*60)
        let readings = try value.ingest((1...120).map { sample($0, tail: 120, chemical: 0) }, received: received, now: received)
        XCTAssertTrue(readings.isEmpty)
        XCTAssertEqual(value.nextIndex, 121)
    }
    func testFinalReadingsKeepOriginalTimestampAndFiveMinuteCadence() throws {
        let value = try session(folder())
        var readings: [GS1Session.Reading] = []
        for index in 1...300 { readings += try feed(value, through: index) }
        XCTAssertFalse(readings.isEmpty)
        for reading in readings {
            XCTAssertEqual(reading.index % 5, 0)
            XCTAssertEqual(reading.date, baseTime.addingTimeInterval(Double(reading.index)*60))
            XCTAssertGreaterThanOrEqual(reading.index, 60)
            XCTAssertTrue(reading.mgdl.isFinite && reading.mgdl > 0)
        }
    }
    func testCorrectionBeforeTailInSamePacketKeepsOriginalTimestamp() throws {
        let value = try session(folder())
        _ = try feed(value, through: 64)
        let received = baseTime.addingTimeInterval(66*60)
        let readings = try value.ingest([sample(65, tail: 66), sample(66, tail: 66)], received: received, now: received)
        XCTAssertEqual(readings.map(\.index), [65])
        XCTAssertEqual(readings.first?.date, baseTime.addingTimeInterval(65*60))
        XCTAssertTrue(value.historyReady)
    }
    func testCorrectionSurvivesSeparatePacketsWithoutRawFallbackOrRepublication() throws {
        let value = try session(folder())
        _ = try feed(value, through: 64)
        let received = baseTime.addingTimeInterval(66*60)
        XCTAssertTrue(try value.ingest([sample(65, tail: 66)], received: received, now: received).isEmpty)
        XCTAssertFalse(value.historyReady)
        // Neither an empty packet nor a duplicate claiming to be the tail completes minute 66.
        XCTAssertTrue(try value.ingest([], received: received, now: received).isEmpty)
        XCTAssertTrue(try value.ingest([sample(65, tail: 65)], received: received, now: received).isEmpty)
        let tail = sample(66, tail: 66, chemical: 0)
        let readings = try value.ingest([tail], received: received, now: received)
        XCTAssertEqual(readings.map(\.index), [65])
        XCTAssertEqual(readings.first?.date, baseTime.addingTimeInterval(65*60))
        XCTAssertGreaterThan(try XCTUnwrap(readings.first).mgdl, 0)
        XCTAssertTrue(try value.ingest([tail], received: received, now: received).isEmpty)
        XCTAssertTrue(try value.ingest([], received: received, now: received).isEmpty)
    }
    func testPendingCorrectionWaitsForGapToBeFilledAndKeepsFreshnessBoundary() throws {
        let value = try session(folder())
        _ = try feed(value, through: 64)
        let firstReceipt = baseTime.addingTimeInterval(66*60)
        XCTAssertTrue(try value.ingest([sample(65, tail: 66)], received: firstReceipt, now: firstReceipt).isEmpty)
        let received = baseTime.addingTimeInterval(67*60)
        XCTAssertTrue(try value.ingest([sample(67, tail: 67)], received: received, now: received).isEmpty)
        XCTAssertEqual(value.nextIndex, 66)
        XCTAssertFalse(value.historyReady)
        let readings = try value.ingest([sample(66, tail: 67), sample(67, tail: 67)], received: received, now: received)
        XCTAssertEqual(readings.map(\.index), [65])
        XCTAssertEqual(readings.first?.date, received.addingTimeInterval(-120))
    }
    func testPendingCorrectionCannotBecomeFreshByReceivingALateTail() throws {
        let value = try session(folder())
        _ = try feed(value, through: 64)
        let received = baseTime.addingTimeInterval(66*60)
        XCTAssertTrue(try value.ingest([sample(65, tail: 66)], received: received, now: received).isEmpty)
        let now = baseTime.addingTimeInterval(67*60+1)
        XCTAssertTrue(try value.ingest([sample(66, tail: 66)], received: received, now: now).isEmpty)
        XCTAssertTrue(value.historyReady)
        // Clock movement and a duplicate cannot revive the discarded correction.
        XCTAssertTrue(try value.ingest([sample(66, tail: 66)], received: received, now: received).isEmpty)
    }
    func testWarmupCorrectionAndPendingAfterRestartAreNotPublished() throws {
        let warmup = try session(folder())
        _ = try feed(warmup, through: 54)
        let warmupReceipt = baseTime.addingTimeInterval(56*60)
        XCTAssertTrue(try warmup.ingest([sample(55, tail: 56), sample(56, tail: 56)], received: warmupReceipt, now: warmupReceipt).isEmpty)

        let base = try folder(), first = try session(base)
        _ = try feed(first, through: 64)
        let received = baseTime.addingTimeInterval(66*60)
        XCTAssertTrue(try first.ingest([sample(65, tail: 66)], received: received, now: received).isEmpty)
        let restored = try session(base)
        XCTAssertEqual(restored.nextIndex, 66)
        XCTAssertTrue(try restored.ingest([sample(66, tail: 66)], received: received, now: received).isEmpty)
    }
    func testPendingCorrectionDoesNotBypassConflictOrClockJump() throws {
        let value = try session(folder())
        _ = try feed(value, through: 64)
        let received = baseTime.addingTimeInterval(66*60)
        XCTAssertTrue(try value.ingest([sample(65, tail: 66)], received: received, now: received).isEmpty)
        XCTAssertThrowsError(try value.ingest([sample(65, tail: 65, chemical: 101)], received: received, now: received))
        let later = received.addingTimeInterval(3600)
        XCTAssertThrowsError(try value.ingest([sample(66, tail: 66)], received: later, now: later))
        XCTAssertEqual(value.nextIndex, 66)
    }
    func testStrictDeviceInformationMACAndCandidateMatching() {
        XCTAssertEqual(GS1Setup.readOnlyMAC(Data("11:22:33:44:55:66".utf8))?.string, "11:22:33:44:55:66")
        for invalid in ["112233445566", "11-22-33-44-55-66", "SERIAL12345678901", "11:22:33:44:55:66\0", UUID().uuidString] {
            XCTAssertNil(GS1Setup.readOnlyMAC(Data(invalid.utf8)))
        }
        XCTAssertTrue(GS1Setup.matches(name: "LT2309ABCD", code: "ABCD802J"))
        XCTAssertFalse(GS1Setup.matches(name: "LT2309OTHR", code: "ABCD802J"))
        XCTAssertNil(GS1Setup.normalizedCode("UNKNOWN!"))
    }

    // Invented static-random address bytes; these are not captured hardware data.
    private var syntheticGS1SerialBytes: Data { Data([0x12, 0x34, 0x56, 0x78, 0x9a, 0xc2]) }
    private let syntheticGS1SerialMAC = "C2:9A:78:56:34:12"

    func testGS1RawDeviceInformationMACUsesReversedSixByteOrder() {
        let mac = GS1Setup.readOnlyMAC(syntheticGS1SerialBytes, model: "GS1", manufacturer: "SISENSING")
        XCTAssertEqual(mac?.string, syntheticGS1SerialMAC)
        XCTAssertNotEqual(mac?.string, "12:34:56:78:9A:C2")
    }

    func testGS1RawMACRequiresBothExactNormalizedModelAndManufacturer() {
        XCTAssertEqual(GS1Setup.readOnlyMAC(syntheticGS1SerialBytes, model: " \tgs1\n", manufacturer: " sisensing \r")?.string,
            syntheticGS1SerialMAC)
        let cases: [(String?, String?)] = [(nil, nil), ("GS1", nil), (nil, "SISENSING"),
            ("", "SISENSING"), ("GS3", "SISENSING"), ("GS1-7", "SISENSING"),
            ("GS1", ""), ("GS1", "Other Manufacturer"), ("GS1", "SISENSING INC")]
        for (model, manufacturer) in cases {
            XCTAssertNil(GS1Setup.readOnlyMAC(syntheticGS1SerialBytes, model: model, manufacturer: manufacturer))
        }
    }

    func testGS1RawMACRejectsEmptyBroadcastASCIIAndWrongLengthSerials() {
        let invalid = [Data(), Data(repeating: 0, count: 6), Data(repeating: 0xff, count: 6), Data([0, 0, 0, 0, 0, 0xc0]),
            Data("ABCDEF".utf8), Data("123456".utf8), Data("123456789012".utf8),
            Data([0x12, 0x34, 0x56, 0x78, 0xc2]), Data([0x12, 0x34, 0x56, 0x78, 0x9a, 0xb1, 0xc2])]
        for serial in invalid {
            XCTAssertNil(GS1Setup.readOnlyMAC(serial, model: "GS1", manufacturer: "SISENSING"))
        }
    }

    func testGS1RawMACRejectsUnobservedAddressSchemas() {
        for lastByte: UInt8 in [0x02, 0x42, 0x82] {
            let serial = Data([0x12, 0x34, 0x56, 0x78, 0x9a, lastByte])
            XCTAssertNil(GS1Setup.readOnlyMAC(serial, model: "GS1", manufacturer: "SISENSING"))
        }
    }

    func testLegacyDeviceInformationASCII17MACDoesNotNeedTheRawGS1FamilyEvidence() {
        let serial = Data("11:22:33:44:55:66".utf8)
        XCTAssertEqual(GS1Setup.readOnlyMAC(serial)?.string, "11:22:33:44:55:66")
        XCTAssertEqual(GS1Setup.readOnlyMAC(serial, model: "Other Model", manufacturer: "Other Manufacturer")?.string,
            "11:22:33:44:55:66")
        XCTAssertEqual(GS1Setup.deviceInformationMAC(["2A25": serial])?.string, "11:22:33:44:55:66")
    }

    func testGS1DeviceInformationTrimsUTF8FieldWhitespaceAndNULTerminators() {
        let fields: [String: Data] = ["2A25": syntheticGS1SerialBytes,
            "2A24": Data("\0 \tGS1\n\0".utf8), "2A29": Data("\tSISENSING \0\r".utf8)]
        XCTAssertEqual(GS1Setup.deviceInformationMAC(fields)?.string, syntheticGS1SerialMAC)
    }

    func testGS1RawMACNeedsAllThreeDeviceInformationFieldsInEveryArrivalOrder() {
        let source: [String: Data] = ["2A25": syntheticGS1SerialBytes,
            "2A24": Data("GS1".utf8), "2A29": Data("SISENSING".utf8)]
        let orders = [["2A25", "2A24", "2A29"], ["2A25", "2A29", "2A24"],
            ["2A24", "2A25", "2A29"], ["2A24", "2A29", "2A25"],
            ["2A29", "2A25", "2A24"], ["2A29", "2A24", "2A25"]]
        for order in orders {
            var received: [String: Data] = [:]
            for (index, key) in order.enumerated() {
                received[key] = source[key]
                if index < 2 { XCTAssertNil(GS1Setup.deviceInformationMAC(received), order.description) }
                else { XCTAssertEqual(GS1Setup.deviceInformationMAC(received)?.string, syntheticGS1SerialMAC, order.description) }
            }
        }
    }

    func testGS1DeviceInformationCannotResolveFromCorruptOrWrongFamilyFields() {
        let valid: [String: Data] = ["2A25": syntheticGS1SerialBytes,
            "2A24": Data("GS1".utf8), "2A29": Data("SISENSING".utf8)]
        for key in ["2A24", "2A29"] {
            var malformed = valid
            malformed[key] = Data([0xff, 0xfe])
            XCTAssertNil(GS1Setup.deviceInformationMAC(malformed))
        }
        var wrongModel = valid
        wrongModel["2A24"] = Data("GS3".utf8)
        XCTAssertNil(GS1Setup.deviceInformationMAC(wrongModel))
        var missingSerial = valid
        missingSerial.removeValue(forKey: "2A25")
        XCTAssertNil(GS1Setup.deviceInformationMAC(missingSerial))
    }

    func testDeliveryGateInvalidatesQueuedOldCallback() throws {
        let gate = GS1DeliveryGate(), old = try XCTUnwrap(gate.token())
        gate.invalidate()
        XCTAssertFalse(gate.allows(old))
        XCTAssertNotNil(gate.token())
    }
    func testStoppedDeliveryGateRejectsOldAndNewCallbacks() throws {
        let gate = GS1DeliveryGate(), old = try XCTUnwrap(gate.token())
        gate.stop()
        XCTAssertFalse(gate.allows(old))
        XCTAssertNil(gate.token())
    }
    func testReleasedDeliveryGateIsPermanent() {
        let gate = GS1DeliveryGate()
        gate.release(); gate.invalidate()
        XCTAssertTrue(gate.isReleased)
        XCTAssertNil(gate.token())
    }

    // MARK: - Synthetic AA55 fixed ten-slot responses

    private func syntheticGS1Response(count: Int, fixed: Bool, validCompactPrefix: Bool = false) -> Data {
        precondition((0...255).contains(count) && (!fixed || count <= 10))
        var bytes: [UInt8] = [0xaa, 0x55, 0x09, UInt8(count)]
        for index in 1..<(count + 1) {
            // Invented minute records. No captured sensor or medical data is used.
            for value in [index, 320, 80, 100, 0, count - index, 0] {
                bytes += [UInt8(truncatingIfNeeded: value >> 8), UInt8(truncatingIfNeeded: value)]
            }
        }
        if validCompactPrefix {
            precondition(fixed && count > 0 && count < 10)
            // Make the compact-length prefix independently checksum-valid even
            // though the transport's real checksum is at byte 144.
            let adjustment = UInt8(truncatingIfNeeded: -bytes.reduce(0) { $0 + Int($1) })
            bytes[4 + (count - 1) * 14 + 9] = adjustment
        }
        if fixed { bytes += [UInt8](repeating: 0, count: 14 * (10 - count)) }
        bytes.append(UInt8(truncatingIfNeeded: -bytes.reduce(0) { $0 + Int($1) }))
        return Data(bytes)
    }

    private func syntheticGS1Echo() -> Data {
        var bytes: [UInt8] = [0xaa, 0x55, 0x07, 0x01, 0x00, 0x66, 0x55, 0x44, 0x33, 0x22, 0x11]
        bytes += [UInt8](repeating: 0, count: 8)
        bytes.append(UInt8(truncatingIfNeeded: -bytes.reduce(0) { $0 + Int($1) }))
        return Data(bytes)
    }

    func testGS1ParserAcceptsExactCompactAndFixedTenSlotCounts() throws {
        for count in [0, 1, 3, 9, 10] {
            let expected = GS1Packet.samples((0..<count).map { sample($0 + 1, tail: count) })
            let compact = syntheticGS1Response(count: count, fixed: false)
            let fixed = syntheticGS1Response(count: count, fixed: true)
            XCTAssertEqual(compact.count, 5 + 14 * count)
            XCTAssertEqual(fixed.count, 145)
            XCTAssertEqual(try GS1ChineseProtocol.parse(compact), expected)
            XCTAssertEqual(try GS1ChineseProtocol.parse(fixed), expected)
        }
    }

    func testGS1FixedLayoutRejectsElevenRecordsWithoutChangingCompactCompatibility() throws {
        let compact = syntheticGS1Response(count: 11, fixed: false)
        XCTAssertEqual(compact.count, 159)
        XCTAssertEqual(try GS1ChineseProtocol.parse(compact), .samples((1...11).map { sample($0, tail: 11) }))
        var invalidFixed = [UInt8](syntheticGS1Response(count: 10, fixed: true))
        invalidFixed[3] = 11
        invalidFixed[144] = UInt8(truncatingIfNeeded: -invalidFixed.prefix(144).reduce(0) { $0 + Int($1) })
        XCTAssertThrowsError(try GS1ChineseProtocol.parse(Data(invalidFixed)))
        var assembler = GS1PacketAssembler(layout: .fixed10)
        XCTAssertThrowsError(try assembler.append(Data(invalidFixed)))
    }

    func testGS1FixedPaddingMustBeZeroEvenWhenTheWholePacketChecksumIsValid() throws {
        var bytes = [UInt8](syntheticGS1Response(count: 3, fixed: true))
        bytes[4 + 3 * 14] = 1
        bytes[144] = UInt8(truncatingIfNeeded: -bytes.prefix(144).reduce(0) { $0 + Int($1) })
        XCTAssertEqual(GS1ChineseProtocol.checksum(bytes), 0)
        XCTAssertThrowsError(try GS1ChineseProtocol.parse(Data(bytes))) {
            XCTAssertEqual($0 as? GS1ProtocolError, .wrongLength)
        }
        var assembler = GS1PacketAssembler(layout: .fixed10)
        XCTAssertThrowsError(try assembler.append(Data(bytes)))
        let valid = syntheticGS1Response(count: 3, fixed: true)
        XCTAssertEqual(try assembler.append(valid), [try GS1ChineseProtocol.parse(valid)])
    }

    func testGS1FixedFinalChecksumFailureDoesNotLeakSamplesAndResetsTheAssembler() throws {
        let valid = syntheticGS1Response(count: 3, fixed: true)
        var corrupt = [UInt8](valid)
        corrupt[144] ^= 1
        XCTAssertThrowsError(try GS1ChineseProtocol.parse(Data(corrupt))) {
            XCTAssertEqual($0 as? GS1ProtocolError, .checksum)
        }
        var assembler = GS1PacketAssembler(layout: .fixed10)
        XCTAssertThrowsError(try assembler.append(Data(corrupt)))
        XCTAssertEqual(try assembler.append(valid), [try GS1ChineseProtocol.parse(valid)])
    }

    func testGS1FixedLayoutWaitsForAll145BytesAtEverySplit() throws {
        for count in [1, 3, 9, 10] {
            let packet = syntheticGS1Response(count: count, fixed: true)
            let expected = try GS1ChineseProtocol.parse(packet)
            for split in 1..<145 {
                var assembler = GS1PacketAssembler(layout: .fixed10)
                XCTAssertTrue(try assembler.append(Data(packet.prefix(split))).isEmpty, "count=\(count), split=\(split)")
                XCTAssertEqual(try assembler.append(Data(packet.dropFirst(split))), [expected], "count=\(count), split=\(split)")
            }
        }
    }

    func testGS1FixedLayoutDoesNotEmitEarlyWhenNotificationsArriveOneByteAtATime() throws {
        let packet = syntheticGS1Response(count: 3, fixed: true)
        var assembler = GS1PacketAssembler(layout: .fixed10)
        for (offset, byte) in packet.enumerated() {
            let parsed = try assembler.append(Data([byte]))
            if offset < 144 { XCTAssertTrue(parsed.isEmpty, "offset=\(offset)") }
            else { XCTAssertEqual(parsed, [try GS1ChineseProtocol.parse(packet)]) }
        }
    }

    func testGS1FixedLayoutDoesNotConsumeAnAccidentallyValidCompactPrefix() throws {
        let packet = syntheticGS1Response(count: 3, fixed: true, validCompactPrefix: true)
        let compactLength = 5 + 3 * 14
        let prefix = Data(packet.prefix(compactLength))
        let expected = try GS1ChineseProtocol.parse(packet)
        XCTAssertEqual(try GS1ChineseProtocol.parse(prefix), expected)
        var compactAssembler = GS1PacketAssembler() // Legacy default remains compact.
        XCTAssertEqual(try compactAssembler.append(prefix), [expected])
        var fixedAssembler = GS1PacketAssembler(layout: .fixed10)
        XCTAssertTrue(try fixedAssembler.append(prefix).isEmpty)
        XCTAssertEqual(try fixedAssembler.append(Data(packet.dropFirst(compactLength))), [expected])
    }

    func testGS1FullRequestEchoCanPrecedeAFixed145ByteReply() throws {
        let echo = syntheticGS1Echo()
        let packet = syntheticGS1Response(count: 3, fixed: true)
        XCTAssertEqual(echo.count, 20)
        XCTAssertEqual(try GS1ChineseProtocol.parse(echo), .echo)
        var assembler = GS1PacketAssembler(layout: .fixed10)
        XCTAssertEqual(try assembler.append(echo + packet), [.echo, try GS1ChineseProtocol.parse(packet)])
    }

    func testGS1ShortEchoLookaheadWaitsForTheFixedTransportFrame() throws {
        let packet = syntheticGS1Response(count: 3, fixed: true, validCompactPrefix: true)
        var assembler = GS1PacketAssembler(layout: .fixed10)
        XCTAssertTrue(try assembler.append(Data([0xaa, 0x55, 0x07])).isEmpty)
        // This prefix is valid compact data, but not a complete fixed response.
        XCTAssertTrue(try assembler.append(Data(packet.prefix(47))).isEmpty)
        XCTAssertEqual(try assembler.append(Data(packet.dropFirst(47))), [.echo, try GS1ChineseProtocol.parse(packet)])
    }

    func testGS1AssemblerCanConsumeTwoFixedFramesWithoutLosingTheSecondHeader() throws {
        let first = syntheticGS1Response(count: 3, fixed: true)
        let second = syntheticGS1Response(count: 9, fixed: true)
        var assembler = GS1PacketAssembler(layout: .fixed10)
        XCTAssertEqual(try assembler.append(first + second), [try GS1ChineseProtocol.parse(first), try GS1ChineseProtocol.parse(second)])
    }

    func testGS1FixedLayoutAlsoAcceptsTheCanonicalFiveByteEmptyResponse() throws {
        let empty = Data([0xaa, 0x55, 0x09, 0x00, 0xf8])
        XCTAssertEqual(try GS1ChineseProtocol.parse(empty), .samples([]))
        var assembler = GS1PacketAssembler(layout: .fixed10)
        XCTAssertTrue(try assembler.append(Data(empty.prefix(4))).isEmpty)
        XCTAssertEqual(try assembler.append(Data(empty.suffix(1))), [.samples([])])
        let fixedEmpty = syntheticGS1Response(count: 0, fixed: true)
        XCTAssertEqual(try assembler.append(fixedEmpty), [.samples([])])
    }

    func testThreeCompleteFixedRecordsAdvanceTheWarmupJournalWithoutPublishingGlucose() throws {
        var assembler = GS1PacketAssembler(layout: .fixed10)
        let packets = try assembler.append(syntheticGS1Response(count: 3, fixed: true))
        guard case .samples(let samples)? = packets.first else { return XCTFail("Expected complete raw records") }
        let value = try session(folder())
        let receipt = baseTime.addingTimeInterval(180)
        XCTAssertTrue(try value.ingest(samples, received: receipt, now: receipt).isEmpty)
        XCTAssertEqual(value.nextIndex, 4)
        XCTAssertEqual(value.journal.records.count, 3)
        XCTAssertEqual(value.start, baseTime)
    }

    @MainActor
    func testUpstreamStoreMigratesToGS1ModelPreservingPeripheral() throws {
        let bundle = Bundle(for: Sensor.self)
        let directory = try XCTUnwrap(bundle.url(forResource: "xdrip", withExtension: "momd"))
        let source = try XCTUnwrap(NSManagedObjectModel(contentsOf: directory.appendingPathComponent("xdrip v37.mom")))
        let destination = try XCTUnwrap(NSManagedObjectModel(contentsOf: directory))
        XCTAssertEqual(Set(destination.entitiesByName.keys), Set(source.entitiesByName.keys).union(["SibionicsCN"]))
        for (name, hash) in source.entityVersionHashesByName where name != "BLEPeripheral" {
            XCTAssertEqual(destination.entityVersionHashesByName[name], hash, name)
        }
        let url = try folder().appendingPathComponent("migration.sqlite")
        let oldCoordinator = NSPersistentStoreCoordinator(managedObjectModel: source)
        let oldStore = try oldCoordinator.addPersistentStore(ofType: NSSQLiteStoreType, configurationName: nil, at: url)
        let context = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        context.persistentStoreCoordinator = oldCoordinator
        let peripheral = NSEntityDescription.insertNewObject(forEntityName: "BLEPeripheral", into: context)
        peripheral.setValue("TEST-PERIPHERAL", forKey: "address")
        peripheral.setValue("Migration fixture", forKey: "name")
        for attribute in ["parameterUpdateNeededAtNextConnect", "shouldconnect", "webOOPEnabled"] {
            peripheral.setValue(false, forKey: attribute)
        }
        try context.save()
        context.reset()
        try oldCoordinator.remove(oldStore)

        let newCoordinator = NSPersistentStoreCoordinator(managedObjectModel: destination)
        let options = [NSMigratePersistentStoresAutomaticallyOption: true, NSInferMappingModelAutomaticallyOption: true]
        let migratedStore = try newCoordinator.addPersistentStore(ofType: NSSQLiteStoreType, configurationName: nil, at: url, options: options)
        defer { try? newCoordinator.remove(migratedStore) }
        let migratedContext = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        migratedContext.persistentStoreCoordinator = newCoordinator
        let devices = try migratedContext.fetch(NSFetchRequest<NSManagedObject>(entityName: "BLEPeripheral"))
        XCTAssertEqual(devices.count, 1)
        XCTAssertEqual(devices.first?.value(forKey: "address") as? String, "TEST-PERIPHERAL")
        XCTAssertNil(devices.first?.value(forKey: "sibionicsCN"))
        let gs1 = NSEntityDescription.insertNewObject(forEntityName: "SibionicsCN", into: migratedContext)
        XCTAssertEqual(gs1.value(forKey: "startAuthorized") as? Bool, false)
        migratedContext.reset()
    }
}
