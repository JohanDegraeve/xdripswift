import Foundation
/// dexcom G5 specific constants
enum ConstantsDexcomG5 {
    
    /// how often to read battery level
    static let batteryReadPeriod = TimeInterval(hours: 2.0)
    
    /// in case transmitter needs pairing, how long to keep connection up to give time to the user to accept the pairing request, inclusive opening the notification
    static let maxTimeToAcceptPairing = TimeInterval(minutes: 1.0)
    
    /// how often to read sensor start time (only for Firefly)
    static let sensorStartTimeReadPeriod = TimeInterval(hours: 0.5)
    
    /// how far in history to go back for fetching readings
    static let maxBackfillPeriod = TimeInterval(hours: 6.0)
    
    /// request back fill reading if time since latest readings is longer than this period
    static let minPeriodOfLatestReadingsToStartBackFill = TimeInterval(minutes: 5.30)
    
    /// if there's a new connect within this period, but latest reading was less than this interval ago, then no need to request new reading
    static let minimumTimeBetweenTwoReadings = TimeInterval(minutes: 2.1)
    
    /// specifically for firefly. If calibration was created more than this period ago, but not yet sent to the transmitter, then it will not be sent anymore
    static let maxUnSentCalibrationAge = TimeInterval(minutes: 5)
    
    /// how many days the sensor session lasts
    static let maxSensorAgeInDays: Double = 10.0
    
    /// maximum days that a user can enter to override the max sensor days for an anubis transmitter
    static let maxSensorAgeInDaysOverridenAnubisMaximum: Double = 60.0
    
}
