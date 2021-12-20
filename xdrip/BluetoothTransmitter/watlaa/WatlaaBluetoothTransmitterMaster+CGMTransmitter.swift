import Foundation

extension WatlaaBluetoothTransmitter: CGMTransmitter {
 
    func setWebOOPEnabled(enabled: Bool) {
        
        webOOPEnabled = enabled
        
        // immediately request a new reading
        // there's no check here to see if peripheral, characteristic, connection, etc.. exists, but that's no issue. If anything's missing, write will simply fail,
        _ = sendStartReadingCommand()
        
    }

    func setNonFixedSlopeEnabled(enabled: Bool) {
        nonFixedSlopeEnabled = enabled
        
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

    func isNonFixedSlopeEnabled() -> Bool {
        return nonFixedSlopeEnabled
    }

    func requestNewReading() {
        _ = sendStartReadingCommand()
    }
    
}
