//
//  NightscoutFollowerGapFillTests.swift
//  xdripTests
//
//  Created by Paul Plant on 13/8/26.
//  Copyright © 2026 Johan Degraeve. All rights reserved.
//

import XCTest
@testable import xdrip

final class NightscoutFollowerGapFillTests: XCTestCase {
    private let site = "https://example.com"
    private let auditEnd = Date(timeIntervalSince1970: 2_000_000_000)

    func testInitialAuditCoversExactlySeventyTwoHours() {
        let window = NightscoutFollowerGapFillService.auditWindow(
            endingAt: auditEnd,
            lastSuccessfulEnd: nil,
            storedSite: nil,
            currentSite: site
        )

        XCTAssertTrue(window.isInitial)
        XCTAssertEqual(window.interval.end, auditEnd)
        XCTAssertEqual(window.interval.duration, 72 * 60 * 60, accuracy: 0.001)
    }

    func testMatchingCheckpointUsesThirtyMinuteOverlap() {
        let checkpoint = auditEnd.addingTimeInterval(-4 * 60 * 60)
        let window = NightscoutFollowerGapFillService.auditWindow(
            endingAt: auditEnd,
            lastSuccessfulEnd: checkpoint,
            storedSite: site,
            currentSite: site
        )

        XCTAssertFalse(window.isInitial)
        XCTAssertEqual(window.interval.start, checkpoint.addingTimeInterval(-30 * 60))
        XCTAssertEqual(window.interval.end, auditEnd)
    }

    func testIncrementalAuditNeverExceedsSeventyTwoHours() {
        let oldCheckpoint = auditEnd.addingTimeInterval(-7 * 24 * 60 * 60)
        let window = NightscoutFollowerGapFillService.auditWindow(
            endingAt: auditEnd,
            lastSuccessfulEnd: oldCheckpoint,
            storedSite: site,
            currentSite: site
        )

        XCTAssertFalse(window.isInitial)
        XCTAssertEqual(window.interval.duration, 72 * 60 * 60, accuracy: 0.001)
    }

    func testChangedSiteAndFutureCheckpointUseInitialWindow() {
        let changedSite = NightscoutFollowerGapFillService.auditWindow(
            endingAt: auditEnd,
            lastSuccessfulEnd: auditEnd.addingTimeInterval(-60),
            storedSite: "https://other.example.com",
            currentSite: site
        )
        let futureCheckpoint = NightscoutFollowerGapFillService.auditWindow(
            endingAt: auditEnd,
            lastSuccessfulEnd: auditEnd.addingTimeInterval(60),
            storedSite: site,
            currentSite: site
        )

        XCTAssertTrue(changedSite.isInitial)
        XCTAssertTrue(futureCheckpoint.isInitial)
        XCTAssertEqual(changedSite.interval.duration, 72 * 60 * 60, accuracy: 0.001)
        XCTAssertEqual(futureCheckpoint.interval.duration, 72 * 60 * 60, accuracy: 0.001)
    }

    func testInvalidCheckpointUsesInitialWindow() {
        let window = NightscoutFollowerGapFillService.auditWindow(
            endingAt: auditEnd,
            lastSuccessfulEnd: Date(timeIntervalSinceReferenceDate: .nan),
            storedSite: site,
            currentSite: site
        )

        XCTAssertTrue(window.isInitial)
        XCTAssertEqual(window.interval.duration, 72 * 60 * 60, accuracy: 0.001)
    }

    func testExactlyFifteenMinuteGapIsIgnoredAndLargerGapIsFilled() {
        let start = auditEnd.addingTimeInterval(-60 * 60)
        let interval = DateInterval(start: start, end: auditEnd)
        let timestamps = [
            start,
            start.addingTimeInterval(15 * 60),
            start.addingTimeInterval(30 * 60 + 1),
            start.addingTimeInterval(45 * 60)
        ]

        let gaps = NightscoutFollowerGapFillService.gapFillIntervals(timestamps: timestamps, in: interval)

        XCTAssertEqual(gaps, [
            DateInterval(
                start: start.addingTimeInterval(15 * 60),
                end: start.addingTimeInterval(30 * 60 + 1)
            )
        ])
    }

    func testLeadingAndInternalGapsAreFilledButTrailingGapIsIgnored() {
        let start = auditEnd.addingTimeInterval(-60 * 60)
        let interval = DateInterval(start: start, end: auditEnd)
        let first = start.addingTimeInterval(20 * 60)
        let second = first.addingTimeInterval(5 * 60)
        let third = second.addingTimeInterval(20 * 60)

        let gaps = NightscoutFollowerGapFillService.gapFillIntervals(
            timestamps: [third, first, second],
            in: interval
        )

        XCTAssertEqual(gaps, [
            DateInterval(start: start, end: first),
            DateInterval(start: second, end: third)
        ])
    }

    func testEmptyLocalWindowFillsCompleteAuditInterval() {
        let interval = DateInterval(start: auditEnd.addingTimeInterval(-60 * 60), end: auditEnd)

        XCTAssertEqual(
            NightscoutFollowerGapFillService.gapFillIntervals(timestamps: [], in: interval),
            [interval]
        )
    }

    func testLegacyCheckpointMigratesAsGlucoseCoverageOnly() {
        let legacyEnd = auditEnd.addingTimeInterval(-60 * 60)

        let coverage = NightscoutFollowerGapFillService.migratedCoverage(
            storedCoverage: nil,
            legacyEnd: legacyEnd,
            legacySite: site,
            currentSite: site
        )

        XCTAssertEqual(coverage.site, site)
        XCTAssertEqual(coverage.bgReadingsEnd, legacyEnd)
        XCTAssertNil(coverage.treatmentsEnd)
        XCTAssertNil(coverage.deviceStatusEnd)
        XCTAssertNil(coverage.profilesEnd)
    }

