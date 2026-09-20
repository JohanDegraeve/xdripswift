import XCTest
@testable import xdrip

final class Libre2DiagnosticCaptureTests: XCTestCase {
    private var directory: URL!
    private var now = Date(timeIntervalSince1970: 1_800_000_000)
    private var capture: Libre2DiagnosticCapture!

    override func setUp() {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        capture = makeCapture()
    }
    override func tearDown() { try? FileManager.default.removeItem(at: directory) }
    private func makeCapture() -> Libre2DiagnosticCapture {
        Libre2DiagnosticCapture(directory: directory, clock: { self.now }, uptime: { 123.5 })
    }
    private func export(_ capture: Libre2DiagnosticCapture) throws -> String {
        let status = try XCTUnwrap(capture.status)
        var download = Libre2DiagnosticCapture.Download(status: status)
        repeat {
            let offset = download.data.count
            try download.append(["captureID": status.id.uuidString, "offset": offset,
                                 "data": capture.chunk(id: status.id, offset: offset)])
        } while !download.isComplete
        return try Libre2DiagnosticCapture.report(status: status, data: download.data)
    }

    func testDisabledCaptureDoesNotEvaluateDetailsOrCreateFiles() {
        var called = false
        func detail() -> String { called = true; return "event" }
        capture.record(detail())
        XCTAssertFalse(called)
        XCTAssertFalse(FileManager.default.fileExists(atPath: directory.path))
    }

    func testNinetyMinuteCaptureSurvivesRelaunchAndExportsEveryChunk() throws {
        let id = UUID()
        try capture.start(id: id)
        for minute in 0..<90 {
            now = now.addingTimeInterval(60)
            for event in 0..<12 { capture.record("minute=\(minute) event=\(event)") }
            if minute == 45 { capture = makeCapture(); capture.record("Relaunched") }
        }
        try capture.stop(id: id)
        XCTAssertGreaterThan(capture.status!.bytes, Libre2DiagnosticCapture.chunkBytes)
        let report = try export(capture)
        XCTAssertTrue(report.contains("minute=0 event=0"))
        XCTAssertTrue(report.contains("minute=89 event=11"))
        XCTAssertTrue(report.contains("Relaunched"))
        XCTAssertEqual(capture.status!.events, 1083)
        XCTAssertTrue(report.contains("run="))
        XCTAssertTrue(report.contains("uptime=123.500"))
    }

    func testStartAndStopAreIdempotentButStaleIDsCannotAffectCapture() throws {
        let id = UUID()
        try capture.start(id: id)
        capture.record("Preserve me")
        let bytes = capture.status!.bytes
        try capture.start(id: id)
        XCTAssertEqual(capture.status!.bytes, bytes)
        XCTAssertThrowsError(try capture.start(id: UUID()))
        XCTAssertThrowsError(try capture.stop(id: UUID()))
        XCTAssertThrowsError(try capture.chunk(id: UUID(), offset: 0))
        XCTAssertThrowsError(try capture.chunk(id: id, offset: 0)) // still recording
        try capture.stop(id: id)
        let finalBytes = capture.status!.bytes
        try capture.stop(id: id)
        XCTAssertEqual(capture.status!.bytes, finalBytes)
        XCTAssertTrue(try export(capture).contains("Preserve me"))
    }

    func testExpirationOnNextEventDoesNotNeedATimerAndSurvivesRestart() throws {
        let id = UUID()
        try capture.start(id: id)
        now = now.addingTimeInterval(Libre2DiagnosticCapture.duration + 60)
        capture = makeCapture()
        capture.record("Too late")
        XCTAssertFalse(capture.status!.isRecording)
        XCTAssertTrue(capture.status!.reason!.contains("Two-hour"))
        XCTAssertFalse(try export(capture).contains("Too late"))
    }

    func testCapacityPreservesBeginningAndExplicitlyMarksTruncation() throws {
        try capture.start(id: UUID())
        for index in 0..<6_000 { capture.record("Event \(index)") }
        XCTAssertEqual(capture.status!.events, Libre2DiagnosticCapture.maximumEvents)
        XCTAssertLessThanOrEqual(capture.status!.bytes, Libre2DiagnosticCapture.maximumBytes)
        let report = try export(capture)
        XCTAssertTrue(report.contains("Event 0"))
        XCTAssertTrue(report.contains("capacity reached"))
        XCTAssertFalse(report.contains("Event 5999"))
    }

