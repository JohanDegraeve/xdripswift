import Foundation

/// some functions to send sensorUID and patchInfo, unlockcode etc. to delegate
protocol LibreNFCDelegate: AnyObject {
    
    func received(sensorUID: Data)
    
    func received(patchInfo: Data)
    
    func streamingEnabled(successful : Bool)
    
}
