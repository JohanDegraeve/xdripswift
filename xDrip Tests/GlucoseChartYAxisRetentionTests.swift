//
//  GlucoseChartYAxisRetentionTests.swift
//  xdripTests
//
//  Created by Paul Plant on 9/8/26.
//  Copyright © 2026 Johan Degraeve. All rights reserved.
//

import XCTest
@testable import xdrip

final class GlucoseChartYAxisRetentionTests: XCTestCase {

    func testRetentionExpandsImmediatelyAndDoesNotContract() {
        var state = GlucoseChartYAxisRetentionState()

        state.retain(maximumInMgDl: 200)
        state.retain(maximumInMgDl: 320)
        state.retain(maximumInMgDl: 250)

        XCTAssertEqual(state.effectiveMaximum(for: 250), 320)
    }

    func testResetAllowsContraction() {
        var state = GlucoseChartYAxisRetentionState()

        state.retain(maximumInMgDl: 320)
        state.reset(to: 200)

        XCTAssertEqual(state.effectiveMaximum(for: 200), 200)
    }

    func testRetentionNeverClipsANewHigherMaximumAfterReset() {
        var state = GlucoseChartYAxisRetentionState()

        state.reset(to: 200)

        XCTAssertEqual(state.effectiveMaximum(for: 280), 280)
    }
}
