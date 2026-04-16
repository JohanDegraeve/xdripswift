import Foundation
import SwiftUI
import UIKit

enum ConstantsAlerts {
    
    /// - to avoid that a specific alert gets raised for instance every minute, this is the default delay used
    /// - the actual delay used is first read from UserDefaults (settings), if not present then this value here is used
    static let defaultDelayBetweenAlertsOfSameKindInMinutes = 5
    
    /// when the snooze all picker is brought up, this will be the default selected mute time
    /// unlike the specific alarms, we'll set this to a longer period such as 6 hours
    static let defaultSnoozeAllPeriodInMinutes = 6 * 60
    
    // Snooze all
    /// the snooze all banner background color when not activated
    static let bannerBackgroundColorWhenNotAllSnoozed = UIColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 1)
    
    /// the snooze all banner text color when not activated
    static let bannerTextColorWhenNotAllSnoozed = UIColor.gray
    
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
    
    /// snooze times in minutes
    static let snoozeValueMinutes = [5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 55, 60, 75, 90, 120, 150, 180, 240, 300, 360, 420, 480, 540, 600, 720, 1440, 10080]
    
    /// snooze times as shown to the user, actual strings will be replaced during init
    static var snoozeValueStrings = [
        "5 minutes",
        "10 minutes",
        "15 minutes",
        "20 minutes",
        "25 minutes",
        "30 minutes",
        "35 minutes",
        "40 minutes",
        "45 minutes",
        "50 minutes",
        "55 minutes",
        "1 hour",
        "1 hour 15 minutes",
        "1,5 hours",
        "2 hours",
        "2,5 hours",
        "3 hours",
        "4 hours",
        "5 hours",
        "6 hours",
        "7 hours",
        "8 hours",
        "9 hours",
        "10 hours",
        "12 hours",
        "1 day",
        "1 week"
    ]
    
    /// snooze all times in minutes - this can be much simpler than the individual alert snooze times...
    static let snoozeAllValueMinutes = [15, 30, 60, 120, 240, 480, 720, 1440, 2880, 10080]
    
    /// snooze all times as shown to the user
    static var snoozeAllValueStrings = [
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
