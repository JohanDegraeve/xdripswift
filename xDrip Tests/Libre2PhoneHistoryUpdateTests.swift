import XCTest
@testable import xdrip

final class Libre2PhoneHistoryUpdateTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)
    private let maximumAge: TimeInterval = 240

    func testFreshValuesAdvanceButDuplicatesAndOlderValuesDoNotRepeatAlerts() {
        var update = Libre2PhoneHistoryUpdate()
        let first = now.addingTimeInterval(-60)
        XCTAssertEqual(update.consume(first, maximumAge: maximumAge, now: now), first)
        XCTAssertNil(update.consume(first, maximumAge: maximumAge, now: now))
        XCTAssertNil(update.consume(first.addingTimeInterval(-60), maximumAge: maximumAge, now: now))
        XCTAssertEqual(update.consume(now, maximumAge: maximumAge, now: now), now)
    }

    func testStaleAbsentAndFutureValuesDoNotConsumeTheNextCurrentValue() {
        var update = Libre2PhoneHistoryUpdate()
        for rejected in [nil, now.addingTimeInterval(-240), now.addingTimeInterval(-3600),
                         now.addingTimeInterval(1), Date(timeIntervalSince1970: .infinity)] {
            XCTAssertNil(update.consume(rejected, maximumAge: maximumAge, now: now))
        }
        XCTAssertEqual(update.consume(now, maximumAge: maximumAge, now: now), now)
    }

    func testFreshnessUsesMeasurementTimeNotDeliveryTime() {
        var update = Libre2PhoneHistoryUpdate()
        let date = now.addingTimeInterval(-239)
        XCTAssertEqual(update.consume(date, maximumAge: maximumAge, now: now), date)
        var delayed = Libre2PhoneHistoryUpdate()
        XCTAssertNil(delayed.consume(date, maximumAge: maximumAge, now: now.addingTimeInterval(2)))
    }
}
