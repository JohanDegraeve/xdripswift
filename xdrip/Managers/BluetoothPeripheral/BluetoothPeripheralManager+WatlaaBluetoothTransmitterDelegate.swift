import Foundation

extension BluetoothPeripheralManager: WatlaaBluetoothTransmitterDelegate {
    
    func received(serialNumber: String, from watlaaBluetoothTransmitter: WatlaaBluetoothTransmitter) {
        
        guard let watlaa = findTransmitter(watlaaTransmitter: watlaaBluetoothTransmitter) else {return}
        
        // store serial number in miaoMiao object
        watlaa.blePeripheral.sensorSerialNumber = serialNumber
        
        coreDataManager.saveChanges()

    }
    
    
    func isReadyToReceiveData(watlaaBluetoothTransmitter: WatlaaBluetoothTransmitter) {
        
        // request battery level
        watlaaBluetoothTransmitter.readBatteryLevel()
        
    }
    
    func received(watlaaBatteryLevel: Int, watlaaBluetoothTransmitter: WatlaaBluetoothTransmitter) {
        
        guard let index = bluetoothTransmitters.firstIndex(of: watlaaBluetoothTransmitter), let watlaa = bluetoothPeripherals[index] as? Watlaa else {return}
        
        watlaa.watlaaBatteryLevel = watlaaBatteryLevel
        
        coreDataManager.saveChanges()
        
    }
    
    func received(transmitterBatteryLevel: Int, watlaaBluetoothTransmitter: WatlaaBluetoothTransmitter) {
        
        guard let index = bluetoothTransmitters.firstIndex(of: watlaaBluetoothTransmitter), let watlaa = bluetoothPeripherals[index] as? Watlaa else {return}
        
        watlaa.transmitterBatteryLevel = transmitterBatteryLevel
        
        coreDataManager.saveChanges()
        
    }
    
    private func findTransmitter(watlaaTransmitter: WatlaaBluetoothTransmitter) -> Watlaa? {
        
        guard let index = bluetoothTransmitters.firstIndex(of: watlaaTransmitter), let watlaa = bluetoothPeripherals[index] as? Watlaa else {return nil}
        
        return watlaa
        
    }
    
}
