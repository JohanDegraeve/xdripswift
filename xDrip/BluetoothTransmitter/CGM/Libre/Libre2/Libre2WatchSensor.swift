import Foundation

/// The active collector reserves counters on its Bluetooth queue and parses history on main.
/// Session replacement belongs to the phone-controlled switching coordinator.
final class Libre2WatchSensor: Libre2SensorDataSource {
    private(set) var session: Libre2WatchSession
    private let sessionURL: URL
    // Parsing on main must not read the session whose counter is updated on the BLE queue.
    private let algorithmParameters: Libre1DerivedAlgorithmParameters
    private var parserState = Libre2BLEUtilities.ParserState()

    init(sessionURL: URL) throws {
        session = try Libre2WatchSession.load(from: sessionURL)
        self.sessionURL = sessionURL
        algorithmParameters = session.algorithmParameters
    }

    var sensorUID: Data? { session.sensorUID }
    var patchInfo: Data? { session.patchInfo }

    func reserveUnlock() throws -> Libre2StreamingUnlock {
        // Reload so a failed/uncertain save cannot cause an attempted counter to be reused.
        var saved = try Libre2WatchSession.load(from: sessionURL)
        guard saved.id == session.id,
              saved.sensorUID == session.sensorUID,
              saved.patchInfo == session.patchInfo,
              saved.unlockCode == session.unlockCode else {
            throw Libre2WatchSession.SessionError.sessionChanged
        }
        let previousCount = max(saved.unlockCount, session.unlockCount)
        guard previousCount < UInt16.max,
              saved.unlockCode <= UInt32.max - UInt32(previousCount) - 1 else {
            throw Libre2WatchSession.SessionError.counterExhausted
        }
        saved.unlockCount = previousCount + 1
        try saved.save(to: sessionURL)
        session = saved
        return Libre2StreamingUnlock(code: saved.unlockCode, count: saved.unlockCount)
    }

    func parseBLEFrame(_ decryptedFrame: Data, date: Date) -> (bleGlucose: [GlucoseData], sensorTimeInMinutes: UInt16)? {
        return Libre2BLEUtilities.parseBLEData(decryptedFrame, libre1DerivedAlgorithmParameters: algorithmParameters, state: &parserState, date: date)
    }
}
