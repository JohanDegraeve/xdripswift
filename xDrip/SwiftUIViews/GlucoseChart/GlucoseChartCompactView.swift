//
//  GlucoseChartCompactView.swift
//  xdrip
//
//  Created by Paul Plant on 12/07/2026.
//  Copyright © 2023 Johan Degraeve. All rights reserved.
//

import Charts
import Foundation
import SwiftUI

/// Compact Swift Charts renderer for memory-restricted uses such as watch complications.
///
/// The original `GlucoseChartView` was expanded to support more chart rendering capabilities,
/// including treatments, basal rates, calibrations, extra glucose datasets and full chart state.
/// Those features are useful in the app and larger widgets, but they make the view too heavy for
/// memory-restricted places like watchOS complication extensions.
///
/// This view keeps the older lightweight chart behaviour needed by complications: glucose points,
/// BG range colours, x-axis gridlines, midnight gridlines, low/high threshold lines, urgent
/// threshold lines and the same chart type sizing hooks.
///
/// It should stay limited to glucose rendering only. If a future caller needs treatments, basal
/// rates, calibrations or other full-chart annotations, use `GlucoseChartView` instead.
struct GlucoseChartCompactView: View {

    private let bgReadingValues: [Double]
    private let bgReadingDates: [Date]
    private let chartType: GlucoseChartType
    private let isMgDl: Bool
    private let urgentLowLimitInMgDl: Double
    private let lowLimitInMgDl: Double
    private let highLimitInMgDl: Double
    private let urgentHighLimitInMgDl: Double
    private let liveActivityType: LiveActivityType
    private let hoursToShow: Double
    private let glucoseCircleDiameter: Double
    private let chartHeight: Double
    private let chartWidth: Double
    private let showHighContrast: Bool
    private let overrideChartHeightWasPassed: Bool
    private let visibleStartDate: Date
    private let visibleEndDate: Date

    private enum YAxisLabelStyle {
        case objective
        case secondaryObjective
    }

    init(glucoseChartType: GlucoseChartType, bgReadingValues: [Double]?, bgReadingDates: [Date]?, isMgDl: Bool, urgentLowLimitInMgDl: Double, lowLimitInMgDl: Double, highLimitInMgDl: Double, urgentHighLimitInMgDl: Double, liveActivityType: LiveActivityType?, hoursToShowScalingHours: Double?, glucoseCircleDiameterScalingHours: Double?, overrideChartHeight: Double?, overrideChartWidth: Double?, highContrast: Bool?) {

        self.chartType = glucoseChartType
        self.isMgDl = isMgDl
        self.urgentLowLimitInMgDl = urgentLowLimitInMgDl
        self.lowLimitInMgDl = lowLimitInMgDl
        self.highLimitInMgDl = highLimitInMgDl
        self.urgentHighLimitInMgDl = urgentHighLimitInMgDl
        self.liveActivityType = liveActivityType ?? .normal
        self.showHighContrast = highContrast ?? false
        self.overrideChartHeightWasPassed = overrideChartHeight != nil

        self.hoursToShow = hoursToShowScalingHours ?? chartType.hoursToShow(liveActivityType: self.liveActivityType)
        self.chartHeight = overrideChartHeight ?? chartType.viewSize(liveActivityType: self.liveActivityType).height
        self.chartWidth = overrideChartWidth ?? chartType.viewSize(liveActivityType: self.liveActivityType).width
        self.glucoseCircleDiameter = chartType.glucoseCircleDiameter(liveActivityType: self.liveActivityType) * ((glucoseCircleDiameterScalingHours ?? self.hoursToShow) / self.hoursToShow)

        let startDate = Date().addingTimeInterval(-self.hoursToShow * 60 * 60)
        let endDate = Date()
        self.visibleStartDate = startDate
        self.visibleEndDate = endDate

        var filteredBgReadingValues = [Double]()
        var filteredBgReadingDates = [Date]()

        if let bgReadingValues = bgReadingValues, let bgReadingDates = bgReadingDates {
            for (bgReadingValue, bgReadingDate) in zip(bgReadingValues, bgReadingDates) {
                if bgReadingDate >= startDate && bgReadingDate <= endDate {
                    filteredBgReadingValues.append(bgReadingValue)
                    filteredBgReadingDates.append(bgReadingDate)
                }
            }
        }

        self.bgReadingValues = filteredBgReadingValues
        self.bgReadingDates = filteredBgReadingDates
    }

