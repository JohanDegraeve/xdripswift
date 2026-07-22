//
//  ReportDailySummarySectionView.swift
//  xdrip
//
//  Created by Paul Plant on 21/7/26.
//  Copyright © 2026 Johan Degraeve. All rights reserved.
//

import Charts
import SwiftUI

struct GlucoseReportDailySummarySectionView: View {
    let summaries: [GlucoseReportDailySummary]
    let usesMgDl: Bool
    let language: GlucoseReportLanguage

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle(language.text(.dailyPatternSummary))

            dailyChart(title: language.text(.high), targetLabel: language.text(.targetLessThanOrEqual, GlucoseReportFormatting.percentage(GlucoseReportClinicalConstants.dailyHighTargetPercentage)), target: GlucoseReportClinicalConstants.dailyHighTargetPercentage, color: GlucoseReportColors.high) { $0.highPercentage }
            dailyChart(title: language.text(.inRange), targetLabel: language.text(.targetGreaterThanOrEqual, GlucoseReportFormatting.percentage(GlucoseReportClinicalConstants.dailyTimeInRangeTargetPercentage)), target: GlucoseReportClinicalConstants.dailyTimeInRangeTargetPercentage, color: GlucoseReportColors.target) { $0.targetPercentage }
            dailyChart(title: language.text(.low), targetLabel: language.text(.targetLessThanOrEqual, GlucoseReportFormatting.percentage(GlucoseReportClinicalConstants.dailyLowTargetPercentage)), target: GlucoseReportClinicalConstants.dailyLowTargetPercentage, color: GlucoseReportColors.low) { $0.lowPercentage }

            HStack(spacing: 10) {
                summaryPill(title: language.text(.bestTIR), value: bestTIRText)
                summaryPill(title: language.text(.lowestAverage), value: lowestDayText)
                summaryPill(title: language.text(.highestAverage), value: highestDayText)
            }
        }
    }

    private var bestTIRText: String {
        guard let summary = summaries.filter({ $0.sampleCount > 0 }).max(by: { $0.targetPercentage < $1.targetPercentage }) else { return "-" }
        return "\(GlucoseReportFormatting.day(summary.date, language: language)) · \(GlucoseReportFormatting.percentage(summary.targetPercentage))"
    }

    private var lowestDayText: String {
        guard let summary = summaries.filter({ $0.sampleCount > 0 }).min(by: { $0.averageMgDl < $1.averageMgDl }) else { return "-" }
        return "\(GlucoseReportFormatting.day(summary.date, language: language)) · \(GlucoseReportFormatting.glucose(summary.averageMgDl, usesMgDl: usesMgDl))"
    }

    private var highestDayText: String {
        guard let summary = summaries.filter({ $0.sampleCount > 0 }).max(by: { $0.averageMgDl < $1.averageMgDl }) else { return "-" }
        return "\(GlucoseReportFormatting.day(summary.date, language: language)) · \(GlucoseReportFormatting.glucose(summary.averageMgDl, usesMgDl: usesMgDl))"
    }

    private func dailyChart(
        title: String,
        targetLabel: String,
        target: Double,
        color: Color,
        value: @escaping (GlucoseReportDailySummary) -> Double
    ) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                HStack(spacing: 3) {
                    Circle()
                        .fill(color)
                        .frame(width: 5, height: 5)
                    Text(title.uppercased())
                        .font(.system(size: 7.5, weight: .semibold))
                        .foregroundStyle(GlucoseReportColors.secondaryText)
                }
                Spacer()
                Text(targetLabel)
                    .font(.system(size: 7))
                    .foregroundStyle(GlucoseReportColors.tertiaryText)
            }

            Chart {
                RuleMark(y: .value("Target", target))
                    .lineStyle(StrokeStyle(lineWidth: 0.8, dash: [3, 3]))
                    .foregroundStyle(GlucoseReportColors.secondaryText.opacity(0.7))

                ForEach(summaries) { summary in
                    BarMark(
                        x: .value("Day", summary.date, unit: .day),
                        y: .value(title, value(summary))
                    )
                    .foregroundStyle(summary.sampleCount > 0 ? color : GlucoseReportColors.rule)
                }
            }
            .chartXScale(domain: xDomain)
            .chartYScale(domain: 0 ... 100)
            .chartYAxis {
                AxisMarks(position: .leading, values: [0, 50, 100]) { axisValue in
                    AxisGridLine()
                        .foregroundStyle(GlucoseReportColors.rule)
                    AxisValueLabel {
                        if let percentage = axisValue.as(Int.self) {
                            Text("\(percentage)%")
                                .font(.system(size: 6.5))
                                .foregroundStyle(GlucoseReportColors.secondaryText)
                        }
                    }
                }
            }
            .chartXAxis {
                AxisMarks(values: weeklyTickDates) { axisValue in
                    AxisGridLine()
                        .foregroundStyle(GlucoseReportColors.rule.opacity(0.7))
                    AxisValueLabel {
                        if let date = axisValue.as(Date.self) {
                            Text(GlucoseReportFormatting.day(date, language: language))
                                .font(.system(size: 6.5))
                                .foregroundStyle(GlucoseReportColors.secondaryText)
                        }
                    }
                }
            }
            .frame(height: 58)
        }
    }

    private var xDomain: ClosedRange<Date> {
        guard let startDate = summaries.first?.date,
              let endDate = summaries.last?.date
        else {
            let now = Date()
            return now ... now
        }

        let paddedEndDate = Calendar.current.date(byAdding: .day, value: 1, to: endDate) ?? endDate
        return startDate ... paddedEndDate
    }

    private var weeklyTickDates: [Date] {
        summaries
            .map(\.date)
            .filter { Calendar.current.component(.weekday, from: $0) == 2 }
    }

    private func summaryPill(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title.uppercased())
                .font(.system(size: 7, weight: .semibold))
                .foregroundStyle(GlucoseReportColors.secondaryText)
            Text(value)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(GlucoseReportColors.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(7)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(GlucoseReportColors.panel)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(GlucoseReportColors.clinicalBlue)
    }

}

