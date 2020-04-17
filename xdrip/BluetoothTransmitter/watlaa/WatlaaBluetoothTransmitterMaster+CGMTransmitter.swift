import Foundation

extension WatlaaBluetoothTransmitter: CGMTransmitter {

    func setWebOOPSite(oopWebSite: String) {
        
        self.oopWebSite = oopWebSite
        
    }
    
    func setWebOOPToken(oopWebToken: String) {
        
        self.oopWebToken = oopWebToken
        
    }
    
    func setWebOOPEnabled(enabled: Bool) {
        
        webOOPEnabled = enabled
        
        // immediately request a new reading
        // there's no check here to see if peripheral, characteristic, connection, etc.. exists, but that's no issue. If anything's missing, write will simply fail,
        _ = sendStartReadingCommand()
        
    }
    
    func cgmTransmitterType() -> CGMTransmitterType {
        return .watlaa
    }
    
    func isWebOOPEnabled() -> Bool {
        return webOOPEnabled
    }

    func requestNewReading() {
        _ = sendStartReadingCommand()
    }
    
}
