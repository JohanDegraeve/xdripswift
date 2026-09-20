import XCTest
@testable import xdrip

final class LiveActivityWarmupTests: XCTestCase {
    func testOlderActivityPayloadDecodesWithoutWarmup() throws {
        let state = makeState()
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(state)) as? [String: Any])
        json.removeValue(forKey: "sensorWarmupEndDate")
        json.removeValue(forKey: "sensorWarmupConfirmationUntil")
        let decoded = try JSONDecoder().decode(XDripWidgetAttributes.ContentState.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertNil(decoded.sensorWarmupEndDate)
        XCTAssertNil(decoded.sensorWarmupConfirmationUntil)
        XCTAssertFalse(decoded.showsSensorWarmupStatus)
        XCTAssertFalse(decoded.isSensorWarmingUp)
    }

    func testWarmupSurvivesEncodingWithoutAnyGlucose() throws {
        var state = makeState()
        state.sensorWarmupEndDate = Date().addingTimeInterval(1800)
        let decoded = try JSONDecoder().decode(XDripWidgetAttributes.ContentState.self, from: JSONEncoder().encode(state))
        XCTAssertTrue(decoded.bgReadingValues.isEmpty)
        XCTAssertTrue(decoded.bgReadingDates.isEmpty)
        XCTAssertEqual(decoded.sensorWarmupEndDate, state.sensorWarmupEndDate)
        XCTAssertTrue(decoded.isSensorWarmingUp)
    }

    func testExpiredWarmupReturnsToNormalPresentation() {
        var state = makeState()
        state.sensorWarmupEndDate = Date().addingTimeInterval(-1)
        XCTAssertFalse(state.isSensorWarmingUp)
        state.sensorWarmupEndDate = nil
        XCTAssertFalse(state.isSensorWarmingUp)
    }

    func testFreshWarmupReportBridgesElapsedEstimateWithoutGlucose() throws {
        var state = makeState()
        state.sensorWarmupEndDate = Date().addingTimeInterval(-60)
        state.sensorWarmupConfirmationUntil = Date().addingTimeInterval(240)
        let decoded = try JSONDecoder().decode(XDripWidgetAttributes.ContentState.self, from: JSONEncoder().encode(state))
        XCTAssertFalse(decoded.isSensorWarmingUp)
        XCTAssertTrue(decoded.isWaitingForSensorReading)
        XCTAssertTrue(decoded.showsSensorWarmupStatus)
        XCTAssertTrue(decoded.bgReadingValues.isEmpty)
    }

    func testWaitingDoesNotStartBeforeEstimateOrOutliveFreshReport() {
        var state = makeState()
        state.sensorWarmupEndDate = Date().addingTimeInterval(60)
        state.sensorWarmupConfirmationUntil = Date().addingTimeInterval(300)
        XCTAssertFalse(state.isWaitingForSensorReading)
        XCTAssertTrue(state.isSensorWarmingUp)
        state.sensorWarmupEndDate = Date().addingTimeInterval(-60)
        state.sensorWarmupConfirmationUntil = Date().addingTimeInterval(-1)
        XCTAssertFalse(state.showsSensorWarmupStatus)
    }

    func testClearingConfirmationRemovesWaitingWithoutGlucose() {
        var state = makeState()
        state.sensorWarmupEndDate = Date().addingTimeInterval(-60)
        state.sensorWarmupConfirmationUntil = Date().addingTimeInterval(240)
        XCTAssertTrue(state.isWaitingForSensorReading)
        state.sensorWarmupConfirmationUntil = nil
        XCTAssertFalse(state.showsSensorWarmupStatus)
    }

    func testPayloadTrimmingPreservesWarmupAndLatestReading() throws {
        let now = Date()
        var state = makeState(values: Array(repeating: 120, count: 144), dates: (0..<144).map { now.addingTimeInterval(Double($0) * -300) })
        state.sensorWarmupEndDate = now.addingTimeInterval(-60)
        state.sensorWarmupConfirmationUntil = now.addingTimeInterval(240)
        let limited = state.limitedForActivityPayload(maximumEncodedBytes: 1000)
        XCTAssertLessThan(limited.bgReadingValues.count, state.bgReadingValues.count)
        XCTAssertEqual(limited.bgReadingDate, now)
        XCTAssertEqual(limited.sensorWarmupEndDate, state.sensorWarmupEndDate)
        XCTAssertEqual(limited.sensorWarmupConfirmationUntil, state.sensorWarmupConfirmationUntil)
        XCTAssertTrue(limited.isWaitingForSensorReading)
        XCTAssertLessThanOrEqual(try JSONEncoder().encode(limited).count, 1000)
    }

    private func makeState(values: [Double] = [], dates: [Date] = []) -> XDripWidgetAttributes.ContentState {
        XDripWidgetAttributes.ContentState(
            bgReadingValues: values, bgReadingDates: dates, isMgDl: true,
            slopeOrdinal: 0, deltaValueInUserUnit: nil,
            urgentLowLimitInMgDl: 55, lowLimitInMgDl: 70,
            highLimitInMgDl: 180, urgentHighLimitInMgDl: 250,
            liveActivityType: .normal, aidStatus: nil
        )
    }
}