    var body: some View {
        let allBgValues = bgReadingValues
        let minimumDomainValue = min((allBgValues.min() ?? 40), urgentLowLimitInMgDl)
        let maximumDomainValue = max((allBgValues.max() ?? urgentHighLimitInMgDl), urgentHighLimitInMgDl)
        let domain = (minimumDomainValue - ConstantsGlucoseChartSwiftUI.yAxisDomainPaddingInMgDl) ... (maximumDomainValue + ConstantsGlucoseChartSwiftUI.yAxisDomainPaddingInMgDl)
        let xAxisLabelEveryHours = xAxisLabelEveryHours()
        let xAxisLabelDates = xAxisLabelDates(everyHours: xAxisLabelEveryHours)
        let xAxisMidnightDates = xAxisMidnightDates()
        let xScaleDomain = visibleStartDate ... visibleEndDate.addingTimeInterval(5 * 60)
        let chartAspectRatio = chartType.aspectRatio()
        let chartPadding = chartType.padding()
        let yAxisLineSize = chartType.yAxisLineSize()

        Chart {
            if chartType != .miniChart {
                ForEach(xAxisMidnightDates, id: \.self) { xAxisMidnightDate in
                    RuleMark(x: .value("Midnight", xAxisMidnightDate))
                        .lineStyle(StrokeStyle(lineWidth: ConstantsGlucoseChartSwiftUI.xAxisMidnightGridLineSize))
                        .foregroundStyle(ConstantsGlucoseChartSwiftUI.xAxisMidnightGridLineColor)
                }
            }

            if chartType.yAxisShowUrgentLowHighLines(), domain.contains(urgentLowLimitInMgDl) {
                RuleMark(y: .value("", urgentLowLimitInMgDl))
                    .lineStyle(StrokeStyle(lineWidth: yAxisLineSize, dash: [2 * yAxisLineSize, 6 * yAxisLineSize]))
                    .foregroundStyle(chartType.yAxisUrgentLowHighLineColor())
            }

            if chartType.yAxisShowUrgentLowHighLines(), domain.contains(urgentHighLimitInMgDl) {
                RuleMark(y: .value("", urgentHighLimitInMgDl))
                    .lineStyle(StrokeStyle(lineWidth: yAxisLineSize, dash: [2 * yAxisLineSize, 6 * yAxisLineSize]))
                    .foregroundStyle(chartType.yAxisUrgentLowHighLineColor())
            }

            if domain.contains(lowLimitInMgDl) {
                RuleMark(y: .value("", lowLimitInMgDl))
                    .lineStyle(StrokeStyle(lineWidth: yAxisLineSize, dash: [4 * yAxisLineSize, 3 * yAxisLineSize]))
                    .foregroundStyle(chartType.yAxisLowHighLineColor())
            }

            if domain.contains(highLimitInMgDl) {
                RuleMark(y: .value("", highLimitInMgDl))
                    .lineStyle(StrokeStyle(lineWidth: yAxisLineSize, dash: [4 * yAxisLineSize, 3 * yAxisLineSize]))
                    .foregroundStyle(chartType.yAxisLowHighLineColor())
            }

            PointMark(x: .value("Time", visibleStartDate),
                      y: .value("BG", 100))
                .symbol(Circle())
                .symbolSize(glucoseCircleDiameter)
                .foregroundStyle(.clear)

            ForEach(bgReadingValues.indices, id: \.self) { index in
                PointMark(x: .value("Time", bgReadingDates[index]),
                          y: .value("BG", bgReadingValues[index]))
                    .symbol(Circle())
                    .symbolSize(glucosePointSymbolSize())
                    .foregroundStyle(bgColor(bgValueInMgDl: bgReadingValues[index]))
            }

            PointMark(x: .value("Time", visibleEndDate.addingTimeInterval(5 * 60)),
                      y: .value("BG", 100))
                .symbol(Circle())
                .symbolSize(glucoseCircleDiameter)
                .foregroundStyle(.clear)
        }
        .chartXAxis {
            AxisMarks(values: xAxisLabelDates) {
                if let value = $0.as(Date.self) {
                    if chartType.xAxisShowLabels() {
                        AxisValueLabel {
                            let shouldHideLabel = abs(visibleEndDate.distance(to: value)) < ConstantsGlucoseChartSwiftUI.xAxisLabelFirstClippingInMinutes || abs(visibleStartDate.distance(to: value)) < ConstantsGlucoseChartSwiftUI.xAxisLabelLastClippingInMinutes

                            Text(value.formatted(.dateTime.hour()))
                                .opacity(shouldHideLabel ? 0 : 1)
                                .foregroundStyle(ConstantsGlucoseChartSwiftUI.xAxisLabelColor)
                                .font(.footnote)
                                .monospacedDigit()
                                .frame(width: ConstantsGlucoseChartSwiftUI.xAxisLabelWidth, alignment: .center)
                                .offset(x: chartType.xAxisLabelOffsetX(), y: chartType.xAxisLabelOffsetY())
                        }
                    }

                    if chartType != .miniChart {
                        AxisGridLine()
                            .foregroundStyle(ConstantsGlucoseChartSwiftUI.xAxisGridLineColor)
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(values: [lowLimitInMgDl, highLimitInMgDl]) {
                if let value = $0.as(Double.self) {
                    AxisValueLabel {
                        yAxisLabel(value: value, style: .objective)
                    }
                }
            }

            if chartType.yAxisShowUrgentLowHighLines() {
                AxisMarks(values: [urgentLowLimitInMgDl, urgentHighLimitInMgDl]) {
                    if let value = $0.as(Double.self) {
                        AxisValueLabel {
                            yAxisLabel(value: value, style: .secondaryObjective)
                        }
                    }
                }
            }
        }
        .if(chartType.frame()) { view in
            view.frame(width: chartWidth, height: chartHeight)
        }
        .if(chartAspectRatio.enable && !overrideChartHeightWasPassed) { view in
            view.aspectRatio(chartAspectRatio.aspectRatio, contentMode: chartAspectRatio.contentMode)
        }
        .if(overrideChartHeightWasPassed) { view in
            view
                .frame(maxWidth: .infinity)
                .frame(height: chartHeight)
        }
        .if(chartPadding.enable) { view in
            view.padding(chartPadding.padding)
        }
        .chartYAxis(chartType.yAxisShowLabels())
        .chartXScale(domain: xScaleDomain)
        .chartYScale(domain: domain)
        .modifier(CompactChartBackgroundModifier(chartType: chartType))
        .clipShape(RoundedRectangle(cornerRadius: chartType.cornerRadius()))
    }

    private func bgColor(bgValueInMgDl: Double) -> Color {
        if chartType != .widgetSystemSmallStandBy || !showHighContrast {
            if bgValueInMgDl >= urgentHighLimitInMgDl || bgValueInMgDl <= urgentLowLimitInMgDl {
                return .red
            } else if bgValueInMgDl >= highLimitInMgDl || bgValueInMgDl <= lowLimitInMgDl {
                return .yellow
            } else {
                return .green
            }
        } else {
            return .white
        }
    }

    private func xAxisLabelEveryHours() -> Int {
        if chartType == .miniChart {
            return chartType.xAxisLabelEveryHours()
        }

        switch hoursToShow {
        case 24...:
            return 4
        case 12...:
            return 2
        case 8...:
            return 2
        default:
            return chartType.xAxisLabelEveryHours()
        }
    }

    private func xAxisLabelDates(everyHours: Int) -> [Date] {
        if chartType == .miniChart {
            return miniChartXAxisLabelDates()
        }

        let hourInterval = max(everyHours, 1)
        let calendar = Calendar.current
        let startOfVisibleHourComponents = calendar.dateComponents([.year, .month, .day, .hour], from: visibleStartDate)

        guard var date = calendar.date(from: startOfVisibleHourComponents) else { return [] }

        if date < visibleStartDate, let nextHourDate = calendar.date(byAdding: .hour, value: 1, to: date) {
            date = nextHourDate
        }

        var dates = [Date]()

        while date <= visibleEndDate {
            let hour = calendar.component(.hour, from: date)

            if hourInterval == 1 || hour % hourInterval == 0 {
                dates.append(date)
            }

            guard let nextDate = calendar.date(byAdding: .hour, value: 1, to: date), nextDate > date else {
                break
            }

            date = nextDate
        }

        return dates
    }

    private func miniChartXAxisLabelDates() -> [Date] {
        let calendar = Calendar.current
        var dates = [Date]()
        var date = calendar.startOfDay(for: visibleStartDate)

        while date <= visibleStartDate {
            guard let nextDate = calendar.date(byAdding: .day, value: 1, to: date), nextDate > date else {
                return dates
            }

            date = nextDate
        }

        while date < visibleEndDate {
            dates.append(date)

            guard let nextDate = calendar.date(byAdding: .day, value: 1, to: date), nextDate > date else {
                break
            }

            date = nextDate
        }

        return dates
    }

    private func xAxisMidnightDates() -> [Date] {
        let calendar = Calendar.current
        var dates = [Date]()
        var date = calendar.startOfDay(for: visibleStartDate)

        if date < visibleStartDate, let nextDate = calendar.date(byAdding: .day, value: 1, to: date) {
            date = nextDate
        }

        while date <= visibleEndDate {
            dates.append(date)

            guard let nextDate = calendar.date(byAdding: .day, value: 1, to: date), nextDate > date else {
                break
            }

            date = nextDate
        }

        return dates
    }

    @ViewBuilder private func yAxisLabel(value: Double, style: YAxisLabelStyle) -> some View {
        Text(value.mgDlToMmolAndToString(mgDl: isMgDl))
            .foregroundStyle(yAxisLabelColor(style: style))
            .font(.footnote)
            .monospacedDigit()
            .frame(width: ConstantsGlucoseChartSwiftUI.yAxisLabelWidth, alignment: .trailing)
            .offset(x: chartType.yAxisLabelOffsetX(), y: chartType.yAxisLabelOffsetY())
    }

    private func yAxisLabelColor(style: YAxisLabelStyle) -> Color {
        switch style {
        case .objective:
            return ConstantsGlucoseChartSwiftUI.yAxisLabelPrimaryColor
        case .secondaryObjective:
            return ConstantsGlucoseChartSwiftUI.yAxisLabelSecondaryColor
        }
    }

    private func glucosePointSymbolSize() -> Double {
        glucoseCircleDiameter * ConstantsGlucoseChartSwiftUI.glucosePointSymbolSizeMultiplier
    }
}

private struct CompactChartBackgroundModifier: ViewModifier {
    let chartType: GlucoseChartType

    func body(content: Content) -> some View {
        if #available(iOS 17.0, *) {
            content.containerBackground(.clear, for: .widget)
        } else {
            content.background(chartType.backgroundColor())
        }
    }
}
