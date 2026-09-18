import Foundation

/// The switching coordinator must construct this only after the phone releases its connection.
/// The Watch connection manager checks the persisted selection before constructing it.
final class Libre2WatchTransmitter: Libre2BluetoothTransmitter {
    override var isConnectionAllowed: Bool {
        let selection = Libre2ConnectionStore.shared.snapshot
        return super.isConnectionAllowed && selection?.allowsWatch == true && selection?.sessionID == sessionID
    }

    let sessionID: UUID
    private let readingsReceived: ([GlucoseData], UInt16) -> Void

    init(sessionURL: URL, bluetoothTransmitterDelegate: BluetoothTransmitterDelegate, readingsReceived: @escaping ([GlucoseData], UInt16) -> Void) throws {
        let sensor = try Libre2WatchSensor(sessionURL: sessionURL)
        sessionID = sensor.session.id
        self.readingsReceived = readingsReceived
        let device = BluetoothTransmitter.rememberedDevice(named: sensor.session.bluetoothName) ?? .notYetConnected(expectedName: sensor.session.bluetoothName)
        super.init(addressAndName: device, sensor: sensor, bluetoothTransmitterDelegate: bluetoothTransmitterDelegate, restorationIdentifier: "DirectLibre-" + sensor.session.sensorUID.hexEncodedString())
    }

    override func received(glucoseData: [GlucoseData], sensorTimeInMinutes: UInt16) {
        readingsReceived(glucoseData, sensorTimeInMinutes)
    }
}
