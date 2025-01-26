import Foundation

extension BluetoothPeripheralManager: CGMG5TransmitterDelegate {
    
    func reset(for cGMG5Transmitter: CGMG5Transmitter, successful: Bool) {
        
        guard let dexcomG5 = getDexcomG5(cGMG5Transmitter: cGMG5Transmitter) else {return}
        
        // as reset was done, set back to false
        dexcomG5.resetRequired = false
        
        // only if successful, set the lastResetTimeStamp to now
        if successful {
            dexcomG5.lastResetTimeStamp = Date()
            coreDataManager.saveChanges()
        }
        
    }
    
    func received(transmitterBatteryInfo: TransmitterBatteryInfo, cGMG5Transmitter: CGMG5Transmitter) {
        
        guard let dexcomG5 = getDexcomG5(cGMG5Transmitter: cGMG5Transmitter) else {return}
        
        guard case .DexcomG5(let voltA, let voltB, let res, let runt, let temp) = transmitterBatteryInfo else {return}
        
        dexcomG5.batteryResist = Int32(res)
        
        dexcomG5.voltageA = Int32(voltA)
        
        dexcomG5.voltageB = Int32(voltB)
        
        dexcomG5.batteryRuntime = Int32(runt)
        
        dexcomG5.batteryTemperature = Int32(temp)
        
        coreDataManager.saveChanges()
        
    }
    

    func received(firmware: String, cGMG5Transmitter: CGMG5Transmitter) {
        
        guard let dexcomG5 = getDexcomG5(cGMG5Transmitter: cGMG5Transmitter) else {return}
        
        dexcomG5.firmwareVersion = firmware
        
        coreDataManager.saveChanges()

    }
    
    func received(transmitterStartDate: Date, cGMG5Transmitter: CGMG5Transmitter) {
        
        guard let dexcomG5 = getDexcomG5(cGMG5Transmitter: cGMG5Transmitter) else {return}
        
        dexcomG5.transmitterStartDate = transmitterStartDate
        
        coreDataManager.saveChanges()
        
    }
    
    func received(sensorStartDate: Date?, cGMG5Transmitter: CGMG5Transmitter) {

        guard let dexcomG5 = getDexcomG5(cGMG5Transmitter: cGMG5Transmitter) else {return}
        
        dexcomG5.sensorStartDate = sensorStartDate
        
        coreDataManager.saveChanges()

    }

    func received(sensorStatus: String?, cGMG5Transmitter: CGMG5Transmitter) {
        
        guard let dexcomG5 = getDexcomG5(cGMG5Transmitter: cGMG5Transmitter) else {return}
        
        dexcomG5.sensorStatus = sensorStatus
        
        coreDataManager.saveChanges()
        
    }
    
    func received(isAnubis: Bool, cGMG5Transmitter: CGMG5Transmitter) {
        
        guard let dexcomG5 = getDexcomG5(cGMG5Transmitter: cGMG5Transmitter) else { return }
        
        dexcomG5.isAnubis = isAnubis
        
        coreDataManager.saveChanges()
        
    }
    
    private func getDexcomG5(cGMG5Transmitter: CGMG5Transmitter) -> DexcomG5? {
        
        guard let index = bluetoothTransmitters.firstIndex(of: cGMG5Transmitter), let dexcomG5 = bluetoothPeripherals[index] as? DexcomG5 else {return nil}
        
        return dexcomG5
        
    }
    
}
