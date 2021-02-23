import Foundation

extension BluetoothPeripheralManager: CGMAtomTransmitterDelegate {
    
    func received(sensorStatus: LibreSensorState, from cGMAtomTransmitter: CGMAtomTransmitter) {
        
        guard let atom = findTransmitter(cGMAtomTransmitter: cGMAtomTransmitter) else {return}
        
        // store serial number in atom object
        atom.sensorState = sensorStatus
        
        // no coredatamanager savechanges needed because batterylevel is not stored in coredata
        
    }
    
    func received(libreSensorType: LibreSensorType, from cGMAtomTransmitter: CGMAtomTransmitter) {
        
        guard let atom = findTransmitter(cGMAtomTransmitter: cGMAtomTransmitter) else {return}
        
        // store libreSensorType in atom.blePeripheral object
        atom.blePeripheral.libreSensorType = libreSensorType
        
        // coredatamanager savechanges needed because webOOPEnabled is stored in coredata
        coreDataManager.saveChanges()
        
    }
    
    func received(batteryLevel: Int, from cGMAtomTransmitter: CGMAtomTransmitter) {
        
        guard let atom = findTransmitter(cGMAtomTransmitter: cGMAtomTransmitter) else {return}
        
        // store serial number in atom object
        atom.batteryLevel = batteryLevel
        
        // no coredatamanager savechanges needed because batterylevel is not stored in coredata
        
    }
    
    
    func received(serialNumber: String, from cGMAtomTransmitter: CGMAtomTransmitter) {
        
        guard let atom = findTransmitter(cGMAtomTransmitter: cGMAtomTransmitter) else {return}
        
        // store serial number in atom object
        atom.blePeripheral.sensorSerialNumber = serialNumber
        
        coreDataManager.saveChanges()
        
    }
    
    func received(firmware: String, from cGMAtomTransmitter: CGMAtomTransmitter) {
        
        guard let atom = findTransmitter(cGMAtomTransmitter: cGMAtomTransmitter) else {return}
        
        // store firmware in atom object
        atom.firmware = firmware
        
        coreDataManager.saveChanges()
        
    }
    
    func received(hardware: String, from cGMAtomTransmitter: CGMAtomTransmitter) {
        
        guard let atom = findTransmitter(cGMAtomTransmitter: cGMAtomTransmitter) else {return}
        
        // store hardware in atom object
        atom.hardware = hardware
        
        coreDataManager.saveChanges()
        
    }
    
    private func findTransmitter(cGMAtomTransmitter: CGMAtomTransmitter) -> Atom? {
        
        guard let index = bluetoothTransmitters.firstIndex(of: cGMAtomTransmitter), let atom = bluetoothPeripherals[index] as? Atom else {return nil}
        
        return atom
        
    }
    
}
