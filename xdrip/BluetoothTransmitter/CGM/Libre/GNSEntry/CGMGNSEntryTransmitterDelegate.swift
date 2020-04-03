import Foundation

protocol CGMGNSEntryTransmitterDelegate: AnyObject {
    
    /// received bootLoader
    func received(bootLoader: String, from cGMGNSEntryTransmitter: CGMGNSEntryTransmitter)
    
    /// received firmwareVersion
    func received(firmwareVersion: String, from cGMGNSEntryTransmitter: CGMGNSEntryTransmitter)
    
    /// received serialNumber (not sensor serial number)
    func received(serialNumber: String, from cGMGNSEntryTransmitter: CGMGNSEntryTransmitter)
    
}