    func testChangedSiteDoesNotMigrateLegacyCoverage() {
        let coverage = NightscoutFollowerGapFillService.migratedCoverage(
            storedCoverage: nil,
            legacyEnd: auditEnd.addingTimeInterval(-60),
            legacySite: "https://other.example.com",
            currentSite: site
        )

        XCTAssertEqual(coverage, .init(site: site))
    }

    func testFreshCoveragePlansAllEnabledResourcesForSeventyTwoHours() {
        let plan = NightscoutFollowerGapFillService.recoveryPlan(
            endingAt: auditEnd,
            site: site,
            coverage: .init(site: site),
            importsTreatments: true,
            importsStatus: true
        )

        XCTAssertEqual(Set(plan.windows.keys), Set(NightscoutFollowerGapFillService.Resource.allCases))
        for window in plan.windows.values {
            XCTAssertTrue(window.isInitial)
            XCTAssertEqual(window.interval.duration, 72 * 60 * 60, accuracy: 0.001)
        }
    }

    func testExistingGlucoseCheckpointDoesNotSuppressInitialSparseRecovery() throws {
        let recent = auditEnd.addingTimeInterval(-5 * 60)
        let coverage = NightscoutFollowerGapFillService.CoverageState(
            site: site,
            bgReadingsEnd: recent
        )

        let plan = NightscoutFollowerGapFillService.recoveryPlan(
            endingAt: auditEnd,
            site: site,
            coverage: coverage,
            importsTreatments: true,
            importsStatus: true
        )

        XCTAssertNil(plan.windows[.bgReadings])
        XCTAssertEqual(try XCTUnwrap(plan.windows[.treatments]).interval.duration, 72 * 60 * 60, accuracy: 0.001)
        XCTAssertEqual(try XCTUnwrap(plan.windows[.deviceStatus]).interval.duration, 72 * 60 * 60, accuracy: 0.001)
        XCTAssertEqual(try XCTUnwrap(plan.windows[.profiles]).interval.duration, 72 * 60 * 60, accuracy: 0.001)
    }

    func testIncrementalSparseRecoveryUsesThirtyMinuteOverlap() {
        let checkpoint = auditEnd.addingTimeInterval(-2 * 60 * 60)
        let coverage = NightscoutFollowerGapFillService.CoverageState(
            site: site,
            bgReadingsEnd: checkpoint,
            treatmentsEnd: checkpoint,
            deviceStatusEnd: checkpoint,
            profilesEnd: checkpoint
        )

        let plan = NightscoutFollowerGapFillService.recoveryPlan(
            endingAt: auditEnd,
            site: site,
            coverage: coverage,
            importsTreatments: true,
            importsStatus: true
        )

        for window in plan.windows.values {
            XCTAssertFalse(window.isInitial)
            XCTAssertEqual(window.interval.start, checkpoint.addingTimeInterval(-30 * 60))
            XCTAssertEqual(window.interval.end, auditEnd)
        }
    }

    func testPolicyGatesSparseResources() {
        let noTherapy = NightscoutFollowerGapFillService.recoveryPlan(
            endingAt: auditEnd,
            site: site,
            coverage: .init(site: site),
            importsTreatments: false,
            importsStatus: false
        )
        let treatmentsOnly = NightscoutFollowerGapFillService.recoveryPlan(
            endingAt: auditEnd,
            site: site,
            coverage: .init(site: site),
            importsTreatments: true,
            importsStatus: false
        )

        XCTAssertEqual(Set(noTherapy.windows.keys), [.bgReadings])
        XCTAssertEqual(Set(treatmentsOnly.windows.keys), [.bgReadings, .treatments])
    }

    func testRecentSuccessfulEndpointsAreCoalesced() {
        let recent = auditEnd.addingTimeInterval(-5 * 60)
        let coverage = NightscoutFollowerGapFillService.CoverageState(
            site: site,
            bgReadingsEnd: recent,
            treatmentsEnd: recent,
            deviceStatusEnd: recent,
            profilesEnd: recent
        )

        let plan = NightscoutFollowerGapFillService.recoveryPlan(
            endingAt: auditEnd,
            site: site,
            coverage: coverage,
            importsTreatments: true,
            importsStatus: true
        )

        XCTAssertTrue(plan.isEmpty)
    }

    func testProfileRecoveryIncludesBaselineAndInWindowChanges() {
        let start = auditEnd.addingTimeInterval(-72 * 60 * 60)
        let interval = DateInterval(start: start, end: auditEnd)

        func profile(id: String, startDate: Date) -> NightscoutProfile {
            var profile = NightscoutProfile()
            profile.id = id
            profile.startDate = startDate
            return profile
        }

        let old = profile(id: "old", startDate: start.addingTimeInterval(-48 * 60 * 60))
        let baseline = profile(id: "baseline", startDate: start.addingTimeInterval(-60 * 60))
        let firstChange = profile(id: "first", startDate: start.addingTimeInterval(60 * 60))
        let secondChange = profile(id: "second", startDate: auditEnd.addingTimeInterval(-60 * 60))
        let atEnd = profile(id: "end", startDate: auditEnd)

        let selected = NightscoutImportService.profilesForFollowerRecovery(
            [secondChange, old, atEnd, firstChange, baseline],
            in: interval
        )

        XCTAssertEqual(selected.map(\.id), ["baseline", "first", "second"])
    }
}
