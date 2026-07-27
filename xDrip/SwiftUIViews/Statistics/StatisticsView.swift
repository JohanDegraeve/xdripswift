//
//  StatisticsView.swift
//  xdrip
//
//  Created by Paul Plant on 21/7/26.
//  Copyright © 2026 Johan Degraeve. All rights reserved.
//

import Charts
import SwiftUI

struct StatisticsView: View {
    @StateObject private var viewModel: StatisticsViewModel
    @State private var isShowingReportGenerator = false
    private let statisticsManager: StatisticsManager

    init(statisticsManager: StatisticsManager) {
        self.statisticsManager = statisticsManager
        _viewModel = StateObject(wrappedValue: StatisticsViewModel(statisticsManager: statisticsManager))
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12, pinnedViews: [.sectionHeaders]) {
                Section {
                    Group {
                        if viewModel.isLoading && viewModel.analytics == nil {
                            ProgressView()
                                .controlSize(.large)
                                .frame(maxWidth: .infinity, minHeight: 220)
                        } else if let analytics = viewModel.analytics, analytics.hasData {
                            content(for: analytics)
                        } else {
                            StatisticsEmptyStateView()
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
                } header: {
                    periodPicker
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                        .padding(.bottom, 8)
                        .background(Color(.systemGroupedBackground))
                }
            }
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle(Texts_Common.statisticsTitle)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    isShowingReportGenerator = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: StatisticsReportButton.systemImage)
                        Text(Texts_Common.reportGenerateTitle)
                    }
                }
                .tint(.yellow)
            }
        }
        .sheet(isPresented: $isShowingReportGenerator) {
            GenerateReportView(statisticsManager: statisticsManager)
        }
        .task {
            viewModel.load()
        }
    }

    @ViewBuilder private func content(for analytics: GlucoseReportAnalytics) -> some View {
        VStack(spacing: 10) {
            StatisticsRangeCard(
                title: Texts_Common.statisticsTimeInRange,
                abbreviation: "TIR",
                buckets: analytics.rangeDistribution.timeInRangeBuckets(usesMgDl: analytics.usesMgDl)
            )
            StatisticsRangeCard(
                title: Texts_Common.statisticsTimeInTightRange,
                abbreviation: "TITR",
                buckets: analytics.tightRangeDistribution.tightRangeBuckets(usesMgDl: analytics.usesMgDl)
            )
            StatisticsSummaryView(analytics: analytics)
            StatisticsAGPCard(analytics: analytics)
            StatisticsTrendCard(trendPoints: analytics.trendPoints)
            StatisticsDailyPatternCard(analytics: analytics, period: viewModel.selectedPeriod)
        }
    }

    private var periodPicker: some View {
        Picker(Texts_Common.statisticsPeriod, selection: $viewModel.selectedPeriod) {
            ForEach(viewModel.selectablePeriods.isEmpty ? [viewModel.selectedPeriod] : viewModel.selectablePeriods) { period in
                Text(period.title)
                    .tag(period)
            }
        }
        .pickerStyle(.segmented)
    }

}

private enum StatisticsReportButton {
    static let systemImage = "chart.line.text.clipboard"
}

private struct StatisticsSummaryView: View {
    let analytics: GlucoseReportAnalytics

    private let tileSpacing: CGFloat = 10
    private var columns: [GridItem] {
        [GridItem(.flexible(), spacing: tileSpacing), GridItem(.flexible(), spacing: tileSpacing)]
    }

    var body: some View {
        LazyVGrid(columns: columns, spacing: tileSpacing) {
            tile(Texts_Common.averageStatistics, GlucoseReportFormatting.glucose(analytics.averageMgDl, usesMgDl: analytics.usesMgDl), Texts_Common.statisticsMeanGlucose)
            tile(Texts_Common.statisticsGMI, "\(analytics.gmiPercentage.round(toDecimalPlaces: 1).stringWithoutTrailingZeroes)%", Texts_Common.statisticsCGMEstimate)
            tile(
                Texts_Common.cvStatistics,
                GlucoseReportFormatting.percentage(analytics.coefficientOfVariation),
                String(format: Texts_Common.statisticsTargetLessThanOrEqual, GlucoseReportFormatting.percentage(GlucoseReportClinicalConstants.coefficientOfVariationTargetPercentage)),
                gauge: StatisticsGauge(
                    value: analytics.coefficientOfVariation,
                    target: GlucoseReportClinicalConstants.coefficientOfVariationTargetPercentage,
                    upperBound: 50,
                    isLowerBetter: true
                )
            )
            tile(
                Texts_Common.statisticsDataCapture,
                GlucoseReportFormatting.percentage(analytics.dataCapturePercentage),
                String(format: Texts_Common.statisticsTargetGreaterThanOrEqual, GlucoseReportFormatting.percentage(GlucoseReportClinicalConstants.minimumDataCapturePercentage)),
                gauge: StatisticsGauge(
                    value: analytics.dataCapturePercentage,
                    target: GlucoseReportClinicalConstants.minimumDataCapturePercentage,
                    upperBound: 100,
                    isLowerBetter: false
                )
            )
        }
    }

