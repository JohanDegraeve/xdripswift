import Foundation
import CoreBluetooth

/// to be implemented for anyone who needs to receive information from a specific type of cgm transmitter
protocol CGMTransmitterDelegate:AnyObject {
     
    /// only for transmitters that can detect new sensor id
    func newSensorDetected()
    
    /// only for transmitters that can detect sensor
    func sensorNotDetected()
    
    /// to pass back transmitter data from cgmtransmitter
    /// - parameters:
    ///     - glucoseData : array of RawGlucoseData, can be empty array, first entry is the youngest
    ///     - transmitterBatteryInfo :
    ///     - sensorTimeInMinutes : sensor age in minutes, only if transmitter can give that info, eg MiaoMiao, otherwise nil
    ///     - firmware : only if transmitter can give that info, eg G5, otherwise nil
    ///     - hardware : only if transmitter can give that info, eg G5, otherwise nil
    ///     - serialNumber : transmitter serial number, only if transmitter can give that info, eg G5, otherwise nil
    ///     - bootloader : for the moment only used by GNSentry, otherwise nil
    ///     - sensorSerialNumber : serial number of the sensor, only applicable for Libre transmitters (MiaoMiao, Blucon, ...)
    func cgmTransmitterInfoReceived(glucoseData:inout [GlucoseData], transmitterBatteryInfo:TransmitterBatteryInfo?, sensorTimeInMinutes:Int?)
    
    /// to pass some text error message, delegate can decide to show to user, log, ...
    func error(message: String)
    
}


