import Foundation

class CGMG6Transmitter: CGMG5Transmitter {
    
    /// - parameters:
    ///     - address: if already connected before, then give here the address that was received during previous connect, if not give nil
    ///     - name : if already connected before, then give here the name that was received during previous connect, if not give nil
    ///     - transmitterID: expected transmitterID, 6 characters
    ///     - bluetoothTransmitterDelegate : a NluetoothTransmitterDelegate
    ///     - cGMTransmitterDelegate : a CGMTransmitterDelegate
    ///     - cGMG5TransmitterDelegate : a CGMG5TransmitterDelegate
    ///     - transmitterStartDate : transmitter start date, optional - actual transmitterStartDate is received from transmitter itself, and stored in coredata. The stored value iss given here as parameter in the initializer. Means  at app start up, it's read from core data and added here as parameter
    ///     - sensorStartDate : if the user starts the sensor via xDrip4iOS, then only after having receivec a confirmation from the transmitter, then sensorStartDate will be assigned to the actual sensor start date
    ///     - calibrationToSendToTransmitter : used to send calibration done by user via xDrip4iOS to Dexcom transmitter. For example, user may have give a calibration in the app, but it's not yet send to the transmitter. This needs to be verified in CGMG5Transmitter, which is why it's given here as parameter - when initializing, assign last known calibration for the active sensor, even if it's already sent.
    ///     - isFireFly : if true then the transmitter will be treated as a firefly, no matter the transmitter id, no matter if it's a G5, G6 or real Firefly
    init(address:String?, name: String?, transmitterID:String, bluetoothTransmitterDelegate: BluetoothTransmitterDelegate, cGMG6TransmitterDelegate: CGMG6TransmitterDelegate, cGMTransmitterDelegate:CGMTransmitterDelegate, transmitterStartDate: Date?, sensorStartDate: Date?, calibrationToSendToTransmitter: Calibration?, firmware: String?, isFireFly: Bool) {
        
        // call super.init
        super.init(address: address, name: name, transmitterID: transmitterID, bluetoothTransmitterDelegate: bluetoothTransmitterDelegate, cGMG5TransmitterDelegate: cGMG6TransmitterDelegate, cGMTransmitterDelegate: cGMTransmitterDelegate, transmitterStartDate: transmitterStartDate, sensorStartDate: sensorStartDate, calibrationToSendToTransmitter: calibrationToSendToTransmitter, firmware: firmware, isFireFly: isFireFly)
        
    }
    
    override func scaleRawValue(firmwareVersion: String?, rawValue: Double) -> Double {
        
        guard let firmwareVersion = firmwareVersion else { return rawValue }
        
        if firmwareVersion.starts(with: "1.") {
            
            return rawValue * 34.0
            
        } else if firmwareVersion.starts(with: "2.") {
            
            return (rawValue - 1151500000.0) / 110.0
            
        }
        
        return rawValue
        
    }
    
    override func cgmTransmitterType() -> CGMTransmitterType {
        return .dexcomG6
    }
    
}
