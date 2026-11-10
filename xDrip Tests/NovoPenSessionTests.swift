//
//  NovoPenSessionTests.swift
//  xdripTests
//
//  Ported from xDrip "OpenNov" by JamOrHam (NightscoutFoundation/xDrip, GPLv3).
//

import XCTest
@testable import xdrip

/// Hands out queued inbound frames (or errors) and records every outbound frame with the number of frames received before it.
private final class ScriptedChannel: NovoPenChannel {
    struct LinkLost: Error {}

    private var script: [Result<Data, Error>]
    /// Returned once the script runs out; nil throws `LinkLost` instead.
    private let endless: Data?
    private(set) var received = 0
    private(set) var sent: [(afterReceiving: Int, frame: Data)] = []

    init(_ script: [Result<Data, Error>], endless: Data? = nil) {
        self.script = script
        self.endless = endless
    }

    func receive() async throws -> Data {
        received += 1
        guard !script.isEmpty else {
            if let endless { return endless }
            throw LinkLost()
        }
        return try script.removeFirst().get()
    }

    func send(_ inner: Data) async throws {
        sent.append((received, inner))
    }

    var outbound: [Data] { sent.map(\.frame) }

    /// The frames sent after the `n`th inbound frame (1-based) and before the next one.
    func sent(afterReceiving n: Int) -> [Data] { sent.filter { $0.afterReceiving == n }.map(\.frame) }
}

final class NovoPenSessionTests: XCTestCase {
    private typealias F = NovoPenFixtures

    private let now = Date(timeIntervalSince1970: 1_800_000_000)
    private let releaseResponse = Data(hexadecimalString: "e50000020000")!
    private let releaseRequestFromPen = Data(hexadecimalString: "e40000020000")!

    private func session(_ channel: ScriptedChannel) -> NovoPenSession {
        NovoPenSession(channel: channel, now: { [now] in now })
    }

    /// Everything up to and including the transfer trigger's answer (6 frames).
    private func handshake(segmentInfo: Data = NovoPenFixtures.segmentInfo) -> [Result<Data, Error>] {
        [F.aRequest, F.configReport, Data(), F.deviceInfo, segmentInfo, F.triggerResponse].map { .success($0) }
    }

    /// segmentInfo whose segment holds `usage` entries.
    private func segmentInfo(usage: UInt8) -> Data {
        var frame = F.segmentInfo
        let attribute = frame.firstRange(of: Data([0x09, 0x7B, 0x00, 0x04, 0x00, 0x00, 0x00, 0x03]))!   // usage count 3
        frame[attribute.upperBound - 1] = usage
        return frame
    }

    /// doseReport with another event relative time (the pen's clock).
    private func doseReport(eventRelativeTime: UInt32) -> Data {
        var frame = F.doseReport
        XCTAssertEqual(frame.subdata(in: 14..<18), Data([0x00, 0x01, 0xC6, 0x13]), "event relative time 116243")
        var w = NovoPenByteWriter()
        w.u32(eventRelativeTime)
        frame.replaceSubrange(14..<18, with: w.data)
        return frame
    }

    private static let doseEntries = 36   // first dose entry in doseReport, 12 bytes each

    private func expectThrows(_ run: () async throws -> NovoPenReadResult, file: StaticString = #filePath, line: UInt = #line) async -> Error? {
        do {
            let result = try await run()
            XCTFail("expected a throw, got \(result)", file: file, line: line)
            return nil
        } catch {
            return error
        }
    }

    // MARK: - Tests

    /// Adding a pen, or a pen not added yet: stop after the serial, release, no doses.
    func testStopsAfterSerialWhenDosesNotWanted() async throws {
        let frames: [Result<Data, Error>] = [F.aRequest, F.configReport, Data(), F.deviceInfo, releaseResponse].map { .success($0) }
        let channel = ScriptedChannel(frames)
        let result = try await NovoPenSession(channel: channel, now: { [now] in now }, wantsDoses: { _ in false }).run()
        XCTAssertEqual(result.serial, "EGDO2U")
        XCTAssertTrue(result.doses.isEmpty)
        XCTAssertTrue(result.completed)
        XCTAssertEqual(channel.outbound.last, NovoPenEncoder.releaseRequest)
        XCTAssertFalse(channel.outbound.contains(NovoPenEncoder.getSegmentInfo(invokeId: 0)))
    }

