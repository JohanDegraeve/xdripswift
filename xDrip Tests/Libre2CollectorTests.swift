import Foundation
import XCTest
@testable import xdrip

final class Libre2CollectorTests: XCTestCase {
    private var directory: URL!
    private var sessionURL: URL { directory.appendingPathComponent("session.json") }

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try FileManager.default.removeItem(at: directory)
    }

    private func session(id: UUID = UUID(), count: UInt16 = 17, code: UInt32 = 42) -> Libre2WatchSession {
        Libre2WatchSession(id: id, sensorUID: Data(hexadecimalString: "e3a18e0100a407e0")!,
            patchInfo: Data(hexadecimalString: "9d0830017317")!, serialNumber: "test", bluetoothName: "ABBOTTtest",
            unlockCode: code, unlockCount: count,
            algorithmParameters: Libre1DerivedAlgorithmParameters(slope_slope: 0, slope_offset: 0,
                offset_slope: 0.1, offset_offset: 0, isValidForFooterWithReverseCRCs: 0,
                extraSlope: 1, extraOffset: 0, sensorSerialNumber: "test"))
    }

    func testSessionRoundTrip() throws {
        let original = session()
        try original.save(to: sessionURL)
        let restored = try Libre2WatchSession.load(from: sessionURL)
        XCTAssertEqual(restored.id, original.id)
        XCTAssertEqual(restored.sensorUID, original.sensorUID)
        XCTAssertEqual(restored.patchInfo, original.patchInfo)
        XCTAssertEqual(restored.unlockCode, original.unlockCode)
        XCTAssertEqual(restored.unlockCount, original.unlockCount)
        XCTAssertEqual(restored.bluetoothName, original.bluetoothName)
        XCTAssertEqual(restored.algorithmParameters.description, original.algorithmParameters.description)
    }

    func testCounterIsSavedBeforeUnlockIsReturnedAndSurvivesRestartWithoutReadings() throws {
        try session().save(to: sessionURL)
        let sensor = try Libre2WatchSensor(sessionURL: sessionURL)
        let unlock = try sensor.reserveUnlock()
        XCTAssertEqual(unlock.count, 18)
        XCTAssertEqual(try Libre2WatchSession.load(from: sessionURL).unlockCount, unlock.count)
        XCTAssertEqual(Data(Libre2BLEUtilities.streamingUnlockPayload(sensorUID: sensor.sensorUID!, info: sensor.patchInfo!, enableTime: unlock.code, unlockCount: unlock.count)).hexEncodedString(), "3c00000073e808168a009e02")
        // No glucose or successful write is reported before the next instance connects.
        let restarted = try Libre2WatchSensor(sessionURL: sessionURL)
        XCTAssertEqual(try restarted.reserveUnlock().count, 19)
        XCTAssertEqual(try Libre2WatchSession.load(from: sessionURL).unlockCount, 19)
    }

    func testReplacedSessionCannotReserveUnlock() throws {
        try session().save(to: sessionURL)
        let sensor = try Libre2WatchSensor(sessionURL: sessionURL)
        let replacement = session(count: 2)
        try replacement.save(to: sessionURL)
        XCTAssertThrowsError(try sensor.reserveUnlock()) { error in
            guard case Libre2WatchSession.SessionError.sessionChanged = error else {
                return XCTFail("Unexpected error: \(error)")
            }
        }
        XCTAssertEqual(try Libre2WatchSession.load(from: sessionURL).unlockCount, 2)
    }

    func testSaveFailureDoesNotReturnAnUnlock() throws {
        try session().save(to: sessionURL)
        let sensor = try Libre2WatchSensor(sessionURL: sessionURL)
        try FileManager.default.setAttributes([.posixPermissions: 0o500], ofItemAtPath: directory.path)
        defer { try? FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: directory.path) }
        XCTAssertThrowsError(try sensor.reserveUnlock())
        XCTAssertEqual(sensor.session.unlockCount, 17)
        XCTAssertEqual(try Libre2WatchSession.load(from: sessionURL).unlockCount, 17)
    }

    func testCounterAndUnlockCodeCannotOverflow() throws {
        for exhausted in [session(count: .max), session(count: 17, code: .max)] {
            try exhausted.save(to: sessionURL)
            let sensor = try Libre2WatchSensor(sessionURL: sessionURL)
            XCTAssertThrowsError(try sensor.reserveUnlock())
            XCTAssertEqual(try Libre2WatchSession.load(from: sessionURL).unlockCount, exhausted.unlockCount)
        }
    }

    func testIncompleteSessionCannotBeLoaded() throws {
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(session())) as? [String: Any])
        object["sensorUID"] = Data([1, 2]).base64EncodedString()
        try JSONSerialization.data(withJSONObject: object).write(to: sessionURL)
        XCTAssertThrowsError(try Libre2WatchSensor(sessionURL: sessionURL))
    }

    func testPhoneStillAdvancesCounterWhenUnlockIsSuppressed() throws {
        let suite = "Libre2CollectorTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.libreActiveSensorUnlockCode = 42
        defaults.libreActiveSensorUnlockCount = 17
        defaults.suppressUnLockPayLoad = true
        let sensor = Libre2PhoneSensor(serialNumber: "test", webOOPEnabled: true, defaults: defaults)
        let suppressed = try sensor.reserveUnlock()
        XCTAssertFalse(suppressed.shouldWrite)
        XCTAssertEqual(suppressed.count, 18)
        XCTAssertEqual(defaults.libreActiveSensorUnlockCount, 18)
        defaults.suppressUnLockPayLoad = false
        let enabled = try sensor.reserveUnlock()
        XCTAssertTrue(enabled.shouldWrite)
        XCTAssertEqual(enabled.count, 19)
    }
}
