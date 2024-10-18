import Foundation
/// dexcom G7 specific constants
enum ConstantsDexcomG7 {
    
    /// how far in history to go back for fetching readings
    static let maxBackfillPeriod = TimeInterval(hours: 6.0)
    
    /// request back fill reading if time since latest readings is longer than this period
    static let minPeriodOfLatestReadingsToStartBackFill = TimeInterval(minutes: 5.30)
    
    /// if there's a new connect within this period, but latest reading was less than this interval ago, then no need to request new reading
    static let minimumTimeBetweenTwoReadings = TimeInterval(minutes: 2.1)
    
    /// how many days the sensor session lasts. In the case of G7/ONE+ it is 10 days + a 12 hour grace period = 10.5 days
    static let maxSensorAgeInDays: Double = 10.5
    
    /// how many days the sensor session lasts. In the case of Stelo it is 15 days + a 12 hour grace period = 15.5 days
    static let maxSensorAgeInDaysStelo: Double = 15.5
    
}