    func testByteLimitAlsoPreservesATerminalReason() throws {
        try capture.start(id: UUID())
        for _ in 0..<3_000 { capture.record(String(repeating: "x", count: 1_200)) }
        XCTAssertFalse(capture.status!.isRecording)
        XCTAssertLessThan(capture.status!.events, Libre2DiagnosticCapture.maximumEvents)
        XCTAssertLessThanOrEqual(capture.status!.bytes, Libre2DiagnosticCapture.maximumBytes)
        XCTAssertTrue(try export(capture).contains("capacity reached"))
    }

    func testWriteFailureIsReportedWithoutThrowingFromCollectorLogging() throws {
        let id = UUID()
        try capture.start(id: id)
        try FileManager.default.removeItem(at: directory.appendingPathComponent(id.uuidString + ".txt"))
        capture.record("Cannot append")
        XCTAssertNotNil(capture.status!.storageError)
        XCTAssertFalse(capture.status!.isRecording)
        XCTAssertThrowsError(try capture.chunk(id: id, offset: 0))
    }

    func testIncompleteAppendIsPreservedAndFlaggedOnRelaunch() throws {
        let id = UUID()
        try capture.start(id: id)
        let handle = try FileHandle(forWritingTo: directory.appendingPathComponent(id.uuidString + ".txt"))
        try handle.seekToEnd()
        try handle.write(contentsOf: Data("partial".utf8))
        try handle.close()
        capture = makeCapture()
        XCTAssertNotNil(capture.status!.storageError)
        try capture.stop(id: id)
        XCTAssertTrue(try export(capture).contains("partial"))
    }

    func testChunkValidationRejectsWrongCaptureOffsetsAndMissingBytes() throws {
        let id = UUID()
        try capture.start(id: id)
        try capture.stop(id: id)
        let status = capture.status!
        let chunk = try capture.chunk(id: id, offset: 0)
        var download = Libre2DiagnosticCapture.Download(status: status)
        XCTAssertThrowsError(try download.append(["captureID": UUID().uuidString, "offset": 0, "data": chunk]))
        XCTAssertThrowsError(try download.append(["captureID": id.uuidString, "offset": 1, "data": chunk]))
        XCTAssertThrowsError(try download.append(["captureID": id.uuidString, "offset": 0, "data": Data()]))
        try download.append(["captureID": id.uuidString, "offset": 0, "data": chunk])
        XCTAssertTrue(download.isComplete)
        XCTAssertThrowsError(try download.append(["captureID": id.uuidString, "offset": 0, "data": chunk]))
        XCTAssertThrowsError(try capture.chunk(id: id, offset: -1))
        XCTAssertThrowsError(try capture.chunk(id: id, offset: status.bytes + 1))
    }

    func testNewCaptureInvalidatesOldExportAndRemovesOnlyOldCaptureFile() throws {
        let old = UUID(), new = UUID()
        try capture.start(id: old)
        try capture.stop(id: old)
        try capture.start(id: new)
        XCTAssertThrowsError(try capture.chunk(id: old, offset: 0))
        XCTAssertFalse(FileManager.default.fileExists(atPath: directory.appendingPathComponent(old.uuidString + ".txt").path))
        capture = makeCapture()
        XCTAssertEqual(capture.status!.id, new)
        XCTAssertTrue(capture.status!.isRecording)
    }

    func testCorruptMetadataReportsWarningButAllowsExplicitNewCapture() throws {
        try capture.start(id: UUID())
        try Data("bad metadata".utf8).write(to: directory.appendingPathComponent("capture.json"))
        capture = makeCapture()
        var reply: [String: Any] = [:]
        capture.receive([Libre2DiagnosticCapture.commandKey: "status"]) { reply = $0 }
        XCTAssertNil(try Libre2DiagnosticCapture.decodeStatus(reply))
        XCTAssertNotNil(reply["captureWarning"])
        let id = UUID()
        try capture.start(id: id)
        XCTAssertEqual(capture.status!.id, id)
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "txt" }.count, 1)
    }

}