    private func tile(_ title: String, _ value: String, _ detail: String, gauge: StatisticsGauge? = nil) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Color(.colorSecondary))
            Text(value)
                .font(.title3.weight(.bold))
                .monospacedDigit()
                .foregroundStyle(Color(.colorPrimary))
            Text(detail)
                .font(.caption2)
                .foregroundStyle(Color(.colorTertiary))
            if let gauge {
                StatisticsTargetGauge(gauge: gauge)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct StatisticsGauge {
    let value: Double
    let target: Double
    let upperBound: Double
    let isLowerBetter: Bool

    var valueFraction: CGFloat {
        fraction(for: value)
    }

    var targetFraction: CGFloat {
        fraction(for: target)
    }

    var color: Color {
        isOnTarget ? ConstantsAppColors.statisticsInRange : ConstantsAppColors.warning
    }

    private var isOnTarget: Bool {
        isLowerBetter ? value <= target : value >= target
    }

    private func fraction(for value: Double) -> CGFloat {
        guard upperBound > 0 else { return 0 }
        return min(max(CGFloat(value / upperBound), 0), 1)
    }
}

private struct StatisticsTargetGauge: View {
    let gauge: StatisticsGauge

    var body: some View {
        GeometryReader { geometry in
            let barHeight: CGFloat = 5
            let targetX = geometry.size.width * gauge.targetFraction
            let markerSize = CGSize(width: 9, height: 11)

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color(.tertiarySystemFill))
                    .frame(height: barHeight)

                Capsule()
                    .fill(gauge.color)
                    .frame(width: max(barHeight, geometry.size.width * gauge.valueFraction), height: barHeight)

                Image(systemName: gauge.isLowerBetter ? "arrowtriangle.left.fill" : "arrowtriangle.right.fill")
                    .font(.system(size: markerSize.height, weight: .bold))
                    .foregroundStyle(Color(.colorSecondary))
                    .scaleEffect(x: 0.72, y: 1)
                    .frame(width: markerSize.width, height: markerSize.height)
                    .offset(
                        x: min(max(targetX - markerSize.width / 2, 0), geometry.size.width - markerSize.width)
                    )
            }
        }
        .frame(height: 11)
        .padding(.top, 5)
    }
}

private struct StatisticsRangeCard: View {
    let title: String
    let abbreviation: String
    let buckets: [GlucoseReportRangeBucket]

    var body: some View {
        StatisticsCard {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color(.colorPrimary))
                Spacer()
                Text(abbreviation)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Color(.colorTertiary))
            }

            GeometryReader { geometry in
                HStack(spacing: 1) {
                    ForEach(buckets) { bucket in
                        Rectangle()
                            .fill(bucket.color)
                            .frame(width: segmentWidth(for: bucket, totalWidth: geometry.size.width))
                    }
                }
            }
            .frame(height: 14)
            .clipShape(RoundedRectangle(cornerRadius: 4))

            HStack(alignment: .top, spacing: 6) {
                ForEach(buckets) { bucket in
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Circle()
                                .fill(bucket.color)
                                .frame(width: 7, height: 7)
                            Text(title(for: bucket))
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(Color(.colorPrimary))
                                .lineLimit(1)
                            if shouldShowRangeDetail(for: bucket) {
                                Text("(\(bucket.detail))")
                                    .font(.caption2)
                                    .foregroundStyle(Color(.colorSecondary))
                                    .lineLimit(1)
                            }
                        }
                        Text(GlucoseReportFormatting.percentage(bucket.percentage))
                            .font(.callout.weight(.bold))
                            .foregroundStyle(Color(.colorPrimary))
                            .monospacedDigit()
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    private func segmentWidth(for bucket: GlucoseReportRangeBucket, totalWidth: CGFloat) -> CGFloat {
        guard bucket.percentage > 0 else { return 0 }
        return max(2, totalWidth * CGFloat(bucket.percentage / 100))
    }

    private func shouldShowRangeDetail(for bucket: GlucoseReportRangeBucket) -> Bool {
        bucket.key == .low || bucket.key == .high
    }

    private func title(for bucket: GlucoseReportRangeBucket) -> String {
        switch bucket.key {
        case .low:
            return Texts_Common.lowStatistics
        case .inRange:
            return Texts_Common.inRangeStatistics
        case .tightRange:
            return Texts_Common.inTightRangeStatistics
        case .high:
            return Texts_Common.highStatistics
        default:
            return bucket.title(language: .english)
        }
    }
}

