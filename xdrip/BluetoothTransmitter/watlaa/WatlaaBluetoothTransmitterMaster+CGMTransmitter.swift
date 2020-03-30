import Foundation

extension WatlaaBluetoothTransmitterMaster: CGMTransmitter {

    func setWebOOPSite(oopWebSite: String) {
        // no web oop for watlaa as sensorid detection not supported
    }
    
    func setWebOOPToken(oopWebToken: String) {
        // no web oop for watlaa as sensorid detection not supported
    }
    
    func setWebOOPEnabled(enabled: Bool) {
        // no web oop for watlaa as sensorid detection not supported
    }
    
    func cgmTransmitterType() -> CGMTransmitterType {
        return .watlaa
    }
    
    func isWebOOPEnabled() -> Bool {
        return false
    }

    func requestNewReading() {
        // not supported for blucon
    }
    
}