    func testFullRead() async throws {
        let channel = ScriptedChannel(handshake() + [.success(F.doseReport), .success(releaseResponse)])
        var progress: [Int] = []
        let result = try await NovoPenSession(channel: channel, now: { [now] in now }, progress: { progress.append($0) }).run()

        XCTAssertEqual(channel.outbound[0], F.aResponse)
        XCTAssertEqual(channel.outbound[1], F.acceptConfig)
        // every request echoes the last invoke id the pen sent, as Android
        XCTAssertEqual(channel.outbound, [
            F.aResponse,
            F.acceptConfig,
            F.askInfo,
            NovoPenEncoder.getSegmentInfo(invokeId: 0),
            NovoPenEncoder.triggerTransfer(invokeId: 1, segment: 16),
            Data(),
            NovoPenEncoder.confirmSegmentData(invokeId: 0x8001, instance: 16, index: 0, count: 3),
            NovoPenEncoder.releaseRequest,
        ])
        XCTAssertEqual(channel.received, 8, "the release response is read")

        XCTAssertEqual(result.serial, "EGDO2U")
        XCTAssertEqual(result.model, "Novo Nordisk A/S NovoPen")
        XCTAssertEqual(result.doses.map(\.units), [3.0, 2.0])
        XCTAssertEqual(result.doses.map(\.relativeTime), [116177, 331])
        XCTAssertEqual(result.doses.first?.date, now.addingTimeInterval(-66))
        XCTAssertEqual(result.skipped, 1)
        XCTAssertTrue(result.completed)
        XCTAssertEqual(progress, [2])
    }

    func testStopsOnceDosesAreOlderThanImportWindow() async throws {
        let channel = ScriptedChannel(handshake(segmentInfo: segmentInfo(usage: 6))
            + [.success(doseReport(eventRelativeTime: 116243 + 8 * 86400)), .success(releaseResponse)])
        let result = try await session(channel).run()

        XCTAssertEqual(channel.sent(afterReceiving: 7), [NovoPenEncoder.releaseRequest], "release right after the dose report, no confirm")
        XCTAssertEqual(result.doses.count, 2)
        XCTAssertTrue(result.completed)
    }

    func testErrorEntriesAreSkippedNotFatal() async throws {
        var report = F.doseReport
        for entry in 0..<3 {
            let flags = Self.doseEntries + entry * 12 + 8
            report.replaceSubrange(flags..<flags + 4, with: [0x04, 0x00, 0x00, 0x08])
        }
        let channel = ScriptedChannel(handshake() + [.success(report), .success(releaseResponse)])
        let result = try await session(channel).run()

        XCTAssertEqual(channel.sent(afterReceiving: 7), [
            NovoPenEncoder.confirmSegmentData(invokeId: 0x8001, instance: 16, index: 0, count: 3),
            NovoPenEncoder.releaseRequest,
        ])
        XCTAssertEqual(result.doses, [])
        XCTAssertEqual(result.skipped, 3)
        XCTAssertTrue(result.completed)
    }

    /// A new pen has nothing logged: no transfer, a normal release, a complete read.
    func testEmptySegmentSkipsTransfer() async throws {
        let channel = ScriptedChannel([F.aRequest, F.configReport, Data(), F.deviceInfo, segmentInfo(usage: 0), releaseResponse].map { .success($0) })
        let result = try await session(channel).run()

        XCTAssertEqual(channel.outbound, [F.aResponse, F.acceptConfig, F.askInfo, NovoPenEncoder.getSegmentInfo(invokeId: 0), NovoPenEncoder.releaseRequest])
        XCTAssertTrue(result.completed)
        XCTAssertEqual(result.doses, [])
    }

    /// IEEE 11073-20601 response 3, segment empty: the end of the log, not a reason to ask again.
    func testRefusedTransferEndsTheRead() async throws {
        var refused = F.triggerResponse
        refused[refused.count - 1] = 3
        let channel = ScriptedChannel(Array(handshake().dropLast()) + [.success(refused), .success(releaseResponse)])
        let result = try await session(channel).run()

        XCTAssertEqual(channel.sent(afterReceiving: 6), [NovoPenEncoder.releaseRequest])
        XCTAssertTrue(result.completed)
        XCTAssertEqual(result.doses, [])
    }

