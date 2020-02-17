import Foundation

extension BluetoothPeripheralManager: WatlaaBluetoothTransmitterDelegate {
    
    func isReadyToReceiveData(watlaaBluetoothTransmitter: WatlaaBluetoothTransmitterMaster) {
        
        // request battery level
        watlaaBluetoothTransmitter.readBatteryLevel()
        
    }
    
    func receivedBattery(level: Int, watlaaBluetoothTransmitter: WatlaaBluetoothTransmitterMaster) {
        
        guard let index = bluetoothTransmitters.firstIndex(of: watlaaBluetoothTransmitter), let watlaa = bluetoothPeripherals[index] as? Watlaa else {return}
        
        watlaa.batteryLevel = level
        
        coreDataManager.saveChanges()
        
    }
    
}
