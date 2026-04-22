import Foundation

extension BluetoothPeripheralManager: CGMMiaoMiaoTransmitterDelegate {
    
    func received(sensorStatus: LibreSensorState, from cGMMiaoMiaoTransmitter: CGMMiaoMiaoTransmitter) {
        
        guard let miaoMiao = findTransmitter(cGMMiaoMiaoTransmitter: cGMMiaoMiaoTransmitter) else {return}
        
        // store serial number in miaoMiao object
        miaoMiao.sensorState = sensorStatus
        
        // no coredatamanager savechanges needed because batterylevel is not stored in coredata
        
    }
    
    func received(libreSensorType: LibreSensorType, from cGMMiaoMiaoTransmitter: CGMMiaoMiaoTransmitter) {
        
        guard let miaoMiao = findTransmitter(cGMMiaoMiaoTransmitter: cGMMiaoMiaoTransmitter) else {return}
        
        // store libreSensorType in miaoMiao.blePeripheral object
        miaoMiao.blePeripheral.libreSensorType = libreSensorType
        
        // coredatamanager savechanges needed because webOOPEnabled is stored in coredata
        coreDataManager.saveChanges()
        
    }

    func received(batteryLevel: Int, from cGMMiaoMiaoTransmitter: CGMMiaoMiaoTransmitter) {
        
        guard let miaoMiao = findTransmitter(cGMMiaoMiaoTransmitter: cGMMiaoMiaoTransmitter) else {return}
        
        // store serial number in miaoMiao object
        miaoMiao.batteryLevel = batteryLevel
        
        // no coredatamanager savechanges needed because batterylevel is not stored in coredata
        
    }
    
    
    func received(serialNumber: String, from cGMMiaoMiaoTransmitter: CGMMiaoMiaoTransmitter) {
        
        guard let miaoMiao = findTransmitter(cGMMiaoMiaoTransmitter: cGMMiaoMiaoTransmitter) else {return}
        
        // store serial number in miaoMiao object
        miaoMiao.blePeripheral.sensorSerialNumber = serialNumber
        
        coreDataManager.saveChanges()
        
    }
    
    func received(firmware: String, from cGMMiaoMiaoTransmitter: CGMMiaoMiaoTransmitter) {
        
        guard let miaoMiao = findTransmitter(cGMMiaoMiaoTransmitter: cGMMiaoMiaoTransmitter) else {return}
        
        // store firmware in miaoMiao object
        miaoMiao.firmware = firmware
        
        coreDataManager.saveChanges()

    }
    
    func received(hardware: String, from cGMMiaoMiaoTransmitter: CGMMiaoMiaoTransmitter) {
        
        guard let miaoMiao = findTransmitter(cGMMiaoMiaoTransmitter: cGMMiaoMiaoTransmitter) else {return}
            
        // store hardware in miaoMiao object
        miaoMiao.hardware = hardware
        
        coreDataManager.saveChanges()
        
    }
    
    private func findTransmitter(cGMMiaoMiaoTransmitter: CGMMiaoMiaoTransmitter) -> MiaoMiao? {
        
        guard let index = bluetoothTransmitters.firstIndex(of: cGMMiaoMiaoTransmitter), let miaoMiao = bluetoothPeripherals[index] as? MiaoMiao else {return nil}
        
        return miaoMiao
        
    }
    
}
