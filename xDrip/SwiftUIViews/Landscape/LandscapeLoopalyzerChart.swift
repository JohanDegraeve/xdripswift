//
//  LandscapeLoopalyzerChart.swift
//  xdrip
//
//  Created by Paul Plant on 4/8/26.
//  Copyright © 2026 Johan Degraeve. All rights reserved.
//

import Charts
import SwiftUI

/// Shows the selected day's temporary basal, IOB and COB patterns in the landscape insight view.
struct LandscapeLoopalyzerChart: View {
    let points: [GlucoseReportLoopalyzerPoint]
    let insulinTreatmentMarkers: [GlucoseReportLoopalyzerTreatmentMarker]
    let carbTreatmentMarkers: [GlucoseReportLoopalyzerTreatmentMarker]
    let plotHeight: CGFloat
    let chartSpacing: CGFloat

    private enum Series: CaseIterable {
        case tempBasalDelta
        case iob
        case cob
    }

    private enum Layout {
        static let xAxisHeight: CGFloat = 18
        static let yAxisLabelWidth: CGFloat = 24
        static let axisLabelFontSize = ConstantsStatistics.chartAxisLabelFontSize + 1
        static let treatmentBarWidthMinutes = 5.0
    }

    var body: some View {
        VStack(spacing: chartSpacing) {
            ForEach(Array(Series.allCases.enumerated()), id: \.offset) { index, series in
                chart(for: series, showsXAxisLabels: index == Series.allCases.indices.last)
            }
        }
    }

    @ViewBuilder private func chart(for series: Series, showsXAxisLabels: Bool) -> some View {
        switch series {
        case .tempBasalDelta:
            loopChart(
                title: Texts_Common.statisticsTempBasalDelta,
                yDomain: basalDeltaDomain,
                series: series,
                showsXAxisLabels: showsXAxisLabels
            )
        case .iob:
            loopChart(
                title: "IOB",
                yDomain: -1 ... iobUpperBound,
                series: series,
                showsXAxisLabels: showsXAxisLabels
            )
        case .cob:
            loopChart(
                title: "COB",
                yDomain: 0 ... cobUpperBound,
                series: series,
                showsXAxisLabels: showsXAxisLabels
            )
        }
    }

