//
//  ExperimentalFeaturesTests.swift
//  xdripTests
//
//  Glucose prediction, insulin catalogue and chart helpers ported from JugglucoNG. Numeric
//  expectations were computed with a Python port of the same arithmetic.
//

import XCTest
import SwiftUI
@testable import xdrip

final class ExperimentalFeaturesTests: XCTestCase {

    private let start = Date(timeIntervalSince1970: 1_800_000_000)

    private func flat(_ value: Double, count: Int = 12) -> [GlucosePredictionKernel.Sample] {
        (0..<count).map { GlucosePredictionKernel.Sample(date: start.addingTimeInterval(TimeInterval($0 * 60)), value: value) }
    }

    private func simulate(_ history: [GlucosePredictionKernel.Sample], momentum: Bool = false, horizon: Int = 120,
                          delta: @escaping (Date) -> Double = { _ in 0 }) -> [GlucosePredictionPoint] {
        GlucosePredictionKernel.simulate(history: history, isMmol: false, trendMomentum: momentum, horizonMinutes: horizon,
                                         stepMinutes: 5, targetLow: 70, targetHigh: 180, treatmentDeltaAt: delta)
    }

    // MARK: Kernel (JugglucoNG GlucosePredictionKernelTests)

    func testTooLittleHistoryPredictsNothing() {
        XCTAssertTrue(simulate([]).isEmpty)
        XCTAssertTrue(simulate(flat(120, count: 1)).isEmpty)
    }

    func testForecastStartsAtTheNewestReadingAndSpansTheHorizon() throws {
        let history = flat(120)
        let result = simulate(history, horizon: 60)
        let first = try XCTUnwrap(result.first), last = try XCTUnwrap(result.last)
        XCTAssertEqual(first.date, history.last?.date)
        XCTAssertEqual(first.value, 120, accuracy: 1e-9)
        XCTAssertEqual(first.confidence, 1)
        XCTAssertEqual(last.date.timeIntervalSince(first.date), 60 * 60)
        XCTAssertEqual(result.count, 1 + 12)
    }

    func testFlatHistorySettlesSlowlyTowardTheTargetCentre() throws {
        // 120 + (125 - 120) * (1 - e^(-120/240)) * 0.18
        let last = try XCTUnwrap(simulate(flat(120)).last)
        XCTAssertEqual(last.unclampedValue, 120.354_122_406, accuracy: 1e-6)
        XCTAssertEqual(last.confidence, 0.26, accuracy: 1e-9)
    }

    func testConfidenceDecaysAcrossTheHorizon() {
        let confidences = simulate(flat(120)).map(\.confidence)
        XCTAssertTrue(zip(confidences, confidences.dropFirst()).allSatisfy { $1 <= $0 })
        XCTAssertLessThan(confidences.last ?? 1, confidences.first ?? 0)
    }

    func testRisingSeriesWithMomentumForecastsHigher() throws {
        let rising = (0..<12).map { GlucosePredictionKernel.Sample(date: start.addingTimeInterval(TimeInterval($0 * 60)), value: 100 + Double($0) * 2) }
        let withMomentum = try XCTUnwrap(simulate(rising, momentum: true).last).unclampedValue
        let without = try XCTUnwrap(simulate(rising, momentum: false).last).unclampedValue
        XCTAssertEqual(withMomentum, 165.434_628_359, accuracy: 1e-6)
        XCTAssertEqual(without, 122.212_473_444, accuracy: 1e-6)
    }

    func testDrawnValueSaturatesButTheUnclampedValueDoesNot() throws {
        let huge = try XCTUnwrap(simulate(flat(120)) { _ in -400 }.last)
        XCTAssertEqual(huge.value, 18)
        XCTAssertEqual(huge.unclampedValue, -279.645_877_594, accuracy: 1e-6)
    }

    func testCurveFractionIsBoundedAndMonotonic() {
        let points = [InsulinCurvePoint(minute: 0, activity: 0), InsulinCurvePoint(minute: 30, activity: 1),
                      InsulinCurvePoint(minute: 60, activity: 1), InsulinCurvePoint(minute: 120, activity: 0.6),
                      InsulinCurvePoint(minute: 240, activity: 0)]
        XCTAssertEqual(InsulinCurveMath.cumulativeFraction(points, elapsedMinutes: 0), 0)
        XCTAssertEqual(InsulinCurveMath.cumulativeFraction(points, elapsedMinutes: 240), 1, accuracy: 1e-9)
        XCTAssertEqual(InsulinCurveMath.cumulativeFraction(points, elapsedMinutes: 600), 1, accuracy: 1e-9)
        let fractions = stride(from: 0.0, through: 240, by: 20).map { InsulinCurveMath.cumulativeFraction(points, elapsedMinutes: $0) }
        XCTAssertTrue(zip(fractions, fractions.dropFirst()).allSatisfy { $1 >= $0 - 1e-12 })
        XCTAssertEqual(InsulinCurveMath.cumulativeFraction([InsulinCurvePoint(minute: 0, activity: 1)], elapsedMinutes: 1), 0)
    }

