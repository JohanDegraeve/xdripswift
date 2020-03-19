import Foundation

extension BluetoothPeripheralManager: CGMG5TransmitterDelegate {
    
    func received(transmitterBatteryInfo: TransmitterBatteryInfo, cGMG5Transmitter: CGMG5Transmitter) {
        
        guard let index = bluetoothTransmitters.firstIndex(of: cGMG5Transmitter), let dexcomG5 = bluetoothPeripherals[index] as? DexcomG5 else {return}
        
        guard case .DexcomG5(let voltA, let voltB, let res, let runt, let temp) = transmitterBatteryInfo else {return}
        
        dexcomG5.batteryResist = Int32(res)
        
        dexcomG5.voltageA = Int32(voltA)
        
        dexcomG5.voltageB = Int32(voltB)
        
        dexcomG5.batteryRuntime = Int32(runt)
        
        dexcomG5.batteryTemperature = Int32(temp)
        
        coreDataManager.saveChanges()
        
    }
    

    func received(firmware: String, cGMG5Transmitter: CGMG5Transmitter) {
        
        guard let index = bluetoothTransmitters.firstIndex(of: cGMG5Transmitter), let dexcomG5 = bluetoothPeripherals[index] as? DexcomG5 else {return}
        
        dexcomG5.firmwareVersion = firmware
        
        coreDataManager.saveChanges()

    }
    
}
