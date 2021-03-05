import Foundation

/// some functions to send FRAM, sensorUID and patchInfo, unlockcode etc. to delegate
protocol LibreNFCDelegate: AnyObject {
    
    func received(sensorUID: Data, patchInfo: Data)
    
    func received(fram: Data)
    
    func streamingEnabled(successful : Bool)
    
}
