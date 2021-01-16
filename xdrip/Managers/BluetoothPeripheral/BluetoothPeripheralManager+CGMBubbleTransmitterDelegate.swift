import Foundation

extension BluetoothPeripheralManager: CGMBubbleTransmitterDelegate {
    
    func received(batteryLevel: Int, from cGMBubbleTransmitter: CGMBubbleTransmitter) {
        
        guard let bubble = findTransmitter(cGMBubbleTransmitter: cGMBubbleTransmitter) else {return}
        
        // store serial number in bubble object
        bubble.batteryLevel = batteryLevel
        
        // no coredatamanager savechanges needed because batterylevel is not stored in coredata
        
    }
    
    func received(sensorStatus: LibreSensorState, from cGMBubbleTransmitter: CGMBubbleTransmitter) {
        
        guard let bubble = findTransmitter(cGMBubbleTransmitter: cGMBubbleTransmitter) else {return}
        
        // store serial number in bubble object
        bubble.sensorState = sensorStatus
        
        // no coredatamanager savechanges needed because batterylevel is not stored in coredata
        
    }
    
    func received(libreSensorType: LibreSensorType, from cGMBubbleTransmitter: CGMBubbleTransmitter) {
        
        guard let bubble = findTransmitter(cGMBubbleTransmitter: cGMBubbleTransmitter) else {return}
        
        // store libreSensorType in bubble.blePeripheral object
        bubble.blePeripheral.libreSensorType = libreSensorType
        
        // coredatamanager savechanges needed because webOOPEnabled is stored in coredata
        coreDataManager.saveChanges()
        
    }
    
    func received(serialNumber: String, from cGMBubbleTransmitter: CGMBubbleTransmitter) {
        
        guard let bubble = findTransmitter(cGMBubbleTransmitter: cGMBubbleTransmitter) else {return}
        
        // store serial number in bubble object
        bubble.blePeripheral.sensorSerialNumber = serialNumber
        
        coreDataManager.saveChanges()
        
    }
    
    func received(firmware: String, from cGMBubbleTransmitter: CGMBubbleTransmitter) {
        
        guard let bubble = findTransmitter(cGMBubbleTransmitter: cGMBubbleTransmitter) else {return}
        
        // store firmware in bubble object
        bubble.firmware = firmware
        
        coreDataManager.saveChanges()

    }
    
    func received(hardware: String, from cGMBubbleTransmitter: CGMBubbleTransmitter) {
        
        guard let bubble = findTransmitter(cGMBubbleTransmitter: cGMBubbleTransmitter) else {return}
            
        // store hardware in bubble object
        bubble.hardware = hardware
        
        coreDataManager.saveChanges()
        
    }
    
    private func findTransmitter(cGMBubbleTransmitter: CGMBubbleTransmitter) -> Bubble? {
        
        guard let index = bluetoothTransmitters.firstIndex(of: cGMBubbleTransmitter), let bubble = bluetoothPeripherals[index] as? Bubble else {return nil}
        
        return bubble
        
    }
    
}
