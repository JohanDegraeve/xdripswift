import Foundation

extension SnoozeParameters {
    
    // MARK: public functions
    
    /// store snoozeperiod in minutes, snoozetimestamp = now,
    public func snooze(snoozePeriodInMinutes:Int) {
        self.snoozePeriodInMinutes = Int16(snoozePeriodInMinutes)
        snoozeTimeStamp = Date()
    }
    

    /// reset snooze, ie not snoozed
    public func unSnooze() {
        snoozePeriodInMinutes = 0
        snoozeTimeStamp = nil
    }
    
    /// checks if snoozed and snoozetimestamp and if current time still within the period, then returns true
    /// - returns:
    ///     - isSnoozed : is the alert snoozed
    ///     - remainingSeconds : if the alert is snoozed, then this says how many seconds remaining
    public func getSnoozeValue() -> (isSnoozed:Bool, remainingSeconds:Int?) {
        if let snoozeTimeStamp = snoozeTimeStamp, snoozePeriodInMinutes > 0 {
            if Date(timeInterval: TimeInterval(Double(snoozePeriodInMinutes) * 60.0), since: snoozeTimeStamp) < Date() {
                // snooze attributes are set, however they are expired
                unSnooze() // set attributes to nil
                return (false, nil)
            } else {
                // alert is still snoozed, calculate remaining seconds
                return (true, Int((snoozeTimeStamp.toMillisecondsAsDouble() + Double(snoozePeriodInMinutes) * 60.0 * 1000.0 - Date().toMillisecondsAsDouble())/1000.0))
            }
        } else {
            return (false, nil)
        }
    }
}

