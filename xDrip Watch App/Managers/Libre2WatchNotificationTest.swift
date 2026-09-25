import Foundation
import UserNotifications
import WatchKit

/// Schedules only on an explicit live request; no delivery retries or collector changes.
final class Libre2WatchNotificationTest {
    private let center: UNUserNotificationCenter
    private var isScheduling = false

    init(center: UNUserNotificationCenter = .current()) { self.center = center }

    /// Called on main by the Watch message router, including completion of scheduling.
    @discardableResult
    func receive(_ dictionary: [String: Any], reply: @escaping ([String: Any]) -> Void) -> Bool {
        guard dictionary[Libre2NotificationTest.requestKey] != nil else { return false }
        guard dictionary[Libre2NotificationTest.requestKey] as? Bool == true, !isScheduling else {
            reply(["error": "A notification test could not be started. Wait for the current request to finish and retry."])
            return true
        }
        isScheduling = true
        Task { @MainActor in
            defer { isScheduling = false }
            do {
                var settings = await center.notificationSettings()
                if settings.authorizationStatus == .notDetermined {
                    guard WKApplication.shared().applicationState == .active else {
                        reply(["error": "Open xDrip on the Watch to schedule the test and allow notifications if asked."])
                        return
                    }
                    guard try await center.requestAuthorization(options: [.alert, .sound]) else {
                        reply(["error": "Enable notification alerts for xDrip on the Watch, then retry the test."])
                        return
                    }
                    settings = await center.notificationSettings()
                }
                // Quiet/provisional delivery would not test notification presentation.
                guard settings.authorizationStatus == .authorized,
                    settings.alertSetting == .enabled else {
                    reply(["error": "Enable notification alerts for xDrip on the Watch, then retry the test."])
                    return
                }

                let content = UNMutableNotificationContent()
                content.title = Libre2NotificationTest.title
                content.body = Libre2NotificationTest.body
                content.sound = .default
                content.categoryIdentifier = Libre2NotificationTest.category
                let trigger = UNTimeIntervalNotificationTrigger(timeInterval: Libre2NotificationTest.delay, repeats: false)
                let date = Date().addingTimeInterval(Libre2NotificationTest.delay)
                // Adding the same identifier replaces the previous pending request. Other
                // notifications, including real glucose alarms, are never removed or changed.
                try await center.add(UNNotificationRequest(identifier: Libre2NotificationTest.identifier,
                    content: content, trigger: trigger))
                reply([Libre2NotificationTest.scheduledAtKey: date.timeIntervalSince1970])
            } catch {
                reply(["error": error.localizedDescription])
            }
        }
        return true
    }
}

#if os(watchOS)
import SwiftUI

/// Uses the same WatchKit custom-notification mechanism as ordinary xDrip alerts,
/// with its own category and content so a test cannot look like a glucose alarm.
final class Libre2NotificationTestController: WKUserNotificationHostingController<Libre2NotificationTestView> {
    override var body: Libre2NotificationTestView { Libre2NotificationTestView() }
}

struct Libre2NotificationTestView: View {
    var body: some View {
        VStack(spacing: 8) {
            Text(Libre2NotificationTest.title).font(.headline)
            Text(Libre2NotificationTest.body).font(.caption)
        }
    }
}
#endif
