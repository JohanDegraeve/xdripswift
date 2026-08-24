//
//  AGPChartView.swift
//  xdrip
//
//  Created by Paul Plant on 24/7/26.
//  Copyright © 2026 Johan Degraeve. All rights reserved.
//

import Charts
import SwiftUI

/// Selects the screen or print treatment without duplicating the AGP calculation and marks.
enum AGPChartPresentation {
    case statistics
    case landscapeComparison
    case printableReport
}

/// One glucose reading overlaid on the AGP baseline in comparison mode.
struct AGPChartGlucosePoint: Identifiable {
    let id: String
    let minuteOfDay: Int
    let valueMgDl: Double
    let isLatest: Bool
}

/// Shared AGP renderer for the Statistics tab, landscape comparison and printable report.
struct AGPChartView: View {
    let points: [GlucoseReportAGPPoint]
    let usesMgDl: Bool
    let presentation: AGPChartPresentation
    let glucosePoints: [AGPChartGlucosePoint]
    let showsNowRule: Bool
    let emptyMessage: String
    let fixedPlotWidth: CGFloat?

    init(
        points: [GlucoseReportAGPPoint],
        usesMgDl: Bool,
        presentation: AGPChartPresentation,
        glucosePoints: [AGPChartGlucosePoint] = [],
        showsNowRule: Bool = false,
        emptyMessage: String,
        fixedPlotWidth: CGFloat? = nil
    ) {
        self.points = points
        self.usesMgDl = usesMgDl
        self.presentation = presentation
        self.glucosePoints = glucosePoints
        self.showsNowRule = showsNowRule
        self.emptyMessage = emptyMessage
        self.fixedPlotWidth = fixedPlotWidth
    }

