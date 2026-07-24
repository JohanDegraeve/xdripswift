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
    @State private var selectedSection = StatisticsSection.summary
    private let statisticsManager: StatisticsManager

    init(statisticsManager: StatisticsManager) {
        self.statisticsManager = statisticsManager
        _viewModel = StateObject(wrappedValue: StatisticsViewModel(statisticsManager: statisticsManager))
    }

    var body: some View {
        Group {
            if selectedSection == .report {
                VStack(spacing: 12) {
                    sectionPicker
                        .padding(.horizontal, 16)
                    GenerateReportView(statisticsManager: statisticsManager, presentation: .embedded)
                }
                .padding(.top, 12)
            } else {
                ScrollView {
                    VStack(spacing: 12) {
                        sectionPicker
                        periodPicker

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
                    .padding(.vertical, 12)
                }
            }
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle(Texts_Common.statisticsTitle)
        .task {
            viewModel.load()
        }
    }

    @ViewBuilder private func content(for analytics: GlucoseReportAnalytics) -> some View {
        switch selectedSection {
        case .summary:
            VStack(spacing: 10) {
                StatisticsSummaryView(analytics: analytics)
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
            }
        case .agp:
            StatisticsAGPCard(analytics: analytics)
            StatisticsTrendCard(trendPoints: analytics.trendPoints)
        case .daily:
            VStack(spacing: 10) {
                StatisticsDailyPatternCard(analytics: analytics, period: viewModel.selectedPeriod)
                StatisticsDailyHighlightsCard(analytics: analytics, period: viewModel.selectedPeriod)
            }
        case .report:
            EmptyView()
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
        .padding(.top, 12)
    }

    private var sectionPicker: some View {
        StatisticsSelectorControl(
            items: StatisticsSection.allCases,
            selection: $selectedSection,
            title: { $0.title },
            systemImage: { $0.systemImage },
            textSize: 16,
            selectedTextWeight: .bold,
            unselectedTextWeight: .semibold,
            selectedColor: { $0 == .report ? Color(.systemYellow).opacity(0.95) : Color(.colorPrimary) },
            unselectedColor: { $0 == .report ? Color(.systemYellow).opacity(0.58) : Color(.colorTertiary) },
            selectedBackgroundColor: { $0 == .report ? Color(.systemYellow).opacity(0.24) : Color.clear },
            unselectedBackgroundColor: { $0 == .report ? Color(.systemYellow).opacity(0.08) : Color.clear }
        )
    }
}

private enum StatisticsSection: String, CaseIterable, Identifiable {
    case summary
    case agp
    case daily
    case report

    var id: String { rawValue }

    var title: String {
        switch self {
        case .summary:
            return Texts_Common.statisticsSummary
        case .agp:
            return Texts_Common.statisticsTrends
        case .daily:
            return Texts_Common.statisticsDaily
        case .report:
            return Texts_Common.statisticsReport
        }
    }

    var systemImage: String? {
        switch self {
        case .report:
            return "chart.line.text.clipboard"
        default:
            return nil
        }
    }
}

private enum StatisticsSelectorLayout {
    static let controlHeight: CGFloat = 40
}

private struct StatisticsSelectorControl<Item: Identifiable & Hashable>: View {
    let items: [Item]
    @Binding var selection: Item
    let title: (Item) -> String
    var systemImage: (Item) -> String? = { _ in nil }
    var textSize: CGFloat = 14
    var selectedTextWeight: Font.Weight = .semibold
    var unselectedTextWeight: Font.Weight = .regular
    var selectedColor: (Item) -> Color = { _ in Color(.colorPrimary) }
    var unselectedColor: (Item) -> Color = { _ in Color(.colorTertiary) }
    var selectedBackgroundColor: (Item) -> Color = { _ in Color.clear }
    var unselectedBackgroundColor: (Item) -> Color = { _ in Color.clear }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(items) { item in
                StatisticsSelectorButton(
                    title: title(item),
                    systemImage: systemImage(item),
                    isSelected: selection == item,
                    textSize: textSize,
                    selectedTextWeight: selectedTextWeight,
                    unselectedTextWeight: unselectedTextWeight,
                    selectedColor: selectedColor(item),
                    unselectedColor: unselectedColor(item),
                    selectedBackgroundColor: selectedBackgroundColor(item),
                    unselectedBackgroundColor: unselectedBackgroundColor(item)
                ) {
                    selection = item
                }
            }
        }
        .frame(height: StatisticsSelectorLayout.controlHeight)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct StatisticsSelectorButton: View {
    let title: String
    var systemImage: String?
    let isSelected: Bool
    let textSize: CGFloat
    let selectedTextWeight: Font.Weight
    let unselectedTextWeight: Font.Weight
    let selectedColor: Color
    let unselectedColor: Color
    let selectedBackgroundColor: Color
    let unselectedBackgroundColor: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: max(10, textSize - 4), weight: isSelected ? selectedTextWeight : unselectedTextWeight))
                }

                Text(title)
                    .font(.system(size: textSize, weight: isSelected ? selectedTextWeight : unselectedTextWeight))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .foregroundStyle(isSelected ? selectedColor : unselectedColor)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                isSelected ? selectedBackgroundColor : unselectedBackgroundColor
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private struct StatisticsSummaryView: View {
    let analytics: GlucoseReportAnalytics

    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 7) {
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
            let height = geometry.size.height
            let targetX = geometry.size.width * gauge.targetFraction

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color(.tertiarySystemFill))

                Capsule()
                    .fill(gauge.color.opacity(0.58))
                    .frame(width: max(height, geometry.size.width * gauge.valueFraction))

                Rectangle()
                    .fill(Color(.colorPrimary).opacity(0.62))
                    .frame(width: 1.2, height: height + 3)
                    .offset(x: min(max(targetX - 0.75, 0), geometry.size.width - 1.5), y: -2)
            }
        }
        .frame(height: 3)
        .padding(.top, 2)
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
        Chart {
            RectangleMark(
                xStart: .value("Start", 0),
                xEnd: .value("End", 1440),
                yStart: .value("Low target", converted(GlucoseReportClinicalConstants.timeInRangeLowMgDl)),
                yEnd: .value("High target", converted(GlucoseReportClinicalConstants.timeInRangeHighMgDl))
            )
            .foregroundStyle(ConstantsAppColors.statisticsInRange.opacity(0.07))

            ForEach(chartPointsForDisplay) { point in
                AreaMark(
                    x: .value("Time", point.minuteOfDay),
                    yStart: .value("P5", converted(point.p5MgDl)),
                    yEnd: .value("P95", converted(point.p95MgDl)),
                    series: .value("Series", "5-95%")
                )
                .foregroundStyle(GlucoseReportColors.agpOuterBand.opacity(0.7))
            }

            ForEach(chartPointsForDisplay) { point in
                AreaMark(
                    x: .value("Time", point.minuteOfDay),
                    yStart: .value("P25", converted(point.p25MgDl)),
                    yEnd: .value("P75", converted(point.p75MgDl)),
                    series: .value("Series", "25-75%")
                )
                .foregroundStyle(Color(red: 0.42, green: 0.66, blue: 0.86).opacity(0.48))
            }

            ForEach(chartPointsForDisplay) { point in
                LineMark(
                    x: .value("Time", point.minuteOfDay),
                    y: .value("Median", converted(point.medianMgDl)),
                    series: .value("Series", "Median")
                )
                .lineStyle(StrokeStyle(lineWidth: 2.2))
                .foregroundStyle(Color.cyan)
            }

            RuleMark(y: .value("Low target", converted(GlucoseReportClinicalConstants.timeInRangeLowMgDl)))
                .lineStyle(StrokeStyle(lineWidth: 1))
                .foregroundStyle(ConstantsAppColors.statisticsInRange.opacity(0.32))

            RuleMark(y: .value("High target", converted(GlucoseReportClinicalConstants.timeInRangeHighMgDl)))
                .lineStyle(StrokeStyle(lineWidth: 1))
                .foregroundStyle(ConstantsAppColors.statisticsInRange.opacity(0.32))
        }
        .chartLegend(.hidden)
        .chartXScale(domain: 0 ... 1440)
        .chartYScale(domain: converted(40) ... converted(dynamicUpperYMgDl))
        .chartXAxis {
            AxisMarks(values: [0, 360, 720, 1080, 1440]) { value in
                AxisGridLine()
                    .foregroundStyle(ConstantsGlucoseChartSwiftUI.xAxisGridLineColor)
                AxisValueLabel {
                    if let minute = value.as(Int.self) {
                        Text(timeLabel(minute: minute))
                            .font(.caption2)
                            .foregroundStyle(Color(.colorTertiary))
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .trailing, values: yAxisContextValues) { value in
                AxisGridLine()
                    .foregroundStyle(ConstantsGlucoseChartSwiftUI.yAxisContextGridLineColor)
                AxisValueLabel {
                    if let glucose = value.as(Double.self) {
                        yAxisLabel(for: glucose, isObjective: false)
                    }
                }
            }

            AxisMarks(position: .trailing, values: [converted(GlucoseReportClinicalConstants.timeInRangeLowMgDl), converted(GlucoseReportClinicalConstants.timeInRangeHighMgDl)]) { value in
                AxisGridLine()
                    .foregroundStyle(ConstantsGlucoseChartSwiftUI.yAxisLowHighLineColor)
                AxisValueLabel {
                    if let glucose = value.as(Double.self) {
                        yAxisLabel(for: glucose, isObjective: true)
                    }
                }
            }
        }
        .frame(height: 165)
        .chartPlotStyle { plotArea in
            plotArea
                .border(Color(.separator).opacity(0.85), width: ConstantsGlucoseChartSwiftUI.chartPlotBorderLineWidth)
        }
        .overlay {
            if points.isEmpty {
                Text(Texts_Common.statisticsInsufficientAGPData)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color(.colorSecondary))
            }
        }
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

    private var yAxisContextValues: [Double] {
        [40, 250, 300, 350, 400, 450]
            .filter { $0 <= dynamicUpperYMgDl }
            .map(converted)
    }

    private func converted(_ valueMgDl: Double) -> Double {
        usesMgDl ? valueMgDl : valueMgDl * ConstantsBloodGlucose.mgDlToMmoll
    }

    private func yAxisLabel(for convertedValue: Double, isObjective: Bool) -> some View {
        Text(yAxisLabelText(for: convertedValue))
            .foregroundStyle(isObjective ? ConstantsGlucoseChartSwiftUI.yAxisMainChartObjectiveLabelColor : ConstantsGlucoseChartSwiftUI.yAxisMainChartDimmedLabelColor)
            .font(isObjective ? .system(size: 11, weight: .bold) : .system(size: 10))
            .monospacedDigit()
    }

    private func yAxisLabelText(for convertedValue: Double) -> String {
        usesMgDl ? "\(Int(convertedValue.rounded()))" : convertedValue.formatted(.number.precision(.fractionLength(1)))
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
                                .font(.system(size: 10))
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
                                .font(.system(size: 9))
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

    private var validSummaries: [GlucoseReportDailySummary] {
        analytics.dailySummaries.filter { $0.sampleCount > 0 }
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

private struct StatisticsDailyHighlightsCard: View {
    let analytics: GlucoseReportAnalytics
    let period: GlucoseReportPeriod

    var body: some View {
        StatisticsCard(title: Texts_Common.statisticsDailySummary) {
            HStack(spacing: 8) {
                contextTile(title: Texts_Common.statisticsBestDay, value: bestDayText)
                contextTile(title: Texts_Common.statisticsMostLow, value: mostLowDayText)
                contextTile(title: Texts_Common.statisticsMostHigh, value: mostHighDayText)
            }
        }
    }

    private var bestDayText: String {
        guard let summary = validSummaries.max(by: { $0.targetPercentage < $1.targetPercentage }) else { return "-" }
        return "\(axisLabel(for: summary.date)) · \(GlucoseReportFormatting.percentage(summary.targetPercentage))"
    }

    private var mostLowDayText: String {
        guard let summary = validSummaries.max(by: { $0.lowPercentage < $1.lowPercentage }) else { return "-" }
        return "\(axisLabel(for: summary.date)) · \(GlucoseReportFormatting.percentage(summary.lowPercentage))"
    }

    private var mostHighDayText: String {
        guard let summary = validSummaries.max(by: { $0.highPercentage < $1.highPercentage }) else { return "-" }
        return "\(axisLabel(for: summary.date)) · \(GlucoseReportFormatting.percentage(summary.highPercentage))"
    }

    private var validSummaries: [GlucoseReportDailySummary] {
        analytics.dailySummaries.filter { $0.sampleCount > 0 }
    }

    private func contextTile(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title.uppercased())
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Color(.colorSecondary))
            Text(value)
                .font(.caption.weight(.bold))
                .foregroundStyle(Color(.colorPrimary))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 8))
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
