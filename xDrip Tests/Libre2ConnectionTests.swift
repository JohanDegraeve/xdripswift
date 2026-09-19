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

    func testRuntimeRequestsRoundTripAndRejectInvalidAccuracy() throws {
        let requests: [Libre2LocationRequest] = [.inspect, .setEnabled(true), .setEnabled(false),
            .setAccuracy(.hundredMeters), .setAccuracy(.kilometer), .setAccuracy(.threeKilometers)]
        for request in requests {
            XCTAssertEqual(try Libre2LocationRequest.decode(request.dictionary), request)
        }
        XCTAssertThrowsError(try Libre2LocationRequest.decode([Libre2LocationRequest.key: true]))
        let encoded = try JSONEncoder().encode(Libre2LocationRequest.setAccuracy(.hundredMeters))
        let invalid = String(decoding: encoded, as: UTF8.self).replacingOccurrences(of: "100", with: "-1")
        XCTAssertThrowsError(try Libre2LocationRequest.decode([Libre2LocationRequest.key: Data(invalid.utf8)]))
    }

    func testSelectionNotificationCanReadDurableSnapshotWithoutLocking() throws {
        let store = Libre2ConnectionStore(directory: directory)
        let changed = expectation(description: "selection change")
        let observer = NotificationCenter.default.addObserver(forName: Libre2ConnectionStore.didChange,
                                                               object: nil, queue: .main) { notification in
            guard let source = notification.object as? Libre2ConnectionStore, source === store else { return }
            XCTAssertEqual(store.snapshot?.phase, .preparingWatch)
            XCTAssertEqual(Libre2ConnectionStore(directory: self.directory).snapshot?.phase, .preparingWatch)
            changed.fulfill()
        }
        defer { NotificationCenter.default.removeObserver(observer) }
        try store.select(.preparingWatch, sessionID: UUID())
        wait(for: [changed], timeout: 2)
    }

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
