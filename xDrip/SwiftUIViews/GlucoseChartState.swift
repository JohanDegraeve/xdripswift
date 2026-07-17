//
//  GlucoseChartState.swift
//  xdrip
//
//  Created by Paul Plant on 8/7/26.
//  Copyright © 2026 Johan Degraeve. All rights reserved.
//

import Foundation
import SwiftUI

/// Optional glucose-like series rendered alongside the primary glucose points.
///
/// This is used for original/raw readings today, but is intentionally generic enough for future
/// overlay series that need their own line/point styling.
struct GlucoseChartDataSet {

    let bgReadingValues: [Double]
    let bgReadingDates: [Date]
    let seriesIdentifier: String
    let lineColor: Color?
    let pointColor: Color?
    let lineWidth: Double
    let dash: [CGFloat]
    let showLine: Bool
    let showPoints: Bool
    let pointSizeMultiplier: Double
    let pointBorderColor: Color?
    let pointBorderSizeMultiplier: Double?

}

/// Background interval rendered behind chart data to annotate a time-based chart state.
struct GlucoseChartBackgroundBand: Identifiable, Hashable {

    enum Style: Hashable {
        case sensorNoiseWarning
        case sensorNoiseUrgent

        var color: Color {
            switch self {
            case .sensorNoiseWarning:
                return ConstantsGlucoseChartSwiftUI.sensorNoiseWarningBandColor
            case .sensorNoiseUrgent:
                return ConstantsGlucoseChartSwiftUI.sensorNoiseUrgentBandColor
            }
        }
    }

    let id: String
    let startDate: Date
    let endDate: Date
    let style: Style

    init(startDate: Date, endDate: Date, style: Style) {
        self.startDate = startDate
        self.endDate = endDate
        self.style = style
        self.id = "\(startDate.timeIntervalSince1970)-\(endDate.timeIntervalSince1970)-\(String(describing: style))"
    }
}

/// Complete renderable state for `GlucoseChartView`.
///
/// `startDate`/`endDate` define the currently visible chart window. `dataStartDate`/`dataEndDate`
/// define the wider cached data range already loaded by `GlucoseChartStateManager`.
///
/// This is intentionally a plain value type. The state manager owns loading, cache mutation and
/// Core Data access; the chart view owns rendering and remains independent of database work.
///
/// `overlayWindowStartDate`/`overlayWindowEndDate` optionally define a highlighted time window
/// inside an overview chart. They are ignored unless both dates are supplied.
struct GlucoseChartState {

    var startDate: Date
    var endDate: Date
    var dataStartDate: Date
    var dataEndDate: Date
    var bgReadingValues: [Double]
    var bgReadingDates: [Date]
    var additionalBgReadingDataSets: [GlucoseChartDataSet]
    var calibrationPoints: [GlucoseChartPoint]
    var treatmentPoints: GlucoseChartTreatmentPoints
    var minimumChartValueInMgDl: Double
    /// Optional background periods, rendered behind glucose and guide marks.
    var backgroundBands: [GlucoseChartBackgroundBand]? = nil
    var overlayWindowStartDate: Date? = nil
    var overlayWindowEndDate: Date? = nil

    static func empty(startDate: Date, endDate: Date) -> GlucoseChartState {
        GlucoseChartState(
            startDate: startDate,
            endDate: endDate,
            dataStartDate: startDate,
            dataEndDate: endDate,
            bgReadingValues: [],
            bgReadingDates: [],
            additionalBgReadingDataSets: [],
            calibrationPoints: [],
            treatmentPoints: GlucoseChartTreatmentPoints(),
            minimumChartValueInMgDl: 38,
            backgroundBands: nil,
            overlayWindowStartDate: nil,
            overlayWindowEndDate: nil
        )
    }

}

/// Bucketed treatment and basal points in the form expected by `GlucoseChartView`.
///
/// Separate buckets let the renderer apply the correct marker size, label policy and layer ordering
/// without recalculating treatment meaning during every body pass.
struct GlucoseChartTreatmentPoints {

