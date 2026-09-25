import Foundation

/// NFC-provisioned credentials for one phone-authorised Watch collection session.
/// The counter is the last reserved attempt, not the last successful reading.
struct Libre2WatchSession: Codable {
    let id: UUID
    let sensorUID: Data
    let patchInfo: Data
    let serialNumber: String
    let bluetoothName: String
    let unlockCode: UInt32
    var unlockCount: UInt16
    let algorithmParameters: Libre1DerivedAlgorithmParameters

    func validate() throws {
        guard sensorUID.count == 8, patchInfo.count >= 6,
              !serialNumber.isEmpty, !bluetoothName.isEmpty,
              algorithmParameters.serialNumber == serialNumber else {
            throw SessionError.invalidSensor
        }
    }

    func save(to url: URL) throws {
        try validate()
        try JSONEncoder().encode(self).write(to: url, options: .atomic)
    }

    static func load(from url: URL) throws -> Libre2WatchSession {
        let session = try JSONDecoder().decode(Self.self, from: Data(contentsOf: url))
        try session.validate()
        return session
    }

    enum SessionError: LocalizedError {
        case invalidSensor
        case sessionChanged
        case counterExhausted

        var errorDescription: String? {
            switch self {
            case .invalidSensor: return "The Libre Watch session has incomplete or mismatched sensor information."
            case .sessionChanged: return "The Libre Watch session has changed. Collection must be restarted by the phone."
            case .counterExhausted: return "The Libre unlock counter is exhausted. Provision the sensor again on the phone."
            }
        }
    }
}
