import Foundation
import CoreBluetooth

/// delegates are classes that will implement specific transmitters, however these are functions that are applicable to all types of transmitters
protocol BluetoothTransmitterDelegate {
    /// called when bluetooth state changes. This is not necessarily the status of the connection to the peripheral.
    ///
    /// whenever status changes to on, and if device address not known yet, then app might want to start scanning
    ///
    func bluetooth(didUpdateState state:CBManagerState)
}