    var smallBolus: [GlucoseChartTreatmentPoint] = []
    var mediumBolus: [GlucoseChartTreatmentPoint] = []
    var largeBolus: [GlucoseChartTreatmentPoint] = []
    var veryLargeBolus: [GlucoseChartTreatmentPoint] = []

    var smallCarbs: [GlucoseChartTreatmentPoint] = []
    var mediumCarbs: [GlucoseChartTreatmentPoint] = []
    var largeCarbs: [GlucoseChartTreatmentPoint] = []
    var veryLargeCarbs: [GlucoseChartTreatmentPoint] = []

    var bgChecks: [GlucoseChartTreatmentPoint] = []
    var notes: [GlucoseChartTreatmentPoint] = []

    var scheduledBasalRates: [GlucoseChartPoint] = []
    var basalRates: [GlucoseChartPoint] = []
    var basalRateFill: [GlucoseChartPoint] = []

}

/// Simple dated chart point used for calibrations and basal series.
///
/// The identifier includes the date and value because basal step lines deliberately contain paired
/// points at the same timestamp when a rate changes.
struct GlucoseChartPoint: Identifiable, Hashable {

    let id: String
    let date: Date
    let value: Double

    init(date: Date, value: Double, idPrefix: String) {
        self.date = date
        self.value = value
        self.id = "\(idPrefix)-\(date.timeIntervalSince1970)-\(value)"
    }

}

/// Dated treatment marker with its display y-value and optional treatment label/notes.
///
/// `yValue` is already resolved by the state manager. For bolus, carbs and notes this means near the
/// glucose line; the view only draws the supplied position.
struct GlucoseChartTreatmentPoint: Identifiable, Hashable {

    let id: String
    let date: Date
    let yValue: Double
    let treatmentValue: Double
    let label: String?
    let notes: String?

    init(date: Date, yValue: Double, treatmentValue: Double, label: String?, notes: String?, idPrefix: String) {
        self.date = date
        self.yValue = yValue
        self.treatmentValue = treatmentValue
        self.label = label
        self.notes = notes
        self.id = "\(idPrefix)-\(date.timeIntervalSince1970)-\(treatmentValue)-\(yValue)"
    }

}

/// Styling constants for treatment marks, kept separate from the cached data model.
enum GlucoseChartTreatmentStyle {

    // MARK: - Calibration

    static let calibrationOuterColor = Color.white
    static let calibrationInnerColor = Color.red
    static let calibrationOuterScale = 1.9
    static let calibrationInnerScale = 1.4

    // MARK: - Bolus

    static let bolusColor = Color.blue
    static let smallBolusScale = 0.6
    static let mediumBolusScale = 0.9
    static let largeBolusScale = 1.2
    static let veryLargeBolusScale = 1.5
    static let bolusTriangleSize3h = 18.0
    static let bolusTriangleSize6h = 15.5
    static let bolusTriangleSize12h = 13.5
    static let bolusTriangleSize24h = 11.0
    static let bolusTriangleHeightScale = 0.9

    // MARK: - Carbs

    static let carbsColor = Color.orange
    static let smallCarbsScale = 1.25
    static let mediumCarbsScale = 2.25
    static let largeCarbsScale = 3.65
    static let veryLargeCarbsScale = 5.5

    // MARK: - BG Checks and Notes

    static let bgCheckOuterColor = Color.gray
    static let bgCheckInnerColor = Color.red
    static let bgCheckOuterScale = 1.9
    static let bgCheckInnerScale = 1.4

    static let noteColor = Color(white: 0.9)
    static let noteScale = 1.9

    // MARK: - Basal

    static let scheduledBasalLineColor = Color.mint.opacity(0.8)
    static let scheduledBasalLineWidth = 0.8
    static let basalLineColor = Color.mint.opacity(0.7)
    static let basalLineWidth = 0.9
    static let basalFillColor = Color.mint.opacity(0.28)

    // MARK: - Labels

    static let treatmentLabelFontSize = 11.0
    static let treatmentLabelBackgroundColor = Color.black.opacity(0.4)
    static let treatmentLabelFontColor = Color.white.opacity(0.85)

}
