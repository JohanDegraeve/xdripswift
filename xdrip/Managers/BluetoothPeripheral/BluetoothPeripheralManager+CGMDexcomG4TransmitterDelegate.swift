import Foundation

extension BluetoothPeripheralManager: CGMDexcomG4TransmitterDelegate {
    
    func received(batteryLevel: Int, from cGMG4xDripTransmitter: CGMG4xDripTransmitter) {
        
        guard let DexcomG4 = findTransmitter(cGMG4xDripTransmitter: cGMG4xDripTransmitter) else {return}
        
        // store serial number in DexcomG4 object
        DexcomG4.batteryLevel = batteryLevel
        
        // no coredatamanager savechanges needed because batterylevel is not stored in coredata
        
    }
    
    
    private func findTransmitter(cGMG4xDripTransmitter: CGMG4xDripTransmitter) -> DexcomG4? {
        
        guard let index = bluetoothTransmitters.firstIndex(of: cGMG4xDripTransmitter), let DexcomG4 = bluetoothPeripherals[index] as? DexcomG4 else {return nil}
        
        return DexcomG4
        
    }
    
}