struct GlucoseReportMetricTrendSectionView: View {
    let trendPoints: [GlucoseReportTrendPoint]
    let language: GlucoseReportLanguage

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .firstTextBaseline) {
                sectionTitle(language.text(.estimatedA1cAndVariabilityTrend))
                Spacer()
                legend
            }

            HStack(spacing: 10) {
                trendChart(
                    title: language.text(.estimatedA1cGMI),
                    targetLabel: language.text(.lowerIsGenerallyBetter),
                    yDomain: gmiDomain,
                    target: nil,
                    value: \.gmiPercentage
                )

                trendChart(
                    title: language.text(.cv),
                    targetLabel: language.text(.targetLessThanOrEqual, GlucoseReportFormatting.percentage(GlucoseReportClinicalConstants.coefficientOfVariationTargetPercentage)),
                    yDomain: 0 ... 60,
                    target: GlucoseReportClinicalConstants.coefficientOfVariationTargetPercentage,
                    value: \.coefficientOfVariation
                )
            }

            Text(language.text(.gmiFootnote))
                .font(.system(size: 7.5))
                .foregroundStyle(GlucoseReportColors.tertiaryText)
        }
    }

    private var legend: some View {
        HStack(spacing: 8) {
            legendItem(color: GlucoseReportColors.clinicalBlue, title: language.text(.weekly))
        }
    }

    private func trendChart(
        title: String,
        targetLabel: String,
        yDomain: ClosedRange<Double>,
        target: Double?,
        value: KeyPath<GlucoseReportTrendPoint, Double>
    ) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(title.uppercased())
                    .font(.system(size: 7.5, weight: .semibold))
                    .foregroundStyle(GlucoseReportColors.secondaryText)
                Spacer()
                Text(targetLabel)
                    .font(.system(size: 7))
                    .foregroundStyle(GlucoseReportColors.tertiaryText)
            }

            Chart {
                if let target {
                    RuleMark(y: .value("Target", target))
                        .lineStyle(StrokeStyle(lineWidth: 0.8, dash: [3, 3]))
                        .foregroundStyle(GlucoseReportColors.secondaryText.opacity(0.7))
                }

                ForEach(trendPoints) { point in
                    if point.interval == .weekly {
                        LineMark(
                            x: .value("Date", point.date),
                            y: .value(title, point[keyPath: value])
                        )
                        .lineStyle(StrokeStyle(lineWidth: 1.4))
                        .foregroundStyle(by: .value("Interval", point.interval.rawValue))

                        PointMark(
                            x: .value("Date", point.date),
                            y: .value(title, point[keyPath: value])
                        )
                        .symbolSize(10)
                        .foregroundStyle(by: .value("Interval", point.interval.rawValue))
                    }
                }
            }
            .chartForegroundStyleScale([
                GlucoseReportTrendInterval.weekly.rawValue: GlucoseReportColors.clinicalBlue
            ])
            .chartLegend(.hidden)
            .chartXScale(domain: xDomain)
            .chartYScale(domain: yDomain)
            .chartYAxis {
                AxisMarks(position: .leading, values: yAxisValues(for: yDomain)) { axisValue in
                    AxisGridLine()
                        .foregroundStyle(GlucoseReportColors.rule)
                    AxisValueLabel {
                        if let axisValue = axisValue.as(Double.self) {
                            Text(axisValue.round(toDecimalPlaces: 1).stringWithoutTrailingZeroes)
                                .font(.system(size: 6.5))
                                .foregroundStyle(GlucoseReportColors.secondaryText)
                        }
                    }
                }
            }
            .chartXAxis {
                AxisMarks(values: xTickDates) { axisValue in
                    AxisGridLine()
                        .foregroundStyle(GlucoseReportColors.rule.opacity(0.7))
                    AxisValueLabel {
                        if let date = axisValue.as(Date.self) {
                            Text(GlucoseReportFormatting.day(date, language: language))
                                .font(.system(size: 6.5))
                                .foregroundStyle(GlucoseReportColors.secondaryText)
                        }
                    }
                }
            }
            .frame(height: 78)
            .overlay {
                if trendPoints.isEmpty {
                    Text(language.text(.insufficientData))
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(GlucoseReportColors.secondaryText)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var gmiDomain: ClosedRange<Double> {
        let values = trendPoints.map(\.gmiPercentage)
        guard let minimum = values.min(), let maximum = values.max() else {
            return 5 ... 10
        }

        let lower = max(4, floor((minimum - 0.2) * 2) / 2)
        let upper = min(14, ceil((maximum + 0.2) * 2) / 2)
        return lower ... max(lower + 1, upper)
    }

    private var xDomain: ClosedRange<Date> {
        guard let startDate = trendPoints.map(\.date).min(),
              let endDate = trendPoints.map(\.date).max()
        else {
            let now = Date()
            return now ... now
        }

        let paddedEndDate = Calendar.current.date(byAdding: .day, value: 7, to: endDate) ?? endDate
        return startDate ... paddedEndDate
    }

    private var xTickDates: [Date] {
        return trendPoints
            .filter { $0.interval == .weekly }
            .map(\.date)
    }

    private func yAxisValues(for domain: ClosedRange<Double>) -> [Double] {
        let middle = (domain.lowerBound + domain.upperBound) / 2
        return [domain.lowerBound, middle, domain.upperBound]
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
}
