import Foundation

/// Interactive settings only: never queue a location start for later delivery.
enum Libre2LocationRequest: Codable, Equatable {
    case inspect
    case setEnabled(Bool)
    case setAccuracy(Accuracy)

    /// Core Location's coarse accuracy levels, in metres.
    enum Accuracy: Int, Codable, CaseIterable {
        case hundredMeters = 100
        case kilometer = 1000
        case threeKilometers = 3000
    }

    static let key = "directLibreLocation"

    var dictionary: [String: Any] {
        get throws { [Self.key: try JSONEncoder().encode(self)] }
    }

    static func decode(_ dictionary: [String: Any]) throws -> Self {
        guard let data = dictionary[key] as? Data else { throw DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "Missing location request")) }
        return try JSONDecoder().decode(Self.self, from: data)
    }
}

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
