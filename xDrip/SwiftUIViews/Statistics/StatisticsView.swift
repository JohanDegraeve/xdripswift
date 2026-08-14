//
//  StatisticsView.swift
//  xdrip
//
//  Created by Paul Plant on 21/7/26.
//  Copyright © 2026 Johan Degraeve. All rights reserved.
//

import Charts
import SwiftUI

/// Presents CGM, AGP and trend statistics for the selected period.
struct StatisticsView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @StateObject private var viewModel: StatisticsViewModel
    @State private var isShowingReportGenerator = false
    @State private var selectedPage: StatisticsPage = .cgmData
    private let statisticsManager: StatisticsManager

    init(statisticsManager: StatisticsManager) {
        self.statisticsManager = statisticsManager
        _viewModel = StateObject(wrappedValue: StatisticsViewModel(statisticsManager: statisticsManager))
    }

    var body: some View {
        VStack(spacing: 0) {
            periodHeader

            contentArea
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle(Texts_Common.statisticsTitle)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                OnlineHelpButton(topic: .statistics)

                Button {
                    isShowingReportGenerator = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: StatisticsReportButton.systemImage)
                        Text(Texts_Common.reportGenerateTitle)
                    }
                }
                .tint(ConstantsAppColors.toolbarAction)
            }
        }
        .sheet(isPresented: $isShowingReportGenerator) {
            GenerateReportView(statisticsManager: statisticsManager)
                .ipadLargeSheet(width: 980, height: 840)
        }
        .task {
            viewModel.load()
        }
    }

    @ViewBuilder private var contentArea: some View {
        if viewModel.isLoading && viewModel.analytics == nil {
            ProgressView()
                .controlSize(.large)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let analytics = viewModel.analytics, analytics.hasData {
            if UIDevice.current.userInterfaceIdiom == .pad {
                GeometryReader { geometry in
                    if IPadLayoutClass.resolve(
                        isPad: true,
                        width: geometry.size.width,
                        usesAccessibilityText: dynamicTypeSize.isAccessibilitySize
                    ) == .compact {
                        phoneContent(analytics: analytics)
                    } else {
                        ipadContent(analytics: analytics, width: geometry.size.width)
                    }
                }
            } else {
                phoneContent(analytics: analytics)
            }
        } else {
            StatisticsEmptyStateView()
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func phoneContent(analytics: GlucoseReportAnalytics) -> some View {
        TabView(selection: $selectedPage) {
            ForEach(StatisticsPage.allCases) { page in
                StatisticsPageScrollView {
                    pagePicker
                    pageContent(page, analytics: analytics)
                }
                .tag(page)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func ipadContent(analytics: GlucoseReportAnalytics, width: CGFloat) -> some View {
        ScrollView {
            VStack(spacing: 14) {
                pagePicker
                    .frame(maxWidth: 520)

                if selectedPage == .cgmData {
                    HStack(alignment: .top, spacing: 14) {
                        StatisticsSection(title: Texts_Common.statisticsTimeInRange, detail: "TIR") {
                            StatisticsRangeCard(buckets: analytics.rangeDistribution.timeInRangeBuckets(usesMgDl: analytics.usesMgDl))
                        }
                        .frame(maxWidth: .infinity)

                        StatisticsSection(title: Texts_Common.statisticsTimeInTightRange, detail: "TITR") {
                            StatisticsRangeCard(buckets: analytics.tightRangeDistribution.tightRangeBuckets(usesMgDl: analytics.usesMgDl))
                        }
                        .frame(maxWidth: .infinity)
                    }

                    StatisticsSummaryView(analytics: analytics, columnCount: width >= 980 ? 4 : 2)
                } else {
                    StatisticsAGPCard(analytics: analytics)

                    HStack(alignment: .top, spacing: 14) {
                        StatisticsTrendCard(trendPoints: analytics.trendPoints)
                            .frame(maxWidth: .infinity)
                        StatisticsDailyPatternCard(analytics: analytics, period: viewModel.selectedPeriod)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
            .frame(maxWidth: 1240)
            .padding(.horizontal, 24)
            .padding(.top, 10)
            .padding(.bottom, 24)
            .frame(maxWidth: .infinity)
        }
    }

    @ViewBuilder private func pageContent(_ page: StatisticsPage, analytics: GlucoseReportAnalytics) -> some View {
        switch page {
        case .cgmData:
            StatisticsCGMDataPage(analytics: analytics)
        case .cgmStatistics:
            StatisticsCGMStatisticsPage(analytics: analytics, period: viewModel.selectedPeriod)
        }
    }

    private var pagePicker: some View {
        Picker(Texts_Common.statisticsSection, selection: $selectedPage) {
            ForEach(StatisticsPage.allCases) { page in
                Text(page.title)
                    .tag(page)
            }
        }
        .pickerStyle(.segmented)
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

    private var periodHeader: some View {
        VStack(spacing: 0) {
            periodPicker
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 8)
                .frame(maxWidth: UIDevice.current.userInterfaceIdiom == .pad ? 560 : .infinity)

            Divider()
                .overlay(Color(.separator))
        }
        .frame(maxWidth: .infinity)
        .background(Color(.systemGroupedBackground))
    }

}

private enum StatisticsPage: String, CaseIterable, Identifiable {
    case cgmData
    case cgmStatistics

    var id: Self { self }

    var title: String {
        switch self {
        case .cgmData:
            return Texts_Common.statisticsSummary
        case .cgmStatistics:
            return Texts_Common.statisticsTrends
        }
    }
}

private enum StatisticsReportButton {
    static let systemImage = "chart.line.text.clipboard"
}

private struct StatisticsPageScrollView<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                content
            }
            .padding(.bottom, 12)
        }
    }
}

private struct StatisticsCGMDataPage: View {
    let analytics: GlucoseReportAnalytics

    var body: some View {
        StatisticsSection(title: Texts_Common.statisticsTimeInRange, detail: "TIR") {
            StatisticsRangeCard(buckets: analytics.rangeDistribution.timeInRangeBuckets(usesMgDl: analytics.usesMgDl))
        }
        StatisticsSection(title: Texts_Common.statisticsTimeInTightRange, detail: "TITR") {
            StatisticsRangeCard(buckets: analytics.tightRangeDistribution.tightRangeBuckets(usesMgDl: analytics.usesMgDl))
        }
        StatisticsSummaryView(analytics: analytics)
    }
}

private struct StatisticsCGMStatisticsPage: View {
    let analytics: GlucoseReportAnalytics
    let period: GlucoseReportPeriod

    var body: some View {
        StatisticsAGPCard(analytics: analytics)
        StatisticsTrendCard(trendPoints: analytics.trendPoints)
        StatisticsDailyPatternCard(analytics: analytics, period: period)
    }
}

private struct StatisticsSummaryView: View {
    let analytics: GlucoseReportAnalytics
    var columnCount = 2

    private let tileSpacing: CGFloat = 10
    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: tileSpacing), count: columnCount)
    }

    var body: some View {
        LazyVGrid(columns: columns, spacing: tileSpacing) {
            tile(Texts_Common.averageStatistics, GlucoseReportFormatting.glucose(analytics.averageMgDl, usesMgDl: analytics.usesMgDl), Texts_Common.statisticsAverageGlucose)
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
                    .foregroundStyle(Color(.colorPrimary))
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
    let buckets: [GlucoseReportRangeBucket]

    var body: some View {
        StatisticsCard {
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
        StatisticsSection(title: Texts_Common.statisticsAmbulatoryGlucoseProfile) {
            StatisticsCard {
                StatisticsAGPChart(points: analytics.agpPoints, usesMgDl: analytics.usesMgDl)
            }
        }
    }
}

private struct StatisticsAGPChart: View {
    let points: [GlucoseReportAGPPoint]
    let usesMgDl: Bool

    var body: some View {
        GeometryReader { geometry in
            AGPChartView(
                points: points,
                usesMgDl: usesMgDl,
                presentation: .statistics,
                emptyMessage: Texts_Common.statisticsInsufficientAGPData,
                fixedPlotWidth: plotWidth(for: geometry.size.width)
            )
        }
        .frame(height: 165)
    }

    private func plotWidth(for availableWidth: CGFloat) -> CGFloat {
        max(0, availableWidth - ConstantsStatistics.chartTrailingAxisWidth)
    }
}

private struct StatisticsTrendCard: View {
    let trendPoints: [GlucoseReportTrendPoint]

    var body: some View {
        VStack(spacing: 10) {
            StatisticsSection(title: Texts_Common.statisticsEstimatedA1cTrend) {
                StatisticsCard {
                    trendChart(
                        title: Texts_Common.statisticsEstimatedA1cTrend,
                        yDomain: gmiDomain,
                        decimalPlaces: 1,
                        value: { $0.gmiPercentage },
                        labelText: { "\(GlucoseReportFormatting.number($0, decimalPlaces: 1))%" }
                    )
                }
            }

            StatisticsSection(title: Texts_Common.statisticsCVTrend) {
                StatisticsCard {
                    trendChart(
                        title: Texts_Common.statisticsCVTrend,
                        yDomain: 0 ... 60,
                        decimalPlaces: 0,
                        value: { $0.coefficientOfVariation },
                        labelText: { "\(GlucoseReportFormatting.number($0, decimalPlaces: 0))%" }
                    )
                }
            }

            if hasTDDTrendData {
                StatisticsSection(title: Texts_Common.statisticsAverageTDD) {
                    StatisticsCard {
                        trendChart(
                            title: Texts_Common.statisticsAverageTDD,
                            yDomain: upperDomain(values: trendPoints.compactMap(\.averageTDDPerDay), minimum: 20),
                            decimalPlaces: 0,
                            value: { $0.averageTDDPerDay },
                            labelText: { "\(GlucoseReportFormatting.number($0, decimalPlaces: 1)) U" }
                        )
                    }
                }
            }

            if hasCarbTrendData {
                StatisticsSection(title: Texts_Common.statisticsAverageCarbs) {
                    StatisticsCard {
                        trendChart(
                            title: Texts_Common.statisticsAverageCarbs,
                            yDomain: upperDomain(values: trendPoints.compactMap(\.averageCarbsPerDay), minimum: 100),
                            decimalPlaces: 0,
                            value: { $0.averageCarbsPerDay },
                            labelText: { "\(GlucoseReportFormatting.number($0, decimalPlaces: 0)) g" }
                        )
                    }
                }
            }
        }
    }

    private func trendChart(
        title: String,
        yDomain: ClosedRange<Double>,
        decimalPlaces: Int,
        value: @escaping (GlucoseReportTrendPoint) -> Double?,
        labelText: @escaping (Double) -> String
    ) -> some View {
        GeometryReader { geometry in
            Chart {
                ForEach(trendPoints) { point in
                    if let valueForPoint = value(point) {
                        LineMark(
                            x: .value("Date", point.date),
                            y: .value(title, valueForPoint)
                        )
                        .lineStyle(StrokeStyle(lineWidth: 2.0))
                        .foregroundStyle(Color.cyan)
                        .interpolationMethod(.catmullRom)

                        PointMark(
                            x: .value("Date", point.date),
                            y: .value(title, valueForPoint)
                        )
                        .symbolSize(10)
                        .foregroundStyle(Color.cyan)
                        .annotation(position: .top, alignment: annotationAlignment(for: point)) {
                            if isTerminalTrendPoint(point) {
                                Text(labelText(valueForPoint))
                                    .font(.system(size: ConstantsStatistics.chartAxisLabelFontSize + 1, weight: .semibold))
                                    .foregroundStyle(ConstantsAppColors.warning)
                                    .monospacedDigit()
                            }
                        }
                    }
                }
            }
            .chartLegend(.hidden)
            .chartXScale(domain: xDomain)
            .chartYScale(domain: yDomain)
            .chartYAxis {
                AxisMarks(position: .trailing, values: yAxisValues(for: yDomain)) { value in
                    AxisGridLine()
                        .foregroundStyle(Color(.colorSecondary).opacity(0.55))
                    AxisValueLabel {
                        if let axisValue = value.as(Double.self) {
                            Text(GlucoseReportFormatting.number(axisValue, decimalPlaces: decimalPlaces))
                                .font(.system(size: ConstantsStatistics.chartAxisLabelFontSize + 1))
                                .foregroundStyle(Color(.colorSecondary))
                                .monospacedDigit()
                                .frame(width: ConstantsStatistics.chartYAxisLabelWidth, alignment: .leading)
                        }
                    }
                }
            }
            .chartXAxis {
                AxisMarks(values: xGridDates) { _ in
                    AxisGridLine()
                        .foregroundStyle(Color(.colorSecondary).opacity(0.55))
                }
            }
            // Fix the plot width itself so differing axis values cannot move the final time point.
            .chartPlotStyle { plotArea in
                plotArea.frame(width: max(0, geometry.size.width - ConstantsStatistics.chartTrailingAxisWidth))
            }
            .overlay {
                if trendPoints.isEmpty {
                    Text(Texts_Common.statisticsInsufficientData)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color(.colorSecondary))
                }
            }
        }
        .frame(height: 76)
    }

    private var hasTDDTrendData: Bool {
        trendPoints.contains { $0.averageTDDPerDay != nil }
    }

    private var hasCarbTrendData: Bool {
        trendPoints.contains { $0.averageCarbsPerDay != nil }
    }

    private var gmiDomain: ClosedRange<Double> {
        let values = trendPoints.map(\.gmiPercentage)
        guard let minimum = values.min(), let maximum = values.max() else { return 5 ... 10 }
        let lower = max(4, floor((minimum - 0.2) * 2) / 2)
        let upper = min(14, ceil((maximum + 0.2) * 2) / 2)
        return lower ... max(lower + 1, upper)
    }

    private func upperDomain(values: [Double], minimum: Double) -> ClosedRange<Double> {
        guard let maximum = values.max(), maximum > 0 else { return 0 ... minimum }
        return 0 ... max(minimum, ceil(maximum * 1.15 / 10) * 10)
    }

    private var orderedTrendPoints: [GlucoseReportTrendPoint] {
        trendPoints.sorted { $0.date < $1.date }
    }

    private var xDomain: ClosedRange<Date> {
        guard let firstDate = orderedTrendPoints.first?.date,
              let lastDate = orderedTrendPoints.last?.date,
              firstDate < lastDate else {
            let now = Date()
            return now.addingTimeInterval(-24 * 60 * 60) ... now
        }

        return firstDate ... lastDate
    }

    private var xGridDates: [Date] {
        let duration = xDomain.upperBound.timeIntervalSince(xDomain.lowerBound)
        return (0 ... 4).map { index in
            xDomain.lowerBound.addingTimeInterval(duration * Double(index) / 4)
        }
    }

    private func isTerminalTrendPoint(_ point: GlucoseReportTrendPoint) -> Bool {
        point.date == orderedTrendPoints.first?.date || point.date == orderedTrendPoints.last?.date
    }

    private func annotationAlignment(for point: GlucoseReportTrendPoint) -> Alignment {
        guard let firstDate = orderedTrendPoints.first?.date,
              let lastDate = orderedTrendPoints.last?.date else {
            return .center
        }

        if point.date == firstDate {
            return .leading
        }

        if point.date == lastDate {
            return .trailing
        }

        return .center
    }

    private func yAxisValues(for domain: ClosedRange<Double>) -> [Double] {
        let midpoint = (domain.lowerBound + domain.upperBound) / 2
        return [domain.lowerBound, midpoint, domain.upperBound]
    }

}

private struct StatisticsDailyPatternCard: View {
    let analytics: GlucoseReportAnalytics
    let period: GlucoseReportPeriod

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            StatisticsSection(title: Texts_Common.statisticsDailyPattern, detail: String(format: Texts_Common.statisticsAverageFormat, GlucoseReportFormatting.percentage(averageInRangePercentage))) {
                StatisticsCard {
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
                    AxisMarks(position: .leading, values: [0.0, 25.0, 50.0, 75.0, 100.0]) { value in
                        AxisGridLine()
                            .foregroundStyle(Color(.separator).opacity(0.45))
                        AxisValueLabel {
                            if let axisValue = value.as(Double.self) {
                                Text(axisValue.round(toDecimalPlaces: 0).stringWithoutTrailingZeroes)
                                    .font(.system(size: ConstantsStatistics.chartAxisLabelFontSize + 1))
                                    .foregroundStyle(Color(.colorSecondary))
                            }
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks(values: xAxisDates) { value in
                        AxisTick()
                            .foregroundStyle(Color(.colorSecondary))
                        AxisGridLine()
                            .foregroundStyle(Color(.separator).opacity(0.45))
                        AxisValueLabel {
                            if let date = value.as(Date.self) {
                                Text(axisLabel(for: date))
                                    .font(.system(size: ConstantsStatistics.chartAxisLabelFontSize + 1))
                                    .foregroundStyle(Color(.colorSecondary))
                            }
                        }
                    }
                }
                .frame(height: 175)
                }
            }

            Text(Texts_Common.statisticsDailyPatternFooter)
                .font(.caption2)
                .foregroundStyle(Color(.colorSecondary))
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

private struct StatisticsSection<Content: View>: View {
    let title: String
    let detail: String?
    @ViewBuilder let content: Content

    init(title: String, detail: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.detail = detail
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.system(size: ConstantsStatistics.chartAxisLabelFontSize + 5, weight: .semibold))
                    .foregroundStyle(Color(.colorPrimary))

                Spacer()

                if let detail {
                    Text(detail)
                        .font(.system(size: ConstantsStatistics.chartAxisLabelFontSize + 2, weight: .semibold))
                        .foregroundStyle(Color(.colorSecondary))
                        .monospacedDigit()
                }
            }
            .padding(.horizontal, 10)

            content
        }
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
