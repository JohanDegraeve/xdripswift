import Foundation
import CoreBluetooth

/// to be implemented for anyone who needs to receive information from a specific type of cgm transmitter
protocol CGMTransmitterDelegate:AnyObject {
     
    /// transmitter reaches final connection status
    ///
    /// needs to be called by deriving specific transmitter class, example in CGMG4xDripTransmitter, the function is called only when subscription to read characteristic has succeeded, whereas for other like MiaoMiao, the function is called as soon as real connection is made
    func cgmTransmitterDidConnect(address:String?, name:String?)
    
    /// transmitter did disconnect
    func cgmTransmitterDidDisconnect()
    
    /// the ios device did change bluetooth status
    func deviceDidUpdateBluetoothState(state: CBManagerState)
    
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
    
    /// transmitter needs bluetooth pairing
    func cgmTransmitterNeedsPairing()
    
    /// transmitter successfully paired
    func successfullyPaired()
    
    /// transmitter pairing failed
    func pairingFailed()
    
    /// transmitter reset result
    func reset(successful: Bool)
    
    func list(list: [BluetoothPeripheral])
}


