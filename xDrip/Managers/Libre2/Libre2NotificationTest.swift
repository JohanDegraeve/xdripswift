import Foundation

/// One interactive diagnostic request. A fixed identifier replaces a pending test.
enum Libre2NotificationTest {
    static let requestKey = "directLibreNotificationTest"
    static let scheduledAtKey = "notificationTestScheduledAt"
    static let identifier = "directLibreNotificationTest"
    static let category = "directLibreNotificationTestCategory"
    static let title = "Direct Libre notification test"
    static let body = "This is a delivery test, not a glucose alarm. Leave xDrip in the background while checking synchronisation."
    static let delay: TimeInterval = 30
}
