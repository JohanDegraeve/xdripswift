import Foundation

extension Date {
    //source https://freakycoder.com/ios-notes-22-how-to-get-current-time-as-timestamp-fa8a0d422879
    /// extension to Date class
    /// - returns:
    ///     time since 1 Jan 1970 in ms, can be negative if Date is before 1 Jan 1970
    func toMillisecondsAsDouble() -> Double {
        return Double(self.timeIntervalSince1970 * 1000)
    }
    
    /// gives current date in milliseconds since 1 Jan 1970
    static func nowInMilliSecondsAsDouble() -> Double {
        return Date().toMillisecondsAsDouble()
    }
}
