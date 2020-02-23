import Foundation

extension WatlaaBluetoothTransmitterMaster: CGMTransmitter {
    
    func reset(for bluetoothTransmitter: BluetoothTransmitter, successful: Bool) {
        // no reset need for watlaa
    }
    
    func setWebOOPEnabled(enabled: Bool) {
        // no web oop for watlaa as sensorid detection not supported
    }
    
    func setWebOOPSiteAndToken(oopWebSite: String, oopWebToken: String) {
        // no web oop for watlaa as sensorid detection not supported
    }
    
    func cgmTransmitterType() -> CGMTransmitterType {
        return .watlaa
    }
    
}
