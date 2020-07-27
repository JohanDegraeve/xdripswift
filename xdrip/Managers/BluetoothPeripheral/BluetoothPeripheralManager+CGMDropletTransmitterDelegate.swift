import Foundation

extension BluetoothPeripheralManager: CGMDropletTransmitterDelegate {
    
    func received(batteryLevel: Int, from cGMDropletTransmitter: CGMDroplet1Transmitter) {
        
        guard let droplet = findTransmitter(cGMDropletTransmitter: cGMDropletTransmitter) else {return}
        
        // store serial number in droplet object
        droplet.batteryLevel = batteryLevel
        
        // no coredatamanager savechanges needed because batterylevel is not stored in coredata
        
    }
    
    
    private func findTransmitter(cGMDropletTransmitter: CGMDroplet1Transmitter) -> Droplet? {
        
        guard let index = bluetoothTransmitters.firstIndex(of: cGMDropletTransmitter), let droplet = bluetoothPeripherals[index] as? Droplet else {return nil}
        
        return droplet
        
    }
    
}
