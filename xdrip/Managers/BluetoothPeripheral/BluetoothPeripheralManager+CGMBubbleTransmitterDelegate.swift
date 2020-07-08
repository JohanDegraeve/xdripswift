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
        
        // store serial number in bubble.blePeripheral object
        bubble.blePeripheral.libreSensorType = libreSensorType
        
        // if the libreSensorType needs oopweb, then enable oopweb. (User may have set it to false, but if it's one that requires oopweb, then we force to true)
        // also disable non-fixed slopes, as calibration is not used, it makes no sense to show this as enabled
        if libreSensorType.needsWebOOP() {
            
            bubble.blePeripheral.webOOPEnabled = true
            
            bubble.blePeripheral.nonFixedSlopeEnabled = false
            
        }
        
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
