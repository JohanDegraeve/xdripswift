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

    func testBasalDirectionPreferenceDefaultsAndPersistence() throws {
        let suite = "BasalDirectionTests-" + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        XCTAssertTrue(defaults.renderBasalDownwards)
        defaults.renderBasalDownwards = false
        XCTAssertFalse(try XCTUnwrap(UserDefaults(suiteName: suite)).renderBasalDownwards)
        XCTAssertEqual(defaults.persistentDomain(forName: suite)?[UserDefaults.Key.renderBasalDownwards.rawValue] as? Bool, false)
        defaults.removeObject(forKey: UserDefaults.Key.renderBasalDownwards.rawValue)
        XCTAssertTrue(defaults.renderBasalDownwards)
    }

    func testDownwardBasalAnchorsZeroAtTopAndPreservesHeight() {
        let layout = GlucoseChartBasalLayout(cachedBaseline: -10, values: [-10, 14, 38],
                                            rendersDownwards: true, contentTop: 258, chartTop: 258)
        XCTAssertEqual(layout.topSpace, 48)
        XCTAssertEqual(layout.baseline, 306)
        XCTAssertEqual(layout.value(-10), 306)
        XCTAssertEqual(layout.value(14), 282)
        XCTAssertEqual(layout.value(38), 258)
    }

    func testBasalReusesAxisHeadroomWithoutReducingDepth() {
        let spacious = GlucoseChartBasalLayout(cachedBaseline: -10, values: [38],
                                              rendersDownwards: true, contentTop: 138, chartTop: 238)
        XCTAssertEqual(spacious.topSpace, 0)
        XCTAssertEqual(spacious.baseline, 238)
        XCTAssertEqual(spacious.value(38), 190)
        let partial = GlucoseChartBasalLayout(cachedBaseline: -10, values: [38],
                                            rendersDownwards: true, contentTop: 218, chartTop: 238)
        XCTAssertEqual(partial.topSpace, 28)
        XCTAssertEqual(partial.value(38), 218)
        // A short basal does not need the full maximum-rate band above the highest point.
        let short = GlucoseChartBasalLayout(cachedBaseline: -10, values: [10],
                                          rendersDownwards: true, contentTop: 238, chartTop: 238)
        XCTAssertEqual(short.topSpace, 20)
        XCTAssertEqual(short.value(10), 238)
    }

    func testBasalSpaceDependsOnDirectionAndVisibleData() {
        for downwards in [false, true] {
            let empty = GlucoseChartBasalLayout(cachedBaseline: -10, values: [],
                                               rendersDownwards: downwards, contentTop: 258, chartTop: 258)
            XCTAssertEqual(empty.topSpace, 0)
        }
        let upward = GlucoseChartBasalLayout(cachedBaseline: -10, values: [-10, 38],
                                            rendersDownwards: false, contentTop: 258, chartTop: 258)
        XCTAssertEqual(upward.topSpace, 0)
        XCTAssertEqual(upward.baseline, -10)
        XCTAssertEqual(upward.value(38), 38)
        let day = GlucoseChartBasalLayout(cachedBaseline: 0, values: [0, 38],
                                         rendersDownwards: true, contentTop: 258, chartTop: 258)
        XCTAssertEqual(day.topSpace, 38)
        let large = GlucoseChartBasalLayout(cachedBaseline: -10, values: [90],
                                           rendersDownwards: true, contentTop: 258, chartTop: 258)
        XCTAssertEqual(large.topSpace, 100)
        XCTAssertEqual(large.value(90), 258)
    }

    func testCompleteBasalCeilingHoldsUntilResetWithoutAccumulating() {
        var retention = GlucoseChartYAxisRetentionState()
        // Axis context stays at 250 while basal clearance varies with visible glucose.
        func candidate(_ glucose: Double) -> GlucoseChartBasalLayout {
            GlucoseChartBasalLayout(cachedBaseline: -10, values: [38], rendersDownwards: true,
                                   contentTop: glucose + 8, chartTop: 258)
        }
        for glucose in [250.0, 230, 200, 250, 190] {
            let required = candidate(glucose)
            let maximum = 250 + required.topSpace
            retention.retain(maximumInMgDl: maximum)
            let heldTop = retention.effectiveMaximum(for: maximum) + 8
            XCTAssertEqual(heldTop, 306)
            XCTAssertEqual(required.anchored(to: heldTop).value(38), 258)
        }
        let current = candidate(190)
        // Both the idle timer and double tap replace the held ceiling with today's candidate.
        retention.reset(to: 250 + current.topSpace)
        XCTAssertEqual(retention.effectiveMaximum(for: 250), 250)
        for _ in 0..<100 {
            retention.retain(maximumInMgDl: 250 + current.topSpace)
            XCTAssertEqual(retention.effectiveMaximum(for: 250), 250)
        }
        // A newly arriving high point must expand the chart immediately, before publication.
        let higher = candidate(300)
        XCTAssertEqual(retention.effectiveMaximum(for: 250 + higher.topSpace), 348)
    }

    /// A finished load can still have a main-queue delivery pending when the chart disappears.
    @MainActor
    func testCleanupRejectsAlreadyQueuedPublication() async {
        let coreDataManager = CoreDataManager(inMemoryModelName: ConstantsCoreData.modelName)
        let syncManager = NightscoutSyncManager(coreDataManager: coreDataManager, messageHandler: nil)
        let queue = OperationQueue()
        let chart = GlucoseChartStateManager(coreDataManager: coreDataManager, nightscoutSyncManager: syncManager, operationQueue: queue)
        let originalEndDate = chart.state.endDate
        let date = Date(timeIntervalSince1970: 100)
        let finished = DispatchSemaphore(value: 0)

        // An empty range avoids Core Data reads while we briefly hold the main queue to keep
        // delivery pending. The barrier confirms processing has finished, not just started.
        queue.isSuspended = true
        for _ in 0..<2 {
            // Queue both together to cover the coalesced callback as well as a computed result.
            chart.updateState(endDate: date, startDate: date, showTreatments: false) { _ in
                XCTFail("A result from before cleanup must not be delivered")
            }
        }
        queue.addBarrierBlock { finished.signal() }
        queue.isSuspended = false
        XCTAssertEqual(finished.wait(timeout: .now() + 5), .success)
        chart.cleanUpMemory()

        // Drain the old delivery before checking that it left the published state untouched.
        await withCheckedContinuation { continuation in
            DispatchQueue.main.async { continuation.resume() }
        }
        XCTAssertEqual(chart.state.endDate, originalEndDate)

        // A new lifecycle must still publish normally after the cleanup barrier.
        let updated: GlucoseChartState = await withCheckedContinuation { continuation in
            chart.updateState(endDate: date, startDate: date, showTreatments: false) {
                continuation.resume(returning: $0)
            }
        }
        XCTAssertEqual(updated.endDate, date)
    }

    /// Reopening the same range must reload storage rather than reuse the discarded cache.
    @MainActor
    func testCleanupResetsCacheBeforeFollowingLoad() async {
        let coreDataManager = CoreDataManager(inMemoryModelName: ConstantsCoreData.modelName)
        let date = Date().addingTimeInterval(-60)
        let treatment = TreatmentEntry(date: date, value: 3, treatmentType: .Insulin, nightscoutEventType: nil, enteredBy: "Test", nsManagedObjectContext: coreDataManager.mainManagedObjectContext)
        XCTAssertTrue(coreDataManager.saveChanges())
        let syncManager = NightscoutSyncManager(coreDataManager: coreDataManager, messageHandler: nil)
        let chart = GlucoseChartStateManager(coreDataManager: coreDataManager, nightscoutSyncManager: syncManager)
        let endDate = Date()
        let first: GlucoseChartState = await withCheckedContinuation { continuation in
            chart.updateState(endDate: endDate, startDate: date.addingTimeInterval(-3600), showTreatments: true) {
                continuation.resume(returning: $0)
            }
        }
        XCTAssertEqual(first.treatmentPoints.boluses.count, 1)

        // Keep the requested dates identical and omit forceReset so only lifecycle cleanup can
        // remove the old snapshot. Submitting immediately also exercises the barrier ordering.
        coreDataManager.mainManagedObjectContext.delete(treatment)
        XCTAssertTrue(coreDataManager.saveChanges())
        chart.cleanUpMemory()
        let reopened: GlucoseChartState = await withCheckedContinuation { continuation in
            chart.updateState(endDate: endDate, startDate: date.addingTimeInterval(-3600), showTreatments: true) {
                continuation.resume(returning: $0)
            }
        }
        XCTAssertTrue(reopened.treatmentPoints.boluses.isEmpty)
    }

    /// Repeated chart updates must not retain the owner through queued closures or old work items.
    @MainActor
    func testDelayedStateReleasesAfterHeavyRescheduling() {
        var state: ChartDelayedState<Int>? = ChartDelayedState(0)
        weak var releasedState = state
        // Exceed the depth seen in the crash while keeping every callback pending during teardown.
        for value in 0..<20_000 { state?.schedule(value, after: 60) }
        state = nil
        XCTAssertNil(releasedState)
    }

    /// Only the latest request may publish, and disappearance cancellation must prevent publication.
    @MainActor
    func testDelayedStateReplacementAndCancellation() async throws {
        let state = ChartDelayedState(0)
        state.schedule(1, after: 0.02)
        state.schedule(2, after: 0)
        try await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertEqual(state.value, 2)

        state.schedule(3, after: 0.02)
        state.cancel()
        try await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertEqual(state.value, 2)
    }

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
