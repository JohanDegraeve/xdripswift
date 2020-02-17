import Foundation
import CoreBluetooth

/// to be implemented for anyone who needs to receive information from a specific type of cgm transmitter
protocol CGMTransmitterDelegate:AnyObject {
     
    /// will only happen for MiaoMiao transmitter, anyway we can do the stuff for any type of transmitter which means restart the sensor, ask calibration blablabla
    func newSensorDetected()
    
    /// will only happen for MiaoMiao transmitter, anyway we can do the stuff for any type of transmitter which means send a warning blablabla
    func sensorNotDetected()
    
    /// to pass back transmitter data from cgmtransmitter
    /// - parameters:
    ///     - glucoseData : array of RawGlucoseData, can be empty array, first entry is the youngest
    ///     - transmitterBatteryInfo :
    ///     - sensorState : only if transmitter can give that info, eg MiaoMiao, otherwise nil
    ///     - sensorTimeInMinutes : sensor age in minutes, only if transmitter can give that info, eg MiaoMiao, otherwise nil
    ///     - firmware : only if transmitter can give that info, eg G5, otherwise nil
    ///     - hardware : only if transmitter can give that info, eg G5, otherwise nil
    ///     - serialNumber : transmitter serial number, only if transmitter can give that info, eg G5, otherwise nil
    ///     - bootloader : for the moment only used by GNSentry, otherwise nil
    ///     - sensorSerialNumber : serial number of the sensor, only applicable for Libre transmitters (MiaoMiao, Blucon, ...)
    func cgmTransmitterInfoReceived(glucoseData:inout [GlucoseData], transmitterBatteryInfo:TransmitterBatteryInfo?, sensorState:LibreSensorState?, sensorTimeInMinutes:Int?, firmware:String?, hardware:String?, hardwareSerialNumber:String?, bootloader:String?, sensorSerialNumber:String?)
    
    /// temporary function till all cgm transmitters have moved to bluetooth tab. - this function returns the currently assigned cgmTransmiter
    func getCGMTransmitter() -> CGMTransmitter?
    
    /// to pass some text error message, delegate can decide to show to user, log, ...
    func error(message: String)
    
}


