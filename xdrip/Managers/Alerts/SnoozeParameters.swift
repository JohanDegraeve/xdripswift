import Foundation

public class SnoozeParameters {
    
    // MARK: private properties
    
    /// this is snooze period chosen by user, nil value is not snoozed
    private(set) var snoozePeriodInMinutes:Int?
    
    /// when was the alert snoozed, nil is not snoozed
    private(set) var snoozeTimeStamp:Date?
    
    // MARK: public functions
    
    /// store snoozeperiod in minutes, snoozetimestamp = now,
    public func snooze(snoozePeriodInMinutes:Int) {
        self.snoozePeriodInMinutes = snoozePeriodInMinutes
        snoozeTimeStamp = Date()
    }
    

    /// reset snooze, ie not snoozed
    public func unSnooze() {
        snoozePeriodInMinutes = nil
        snoozeTimeStamp = nil
    }
    
    /// checks if snoozed and snoozetimestamp and if current time still within the period, then returns true
    /// - returns:
    ///     - isSnoozed : is the alert snoozed
    ///     - remainingSeconds : if the alert is snoozed, then this says how many seconds remaining
    public func getSnoozeValue() -> (isSnoozed:Bool, remainingSeconds:Int?) {
        if let snoozeTimeStamp = snoozeTimeStamp, let snoozePeriodInMinutes = snoozePeriodInMinutes {
            if Date(timeInterval: TimeInterval(snoozePeriodInMinutes * 60), since: snoozeTimeStamp) < Date() {
                // snooze attributes are set, however they are expired
                unSnooze() // set attributes to nil
                return (false, nil)
            } else {
                // alert is still snoozed, calculate remaining seconds
                return (true, Int((snoozeTimeStamp.toMillisecondsAsDouble() + Double(snoozePeriodInMinutes) * 60 * 1000 - Date().toMillisecondsAsDouble())/1000))
            }
        } else {
            return (false, nil)
        }
    }
}