    private func loopChart(
        title: String,
        yDomain: ClosedRange<Double>,
        series: Series,
        showsXAxisLabels: Bool
    ) -> some View {
        let includesZero = series != .cob

        return VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: ConstantsStatistics.chartAxisLabelFontSize + 3, weight: .semibold))
                .foregroundStyle(Color(.colorPrimary))
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(alignment: .top, spacing: 4) {
                Chart {
                    dataMarks(for: series)
                    referenceMarks(yDomain: yDomain, includesZero: includesZero)
                    treatmentMarks(for: series, yDomain: yDomain)
                }
                .chartLegend(.hidden)
                .chartXScale(
                    domain: 0.0 ... 1440.0,
                    range: .plotDimension(startPadding: 0, endPadding: 0)
                )
                .chartYScale(domain: yDomain)
                .chartYAxis {
                    AxisMarks(position: .trailing, values: yAxisValues(for: yDomain, includesZero: includesZero)) { _ in
                        AxisGridLine()
                            .foregroundStyle(Color(.colorSecondary).opacity(0.55))
                    }
                }
                .chartXAxis {
                    AxisMarks(values: [0.0, 360.0, 720.0, 1080.0, 1440.0]) { value in
                        if showsXAxisLabels {
                            AxisTick(length: 5, stroke: StrokeStyle(lineWidth: 0.5))
                                .foregroundStyle(Color(.colorSecondary).opacity(0.45))
                            AxisValueLabel {
                                if let minute = value.as(Double.self) {
                                    Text(timeLabel(for: Int(minute)))
                                        .font(.system(size: Layout.axisLabelFontSize))
                                        .foregroundStyle(Color(.colorSecondary))
                                }
                            }
                        }
                    }
                }
                .chartPlotStyle { plotArea in
                    plotArea.frame(height: plotHeight)
                }
                .frame(height: showsXAxisLabels ? plotHeight + Layout.xAxisHeight : plotHeight, alignment: .top)

                yAxisLabels(for: yDomain, includesZero: includesZero)
            }
        }
    }

    @ChartContentBuilder private func dataMarks(for series: Series) -> some ChartContent {
        ForEach(points) { point in
            switch series {
            case .tempBasalDelta:
                if let value = point.basalDeltaRate {
                    RectangleMark(
                        xStart: .value("Start", point.bucketBarStartMinute),
                        xEnd: .value("End", point.bucketBarEndMinute),
                        yStart: .value("Zero", 0),
                        yEnd: .value("Delta", value)
                    )
                    .foregroundStyle(
                        GlucoseReportColors.aidDeliveredBasal.opacity(
                            GlucoseReportColors.aidDeliveredBasalOpacity
                        )
                    )
                }
            case .iob:
                if let value = point.iob {
                    RectangleMark(
                        xStart: .value("Start", point.bucketBarStartMinute),
                        xEnd: .value("End", point.bucketBarEndMinute),
                        yStart: .value("Zero", 0),
                        yEnd: .value("IOB", value)
                    )
                    .foregroundStyle(
                        value < 0
                            ? ConstantsAppColors.statisticsLow
                            : GlucoseReportColors.aidIOB.opacity(GlucoseReportColors.aidIOBOpacity)
                    )
                }
            case .cob:
                if let value = point.cob {
                    RectangleMark(
                        xStart: .value("Start", point.bucketBarStartMinute),
                        xEnd: .value("End", point.bucketBarEndMinute),
                        yStart: .value("Zero", 0),
                        yEnd: .value("COB", value)
                    )
                    .foregroundStyle(
                        GlucoseReportColors.aidCOB.opacity(GlucoseReportColors.aidCOBOpacity)
                    )
                }
            }
        }
    }

    /// Draws the time and value guides above the full-width bar marks.
    @ChartContentBuilder private func referenceMarks(
        yDomain: ClosedRange<Double>,
        includesZero: Bool
    ) -> some ChartContent {
        ForEach([360.0, 720.0, 1080.0], id: \.self) { minute in
            RuleMark(x: .value("Grid Time", minute))
                .lineStyle(StrokeStyle(lineWidth: 0.5))
                .foregroundStyle(Color(.colorSecondary).opacity(0.45))
        }

        if includesZero {
            RuleMark(y: .value("Zero", 0))
                .lineStyle(StrokeStyle(lineWidth: 0.75))
                .foregroundStyle(Color(.colorSecondary).opacity(0.65))
        } else {
            RuleMark(y: .value("Grid Value", (yDomain.lowerBound + yDomain.upperBound) / 2))
                .lineStyle(StrokeStyle(lineWidth: 0.5))
                .foregroundStyle(Color(.colorSecondary).opacity(0.45))
        }
    }

    @ChartContentBuilder private func treatmentMarks(
        for series: Series,
        yDomain: ClosedRange<Double>
    ) -> some ChartContent {
        if series == .iob {
            ForEach(insulinTreatmentMarkers) { marker in
                treatmentMarker(marker, yDomain: yDomain)
            }
        }

        if series == .cob {
            ForEach(carbTreatmentMarkers) { marker in
                treatmentMarker(marker, yDomain: yDomain)
            }
        }
    }

    private func yAxisLabels(for yDomain: ClosedRange<Double>, includesZero: Bool) -> some View {
        VStack(alignment: .leading) {
            axisLabel(yDomain.upperBound)
            Spacer()
            axisLabel(yDomain.lowerBound)
        }
        // Match the explicit plot height rather than the chart's additional x-axis space so the
        // lower value stays on the true baseline.
        .frame(width: Layout.yAxisLabelWidth, height: plotHeight, alignment: .leading)
        .overlay(alignment: .topLeading) {
            if includesZero, yDomain.lowerBound < 0, yDomain.upperBound > 0 {
                axisLabel(0)
                    .offset(y: zeroAxisOffset(for: yDomain))
            }
        }
    }

    private func yAxisValues(for yDomain: ClosedRange<Double>, includesZero: Bool) -> [Double] {
        let values = includesZero
            ? [yDomain.lowerBound, 0, yDomain.upperBound]
            : [yDomain.lowerBound, yDomain.upperBound]
        return Array(Set(values)).sorted()
    }

    private func zeroAxisOffset(for yDomain: ClosedRange<Double>) -> CGFloat {
        let domainHeight = yDomain.upperBound - yDomain.lowerBound
        guard domainHeight > 0 else { return 0 }

        let zeroPosition = CGFloat(yDomain.upperBound / domainHeight) * plotHeight
        return max(0, min(plotHeight - Layout.axisLabelFontSize, zeroPosition - Layout.axisLabelFontSize / 2))
    }

    private func axisLabel(_ value: Double) -> some View {
        Text(value.round(toDecimalPlaces: 1).stringWithoutTrailingZeroes)
            .font(.system(size: Layout.axisLabelFontSize))
            .foregroundStyle(Color(.colorSecondary))
            .lineLimit(1)
    }

    /// Draws Nightscout treatment amounts as narrow bars on the matching IOB or COB chart.
    private func treatmentMarker(
        _ marker: GlucoseReportLoopalyzerTreatmentMarker,
        yDomain: ClosedRange<Double>
    ) -> some ChartContent {
        let halfWidth = Layout.treatmentBarWidthMinutes / 2
        return RectangleMark(
            xStart: .value("Start", max(Double(marker.minuteOfDay) - halfWidth, 0)),
            xEnd: .value("End", min(Double(marker.minuteOfDay) + halfWidth, 1440)),
            yStart: .value("Zero", 0),
            yEnd: .value("Treatment", min(marker.amount, yDomain.upperBound))
        )
        .foregroundStyle(Color(.lightGray).opacity(0.6))
    }

    private var basalDeltaDomain: ClosedRange<Double> {
        let maximum = max(points.compactMap(\.basalDeltaRate).map(abs).max() ?? 0, 1)
        let bound = ceil(maximum * 1.15 * 10) / 10
        return -bound ... bound
    }

    private var iobUpperBound: Double {
        upperBound(values: points.compactMap(\.iob) + insulinTreatmentMarkers.map(\.amount), minimum: 5)
    }

    private var cobUpperBound: Double {
        upperBound(values: points.compactMap(\.cob) + carbTreatmentMarkers.map(\.amount), minimum: 30)
    }

    private func upperBound(values: [Double], minimum: Double) -> Double {
        guard let maximum = values.max(), maximum > 0 else { return minimum }
        return max(minimum, ceil(maximum * 1.15))
    }

    private func timeLabel(for minute: Int) -> String {
        String(format: "%02d:00", min(minute / 60, 24))
    }
}
