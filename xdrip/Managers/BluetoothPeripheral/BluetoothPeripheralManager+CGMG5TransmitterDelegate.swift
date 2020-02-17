import Foundation

extension BluetoothPeripheralManager: CGMG5TransmitterDelegate {

    func received(firmware: String, cGMG5Transmitter: CGMG5Transmitter) {
        
        guard let index = bluetoothTransmitters.firstIndex(of: cGMG5Transmitter), let dexcomG5 = bluetoothPeripherals[index] as? DexcomG5 else {return}
        
        dexcomG5.firmwareVersion = firmware
        
        coreDataManager.saveChanges()

    }
    
}