    // MARK: Treatment model

    private func model() -> ExperimentalPredictionModel {
        var model = ExperimentalPredictionModel()
        model.trendMomentum = false
        return model
    }

    private func readings(_ value: Double) -> [(date: Date, mgDl: Double)] {
        flat(value).map { (date: $0.date, mgDl: $0.value) }
    }

    func testCarbsRaiseTheForecastBySensitivityOverCarbRatio() throws {
        let baseline = start.addingTimeInterval(11 * 60)
        let carbs = ExperimentalTreatment(date: baseline, amount: 40, kind: .carbs, notes: nil)
        let result = model().forecast(readings: readings(120), treatments: [carbs], isMmol: false,
                                      targetLowMgDl: 70, targetHighMgDl: 180, now: baseline)
        // 40 g / 10 g/U * 54 mg/dL, fully absorbed within two hours, plus the settling term.
        XCTAssertEqual(try XCTUnwrap(result.last).unclampedValue, 336.354_122_406, accuracy: 1e-6)
    }

    func testBolusLowersTheForecastAlongItsInsulinCurve() throws {
        let baseline = start.addingTimeInterval(11 * 60)
        let bolus = ExperimentalTreatment(date: baseline, amount: 4, kind: .bolus, notes: nil)
        let result = model().forecast(readings: readings(200), treatments: [bolus], isMmol: false,
                                      targetLowMgDl: 70, targetHighMgDl: 180, now: baseline)
        // NovoRapid's curve has delivered 55.95 % of its action after two hours.
        XCTAssertEqual(try XCTUnwrap(result.last).unclampedValue, 73.831_515_943, accuracy: 1e-6)
    }

    func testBasalInsulinIsNotPartOfTheForecast() throws {
        let baseline = start.addingTimeInterval(11 * 60)
        let basal = ExperimentalTreatment(date: baseline, amount: 20, kind: .basalInjection, notes: "Tresiba")
        let plain = model().forecast(readings: readings(120), treatments: [], isMmol: false, targetLowMgDl: 70, targetHighMgDl: 180, now: baseline)
        let withBasal = model().forecast(readings: readings(120), treatments: [basal], isMmol: false, targetLowMgDl: 70, targetHighMgDl: 180, now: baseline)
        XCTAssertEqual(try XCTUnwrap(withBasal.last).unclampedValue, try XCTUnwrap(plain.last).unclampedValue, accuracy: 1e-9)
    }

    func testForecastNeedsARecentReading() {
        let tooLate = start.addingTimeInterval(11 * 60 + ExperimentalPredictionModel.maximumBaselineAge + 60)
        XCTAssertTrue(model().forecast(readings: readings(120), treatments: [], isMmol: false,
                                       targetLowMgDl: 70, targetHighMgDl: 180, now: tooLate).isEmpty)
    }

    func testMmolForecastIsReturnedInMgDl() throws {
        let baseline = start.addingTimeInterval(11 * 60)
        let result = model().forecast(readings: readings(120), treatments: [], isMmol: true, targetLowMgDl: 70, targetHighMgDl: 180, now: baseline)
        XCTAssertEqual(try XCTUnwrap(result.first).value, 120, accuracy: 1e-9)
        XCTAssertEqual(try XCTUnwrap(result.last).unclampedValue, 120.354_122_406, accuracy: 1e-6)
    }

    // MARK: Insulin catalogue

    func testEveryCurveStartsAtMinuteZeroWithSortedMinutesAndBoundedActivity() {
        for insulin in InsulinProfile.allCases {
            let points = InsulinCurveCatalogue.referenceCurve(insulin)
            XCTAssertGreaterThanOrEqual(points.count, 2, insulin.rawValue)
            XCTAssertEqual(points.first?.minute, 0, insulin.rawValue)
            XCTAssertTrue(zip(points, points.dropFirst()).allSatisfy { $0.minute < $1.minute }, insulin.rawValue)
            XCTAssertTrue(points.allSatisfy { (0...1).contains($0.activity) }, insulin.rawValue)
        }
    }

