import Foundation

enum ConstantsHeartBeat {
    
    /// minimum time between two heartbeats
    static let minimumTimeBetweenTwoHeartBeats = TimeInterval(30)
    
    /// how many seconds should pass since the previous Libre 3 BLE heartbeat until we show it as disconnected (i.e. having missed a heartbeat)
    static let secondsUntilHeartBeatDisconnectWarningLibre3: Double = 70
    
    /// how many seconds should pass since the previous Dexcom G7 heartbeat until we show it as disconnected (i.e. having missed a heartbeat)
    static let secondsUntilHeartBeatDisconnectWarningDexcomG7: Double = 60 * 5.5
    
    /// how many seconds should pass since the previous OmniPod heartbeat until we show it as disconnected (i.e. having missed a heartbeat)
    static let secondsUntilHeartBeatDisconnectWarningOmniPod: Double = 60 * 5.5
    
}

