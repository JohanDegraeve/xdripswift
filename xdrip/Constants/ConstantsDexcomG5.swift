/// dexcom G5 specific constants
enum ConstantsDexcomG5 {
    /// how often to read battery level
    static let batteryReadPeriodInHours = 12.0
    
    /// in case transmitter needs pairing, how long to keep connection up to give time to the user to accept the pairing request, inclusive opening the notification
    static let maxTimeToAcceptPairingInSeconds = 60
}
