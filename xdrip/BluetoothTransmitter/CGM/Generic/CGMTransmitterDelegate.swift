import Foundation
import CoreBluetooth

/// to be implemented for anyone who needs to receive information from a specific type of cgm transmitter
protocol CGMTransmitterDelegate:AnyObject {
     
    /// only for transmitters that can detect new sensor
    func newSensorDetected()
    
    /// only for transmitters that can detect missing sensor
    func sensorNotDetected()
    
    /// to pass back transmitter data from cgmtransmitter
    /// - parameters:
    ///     - glucoseData : array of RawGlucoseData, can be empty array, first entry is the youngest
    ///     - transmitterBatteryInfo : needed for battery level alarm
    ///     - sensorTimeInMinutes : sensor age in minutes, only if transmitter can give that info, eg MiaoMiao, otherwise nil
    func cgmTransmitterInfoReceived(glucoseData:inout [GlucoseData], transmitterBatteryInfo:TransmitterBatteryInfo?, sensorTimeInMinutes:Int?)
    
    /// to pass some text error message, delegate can decide to show to user, log, ...
    func errorOccurred(xDripError: XdripError)
    
}


