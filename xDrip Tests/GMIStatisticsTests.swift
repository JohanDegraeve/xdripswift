//
//  GMIStatisticsTests.swift
//  xdripTests
//
//  Created by Paul Plant on 21/09/2026.
//  Copyright © 2026 Johan Degraeve. All rights reserved.
//

import Combine
import PDFKit
import XCTest
@testable import xdrip

final class GMIStatisticsTests: XCTestCase {
    func testGMIAndIFCCConversionUseUnroundedValues() {
        let percentage = GlucoseReportClinicalMath.gmiPercentage(forAverageMgDl: 120)
        XCTAssertEqual(percentage, 6.1804, accuracy: 0.000001)
        XCTAssertEqual(GlucoseReportClinicalMath.gmiValue(7, usesIFCC: true), 53, accuracy: 0.01)
        // Converting a rounded 6.2% instead would incorrectly display 44 mmol/mol.
        XCTAssertEqual(GlucoseReportFormatting.gmi(6.23, usesIFCC: true), "45 mmol/mol")
        XCTAssertEqual(GlucoseReportFormatting.gmi(6.22, usesIFCC: true), "44 mmol/mol")
        XCTAssertEqual(GlucoseReportFormatting.gmi(6.22, usesIFCC: true, compactUnit: true), "44 mmol")
        XCTAssertEqual(GlucoseReportFormatting.gmi(6.22, usesIFCC: false, locale: Locale(identifier: "en_US")), "6.2%")
        XCTAssertEqual(GlucoseReportFormatting.gmi(6.22, usesIFCC: false, locale: Locale(identifier: "es_ES")), "6,2%")
        XCTAssertEqual(GlucoseReportFormatting.gmi(0, usesIFCC: true), "-")
    }

    func testNearbyAveragesCanDisplayTheSameWholeNumberGMI() {
        let first = GlucoseReportClinicalMath.gmiPercentage(forAverageMgDl: 107)
        let second = GlucoseReportClinicalMath.gmiPercentage(forAverageMgDl: 110)
        XCTAssertNotEqual(first, second)
        XCTAssertEqual(GlucoseReportFormatting.gmi(first, usesIFCC: true), "41 mmol/mol")
        XCTAssertEqual(GlucoseReportFormatting.gmi(second, usesIFCC: true), "41 mmol/mol")
    }

    func testChartDomainsContainConvertedValuesAndHaveIntegerIFCCTicks() {
        for percentages in [[], [6.2], [5.1, 6.2, 9.9]] as [[Double]] {
            let domain = GlucoseReportClinicalMath.gmiDomain(percentages: percentages, usesIFCC: true)
            for percentage in percentages {
                XCTAssertTrue(domain.contains(GlucoseReportClinicalMath.gmiValue(percentage, usesIFCC: true)))
            }
            let ticks = [domain.lowerBound, (domain.lowerBound + domain.upperBound) / 2, domain.upperBound]
            XCTAssertTrue(ticks.allSatisfy { $0.rounded() == $0 })
            XCTAssertLessThan(domain.lowerBound, domain.upperBound)
        }
        XCTAssertEqual(GlucoseReportClinicalMath.gmiDomain(percentages: [6.2], usesIFCC: false), 6 ... 7)
    }

