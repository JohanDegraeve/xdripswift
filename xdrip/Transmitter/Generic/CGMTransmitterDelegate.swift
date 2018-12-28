import Foundation
import CoreBluetooth

/// to be implemented for anyone who needs to receive information from a specific type of transmitter
protocol CGMTransmitterDelegate {
    /// if bluetooth state changes. This is not necessarily the status of the connection to the peripheral.
    ///
    /// whenever status changes to on, and if device address not known yet, then app might want to start scanning
    ///
    func bluetooth(didUpdateState state:CBManagerState)
    
    /// transmitter reaches final connection status
    func cgmTransmitterdidConnect()
}


