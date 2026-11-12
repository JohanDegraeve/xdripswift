import XCTest
@testable import xdrip

final class WidgetRuntimeDataTests: XCTestCase {
    private let collectorData = Data(#"""
    {
        "bgReadingValues": [118, 115],
        "bgReadingDatesAsDouble": [2000000000, 1999999700],
        "isMgDl": false,
        "slopeOrdinal": 4,
        "deltaValueInUserUnit": 0.2,
        "urgentLowLimitInMgDl": 54,
        "lowLimitInMgDl": 75,
        "highLimitInMgDl": 170,
        "urgentHighLimitInMgDl": 240,
        "dataSourceDescription": "Fixture CGM",
        "followerPatientName": "Fixture patient",
        "allowStandByHighContrast": false,
        "forceStandByBigNumbers": true
    }
    """#.utf8)

    func testMissingCollectorDataHasNoGlucoseOrSourceIdentity() {
        assertUnavailable(WidgetSharedUserDefaultsModel.decodeForDisplay(nil))
    }

    func testCorruptOrIncompatibleCollectorDataHasNoDemonstrationReadings() {
        for value in ["", "{", "null", "[]", "{}", #"{"bgReadingValues":"invalid"}"#] {
            assertUnavailable(WidgetSharedUserDefaultsModel.decodeForDisplay(Data(value.utf8)))
        }
    }

    func testValidCollectorDataPreservesReadingsMeasurementTimesAndPreferences() {
        let data = WidgetSharedUserDefaultsModel.decodeForDisplay(collectorData)

        XCTAssertEqual(data.bgReadingValues, [118, 115])
        XCTAssertEqual(data.bgReadingDatesAsDouble, [2_000_000_000, 1_999_999_700])
        XCTAssertFalse(data.isMgDl)
        XCTAssertEqual(data.slopeOrdinal, 4)
        XCTAssertEqual(data.deltaValueInUserUnit, 0.2)
        XCTAssertEqual(data.urgentLowLimitInMgDl, 54)
        XCTAssertEqual(data.lowLimitInMgDl, 75)
        XCTAssertEqual(data.highLimitInMgDl, 170)
        XCTAssertEqual(data.urgentHighLimitInMgDl, 240)
        XCTAssertEqual(data.dataSourceDescription, "Fixture CGM")
        XCTAssertEqual(data.followerPatientName, "Fixture patient")
        XCTAssertFalse(data.allowStandByHighContrast)
        XCTAssertTrue(data.forceStandByBigNumbers)
    }

    func testValidEmptyCollectorDataRetainsItsSourceWithoutInventingGlucose() throws {
        var payload = try XCTUnwrap(JSONSerialization.jsonObject(with: collectorData) as? [String: Any])
        payload["bgReadingValues"] = [Double]()
        payload["bgReadingDatesAsDouble"] = [Double]()
        let data = WidgetSharedUserDefaultsModel.decodeForDisplay(try JSONSerialization.data(withJSONObject: payload))

        XCTAssertTrue(data.bgReadingValues.isEmpty)
        XCTAssertTrue(data.bgReadingDatesAsDouble.isEmpty)
        XCTAssertEqual(data.dataSourceDescription, "Fixture CGM")
        XCTAssertFalse(data.isMgDl)
        XCTAssertTrue(data.forceStandByBigNumbers)
    }

    func testMismatchedValuesAndDatesCannotDisplayAnUnpairedGlucoseValue() throws {
        for dates in [[2_000_000_000.0], []] {
            var payload = try XCTUnwrap(JSONSerialization.jsonObject(with: collectorData) as? [String: Any])
            payload["bgReadingDatesAsDouble"] = dates
            assertUnavailable(WidgetSharedUserDefaultsModel.decodeForDisplay(try JSONSerialization.data(withJSONObject: payload)))
        }
    }

    func testValidCollectorDataRetainsOptionalTherapyAndAIDStatus() throws {
        var data = WidgetSharedUserDefaultsModel.decodeForDisplay(collectorData)
        let now = Date(timeIntervalSince1970: 2_000_000_000)
        data.aidStatus = AIDStatus(condition: .active, style: .loop, statusUpdatedAt: now,
            lastActivityAt: now, iob: 2, cob: 10, statusTitle: "Fixture", staleStatusTitle: "Unavailable")
        data.therapyMetrics = .external(data.aidStatus, at: now)

        XCTAssertEqual(WidgetSharedUserDefaultsModel.decodeForDisplay(try JSONEncoder().encode(data)), data)
    }

    private func assertUnavailable(_ data: WidgetSharedUserDefaultsModel, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(data.bgReadingValues.isEmpty, file: file, line: line)
        XCTAssertTrue(data.bgReadingDatesAsDouble.isEmpty, file: file, line: line)
        XCTAssertTrue(data.dataSourceDescription.isEmpty, file: file, line: line)
        XCTAssertNil(data.followerPatientName, file: file, line: line)
        XCTAssertNil(data.aidStatus, file: file, line: line)
        XCTAssertNil(data.therapyMetrics, file: file, line: line)
    }
}
