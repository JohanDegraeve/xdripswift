import Foundation

public class SnoozeParameters {
    /// this is snooze period chosen by user, nil value is not snoozed
    private(set) var snoozePeriodInMinutes:Int?
    /// when was the alert snoozed, nil is not snoozed
    private(set) var snoozeTimeStamp:Date?
    /// was the alert presnoozed by the user
    private(set) var preSnoozed:Bool = false
    
    /// store snoozeperiod in minutes, snoozetimestamp = now, set preSnoozed to false
    public func snooze(snoozePeriodInMinutes:Int) {
        self.snoozePeriodInMinutes = snoozePeriodInMinutes
        snoozeTimeStamp = Date()
        preSnoozed = false
    }
    
    /// store snoozeperiod in minutes, snoozetimestamp = now, set preSnoozed to trye
    public func preSnooze(snoozePeriodInMinutes:Int) {
        snooze(snoozePeriodInMinutes: snoozePeriodInMinutes)
        preSnoozed = true
    }
    
    /// reset snooze, ie not snoozed
    public func unSnooze() {
        snoozePeriodInMinutes = nil
        snoozeTimeStamp = nil
        preSnoozed = false
    }
    
    /// checks if snoozed and snoozetimestamp and if current time still within the period, then returns true
    /// - returns:
    ///     - isSnoozed : is the alert snoozed
    ///     - isPreSnoozed : if the alert is snoozed (ie isSnoozed = true), then this says if the user snoozed the alert yes or no
    ///     - remainingSeconds : if the alert is snoozed, then this says how many seconds remaining
    public func getSnoozeValue() -> (isSnoozed:Bool, isPreSnoozed:Bool?, remainingSeconds:Int?) {
        if let snoozeTimeStamp = snoozeTimeStamp, let snoozePeriodInMinutes = snoozePeriodInMinutes {
            if Date(timeInterval: TimeInterval(snoozePeriodInMinutes * 60), since: snoozeTimeStamp) > Date() {
                // snooze attributes are set, however they are expired
                unSnooze() // set attributes to nil
                return (false, nil, nil)
            } else {
                // alert is still snoozed, calculate
                return (true, preSnoozed, Int((snoozeTimeStamp.toMillisecondsAsDouble() + Double(snoozePeriodInMinutes) * 60 * 1000 - Date().toMillisecondsAsDouble())/1000))
            }
        } else {
            return (false, nil, nil)
        }
    }
}

