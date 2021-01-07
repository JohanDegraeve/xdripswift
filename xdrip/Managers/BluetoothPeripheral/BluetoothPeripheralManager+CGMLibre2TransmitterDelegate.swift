import Foundation

extension BluetoothPeripheralManager: CGMLibre2TransmitterDelegate {
    
    func received(serialNumber: String, from cGMLibre2Transmitter: CGMLibre2Transmitter) {
        
        guard let libre2 = findTransmitter(cGMLibre2Transmitter: cGMLibre2Transmitter) else {return}
        
        // store serial number in Libre2 object
        libre2.blePeripheral.sensorSerialNumber = serialNumber
        
        coreDataManager.saveChanges()
        
    }

    func received(sensorStatus: LibreSensorState, from cGMLibre2Transmitter: CGMLibre2Transmitter) {
        
        guard let libre2 = findTransmitter(cGMLibre2Transmitter: cGMLibre2Transmitter) else {return}
        
        // store sensor state Libre 2 object
        libre2.sensorState = sensorStatus
        
        // no coredatamanager savechanges needed because sensor state is not stored in coredata
        
    }
    
    private func findTransmitter(cGMLibre2Transmitter: CGMLibre2Transmitter) -> Libre2? {
        
        guard let index = bluetoothTransmitters.firstIndex(of: cGMLibre2Transmitter), let libre2 = bluetoothPeripherals[index] as? Libre2 else {return nil}
        
        return libre2
        
    }
    
}
