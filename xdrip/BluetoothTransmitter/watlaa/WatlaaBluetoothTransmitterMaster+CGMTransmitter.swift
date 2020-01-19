import Foundation

extension WatlaaBluetoothTransmitterMaster: CGMTransmitter {
    
    func initiatePairing() {
        // no pairing needed for watlaa
    }
    
    func reset(requested: Bool) {
        // no reset need for watlaa
    }
    
    func setWebOOPEnabled(enabled: Bool) {
        // no web oop for watlaa as sensorid detection not supported
    }
    
    func setWebOOPSiteAndToken(oopWebSite: String, oopWebToken: String) {
        // no web oop for watlaa as sensorid detection not supported
    }
    
}