    var body: some View {
        Chart {
            nighttimeBackground
            targetRange
            outerBand
            innerBand
            medianLine
            glucosePointMarks
            nowRule
        }
        .chartLegend(.hidden)
        .chartXScale(domain: 0 ... 1440)
        .chartYScale(domain: converted(40) ... converted(dynamicUpperYMgDl))
        .chartXAxis {
            AxisMarks(values: [0, 360, 720, 1080, 1440]) { value in
                if presentation == .statistics {
                    AxisTick()
                        .foregroundStyle(axisLabelColor)
                }
                AxisGridLine()
                    .foregroundStyle(xAxisGridLineColor)
                AxisValueLabel {
                    if let minute = value.as(Int.self) {
                        Text(timeLabel(minute: minute))
                            .font(xAxisLabelFont)
                            .foregroundStyle(axisLabelColor)
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: yAxisPosition, values: yAxisValues) { value in
                AxisGridLine()
                    .foregroundStyle(yAxisGridLineColor(for: value.as(Double.self)))
                AxisValueLabel {
                    if let glucose = value.as(Double.self) {
                        yAxisLabel(for: glucose)
                    }
                }
            }
        }
        .chartPlotStyle { plotArea in
            if showsPlotBorder {
                plotArea
                    .frame(width: fixedPlotWidth)
                    .border(ConstantsAppColors.agpPlotBorder, width: ConstantsGlucoseChartSwiftUI.chartPlotBorderLineWidth)
            } else {
                plotArea
                    .frame(width: fixedPlotWidth)
            }
        }
        .overlay {
            if points.isEmpty && glucosePoints.isEmpty {
                Text(emptyMessage)
                    .font(emptyMessageFont)
                    .foregroundStyle(emptyMessageColor)
            }
        }
    }

    @ChartContentBuilder private var targetRange: some ChartContent {
        RectangleMark(
            xStart: .value("Start", 0),
            xEnd: .value("End", 1440),
            yStart: .value("Low target", converted(GlucoseReportClinicalConstants.timeInRangeLowMgDl)),
            yEnd: .value("High target", converted(GlucoseReportClinicalConstants.timeInRangeHighMgDl))
        )
        .foregroundStyle(targetFillColor)

        RuleMark(y: .value("Low target", converted(GlucoseReportClinicalConstants.timeInRangeLowMgDl)))
            .lineStyle(StrokeStyle(lineWidth: targetRuleLineWidth))
            .foregroundStyle(agpLowGridLineColor)

        RuleMark(y: .value("High target", converted(GlucoseReportClinicalConstants.timeInRangeHighMgDl)))
            .lineStyle(StrokeStyle(lineWidth: targetRuleLineWidth))
            .foregroundStyle(agpHighGridLineColor)
    }

    @ChartContentBuilder private var nighttimeBackground: some ChartContent {
        if presentation == .printableReport {
            RectangleMark(
                xStart: .value("Start", 0),
                xEnd: .value("End", GlucoseReportClinicalConstants.dayStartMinute),
                yStart: .value("Low", converted(40)),
                yEnd: .value("High", converted(dynamicUpperYMgDl))
            )
            .foregroundStyle(GlucoseReportColors.nighttimeBackground)

            RectangleMark(
                xStart: .value("Start", GlucoseReportClinicalConstants.nightStartMinute),
                xEnd: .value("End", 1440),
                yStart: .value("Low", converted(40)),
                yEnd: .value("High", converted(dynamicUpperYMgDl))
            )
            .foregroundStyle(GlucoseReportColors.nighttimeBackground)
        }
    }

    @ChartContentBuilder private var outerBand: some ChartContent {
        ForEach(chartPointsForDisplay) { point in
            AreaMark(
                x: .value("Time", point.minuteOfDay),
                yStart: .value("P5", converted(point.p5MgDl)),
                yEnd: .value("P95", converted(point.p95MgDl)),
                series: .value("Series", "5-95%")
            )
            .foregroundStyle(outerBandColor)
            .interpolationMethod(.linear)
        }
    }

    @ChartContentBuilder private var innerBand: some ChartContent {
        ForEach(chartPointsForDisplay) { point in
            AreaMark(
                x: .value("Time", point.minuteOfDay),
                yStart: .value("P25", converted(point.p25MgDl)),
                yEnd: .value("P75", converted(point.p75MgDl)),
                series: .value("Series", "25-75%")
            )
            .foregroundStyle(innerBandColor)
            .interpolationMethod(.linear)
        }
    }

    @ChartContentBuilder private var medianLine: some ChartContent {
        ForEach(chartPointsForDisplay) { point in
            LineMark(
                x: .value("Time", point.minuteOfDay),
                y: .value("Median", converted(point.medianMgDl)),
                series: .value("Series", "Median")
            )
            .lineStyle(StrokeStyle(lineWidth: medianLineWidth))
            .foregroundStyle(medianColor)
            .interpolationMethod(.linear)
        }
    }

    @ChartContentBuilder private var glucosePointMarks: some ChartContent {
        if presentation == .landscapeComparison {
            ForEach(glucosePoints) { point in
                let isCurrentPoint = point.isLatest && showsNowRule

                PointMark(
                    x: .value("Time", point.minuteOfDay),
                    y: .value("Today", converted(point.valueMgDl))
                )
                .symbolSize(isCurrentPoint ? 72 : 16)
                .foregroundStyle(isCurrentPoint ? ConstantsAppColors.primaryText : glucosePointColor(valueMgDl: point.valueMgDl))
            }
        }
    }

    @ChartContentBuilder private var nowRule: some ChartContent {
        if presentation == .landscapeComparison && showsNowRule {
            RuleMark(x: .value("Now", currentMinuteOfDay))
                .lineStyle(StrokeStyle(lineWidth: 1.0, dash: [4, 4]))
                .foregroundStyle(ConstantsAppColors.primaryText)
        }
    }

    private var chartPointsForDisplay: [GlucoseReportAGPPoint] {
        let smoothedPoints = GlucoseReportAGPDisplayPoints.smoothedDisplayPoints(from: points)
        let presentationPoints = presentation == .landscapeComparison ? landscapeSmoothedDisplayPoints(from: smoothedPoints) : smoothedPoints

        // Reject malformed percentile buckets before Swift Charts joins them into crossing bands.
        return presentationPoints.filter { point in
            point.p5MgDl <= point.p25MgDl &&
                point.p25MgDl <= point.medianMgDl &&
                point.medianMgDl <= point.p75MgDl &&
                point.p75MgDl <= point.p95MgDl
        }
    }

    private func landscapeSmoothedDisplayPoints(from points: [GlucoseReportAGPPoint]) -> [GlucoseReportAGPPoint] {
        let sortedPoints = points.sorted { $0.minuteOfDay < $1.minuteOfDay }
        guard sortedPoints.count >= 5 else { return sortedPoints }

        // The full-screen chart exposes small bucket changes more strongly, so use a short moving
        // average while preserving the percentile order at every point.
        return sortedPoints.indices.map { index in
            let lowerIndex = max(sortedPoints.startIndex, index - 2)
            let upperIndex = min(sortedPoints.index(before: sortedPoints.endIndex), index + 2)
            let window = Array(sortedPoints[lowerIndex ... upperIndex])
            let ordered = [
                average(\.p5MgDl, in: window),
                average(\.p25MgDl, in: window),
                average(\.medianMgDl, in: window),
                average(\.p75MgDl, in: window),
                average(\.p95MgDl, in: window)
            ].sorted()

            return GlucoseReportAGPPoint(
                minuteOfDay: sortedPoints[index].minuteOfDay,
                p5MgDl: ordered[0],
                p25MgDl: ordered[1],
                medianMgDl: ordered[2],
                p75MgDl: ordered[3],
                p95MgDl: ordered[4]
            )
        }
    }

    private func average(_ keyPath: KeyPath<GlucoseReportAGPPoint, Double>, in points: [GlucoseReportAGPPoint]) -> Double {
        points.map { $0[keyPath: keyPath] }.reduce(0, +) / Double(points.count)
    }

    private var dynamicUpperYMgDl: Double {
        let agpMaximum = chartPointsForDisplay.map(\.p95MgDl).max() ?? 250
        let glucoseMaximum = glucosePoints.map(\.valueMgDl).max() ?? 250
        let plottedMaximum = max(agpMaximum, glucoseMaximum)

        if plottedMaximum <= 250 {
            return 250
        }

        let paddedMaximum = plottedMaximum + 20
        if paddedMaximum <= 400 {
            return ceil(paddedMaximum / 50) * 50
        }

        return min(450, ceil(paddedMaximum / 50) * 50)
    }

    private var yAxisValues: [Double] {
        switch presentation {
        case .statistics:
            return ([40, 250, 300, 350, 400, 450] + [GlucoseReportClinicalConstants.timeInRangeLowMgDl, GlucoseReportClinicalConstants.timeInRangeHighMgDl])
                .filter { $0 <= dynamicUpperYMgDl }
                .sorted()
                .map(converted)
        case .landscapeComparison, .printableReport:
            return [40, GlucoseReportClinicalConstants.timeInRangeLowMgDl, GlucoseReportClinicalConstants.timeInRangeHighMgDl, 250, 300, 350, 400, 450]
                .filter { $0 <= dynamicUpperYMgDl }
                .map(converted)
        }
    }

    private var objectiveAxisValues: [Double] {
        [converted(GlucoseReportClinicalConstants.timeInRangeLowMgDl), converted(GlucoseReportClinicalConstants.timeInRangeHighMgDl)]
    }

    private var yAxisPosition: AxisMarkPosition {
        presentation == .printableReport ? .leading : .trailing
    }

    private var xAxisLabelFont: Font {
        switch presentation {
        case .statistics:
            return .system(size: ConstantsStatistics.chartAxisLabelFontSize + 1)
        case .landscapeComparison:
            return .system(size: ConstantsStatistics.chartAxisLabelFontSize + 1)
        case .printableReport:
            return .system(size: 7)
        }
    }

    private var axisLabelColor: Color {
        switch presentation {
        case .statistics:
            return Color(.colorSecondary)
        case .landscapeComparison:
            return Color(.colorSecondary)
        case .printableReport:
            return GlucoseReportColors.secondaryText
        }
    }

    private func yAxisLabel(for convertedValue: Double) -> some View {
        let isObjective = objectiveAxisValues.contains(convertedValue)
        let font: Font
        let color: Color

        switch presentation {
        case .statistics:
            font = .system(size: ConstantsStatistics.chartAxisLabelFontSize + 1, weight: isObjective ? .bold : .regular)
            color = isObjective ? ConstantsGlucoseChartSwiftUI.yAxisMainChartObjectiveLabelColor : Color(.colorSecondary)
        case .landscapeComparison:
            font = .system(size: 14, weight: isObjective ? .bold : .semibold)
            color = isObjective ? ConstantsGlucoseChartSwiftUI.yAxisMainChartObjectiveLabelColor : ConstantsAppColors.tertiaryText
        case .printableReport:
            font = .system(size: 7)
            color = GlucoseReportColors.secondaryText
        }

        return Text(axisLabelText(for: convertedValue))
            .font(font)
            .foregroundStyle(color)
            .monospacedDigit()
            .frame(width: statisticsYAxisLabelWidth, alignment: .leading)
    }

    private var statisticsYAxisLabelWidth: CGFloat? {
        presentation == .statistics ? ConstantsStatistics.chartYAxisLabelWidth : nil
    }

    private func yAxisGridLineColor(for convertedValue: Double?) -> Color {
        guard let convertedValue else {
            return presentation == .printableReport ? GlucoseReportColors.rule : ConstantsAppColors.agpYAxisGridLine
        }

        if isAxisValue(convertedValue, equalTo: converted(GlucoseReportClinicalConstants.timeInRangeLowMgDl)) {
            return agpLowGridLineColor
        }

        if isAxisValue(convertedValue, equalTo: converted(GlucoseReportClinicalConstants.timeInRangeHighMgDl)) {
            return agpHighGridLineColor
        }

        return presentation == .printableReport ? GlucoseReportColors.rule : ConstantsAppColors.agpYAxisGridLine
    }

    private func isAxisValue(_ value: Double, equalTo comparison: Double) -> Bool {
        abs(value - comparison) < 0.01
    }

    private var xAxisGridLineColor: Color {
        presentation == .printableReport ? GlucoseReportColors.rule : ConstantsAppColors.agpXAxisGridLine
    }

    private var targetFillColor: Color {
        presentation == .printableReport ? GlucoseReportColors.target.opacity(0.12) : ConstantsAppColors.agpTargetFill
    }

    private var agpLowGridLineColor: Color {
        switch presentation {
        case .printableReport:
            return GlucoseReportColors.low.opacity(0.75)
        case .statistics, .landscapeComparison:
            return ConstantsAppColors.statisticsLow.opacity(0.5)
        }
    }

    private var agpHighGridLineColor: Color {
        switch presentation {
        case .printableReport:
            return GlucoseReportColors.high.opacity(0.75)
        case .statistics, .landscapeComparison:
            return ConstantsAppColors.statisticsHigh.opacity(0.5)
        }
    }

    private var targetRuleLineWidth: CGFloat {
        presentation == .printableReport ? 0.8 : 1.2
    }

    private var outerBandColor: Color {
        presentation == .printableReport ? GlucoseReportColors.agpOuterBand : ConstantsAppColors.agpOuterBand
    }

    private var innerBandColor: Color {
        presentation == .printableReport ? GlucoseReportColors.agpInnerBand : ConstantsAppColors.agpInnerBand
    }

    private var medianColor: Color {
        presentation == .printableReport ? GlucoseReportColors.clinicalBlue : ConstantsAppColors.agpMedian
    }

    private var medianLineWidth: CGFloat {
        switch presentation {
        case .statistics, .landscapeComparison:
            return 2.2
        case .printableReport:
            return 2.0
        }
    }

    private var showsPlotBorder: Bool {
        presentation != .printableReport
    }

    private var emptyMessageFont: Font {
        switch presentation {
        case .statistics:
            return .subheadline.weight(.semibold)
        case .landscapeComparison:
            return .system(size: 16, weight: .semibold)
        case .printableReport:
            return .system(size: 11, weight: .semibold)
        }
    }

    private var emptyMessageColor: Color {
        switch presentation {
        case .statistics:
            return Color(.colorSecondary)
        case .landscapeComparison:
            return ConstantsAppColors.secondaryText
        case .printableReport:
            return GlucoseReportColors.secondaryText
        }
    }

    private var currentMinuteOfDay: Int {
        let components = Calendar.current.dateComponents([.hour, .minute], from: Date())

        return (components.hour ?? 0) * 60 + (components.minute ?? 0)
    }

    private func glucosePointColor(valueMgDl: Double) -> Color {
        if valueMgDl >= UserDefaults.standard.urgentHighMarkValue || valueMgDl <= UserDefaults.standard.urgentLowMarkValue {
            return ConstantsGlucoseChart.glucoseUrgentRangeColor
        }

        if valueMgDl >= UserDefaults.standard.highMarkValue || valueMgDl <= UserDefaults.standard.lowMarkValue {
            return ConstantsGlucoseChart.glucoseNotUrgentRangeColor
        }

        return ConstantsGlucoseChart.glucoseInRangeColor
    }

    private func converted(_ valueMgDl: Double) -> Double {
        valueMgDl.mgDlToMmol(mgDl: usesMgDl)
    }

    private func axisLabelText(for convertedValue: Double) -> String {
        convertedValue.bgValueToString(mgDl: usesMgDl)
    }

    private func timeLabel(minute: Int) -> String {
        switch minute {
        case 0:
            return "00:00"
        case 1440:
            return presentation == .printableReport ? "00:00" : "24:00"
        case 360:
            return "06:00"
        case 720:
            return "12:00"
        case 1080:
            return "18:00"
        default:
            return ""
        }
    }
}
