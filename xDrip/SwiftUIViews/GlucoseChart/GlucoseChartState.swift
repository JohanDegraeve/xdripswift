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

/// Date-based AGP percentile point rendered as a background layer behind glucose readings.
///
/// AGP itself is time-of-day based, but the chart renderer works with real dates. Callers should map
/// the AGP values onto the visible chart dates before passing them here.
struct GlucoseChartAGPPoint: Identifiable, Hashable {

    let id: String
    let date: Date
    let p5MgDl: Double
    let p25MgDl: Double
    let medianMgDl: Double
    let p75MgDl: Double
    let p95MgDl: Double

    init(date: Date, p5MgDl: Double, p25MgDl: Double, medianMgDl: Double, p75MgDl: Double, p95MgDl: Double) {
        self.date = date
        self.p5MgDl = p5MgDl
        self.p25MgDl = p25MgDl
        self.medianMgDl = medianMgDl
        self.p75MgDl = p75MgDl
        self.p95MgDl = p95MgDl
        self.id = "\(date.timeIntervalSince1970)-\(p5MgDl)-\(p25MgDl)-\(medianMgDl)-\(p75MgDl)-\(p95MgDl)"
    }

}

/// Complete renderable state for `GlucoseChartView`.
///
/// `startDate`/`endDate` define the currently visible chart window. `dataStartDate`/`dataEndDate`
/// define the wider cached data range already loaded by `GlucoseChartStateManager`.
///
/// This is intentionally a plain value type. The state manager owns loading, cache mutation and
/// Core Data access. The chart view owns rendering and remains independent of database work.
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
/// Each dose type has one series. Marker size is interpolated from its value by the renderer,
/// while cached labels retain the existing visibility policy.
struct GlucoseChartTreatmentPoints {

    var boluses: [GlucoseChartTreatmentPoint] = []
    // Keep injections outside bolus sizing and pump basal series.
    var basalInjections: [GlucoseChartTreatmentPoint] = []

    var carbs: [GlucoseChartTreatmentPoint] = []

    var bgChecks: [GlucoseChartTreatmentPoint] = []
    var notes: [GlucoseChartTreatmentPoint] = []

    var scheduledBasalRates: [GlucoseChartPoint] = []
    var basalRates: [GlucoseChartPoint] = []
    var basalRateFill: [GlucoseChartPoint] = []
    var automaticBasalPulses: [GlucoseChartBasalPulse] = []

}

/// One native automatic-basal delivery rendered for an exact time width in the basal band.
struct GlucoseChartBasalPulse: Identifiable, Hashable {
    let id: String
    let startDate: Date
    let endDate: Date
    let value: Double

    init(startDate: Date, endDate: Date, value: Double) {
        self.startDate = startDate
        self.endDate = endDate
        self.value = value
        self.id = "automatic-basal-pulse-\(startDate.timeIntervalSince1970)-\(endDate.timeIntervalSince1970)-\(value)"
    }
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
/// glucose line. The view only draws the supplied position.
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

    // Share SF Symbol names between chart points, rows and treatment entry. Filters remove
    // the fill suffix when excluded, rather than using a different treatment symbol.
    static let bolusSymbol = "arrowtriangle.down.fill"
    static let carbsSymbol = "arrowtriangle.up.fill"
    // Use the single triangle on every iOS version. Pink and fixed chart sizing distinguish basal injections.
    static let basalInjectionSymbol = "arrowtriangle.down.fill"
    static let treatmentIconSize = 17.0
    /// Small chart-only halo to separate treatment symbols from similarly coloured data.
    static let symbolHaloRadius = 1.0
    static let bolusColor = Color.blue
    // Use a light pink to keep basal injections distinct from the red BG check.
    static let basalInjectionColor = Color(red: 1, green: 0.72, blue: 0.88)
    /// Fixed basal injection marker scale, independent of the injected dose.
    static let basalInjectionScale = 1.6
    /// Small-bolus row and filter scale. Chart dose sizing is independent of this preference.
    static let smallBolusScale = 0.6

    /// Dose bounds and physical SF Symbol sizes in points. Values outside the bounds clamp
    /// to the endpoint size. The actual dose and its label are never clamped.
    static let bolusSymbolSizing = GlucoseChartTreatmentSizeRange(minimumValue: 0.5, maximumValue: 10, minimumSize: 9, maximumSize: 30)
    static let carbsSymbolSizing = GlucoseChartTreatmentSizeRange(minimumValue: 5, maximumValue: 70, minimumSize: 9, maximumSize: 30)
    static let treatmentSymbolSize3h = 18.0
    static let treatmentSymbolSize6h = 15.5
    static let treatmentSymbolSize12h = 13.5
    static let treatmentSymbolSize24h = 11.0

    // MARK: - Carbs

    static let carbsColor = Color.orange

    // MARK: - BG Checks and Notes

    static let bgCheckSymbol = "drop.fill"
    static let bgCheckInnerColor = Color.red

    static let noteColor = Color(white: 0.9)
    static let noteSymbol = "note.text"
    /// Keep note labels short enough to read vertically above their markers.
    static let noteLabelCharacterLimit = 16
    static let noteLabelFontSize = 13.0
    /// Extra space above the glucose point before the vertical note text begins.
    static let noteLabelExtraSpacing = 3.0

    /// Collapse line breaks for the chart and truncate by Character so emoji remain intact.
    static func noteLabel(_ notes: String?) -> String? {
        guard let notes else { return nil }
        let text = notes.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
        guard !text.isEmpty, noteLabelCharacterLimit > 0 else { return nil }
        guard text.count > noteLabelCharacterLimit else { return text }
        return String(text.prefix(noteLabelCharacterLimit - 1)) + "…"
    }

    // MARK: - Basal

    static let scheduledBasalLineColor = Color.mint.opacity(0.8)
    static let scheduledBasalLineWidth = 0.8
    static let basalLineColor = Color.mint.opacity(0.7)
    static let basalLineWidth = 0.9
    static let basalFillColor = Color.mint.opacity(0.28)
    /// Native automatic-basal doses use the basal hue with stronger emphasis than rate-area fill.
    static let automaticBasalPulseColor = Color.mint.opacity(0.5)

    // MARK: - Labels

    static let treatmentLabelFontSize = 11.0
    static let treatmentLabelBackgroundColor = Color.black.opacity(0.4)
    static let treatmentLabelFontColor = Color.white.opacity(0.85)

}

/// Linear interpolation of symbol side length in points, rather than area or dose buckets.
/// This is a small, allocation-free calculation shared by bolus and carbohydrate chart markers.
struct GlucoseChartTreatmentSizeRange {
    let minimumValue: Double
    let maximumValue: Double
    let minimumSize: Double
    let maximumSize: Double

    func size(for value: Double) -> Double {
        guard !value.isNaN, value > minimumValue else { return minimumSize }
        guard value < maximumValue else { return maximumSize }
        let fraction = (value - minimumValue) / (maximumValue - minimumValue)
        return minimumSize + fraction * (maximumSize - minimumSize)
    }
}
