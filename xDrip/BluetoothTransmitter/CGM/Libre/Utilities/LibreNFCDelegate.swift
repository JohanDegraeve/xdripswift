import Foundation

/// The user-understandable outcome of one NFC sensor scan.
///
/// A Boolean previously made a cancelled or timed-out session look like a sensor failure. Keeping
/// the result typed lets both the normal trace and Activity Log describe what actually happened,
/// while raw Core NFC errors remain restricted to developer tracing.
enum LibreNFCScanResult: Equatable {
    case succeeded
    case failed
    case cancelled
    case timedOut
}

/// some functions to send FRAM, sensorUID and patchInfo, unlockcode etc. to delegate
protocol LibreNFCDelegate: AnyObject {
    
    func received(sensorUID: Data, patchInfo: Data)
    
    func received(fram: Data)
    
    func streamingEnabled(successful : Bool)
    
    /// Used to pass back the high-level result of the NFC scan.
    func nfcScanResult(_ result: LibreNFCScanResult)
    
    /// tell the superclass to initiate BLE scanning
    func startBLEScanning()
    
    /// used to pass the recently scanned serial number back
    func nfcScanExpectedDevice(serialNumber: String, macAddress: String)
    
}
