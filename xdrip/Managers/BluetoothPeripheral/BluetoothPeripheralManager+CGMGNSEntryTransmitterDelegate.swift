import Foundation

extension BluetoothPeripheralManager: CGMGNSEntryTransmitterDelegate {
    
    func received(bootLoader: String, from cGMGNSEntryTransmitter: CGMGNSEntryTransmitter) {
        
        guard let gNSEntry = findTransmitter(cGMGNSEntryTransmitter: cGMGNSEntryTransmitter) else {return}
        
        // store bootLoader in gNSEntry object
        gNSEntry.bootLoader = bootLoader
        
        coreDataManager.saveChanges()
        
    }
    
    func received(firmwareVersion: String, from cGMGNSEntryTransmitter: CGMGNSEntryTransmitter) {
        
        guard let gNSEntry = findTransmitter(cGMGNSEntryTransmitter: cGMGNSEntryTransmitter) else {return}
        
        // store firmwareVersion in gNSEntry object
        gNSEntry.firmwareVersion = firmwareVersion
        
        coreDataManager.saveChanges()
        
    }
    
    func received(serialNumber: String, from cGMGNSEntryTransmitter: CGMGNSEntryTransmitter) {
        
        guard let gNSEntry = findTransmitter(cGMGNSEntryTransmitter: cGMGNSEntryTransmitter) else {return}
        
        // store serialNumber in gNSEntry object
        gNSEntry.serialNumber = serialNumber
        
        coreDataManager.saveChanges()
        
    }
    
    private func findTransmitter(cGMGNSEntryTransmitter: CGMGNSEntryTransmitter) -> GNSEntry? {
        
        guard let index = bluetoothTransmitters.firstIndex(of: cGMGNSEntryTransmitter), let gNSEntry = bluetoothPeripherals[index] as? GNSEntry else {return nil}
        
        return gNSEntry
        
    }
    
}