    @MainActor
    func testHomeSummaryAndTrendShareSamplesAcrossUnitsAndCachedResults() async throws {
        let savedIFCC = UserDefaults.standard.object(forKey: "useIFCCA1C")
        let savedGlucoseUnit = UserDefaults.standard.object(forKey: UserDefaults.Key.bloodGlucoseUnitIsMgDl.rawValue)
        defer {
            UserDefaults.standard.set(savedIFCC, forKey: "useIFCCA1C")
            UserDefaults.standard.set(savedGlucoseUnit, forKey: UserDefaults.Key.bloodGlucoseUnitIsMgDl.rawValue)
        }
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let core = try CoreDataManager(testModelName: ConstantsCoreData.modelName,
            persistentStoreURL: directory.appendingPathComponent("GMI.sqlite"))
        defer {
            try? core.disconnectPersistentStoresForTesting()
            try? FileManager.default.removeItem(at: directory)
        }
        let end = Date()
        // One-minute data exposes the old Home-only 4.5-minute filter. Its selected values are
        // always 100, whereas the shared population averages 180 mg/dL.
        for index in 0..<60 {
            let value = index % 5 == 0 ? 100.0 : 200.0
            let reading = BgReading(timeStamp: end.addingTimeInterval(Double(index - 120) * 60),
                sensor: nil, calibration: nil, rawData: value, deviceName: "GMI regression",
                nsManagedObjectContext: core.mainManagedObjectContext)
            reading.calculatedValue = value
        }
        // Suppressed readings must not contribute to either surface.
        let suppressed = BgReading(timeStamp: end.addingTimeInterval(-30 * 60), sensor: nil,
            calibration: nil, rawData: 350, deviceName: "GMI regression",
            nsManagedObjectContext: core.mainManagedObjectContext)
        suppressed.calculatedValue = 350
        suppressed.isSuppressedByFiveMinuteCadence = true
        XCTAssertTrue(core.saveChangesSynchronously())
        let manager = StatisticsManager(coreDataManager: core)
        let expected = 7.6156
        for usesMgDl in [true, false] {
            UserDefaults.standard.bloodGlucoseUnitIsMgDl = usesMgDl
            for usesIFCC in [false, true] {
                UserDefaults.standard.useIFCCA1C = usesIFCC
                let configuration = GlucoseReportConfiguration(patientName: "GMI regression", patientID: "",
                    period: .seven, aidPeriod: .notIncluded, paperSize: .a4, language: .english,
                    usesIFCC: usesIFCC)
                let analytics = await manager.reportAnalytics(for: configuration)
                let home = await withCheckedContinuation { continuation in
                    manager.calculateStatistics(fromDate: end.addingTimeInterval(-7 * 86400), toDate: end) {
                        continuation.resume(returning: $0)
                    }
                }
                XCTAssertEqual(analytics.sampleCount, 60)
                XCTAssertEqual(home.gmiPercentage, expected, accuracy: 0.000001)
                XCTAssertEqual(home.gmiPercentage, analytics.gmiPercentage, accuracy: 0.000001)
                XCTAssertEqual(try XCTUnwrap(analytics.trendPoints.first).gmiPercentage, expected, accuracy: 0.000001)
                let model = RootHomeStateModel()
                model.updateStatistics(home)
                XCTAssertEqual(model.state.statistics.gmi.title, "GMI")
                XCTAssertEqual(model.state.statistics.gmi.value,
                    GlucoseReportFormatting.gmi(expected, usesIFCC: usesIFCC, compactUnit: true))
                // Home's existing average is intentionally unaffected by GMI sample alignment.
                XCTAssertEqual(home.averageStatisticValue, usesMgDl ? 100 : 100 * ConstantsBloodGlucose.mgDlToMmoll, accuracy: 0.000001)
            }
        }
    }

