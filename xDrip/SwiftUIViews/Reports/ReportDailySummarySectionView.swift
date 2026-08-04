//
//  ReportDailySummarySectionView.swift
//  xdrip
//
//  Created by Paul Plant on 21/7/26.
//  Copyright © 2026 Johan Degraeve. All rights reserved.
//

import Charts
import SwiftUI

/// Renders daily glucose summaries for the generated report.
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
        VStack(alignment: .leading, spacing: 5) {
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
                    .cornerRadius(1.2)
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

/// Renders glucose, insulin and carbohydrate trends at the interval selected for the report period.
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
                    decimalPlaces: 1,
                    target: nil,
                    value: { $0.gmiPercentage },
                    labelText: { "\(GlucoseReportFormatting.number($0, decimalPlaces: 1, locale: language.locale))%" }
                )

                trendChart(
                    title: language.text(.cv),
                    targetLabel: language.text(.targetLessThanOrEqual, GlucoseReportFormatting.percentage(GlucoseReportClinicalConstants.coefficientOfVariationTargetPercentage)),
                    yDomain: 0 ... 60,
                    decimalPlaces: 0,
                    target: GlucoseReportClinicalConstants.coefficientOfVariationTargetPercentage,
                    value: { $0.coefficientOfVariation },
                    labelText: { "\(GlucoseReportFormatting.number($0, decimalPlaces: 0, locale: language.locale))%" }
                )
            }

            treatmentTrendCharts

            Text(language.text(.gmiFootnote))
                .font(.system(size: 7.5))
                .foregroundStyle(GlucoseReportColors.tertiaryText)
        }
    }

    private var legend: some View {
        HStack(spacing: 8) {
            legendItem(color: GlucoseReportColors.clinicalBlue, title: trendIntervalTitle)
        }
    }

    private var trendIntervalTitle: String {
        switch trendPoints.first?.interval {
        case .daily: return language.text(.daily)
        case .threeDay: return language.text(.threeDay)
        case .weekly, .none: return language.text(.weekly)
        }
    }

    private func trendChart(
        title: String,
        targetLabel: String,
        yDomain: ClosedRange<Double>,
        decimalPlaces: Int,
        target: Double?,
        value: @escaping (GlucoseReportTrendPoint) -> Double?,
        labelText: @escaping (Double) -> String
    ) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(title.uppercased())
                    .font(.system(size: 7.5, weight: .semibold))
                    .foregroundStyle(GlucoseReportColors.secondaryText)
                Spacer()
                Text(targetLabel)
                    .font(.system(size: 7))
                    .foregroundStyle(GlucoseReportColors.tertiaryText)
                    .opacity(targetLabel.isEmpty ? 0 : 1)
            }

            Chart {
                if let target {
                    RuleMark(y: .value("Target", target))
                        .lineStyle(StrokeStyle(lineWidth: 0.8, dash: [3, 3]))
                        .foregroundStyle(GlucoseReportColors.secondaryText.opacity(0.7))
                }

                ForEach(trendPoints) { point in
                    if let pointValue = value(point) {
                        LineMark(
                            x: .value("Date", point.date),
                            y: .value(title, pointValue)
                        )
                        .lineStyle(StrokeStyle(lineWidth: 1.4))
                        .foregroundStyle(by: .value("Interval", point.interval.rawValue))

                        PointMark(
                            x: .value("Date", point.date),
                            y: .value(title, pointValue)
                        )
                        .symbolSize(10)
                        .foregroundStyle(by: .value("Interval", point.interval.rawValue))
                        .annotation(position: .top, alignment: annotationAlignment(for: point, value: value)) {
                            if isTerminalTrendPoint(point, value: value) {
                                Text(labelText(pointValue))
                                    .font(.system(size: 6.5, weight: .semibold))
                                    .foregroundStyle(GlucoseReportColors.secondaryText)
                                    .monospacedDigit()
                            }
                        }
                    }
                }
            }
            .chartForegroundStyleScale([
                GlucoseReportTrendInterval.daily.rawValue: GlucoseReportColors.clinicalBlue,
                GlucoseReportTrendInterval.threeDay.rawValue: GlucoseReportColors.clinicalBlue,
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
                            Text(GlucoseReportFormatting.number(axisValue, decimalPlaces: decimalPlaces, locale: language.locale))
                                .font(.system(size: 6.5))
                                .foregroundStyle(GlucoseReportColors.secondaryText)
                        }
                    }
                }
            }
            .chartXAxis {
                AxisMarks(values: monthTickDates) { axisValue in
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
                if metricTrendPoints(value: value).isEmpty {
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

    @ViewBuilder private var treatmentTrendCharts: some View {
        if hasTDDTrendData || hasCarbTrendData {
            HStack(spacing: 10) {
                if hasTDDTrendData {
                    trendChart(
                        title: language.text(.averageTDD),
                        targetLabel: "",
                        yDomain: upperDomain(values: trendPoints.compactMap(\.averageTDDPerDay), minimum: 20),
                        decimalPlaces: 1,
                        target: nil,
                        value: { $0.averageTDDPerDay },
                        labelText: { "\(GlucoseReportFormatting.number($0, decimalPlaces: 1, locale: language.locale)) U" }
                    )
                }

                if hasCarbTrendData {
                    trendChart(
                        title: language.text(.averageCarbs),
                        targetLabel: "",
                        yDomain: upperDomain(values: trendPoints.compactMap(\.averageCarbsPerDay), minimum: 100),
                        decimalPlaces: 0,
                        target: nil,
                        value: { $0.averageCarbsPerDay },
                        labelText: { "\(GlucoseReportFormatting.number($0, decimalPlaces: 0, locale: language.locale)) g" }
                    )
                }
            }
        }
    }

    private var hasTDDTrendData: Bool {
        trendPoints.contains { $0.averageTDDPerDay != nil }
    }

    private var hasCarbTrendData: Bool {
        trendPoints.contains { $0.averageCarbsPerDay != nil }
    }

    private func upperDomain(values: [Double], minimum: Double) -> ClosedRange<Double> {
        guard let maximum = values.max(), maximum > 0 else { return 0 ... minimum }
        return 0 ... max(minimum, ceil(maximum * 1.15 / 10) * 10)
    }

    private var xDomain: ClosedRange<Date> {
        guard let startDate = trendPoints.map(\.date).min(),
              let endDate = trendPoints.map(\.date).max()
        else {
            let now = Date()
            return now ... now
        }

        let paddedEndDate = Calendar.current.date(
            byAdding: .day,
            value: trendIntervalDayCount,
            to: endDate
        ) ?? endDate
        return startDate ... paddedEndDate
    }

    private var trendIntervalDayCount: Int {
        switch trendPoints.first?.interval {
        case .daily: return 1
        case .threeDay: return 3
        case .weekly, .none: return 7
        }
    }

    private var monthTickDates: [Date] {
        guard !trendPoints.isEmpty else { return [] }

        let calendar = Calendar.current
        let domain = xDomain
        let startComponents = calendar.dateComponents([.year, .month], from: domain.lowerBound)
        guard var month = calendar.date(from: startComponents) else { return [] }

        if month < domain.lowerBound {
            month = calendar.date(byAdding: .month, value: 1, to: month) ?? month
        }

        var ticks: [Date] = []
        while month <= domain.upperBound {
            ticks.append(month)
            guard let nextMonth = calendar.date(byAdding: .month, value: 1, to: month) else { break }
            month = nextMonth
        }

        return ticks
    }

    private var orderedTrendPoints: [GlucoseReportTrendPoint] {
        trendPoints.sorted { $0.date < $1.date }
    }

    private func metricTrendPoints(
        value: (GlucoseReportTrendPoint) -> Double?
    ) -> [GlucoseReportTrendPoint] {
        orderedTrendPoints.filter { value($0) != nil }
    }

    private func isTerminalTrendPoint(
        _ point: GlucoseReportTrendPoint,
        value: (GlucoseReportTrendPoint) -> Double?
    ) -> Bool {
        let points = metricTrendPoints(value: value)
        return point.date == points.first?.date || point.date == points.last?.date
    }

    private func annotationAlignment(
        for point: GlucoseReportTrendPoint,
        value: (GlucoseReportTrendPoint) -> Double?
    ) -> Alignment {
        let points = metricTrendPoints(value: value)
        if point.date == points.first?.date {
            return .leading
        }

        if point.date == points.last?.date {
            return .trailing
        }

        return .center
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