    func testMalformedFrameIsNotFatal() async throws {
        let malformed = Data(hexadecimalString: "e7000002")!
        let channel = ScriptedChannel(handshake() + [.success(malformed), .success(F.doseReport), .success(releaseResponse)])
        let result = try await session(channel).run()

        XCTAssertEqual(channel.sent(afterReceiving: 7), [Data()])
        XCTAssertTrue(result.completed)
        XCTAssertEqual(result.doses.map(\.units), [3.0, 2.0])
    }

    func testNonTypicalSegmentsThrows() async {
        var info = F.segmentInfo
        let otype = info.firstRange(of: Data([0x34, 0x01]))!
        info[otype.upperBound - 1] = 0x02
        let channel = ScriptedChannel(handshake(segmentInfo: info))

        let error = await expectThrows { try await session(channel).run() }
        guard case NovoPenError.nonTypicalSegments = error ?? ScriptedChannel.LinkLost() else { return XCTFail("\(String(describing: error))") }
    }

    func testTransportFailureAfterDosesReturnsPartialResult() async throws {
        let lost = ScriptedChannel.LinkLost()
        let channel = ScriptedChannel(handshake(segmentInfo: segmentInfo(usage: 6))
            + [.success(F.doseReport), .failure(lost), .failure(lost), .failure(lost)])
        let result = try await session(channel).run()

        XCTAssertFalse(result.completed)
        XCTAssertEqual(result.serial, "EGDO2U")
        XCTAssertEqual(result.doses.count, 2)
        XCTAssertEqual(result.skipped, 1)
        XCTAssertEqual(channel.received, 10, "3 failed receives, no more")
    }

    /// A dose list shorter than its count must not finish the segment, even when index + count reaches the usage.
    func testTruncatedDoseListDoesNotCompleteSegment() async throws {
        let truncated = F.doseReport.dropLast(12)   // count 3, only the two valid entries
        let channel = ScriptedChannel(handshake() + [.success(Data(truncated)), .success(releaseRequestFromPen)])
        let result = try await session(channel).run()

        XCTAssertEqual(channel.sent(afterReceiving: 7), [NovoPenEncoder.confirmSegmentData(invokeId: 0x8001, instance: 16, index: 0, count: 3)])
        XCTAssertEqual(channel.sent(afterReceiving: 8), [NovoPenEncoder.releaseRequest], "the pen's release is answered")
        XCTAssertFalse(result.completed)
        XCTAssertEqual(result.doses.map(\.units), [3.0, 2.0])
        XCTAssertEqual(result.skipped, 0)
    }

    /// The pen moves on after our confirm, so entries missing from a short frame are lost for this read even if a later frame ends the segment.
    func testShortFrameMidLogMakesReadIncomplete() async throws {
        let short = Data(F.doseReport.dropLast(12))   // index 0, count 3, only the two valid entries
        var last = F.doseReport
        XCTAssertEqual(last.subdata(in: 24..<28), Data([0, 0, 0, 0]), "index 0")
        last[27] = 3   // index 3, count 3, complete
        let channel = ScriptedChannel(handshake(segmentInfo: segmentInfo(usage: 6)) + [.success(short), .success(last), .success(releaseResponse)])
        let result = try await session(channel).run()

        XCTAssertEqual(channel.sent(afterReceiving: 8), [
            NovoPenEncoder.confirmSegmentData(invokeId: 0x8001, instance: 16, index: 3, count: 3),
            NovoPenEncoder.releaseRequest,
        ], "the segment end still ends the read")
        XCTAssertFalse(result.completed)
        XCTAssertEqual(result.doses.count, 4)
    }

    func testFailureBeforeSerialThrows() async {
        let lost = ScriptedChannel.LinkLost()
        let channel = ScriptedChannel([.failure(lost), .failure(lost), .failure(lost), .success(F.aRequest)])

        let error = await expectThrows { try await session(channel).run() }
        XCTAssertTrue(error is ScriptedChannel.LinkLost)
        XCTAssertEqual(channel.received, 3)
    }

    func testTransactionCap() async {
        let channel = ScriptedChannel([], endless: Data())

        let error = await expectThrows { try await session(channel).run() }
        guard case NovoPenError.limitExceeded = error ?? ScriptedChannel.LinkLost() else { return XCTFail("\(String(describing: error))") }
        XCTAssertEqual(channel.received, 200)
    }
}