    func testGeneratedRapidCurveMatchesJugglucoNG() {
        let aspart = InsulinCurveCatalogue.referenceCurve(.aspart)
        XCTAssertEqual(aspart.map(\.minute), [0, 14, 28, 40, 98, 174, 264, 360])
        XCTAssertEqual(aspart[3].activity, 0.927_127_140, accuracy: 1e-6)
        XCTAssertEqual(InsulinCurveMath.cumulativeFraction(aspart, elapsedMinutes: 60), 0.248_447_817, accuracy: 1e-6)
    }

    func testFiaspReferenceCurveDeliversAboutHalfInTwoHours() {
        XCTAssertEqual(InsulinCurveMath.cumulativeFraction(InsulinCurveCatalogue.referenceCurve(.fiasp), elapsedMinutes: 120), 0.552_955_201, accuracy: 1e-6)
    }

    func testLyumjevCurveIsInterpolatedBetweenStudyDosesAndKeepsAPeakOfOne() {
        let curve = InsulinCurveCatalogue.curve(for: .urli, units: 11)
        XCTAssertEqual(curve.map(\.activity).max() ?? 0, 1, accuracy: 1e-9)
        XCTAssertEqual(InsulinCurveCatalogue.curve(for: .urli, units: 3).last?.minute, 276)
        XCTAssertEqual(InsulinCurveCatalogue.curve(for: .urli, units: 40).last?.minute, 438)
    }

    func testNotesNameTheInsulinAndSpecificNamesWin() {
        XCTAssertEqual(InsulinProfile.matching(notes: "Tresiba 20"), .degludec)
        XCTAssertEqual(InsulinProfile.matching(notes: "humalog mix 25"), .lisproMix7525)
        XCTAssertEqual(InsulinProfile.matching(notes: "Humalog"), .lispro)
        XCTAssertEqual(InsulinProfile.matching(notes: "Новорапід"), .aspart)
        XCTAssertNil(InsulinProfile.matching(notes: "after lunch"))
        XCTAssertNil(InsulinProfile.matching(notes: nil))
    }

    func testEveryPerDoseChoiceIsRecognisedFromTheNameItWrites() {
        for insulin in InsulinProfile.perDoseBolusChoices + InsulinProfile.perDoseBasalChoices {
            XCTAssertEqual(InsulinProfile.matching(notes: insulin.shortName), insulin, insulin.shortName)
        }
    }

    func testTreatmentUsesItsNamedInsulinOrTheDefault() {
        let named = ExperimentalTreatment(date: start, amount: 4, kind: .bolus, notes: "Fiasp")
        let unnamed = ExperimentalTreatment(date: start, amount: 4, kind: .bolus, notes: nil)
        let basal = ExperimentalTreatment(date: start, amount: 20, kind: .basalInjection, notes: "evening")
        XCTAssertEqual(named.insulin(bolusDefault: .aspart, basalDefault: .degludec), .fiasp)
        XCTAssertEqual(unnamed.insulin(bolusDefault: .aspart, basalDefault: .degludec), .aspart)
        XCTAssertEqual(basal.insulin(bolusDefault: .aspart, basalDefault: .degludec), .degludec)
        XCTAssertNil(ExperimentalTreatment(date: start, amount: 30, kind: .carbs, notes: "Fiasp").insulin(bolusDefault: .aspart, basalDefault: .degludec))
    }

    // MARK: Insulin activity

    func testActivityOfADoseAddsUpToTheDose() {
        let shape = InsulinActivityStack.shape(for: .aspart, units: 6)
        let total = (0...360).reduce(0.0) { $0 + InsulinActivityStack.rate(units: 6, shape: shape, minutes: Double($1)) } / 60
        XCTAssertEqual(total, 6, accuracy: 0.05)
        XCTAssertEqual(InsulinActivityStack.rate(units: 6, shape: shape, minutes: 400), 0)
    }

    func testSteadyStateCurveIsReducedToOneDailyDose() {
        let shape = InsulinActivityStack.shape(for: .degludec, units: 20)
        XCTAssertEqual(shape.first?.activity, 0)
        XCTAssertTrue(shape.allSatisfy { $0.activity >= 0 })
        // One dose is what the regimen does less what it still does a day later.
        let full = InsulinCurveCatalogue.referenceCurve(.degludec)
        XCTAssertEqual(InsulinCurveCatalogue.interpolate(shape, minute: 720),
                       InsulinCurveCatalogue.interpolate(full, minute: 720) - InsulinCurveCatalogue.interpolate(full, minute: 2160), accuracy: 1e-9)
    }

