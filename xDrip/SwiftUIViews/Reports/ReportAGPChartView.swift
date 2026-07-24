//
//  ReportAGPChartView.swift
//  xdrip
//
//  Created by Paul Plant on 21/7/26.
//  Copyright © 2026 Johan Degraeve. All rights reserved.
//

import Charts
import SwiftUI

struct GlucoseReportAGPChartView: View {
    let points: [GlucoseReportAGPPoint]
    let usesMgDl: Bool
    let language: GlucoseReportLanguage

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                sectionTitle(language.text(.ambulatoryGlucoseProfile))
                Spacer()
                legend
            }

            Chart {
                RectangleMark(
                    xStart: .value("Start", 0),
                    xEnd: .value("End", 1440),
                    yStart: .value("Low target", converted(GlucoseReportClinicalConstants.timeInRangeLowMgDl)),
                    yEnd: .value("High target", converted(GlucoseReportClinicalConstants.timeInRangeHighMgDl))
                )
                .foregroundStyle(GlucoseReportColors.target.opacity(0.12))

            RuleMark(y: .value("Low target", converted(GlucoseReportClinicalConstants.timeInRangeLowMgDl)))
                    .lineStyle(StrokeStyle(lineWidth: 0.8))
                    .foregroundStyle(GlucoseReportColors.target.opacity(0.75))

            RuleMark(y: .value("High target", converted(GlucoseReportClinicalConstants.timeInRangeHighMgDl)))
                    .lineStyle(StrokeStyle(lineWidth: 0.8))
                    .foregroundStyle(GlucoseReportColors.target.opacity(0.75))

                ForEach(chartPointsForDisplay) { point in
                    AreaMark(
                        x: .value("Time", point.minuteOfDay),
                        yStart: .value("P5", converted(point.p5MgDl)),
                        yEnd: .value("P95", converted(point.p95MgDl)),
                        series: .value("Series", "5-95%")
                    )
                    .foregroundStyle(by: .value("Series", "5-95%"))
                }

                ForEach(chartPointsForDisplay) { point in
                    AreaMark(
                        x: .value("Time", point.minuteOfDay),
                        yStart: .value("P25", converted(point.p25MgDl)),
                        yEnd: .value("P75", converted(point.p75MgDl)),
                        series: .value("Series", "25-75%")
                    )
                    .foregroundStyle(by: .value("Series", "25-75%"))
                }

                ForEach(chartPointsForDisplay) { point in
                    LineMark(
                        x: .value("Time", point.minuteOfDay),
                        y: .value("Median", converted(point.medianMgDl)),
                        series: .value("Series", "Median")
                    )
                    .lineStyle(StrokeStyle(lineWidth: 2.0))
                    .foregroundStyle(by: .value("Series", "Median"))
                }
            }
            .chartForegroundStyleScale([
                "5-95%": GlucoseReportColors.agpOuterBand,
                "25-75%": GlucoseReportColors.agpInnerBand,
                "Median": GlucoseReportColors.clinicalBlue
            ])
            .chartLegend(.hidden)
            .chartXScale(domain: 0 ... 1440)
            .chartYScale(domain: converted(40) ... converted(dynamicUpperYMgDl))
            .chartXAxis {
                AxisMarks(values: [0, 360, 720, 1080, 1440]) { value in
                    AxisGridLine()
                        .foregroundStyle(GlucoseReportColors.rule)
                    AxisValueLabel {
                        if let minute = value.as(Int.self) {
                            Text(timeLabel(minute: minute))
                                .font(.system(size: 7))
                                .foregroundStyle(GlucoseReportColors.secondaryText)
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading, values: yAxisValues) { value in
                    AxisGridLine()
                        .foregroundStyle(GlucoseReportColors.rule)
                    AxisValueLabel {
                        if let glucose = value.as(Double.self) {
                            Text(yAxisLabel(for: glucose))
                                .font(.system(size: 7))
                                .foregroundStyle(GlucoseReportColors.secondaryText)
                        }
                    }
                }
            }
            .frame(height: 205)
            .overlay {
                if points.isEmpty {
                    Text(language.text(.insufficientAGPData))
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(GlucoseReportColors.secondaryText)
                }
            }
        }
    }

    private var legend: some View {
        HStack(spacing: 8) {
            legendItem(color: GlucoseReportColors.agpOuterLine, title: "5-95%")
            legendItem(color: GlucoseReportColors.agpInnerLine, title: "25-75%")
            legendItem(color: GlucoseReportColors.clinicalBlue, title: "Median")
        }
    }

    private func legendItem(color: Color, title: String) -> some View {
        HStack(spacing: 3) {
            RoundedRectangle(cornerRadius: 2)
                .fill(color)
                .frame(width: 12, height: 4)
            Text(title)
                .font(.system(size: 7.5))
                .foregroundStyle(GlucoseReportColors.secondaryText)
        }
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(GlucoseReportColors.clinicalBlue)
    }

    private func converted(_ valueMgDl: Double) -> Double {
        usesMgDl ? valueMgDl : valueMgDl * ConstantsBloodGlucose.mgDlToMmoll
    }

    private var chartPointsForDisplay: [GlucoseReportAGPPoint] {
        GlucoseReportAGPDisplayPoints.smoothedDisplayPoints(from: points)
    }

    private var dynamicUpperYMgDl: Double {
        guard let maximumP95 = chartPointsForDisplay.map(\.p95MgDl).max() else { return 250 }
        let paddedMaximum = maximumP95 + 20

        if paddedMaximum <= 250 {
            return 250
        }

        if paddedMaximum <= 400 {
            return ceil(paddedMaximum / 50) * 50
        }

        return min(450, ceil(paddedMaximum / 50) * 50)
    }

    private var yAxisValues: [Double] {
        [40, GlucoseReportClinicalConstants.timeInRangeLowMgDl, GlucoseReportClinicalConstants.timeInRangeHighMgDl, 250, 300, 350, 400, 450]
            .filter { $0 <= dynamicUpperYMgDl }
            .map(converted)
    }

    private func yAxisLabel(for convertedValue: Double) -> String {
        if usesMgDl {
            return "\(Int(convertedValue.rounded()))"
        }

        return convertedValue.round(toDecimalPlaces: 1).stringWithoutTrailingZeroes
    }

    private func timeLabel(minute: Int) -> String {
        switch minute {
        case 0, 1440:
            return "00:00"
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
