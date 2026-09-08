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