private struct StatisticsAGPCard: View {
    let analytics: GlucoseReportAnalytics

    var body: some View {
        StatisticsCard(title: Texts_Common.statisticsAmbulatoryGlucoseProfile) {
            StatisticsAGPChart(points: analytics.agpPoints, usesMgDl: analytics.usesMgDl)
        }
    }
}

private struct StatisticsAGPChart: View {
    let points: [GlucoseReportAGPPoint]
    let usesMgDl: Bool

    var body: some View {
        AGPChartView(
            points: points,
            usesMgDl: usesMgDl,
            presentation: .statistics,
            emptyMessage: Texts_Common.statisticsInsufficientAGPData
        )
        .frame(height: 165)
    }
}

private struct StatisticsTrendCard: View {
    let trendPoints: [GlucoseReportTrendPoint]

    var body: some View {
        StatisticsCard {
            VStack(spacing: 8) {
                trendChart(
                    title: Texts_Common.statisticsEstimatedA1cTrend,
                    targetLabel: "",
                    yDomain: gmiDomain,
                    target: nil,
                    showsXAxisLabels: false,
                    value: \.gmiPercentage
                )

                trendChart(
                    title: Texts_Common.statisticsCVTrend,
                    targetLabel: String(format: Texts_Common.statisticsTargetLessThanOrEqual, GlucoseReportFormatting.percentage(GlucoseReportClinicalConstants.coefficientOfVariationTargetPercentage)),
                    yDomain: 0 ... 60,
                    target: GlucoseReportClinicalConstants.coefficientOfVariationTargetPercentage,
                    showsXAxisLabels: true,
                    value: \.coefficientOfVariation
                )
            }
        }
    }

    private func trendChart(
        title: String,
        targetLabel: String,
        yDomain: ClosedRange<Double>,
        target: Double?,
        showsXAxisLabels: Bool,
        value: KeyPath<GlucoseReportTrendPoint, Double>
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color(.colorPrimary))
                Spacer()
                if !targetLabel.isEmpty {
                    Text(targetLabel)
                        .font(.caption2)
                        .foregroundStyle(Color(.colorTertiary))
                }
            }

            Chart {
                if let target {
                    RuleMark(y: .value("Target", target))
                        .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [3, 4]))
                        .foregroundStyle(Color.white.opacity(0.75))
                }

                ForEach(trendPoints) { point in
                    if point.interval == .weekly {
                        LineMark(
                            x: .value("Date", point.date),
                            y: .value(title, point[keyPath: value])
                        )
                        .lineStyle(StrokeStyle(lineWidth: 2.0))
                        .foregroundStyle(Color.cyan)
                        .interpolationMethod(.catmullRom)

                        PointMark(
                            x: .value("Date", point.date),
                            y: .value(title, point[keyPath: value])
                        )
                        .symbolSize(10)
                        .foregroundStyle(Color.cyan)
                    }
                }
            }
            .chartLegend(.hidden)
            .chartXScale(domain: xDomain)
            .chartYScale(domain: yDomain)
            .chartYAxis {
                AxisMarks(position: .trailing, values: yAxisValues(for: yDomain)) { value in
                    AxisGridLine()
                        .foregroundStyle(Color(.separator).opacity(0.6))
                    AxisValueLabel {
                        if let axisValue = value.as(Double.self) {
                            Text(axisValue.round(toDecimalPlaces: 1).stringWithoutTrailingZeroes)
                                .font(.system(size: ConstantsStatistics.chartAxisLabelFontSize))
                                .foregroundStyle(Color(.colorTertiary))
                                .monospacedDigit()
                        }
                    }
                }
            }
            .chartXAxis {
                AxisMarks(values: xTickDates) { value in
                    AxisGridLine()
                        .foregroundStyle(Color(.separator).opacity(0.6))
                    AxisValueLabel {
                        if showsXAxisLabels, let date = value.as(Date.self) {
                            Text(axisLabel(for: date))
                                .font(.system(size: ConstantsStatistics.chartAxisLabelFontSize))
                                .foregroundStyle(Color(.colorTertiary))
                        }
                    }
                }
            }
            .frame(height: 76)
            .overlay {
                if trendPoints.isEmpty {
                    Text(Texts_Common.statisticsInsufficientData)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color(.colorSecondary))
                }
            }
        }
    }

    private var gmiDomain: ClosedRange<Double> {
        let values = trendPoints.map(\.gmiPercentage)
        guard let minimum = values.min(), let maximum = values.max() else { return 5 ... 9 }
        let lowerBound = max(4, floor(minimum) - 0.5)
        let upperBound = max(9, ceil(maximum) + 0.5)
        return lowerBound ... min(14, upperBound)
    }

    private var xDomain: ClosedRange<Date> {
        guard let start = trendPoints.map(\.date).min(),
              let end = trendPoints.map(\.date).max(),
              start < end else {
            let now = Date()
            return now.addingTimeInterval(-24 * 60 * 60) ... now
        }

        return start ... end
    }

    private var xTickDates: [Date] {
        return trendPoints
            .filter { $0.interval == .weekly }
            .map(\.date)
            .enumerated()
            .compactMap { index, date in index.isMultiple(of: 4) ? date : nil }
    }

    private func yAxisValues(for domain: ClosedRange<Double>) -> [Double] {
        let midpoint = (domain.lowerBound + domain.upperBound) / 2
        return [domain.lowerBound, midpoint, domain.upperBound]
    }

    private func axisLabel(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("MMM")
        return formatter.string(from: date)
    }
}

