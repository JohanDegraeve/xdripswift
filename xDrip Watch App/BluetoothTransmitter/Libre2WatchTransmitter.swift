import Foundation

/// The switching coordinator constructs this after the phone suspends collection and sends ACTIVATE.
/// The Watch connection manager checks the persisted selection before constructing it.
final class Libre2WatchTransmitter: Libre2BluetoothTransmitter {
    override var isConnectionAllowed: Bool {
        let selection = Libre2ConnectionStore.shared.snapshot
        return super.isConnectionAllowed && selection?.allowsWatch == true && selection?.sessionID == sessionID
    }

    private let diagnosticID = String(UUID().uuidString.prefix(8))

    #if os(watchOS)
    override func recordDiagnostic(_ message: @autoclosure () -> String) {
        Libre2WatchDiagnostics.shared.record("collector=\(diagnosticID) \(message())")
    }

    #endif

    let sessionID: UUID
    private let readingsReceived: ([GlucoseData], UInt16) -> Void

    init(sessionURL: URL, bluetoothTransmitterDelegate: BluetoothTransmitterDelegate, reuseKnownPeripheral: Bool = true, readingsReceived: @escaping ([GlucoseData], UInt16) -> Void) throws {
        let sensor = try Libre2WatchSensor(sessionURL: sessionURL)
        sessionID = sensor.session.id
        self.readingsReceived = readingsReceived
        let remembered = reuseKnownPeripheral ? BluetoothTransmitter.rememberedDevice(named: sensor.session.bluetoothName) : nil
        let device = remembered ?? .notYetConnected(expectedName: sensor.session.bluetoothName)
        super.init(addressAndName: device, sensor: sensor, bluetoothTransmitterDelegate: bluetoothTransmitterDelegate, restorationIdentifier: "DirectLibre-" + sensor.session.sensorUID.hexEncodedString())
    }

    override func received(glucoseData: [GlucoseData], sensorTimeInMinutes: UInt16) {
        recordDiagnostic("Watch adapter received readings=\(glucoseData.count) sensorMinute=\(sensorTimeInMinutes)")
        readingsReceived(glucoseData, sensorTimeInMinutes)
    }
}
