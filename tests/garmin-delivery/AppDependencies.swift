// Small stand-ins for app/UIKit dependencies. Tests compile the production manager,
// transport interface, queue and lifecycle state. They do not exercise Core Data,
// UIKit background execution or the proprietary Connect IQ binary.
import Foundation

struct TestSnapshot {
    var finalValue: Double
    var timeStamp: Date
    var trend: Int
    func slopeOrdinal() -> Int { trend }
}
final class CoreDataManager { var snapshot: TestSnapshot? }
final class BgReadingsAccessor {
    let coreDataManager: CoreDataManager
    init(coreDataManager: CoreDataManager) { self.coreDataManager = coreDataManager }
    func lastSnapshot(forSensor: String?) -> TestSnapshot? { coreDataManager.snapshot }
}
extension UserDefaults {
    var garminWatchEnabled: Bool {
        get { bool(forKey: "garminWatchEnabled") }
        set { set(newValue, forKey: "garminWatchEnabled") }
    }
}
enum Texts_SettingsView {
    static let garminWatchSDKUnavailable = "SDK Unavailable"
    static let garminWatchDisabled = "Disabled"
    static let garminWatchNotConfigured = "Not Configured"
    static let garminWatchConnected = "Ready"
    static let garminWatchDisconnected = "Not Ready"
}
final class GarminBackgroundWork {
    static var instances: [GarminBackgroundWork] = []
    static var allowed = true
    var endCount = 0
    private var active = false
    private var expiration: (() -> Void)?
    init(_ name: String) { Self.instances.append(self) }
    func begin(onExpiration: @escaping () -> Void) -> Bool {
        active = Self.allowed; expiration = onExpiration; return active
    }
    func end() {
        if active { active = false; endCount += 1 }
    }
    func expire() {
        guard active else { return }
        expiration?(); end()
    }
}