final class Libre2DiagnosticRecorderTests: XCTestCase {
    private var directory: URL!
    override func setUp() { directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString) }
    override func tearDown() { try? FileManager.default.removeItem(at: directory) }

    private func command(_ recorder: Libre2DiagnosticRecorder, _ command: String, id: UUID? = nil, offset: Int? = nil) -> [String: Any] {
        let done = expectation(description: command)
        var response: [String: Any] = [:]
        var message: [String: Any] = [Libre2DiagnosticCapture.commandKey: command]
        if let id { message["captureID"] = id.uuidString }
        if let offset { message["offset"] = offset }
        recorder.receive(message) { response = $0; done.fulfill() }
        wait(for: [done], timeout: 10)
        return response
    }

    func testDisabledRecorderDoesNotEvaluateDetailsAndStopDrainsAcceptedEvents() throws {
        let recorder = Libre2DiagnosticRecorder(directory: directory)
        _ = command(recorder, "status")
        var evaluated = false
        func detail() -> String { evaluated = true; return "unexpected" }
        recorder.record(detail())
        XCTAssertFalse(evaluated)
        XCTAssertFalse(FileManager.default.fileExists(atPath: directory.path))
        let id = UUID()
        XCTAssertNotNil(try Libre2DiagnosticCapture.decodeStatus(command(recorder, "start", id: id)))
        for number in 0..<100 { recorder.record("ordered event \(number)") }
        let stopped = try XCTUnwrap(Libre2DiagnosticCapture.decodeStatus(command(recorder, "stop", id: id)))
        XCTAssertFalse(recorder.isRecording)
        recorder.record("after stop")
        let chunk = command(recorder, "chunk", id: id, offset: 0)["data"] as! Data
        let text = try Libre2DiagnosticCapture.report(status: stopped, data: chunk)
        XCTAssertTrue(text.contains("ordered event 0"))
        XCTAssertTrue(text.contains("ordered event 99"))
        XCTAssertFalse(text.contains("after stop"))
        XCTAssertTrue(text.contains("origin="))
    }

    func testStaleStopDoesNotDisableActiveRecording() throws {
        let recorder = Libre2DiagnosticRecorder(directory: directory)
        let id = UUID()
        _ = command(recorder, "start", id: id)
        XCTAssertNotNil(command(recorder, "stop", id: UUID())["error"])
        XCTAssertTrue(recorder.isRecording)
        recorder.record("still running")
        let stopped = try XCTUnwrap(Libre2DiagnosticCapture.decodeStatus(command(recorder, "stop", id: id)))
        XCTAssertEqual(stopped.events, 3)
    }

    func testConcurrentEventsRemainBoundedAndReportAnyLoss() throws {
        let recorder = Libre2DiagnosticRecorder(directory: directory)
        let id = UUID()
        _ = command(recorder, "start", id: id)
        DispatchQueue.concurrentPerform(iterations: 1_000) { recorder.record("concurrent event \($0)") }
        let stopped = try XCTUnwrap(Libre2DiagnosticCapture.decodeStatus(command(recorder, "stop", id: id)))
        var download = Libre2DiagnosticCapture.Download(status: stopped)
        repeat { try download.append(command(recorder, "chunk", id: id, offset: download.data.count)) } while !download.isComplete
        let report = try Libre2DiagnosticCapture.report(status: stopped, data: download.data)
        let recorded = report.components(separatedBy: "concurrent event ").count - 1
        XCTAssertGreaterThan(recorded, 0)
        if recorded < 1_000 { XCTAssertTrue(report.contains("events dropped")) }
        XCTAssertLessThanOrEqual(stopped.events, Libre2DiagnosticCapture.maximumEvents)
    }

    func testOriginTimestampIsPreservedInsteadOfFileWriteTime() throws {
        let time = Date(timeIntervalSince1970: 1_800_000_000)
        let capture = Libre2DiagnosticCapture(directory: directory, clock: { time })
        let id = UUID()
        try capture.start(id: id)
        capture.record("delayed delivery", date: time.addingTimeInterval(-10), uptime: 7.25)
        try capture.stop(id: id)
        let data = try capture.chunk(id: id, offset: 0)
        let text = String(decoding: data, as: UTF8.self)
        XCTAssertTrue(text.contains("uptime=7.250"))
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        XCTAssertTrue(text.contains(formatter.string(from: time.addingTimeInterval(-10))))
    }
}
