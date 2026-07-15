import Foundation
import SwiftUI

enum ConstantsAlerts {
    
    /// - to avoid that a specific alert gets raised for instance every minute, this is the default delay used
    /// - the actual delay used is first read from UserDefaults (settings), if not present then this value here is used
    static let defaultDelayBetweenAlertsOfSameKindInMinutes = 5
    
    /// when the snooze all picker is brought up, this will be the default selected mute time
    /// unlike the specific alarms, we'll set this to a longer period such as 6 hours
    static let defaultSnoozeAllPeriodInMinutes = 6 * 60
    
    // Snooze all
    /// the snooze all banner background color when not activated
    static let bannerBackgroundColorWhenNotAllSnoozed = Color(white: 0.2)
    
    /// the snooze all banner text color when not activated
    static let bannerTextColorWhenNotAllSnoozed = Color.gray
    
    /// the symbol used to indicate a disabled alert type - basically indicating that "no alarm will happen"
    static let disabledAlertSymbol = "\u{26A0}"
    
    /// the string used to append to an alert type name that is disabled - basically saying that "no alarm will happen"
    static let disabledAlertSymbolStringToAppend = " (\u{26A0})"
    
    
    // Notifications
    /// the background color to be used for the notifications (and chart etc) - iOS App
    static let notificationBackgroundColor = Color.black
    
    /// the background color to be used for the notifications (and chart etc) - WatchOS App
    static let notificationWatchBackgroundColor = Color(red: 0.1, green: 0.1, blue: 0.1, opacity: 1)
    
    /// the background color to be used for the alert title banner of the notifications - WatchOS App
    static let notificationBannerBackgroundColor = Color(red: 0.15, green: 0.15, blue: 0.15, opacity: 1)
    
    /// The single supported set of durations for every snooze picker, in minutes.
    static let snoozeValueMinutes = [15, 30, 60, 120, 240, 360, 720, 1440, 2880, 10080]

    /// Localized labels corresponding one-to-one with `snoozeValueMinutes`.
    static let snoozeValueStrings = [
        "15 " + Texts_Common.minutes,
        "30 " + Texts_Common.minutes,
        "1 " + Texts_Common.hour,
        "2 " + Texts_Common.hours,
        "4 " + Texts_Common.hours,
        "6 " + Texts_Common.hours,
        "12 " + Texts_Common.hours,
        "1 " + Texts_Common.day,
        "2 " + Texts_Common.days,
        "1 " + Texts_Common.week
    ]
}
