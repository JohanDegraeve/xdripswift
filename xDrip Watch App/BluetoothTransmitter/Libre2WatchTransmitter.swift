import Foundation

/// The switching coordinator must construct this only after the phone releases its connection.
/// No app startup or UI path instantiates it until that coordinator is in place.
final class Libre2WatchTransmitter: Libre2BluetoothTransmitter {
    private let readingsReceived: ([GlucoseData], UInt16) -> Void

    init(sessionURL: URL, bluetoothTransmitterDelegate: BluetoothTransmitterDelegate, readingsReceived: @escaping ([GlucoseData], UInt16) -> Void) throws {
        let sensor = try Libre2WatchSensor(sessionURL: sessionURL)
        self.readingsReceived = readingsReceived
        super.init(addressAndName: .notYetConnected(expectedName: sensor.session.bluetoothName), sensor: sensor, bluetoothTransmitterDelegate: bluetoothTransmitterDelegate)
    }

    override func received(glucoseData: [GlucoseData], sensorTimeInMinutes: UInt16) {
        readingsReceived(glucoseData, sensorTimeInMinutes)
    }
}
