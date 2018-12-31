import Foundation
import CoreBluetooth

/// to be implemented for anyone who needs to receive information from a specific type of transmitter
protocol CGMTransmitterDelegate:BluetoothTransmitterDelegate {
    
    /// transmitter reaches final connection status
    ///
    /// needs to be called by deriving specific transmitter class, example in CGMG4xDripTransmitter, the function is called only when subscription to read characteristic has succeeded, whereas for other like MiaoMiao, the function is called as soon as real connection is made
    func cgmTransmitterdidConnect()
}


