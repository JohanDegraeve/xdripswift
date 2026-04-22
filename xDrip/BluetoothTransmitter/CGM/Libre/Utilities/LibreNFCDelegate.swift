import Foundation

/// some functions to send FRAM, sensorUID and patchInfo, unlockcode etc. to delegate
protocol LibreNFCDelegate: AnyObject {
    
    func received(sensorUID: Data, patchInfo: Data)
    
    func received(fram: Data)
    
    func streamingEnabled(successful : Bool)
    
    /// used to pass back the result of the NFC scan 
    func nfcScanResult(successful : Bool)
    
    /// tell the superclass to initiate BLE scanning
    func startBLEScanning()
    
    /// used to pass the recently scanned serial number back
    func nfcScanExpectedDevice(serialNumber: String, macAddress: String)
    
}