    func testBandStacksBasalBelowBolus() throws {
        let treatments = [ExperimentalTreatment(date: start, amount: 20, kind: .basalInjection, notes: nil),
                          ExperimentalTreatment(date: start.addingTimeInterval(3600), amount: 5, kind: .bolus, notes: nil),
                          ExperimentalTreatment(date: start, amount: 50, kind: .carbs, notes: nil)]
        let dates = InsulinActivityStack.sampleDates(from: start, to: start.addingTimeInterval(6 * 3600), treatments: treatments)
        let band = InsulinActivityStack.band(treatments: treatments, dates: dates, bolusDefault: .aspart, basalDefault: .glargineU100)
        XCTAssertEqual(band.layers.map(\.insulin), [.glargineU100, .aspart])
        let basal = band.layers[0], bolus = band.layers[1]
        XCTAssertEqual(bolus.bottoms, basal.tops)
        XCTAssertTrue(zip(bolus.tops, basal.tops).allSatisfy { $0 >= $1 })
        XCTAssertTrue(dates.contains(start.addingTimeInterval(3600)))
    }

    // MARK: Chart helpers

    func testGlucoseLineBreaksAtGapsAndChangesColourWithTheRange() {
        let dates = [0, 5, 10, 15, 40].map { start.addingTimeInterval(TimeInterval($0 * 60)) }
        let runs = GlucoseChartExperimentalPlots.lineRuns(values: [100, 110, 200, 210, 220], dates: dates) { $0 >= 180 ? .red : .green }
        XCTAssertEqual(runs.map { $0.points.map(\.mgDl) }, [[100, 110, 200], [200, 210], [220]])
        XCTAssertEqual(runs.map(\.color), [.green, .red, .red])
    }

    func testPredictionIsCutAtTheChartEdge() {
        var plots = GlucoseChartExperimentalPlots()
        plots.prediction = [0, 5, 10].map { GlucoseChartExperimentalPlots.PredictionPoint(date: start.addingTimeInterval(TimeInterval($0 * 60)), mgDl: 100 + Double($0)) }
        let points = plots.predictionPoints(until: start.addingTimeInterval(7.5 * 60))
        XCTAssertEqual(points.map(\.mgDl), [100, 105, 107.5])
    }

    // MARK: Settings

    func testSettingsDefaultsAndClamping() {
        let suite = "ExperimentalFeaturesTests"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        defer { defaults.removePersistentDomain(forName: suite) }
        XCTAssertFalse(defaults.experimentalPredictionEnabled)
        XCTAssertTrue(defaults.experimentalPredictionTrendMomentum)
        XCTAssertEqual(defaults.experimentalPredictionHorizonMinutes, 120)
        XCTAssertEqual(defaults.experimentalPredictionInsulinSensitivityMgDl, 54)
        XCTAssertEqual(defaults.experimentalGlucoseChartStyle, .points)
        defaults.set(75, forKey: "experimentalPredictionHorizonMinutes")
        XCTAssertEqual(defaults.experimentalPredictionHorizonMinutes, 120)
        defaults.experimentalPredictionCarbRatio = 50
        XCTAssertEqual(defaults.experimentalPredictionCarbRatio, 30)
        defaults.set(55.0, forKey: "localInsulinPeak")
        XCTAssertEqual(defaults.experimentalBolusInsulin, .fiasp)
        defaults.experimentalBolusInsulin = .lispro
        XCTAssertEqual(defaults.experimentalBolusInsulin, .lispro)
    }

    @MainActor
    func testExperimentalSectionSitsBeforeAboutWithItsThreeRows() throws {
        let sections = SettingsListFactory.makeRootSections(coreDataManager: nil, selectedFollowerActions: .none,
                                                            presenter: SettingsActionPresenter(router: SettingsRouter()))
        let experimentalID = SettingsRootSection.experimental.rawValue * 10
        let index = try XCTUnwrap(sections.firstIndex { $0.id == experimentalID })
        let aboutIndex = try XCTUnwrap(sections.firstIndex { $0.id == SettingsRootSection.about.rawValue * 10 })
        XCTAssertLessThan(index, aboutIndex)
        XCTAssertEqual(sections[index].section().rows.map(\.id), ["experimental.chartStyle", "experimental.prediction", "experimental.insulins"])
    }
}