    @MainActor
    func testSummaryGMIUpdatesWhenChangingAndRevisitingPeriods() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let core = try CoreDataManager(testModelName: ConstantsCoreData.modelName,
            persistentStoreURL: directory.appendingPathComponent("Periods.sqlite"))
        defer {
            try? core.disconnectPersistentStoresForTesting()
            try? FileManager.default.removeItem(at: directory)
        }
        let end = Date()
        // Distinct averages in each window make an accidentally static summary unmistakable.
        for day in 0..<90 {
            let value = day < 7 ? 100.0 : day < 30 ? 160.0 : day < 60 ? 200.0 : 240.0
            for hour in 0..<24 {
                let date = end.addingTimeInterval(-Double(day * 86400 + hour * 3600 + 1800))
                let reading = BgReading(timeStamp: date, sensor: nil, calibration: nil,
                    rawData: value, deviceName: "GMI period regression",
                    nsManagedObjectContext: core.mainManagedObjectContext)
                reading.calculatedValue = value
            }
        }
        XCTAssertTrue(core.saveChangesSynchronously())
        let viewModel = StatisticsViewModel(statisticsManager: StatisticsManager(coreDataManager: core))
        let cases: [(GlucoseReportPeriod, Double, String, String)] = [
            (.seven, 100, "5.7%", "39 mmol/mol"),
            (.thirty, 146, "6.8%", "51 mmol/mol"),
            (.sixty, 173, "7.4%", "58 mmol/mol"),
            (.ninety, 195.3333333333333, "8.0%", "64 mmol/mol"),
            (.seven, 100, "5.7%", "39 mmol/mol")
        ]
        for (period, expectedAverage, percentageText, ifccText) in cases {
            let loaded = expectation(description: "Summary updated for \(period.rawValue) days")
            var result: GlucoseReportAnalytics?
            let subscription = viewModel.$analytics.compactMap { $0 }
                .first { abs($0.periodEnd.timeIntervalSince($0.periodStart) - Double(period.rawValue * 86400)) < 1 }
                .sink {
                    result = $0
                    loaded.fulfill()
                }
            viewModel.selectedPeriod = period
            await fulfillment(of: [loaded], timeout: 10)
            subscription.cancel()
            let analytics = try XCTUnwrap(result)
            XCTAssertEqual(analytics.sampleCount, period.rawValue * 24)
            XCTAssertEqual(analytics.averageMgDl, expectedAverage, accuracy: 0.000001)
            XCTAssertEqual(analytics.gmiPercentage, 3.31 + 0.02392 * expectedAverage, accuracy: 0.000001)
            XCTAssertEqual(GlucoseReportFormatting.gmi(analytics.gmiPercentage, usesIFCC: false,
                locale: Locale(identifier: "en_US")), percentageText)
            XCTAssertEqual(GlucoseReportFormatting.gmi(analytics.gmiPercentage, usesIFCC: true), ifccText)
        }
    }

    @MainActor
    func testReportSnapshotAndBothPaperSizesRenderInBothUnits() async throws {
        let savedIFCC = UserDefaults.standard.object(forKey: "useIFCCA1C")
        defer { UserDefaults.standard.set(savedIFCC, forKey: "useIFCCA1C") }
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let core = try CoreDataManager(testModelName: ConstantsCoreData.modelName,
            persistentStoreURL: directory.appendingPathComponent("Report.sqlite"))
        defer {
            try? core.disconnectPersistentStoresForTesting()
            try? FileManager.default.removeItem(at: directory)
        }
        let end = Date()
        for index in 1...2016 {
            let value = 120 + 35 * sin(Double(index) / 50)
            let reading = BgReading(timeStamp: end.addingTimeInterval(-Double(index) * 300),
                sensor: nil, calibration: nil, rawData: value, deviceName: "GMI report regression",
                nsManagedObjectContext: core.mainManagedObjectContext)
            reading.calculatedValue = value
        }
        XCTAssertTrue(core.saveChangesSynchronously())
        let manager = StatisticsManager(coreDataManager: core)
        for usesIFCC in [false, true] {
            for paperSize in [GlucoseReportPaperSize.a4, .usLetter] {
                let configuration = GlucoseReportConfiguration(
                    patientName: "GMI-QA-\(usesIFCC ? "IFCC" : "Percent")-\(paperSize)", patientID: "Synthetic data",
                    period: .seven, aidPeriod: .notIncluded, paperSize: paperSize, language: .english,
                    usesIFCC: usesIFCC)
                // Changes after capture must not affect the generated report.
                UserDefaults.standard.useIFCCA1C = !usesIFCC
                let analytics = await manager.reportAnalytics(for: configuration)
                let url = try await GlucoseReportPDFGenerator().generatePDF(configuration: configuration,
                    analytics: analytics, generatedAt: end)
                let pdf = try XCTUnwrap(PDFDocument(url: url))
                XCTAssertEqual(pdf.pageCount, 3)
                XCTAssertEqual(try XCTUnwrap(pdf.page(at: 0)).bounds(for: .mediaBox).size, paperSize.pageSize)
                // Keep the rendered report in the test results for visual review.
                let attachment = XCTAttachment(contentsOfFile: url)
                attachment.lifetime = .keepAlways
                add(attachment)
                try FileManager.default.removeItem(at: url)
            }
        }
    }
}