private struct StatisticsDailyPatternCard: View {
    let analytics: GlucoseReportAnalytics
    let period: GlucoseReportPeriod

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            StatisticsCard {
                HStack(alignment: .firstTextBaseline) {
                    Text(Texts_Common.statisticsDailyPattern)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color(.colorPrimary))
                    Spacer()
                    Text(String(format: Texts_Common.statisticsAverageFormat, GlucoseReportFormatting.percentage(averageInRangePercentage)))
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color(.colorTertiary))
                        .monospacedDigit()
                }

                Chart {
                    ForEach(analytics.dailySummaries) { summary in
                        if summary.sampleCount > 0 {
                            BarMark(
                                x: .value("Date", summary.date, unit: .day),
                                y: .value("In Range", summary.targetPercentage)
                            )
                            .foregroundStyle(ConstantsAppColors.statisticsInRange)
                        }
                    }

                    RuleMark(y: .value("Target", GlucoseReportClinicalConstants.dailyTimeInRangeTargetPercentage))
                        .lineStyle(StrokeStyle(lineWidth: 2, dash: [3, 4]))
                        .foregroundStyle(Color.white.opacity(0.9))
                }
                .chartYScale(domain: 0 ... 100)
                .chartYAxis {
                    AxisMarks(position: .leading, values: [0, 25, 50, 75, 100])
                }
                .chartXAxis {
                    AxisMarks(values: xAxisDates) { value in
                        AxisGridLine()
                            .foregroundStyle(Color(.separator).opacity(0.35))
                        AxisValueLabel {
                            if let date = value.as(Date.self) {
                                Text(axisLabel(for: date))
                                    .font(.caption2)
                                    .foregroundStyle(Color(.colorTertiary))
                            }
                        }
                    }
                }
                .frame(height: 175)
            }

            Text(Texts_Common.statisticsDailyPatternFooter)
                .font(.caption2)
                .foregroundStyle(Color(.colorTertiary))
                .padding(.horizontal, 12)
        }
    }

    private var averageInRangePercentage: Double {
        let validSummaries = analytics.dailySummaries.filter { $0.sampleCount > 0 }
        guard !validSummaries.isEmpty else { return 0 }
        return validSummaries.map(\.targetPercentage).reduce(0, +) / Double(validSummaries.count)
    }

    private var xAxisDates: [Date] {
        let calendar = Calendar.current
        let dates = analytics.dailySummaries.map(\.date)

        switch period {
        case .ninety:
            return dates.filter { calendar.component(.day, from: $0) == 1 }
        case .oneEighty:
            return dates.filter {
                calendar.component(.day, from: $0) == 1 && calendar.component(.month, from: $0).isMultiple(of: 2)
            }
        case .oneYear:
            return dates.filter {
                calendar.component(.day, from: $0) == 1 && (calendar.component(.month, from: $0) - 1).isMultiple(of: 4)
            }
        case .sixty:
            return dates.enumerated().compactMap { index, date in index.isMultiple(of: 14) ? date : nil }
        default:
            return dates.enumerated().compactMap { index, date in index.isMultiple(of: 7) ? date : nil }
        }
    }

    private func axisLabel(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate(period == .seven || period == .thirty || period == .sixty ? "d MMM" : "MMM")
        return formatter.string(from: date)
    }
}

private struct StatisticsCard<Content: View>: View {
    let title: String?
    @ViewBuilder let content: Content

    init(title: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let title {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color(.colorPrimary))
            }
            content
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct StatisticsEmptyStateView: View {
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "chart.xyaxis.line")
                .font(.system(size: 36, weight: .semibold))
                .foregroundStyle(Color(.colorTertiary))
            Text(Texts_Common.statisticsNoDataTitle)
                .font(.headline)
                .foregroundStyle(Color(.colorPrimary))
            Text(Texts_Common.statisticsNoDataMessage)
                .font(.subheadline)
                .foregroundStyle(Color(.colorSecondary))
                .multilineTextAlignment(.center)
        }
        .padding(24)
        .frame(maxWidth: .infinity, minHeight: 220)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 8))
    }
}
