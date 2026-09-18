import Foundation
import XCTest
@testable import xdrip

final class Libre2ConnectionTests: XCTestCase {
    private var directory: URL!
    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }
    override func tearDownWithError() throws { try FileManager.default.removeItem(at: directory) }

    func testOrdinaryPhoneSelectionDoesNotCreateFiles() throws {
        let store = Libre2ConnectionStore(directory: directory)
        XCTAssertEqual(store.snapshot?.allowsPhone, true)
        XCTAssertEqual(store.snapshot?.allowsWatch, false)
        XCTAssertTrue(try FileManager.default.contentsOfDirectory(atPath: directory.path).isEmpty)
    }

    func testPrepareDoesNotEnableWatchAndReleasedSelectionSurvivesRestart() throws {
        let store = Libre2ConnectionStore(directory: directory)
        let id = UUID()
        try store.select(.preparingWatch, sessionID: id)
        XCTAssertEqual(store.snapshot?.allowsPhone, true)
        XCTAssertEqual(store.snapshot?.allowsWatch, false)
        try store.select(.watch, sessionID: id)
        let restarted = Libre2ConnectionStore(directory: directory)
        XCTAssertEqual(restarted.snapshot?.allowsPhone, false)
        XCTAssertEqual(restarted.snapshot?.allowsWatch, true)
    }

    func testReturnKeepsBothCollectorsDisabledUntilCommit() throws {
        let store = Libre2ConnectionStore(directory: directory)
        let id = UUID()
        try store.select(.preparingWatch, sessionID: id)
        try store.select(.watch, sessionID: id)
        try store.select(.returningToPhone, sessionID: id)
        let restarted = Libre2ConnectionStore(directory: directory)
        XCTAssertEqual(restarted.snapshot?.allowsPhone, false)
        XCTAssertEqual(restarted.snapshot?.allowsWatch, false)
        try restarted.select(.phone, sessionID: id)
        XCTAssertEqual(restarted.snapshot?.allowsPhone, true)
        XCTAssertEqual(restarted.snapshot?.allowsWatch, false)
    }

    func testDuplicateCommitsAreIdempotentButLateActivationIsRejected() throws {
        let store = Libre2ConnectionStore(directory: directory)
        let id = UUID()
        try store.select(.preparingWatch, sessionID: id)
        try store.select(.watch, sessionID: id)
        try store.select(.watch, sessionID: id)
        try store.select(.returningToPhone, sessionID: id)
        try store.select(.phone, sessionID: id)
        try store.select(.phone, sessionID: id)
        XCTAssertThrowsError(try store.select(.watch, sessionID: id))
        XCTAssertThrowsError(try store.select(.preparingWatch, sessionID: id))
    }

    func testStaleIDCannotActivateReturnOrReplaceActiveSelection() throws {
        let store = Libre2ConnectionStore(directory: directory)
        let id = UUID(), stale = UUID()
        try store.select(.preparingWatch, sessionID: id)
        XCTAssertThrowsError(try store.select(.watch, sessionID: stale))
        try store.select(.watch, sessionID: id)
        XCTAssertThrowsError(try store.select(.preparingWatch, sessionID: stale))
        XCTAssertThrowsError(try store.select(.returningToPhone, sessionID: stale))
        XCTAssertEqual(store.snapshot?.sessionID, id)
    }

    func testNFCResetRetiresTransferAndDoesNotDependOnWatchReply() throws {
        let store = Libre2ConnectionStore(directory: directory)
        let id = UUID()
        try store.select(.preparingWatch, sessionID: id)
        try store.select(.watch, sessionID: id)
        try store.resetToPhone()
        let restarted = Libre2ConnectionStore(directory: directory)
        XCTAssertEqual(restarted.snapshot?.allowsPhone, true)
        XCTAssertNil(restarted.snapshot?.sessionID)
        XCTAssertThrowsError(try restarted.select(.preparingWatch, sessionID: id))
    }

    func testOldRevocationCannotStopNewSession() throws {
        let store = Libre2ConnectionStore(directory: directory)
        let old = UUID(), current = UUID()
        try store.select(.preparingWatch, sessionID: old)
        try store.resetToPhone()
        try store.select(.preparingWatch, sessionID: current)
        try store.select(.watch, sessionID: current)
        XCTAssertFalse(try store.revoke([old]))
        XCTAssertEqual(store.snapshot?.allowsWatch, true)
        XCTAssertTrue(try store.revoke([current]))
        XCTAssertEqual(store.snapshot?.allowsWatch, false)
    }

    func testCorruptSelectionFailsClosedUntilExplicitNFCReset() throws {
        try Data("broken".utf8).write(to: directory.appendingPathComponent("selection.json"))
        let store = Libre2ConnectionStore(directory: directory)
        XCTAssertNil(store.snapshot)
        XCTAssertThrowsError(try store.select(.watch, sessionID: UUID()))
        try store.resetToPhone()
        XCTAssertEqual(store.snapshot?.allowsPhone, true)
    }

    func testSaveFailureCannotEnableOtherCollector() throws {
        let store = Libre2ConnectionStore(directory: directory)
        let id = UUID()
        try store.select(.preparingWatch, sessionID: id)
        try FileManager.default.setAttributes([.posixPermissions: 0o500], ofItemAtPath: directory.path)
        defer { try? FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: directory.path) }
        XCTAssertThrowsError(try store.select(.watch, sessionID: id))
        XCTAssertEqual(store.snapshot?.allowsWatch, false)
        XCTAssertEqual(Libre2ConnectionStore(directory: directory).snapshot?.allowsWatch, false)
    }
}
