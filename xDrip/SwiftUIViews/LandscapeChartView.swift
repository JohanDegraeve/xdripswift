//
//  LandscapeChartView.swift
//  xdrip
//
//  Created by Paul Plant on 16/9/21.
//  Copyright © 2021 Johan Degraeve. All rights reserved.
//

import SwiftUI

// MARK: - State Model

/// Owns the selected day, chart cache and statistics used by the landscape Home presentation.
///
/// The same chart and statistics managers remain alive while the user moves between days, avoiding
/// a new data stack for each SwiftUI body update.
final class LandscapeChartStateModel: ObservableObject {

    // MARK: - TIR Data Structure

    /// Time-in-range percentages calculated for one calendar day.
    struct DailyTIRData: Identifiable {
        let date: Date
        let lowPercentage: Double
        let inRangePercentage: Double
        let highPercentage: Double

        var id: Date {
            date
        }
    }

    // MARK: - Published State

    @Published var selectedDate = Date().toMidnight()
    @Published var dailyTIRData = [DailyTIRData]()
    @Published var statistics = RootHomeStatisticsState()
    @Published var chartState = GlucoseChartState.empty(startDate: Date().toMidnight(), endDate: Date().toMidnight().addingTimeInterval(.hours(24) - 1))
    @Published var isLoadingChart = false
    @Published var isLoadingStatistics = false
    @Published var showTreatments = UserDefaults.standard.showTreatmentsOnLandscapeChart
    @Published var showStatistics = UserDefaults.standard.showStatisticsOnLandscapeChart

    // MARK: - Private Properties

    private var tirWindowStartDate = Date().toMidnight()
    private var chartStateManager: GlucoseChartStateManager?
    private var statisticsManager: StatisticsManager?

    private let dateFormatter: DateFormatter = {
        let dateFormatter = DateFormatter()
        dateFormatter.setLocalizedDateFormatFromTemplate(ConstantsGlucoseChart.dateFormatLandscapeChart)

        return dateFormatter
    }()

    // MARK: - Initialisation

    init() {}

    init(coreDataManager: CoreDataManager, nightscoutSyncManager: NightscoutSyncManager) {
        configure(coreDataManager: coreDataManager, nightscoutSyncManager: nightscoutSyncManager)
    }

    // MARK: - Configuration

    /// Creates the managers once and loads the current landscape presentation.
    func configure(coreDataManager: CoreDataManager, nightscoutSyncManager: NightscoutSyncManager) {
        guard chartStateManager == nil else { return }

        chartStateManager = GlucoseChartStateManager(coreDataManager: coreDataManager, nightscoutSyncManager: nightscoutSyncManager)
        statisticsManager = StatisticsManager(coreDataManager: coreDataManager)

        refreshForDisplay()
    }

    /// Resets the selected day to today when the landscape screen becomes visible.
    func refreshForDisplay() {
        guard chartStateManager != nil, statisticsManager != nil else { return }

        selectedDate = Date().toMidnight()
        tirWindowStartDate = selectedDate.addingTimeInterval(Double(-(ConstantsStatistics.numberOfDaysForTIRChartLandscapeView - 1)) * .hours(24))

        calculateDailyTIRData()
        refreshSelectedDay(forceReset: true)
    }

    // MARK: - Derived State

    var selectedDateText: String {
        dateFormatter.string(from: selectedDate)
    }

    var canMoveForward: Bool {
        !Calendar.current.isDateInToday(selectedDate)
    }

    var yAxisMinimumForTIR: Double {
        let tirValues = dailyTIRData.map(\.inRangePercentage).filter { $0 > 0 }
        let tirValuesMin = min(ConstantsStatistics.tirChartYAxisMinimumAxisValue, tirValues.min() ?? 0)

        return UserDefaults.standard.tirChartHasDynamicYAxis ? max(0.0, tirValuesMin - ConstantsStatistics.tirChartYAxisMinimumOffset) : 0
    }

    // MARK: - User Actions

    func setShowTreatments(_ value: Bool) {
        showTreatments = value
        UserDefaults.standard.showTreatmentsOnLandscapeChart = value
        refreshChart(forceReset: false)
    }

    func setShowStatistics(_ value: Bool) {
        showStatistics = value
        UserDefaults.standard.showStatisticsOnLandscapeChart = value
    }

    func moveBackOneDay() {
        if Calendar.current.isDate(selectedDate, inSameDayAs: tirWindowStartDate) {
            tirWindowStartDate = tirWindowStartDate.addingTimeInterval(-.hours(24))
            selectedDate = tirWindowStartDate
            calculateDailyTIRData()
        } else {
            selectedDate = selectedDate.addingTimeInterval(-.hours(24)).toMidnight()
        }

        UISelectionFeedbackGenerator().selectionChanged()
        refreshSelectedDay(forceReset: false)
    }

    func moveForwardOneDay() {
        guard !Calendar.current.isDateInToday(selectedDate) else { return }

        if Calendar.current.isDate(selectedDate, inSameDayAs: tirWindowEndDate) {
            tirWindowStartDate = tirWindowStartDate.addingTimeInterval(.hours(24)).toMidnight()
            selectedDate = selectedDate.addingTimeInterval(.hours(24)).toMidnight()
            calculateDailyTIRData()
        } else {
            selectedDate = selectedDate.addingTimeInterval(.hours(24)).toMidnight()
        }

        UISelectionFeedbackGenerator().selectionChanged()
        refreshSelectedDay(forceReset: false)
    }

    func selectToday() {
        selectedDate = Date().toMidnight()
        tirWindowStartDate = selectedDate.addingTimeInterval(Double(-(ConstantsStatistics.numberOfDaysForTIRChartLandscapeView - 1)) * .hours(24))

        UISelectionFeedbackGenerator().selectionChanged()
        calculateDailyTIRData()
        refreshSelectedDay(forceReset: false)
    }

    func selectTIRDate(_ date: Date) {
        guard !Calendar.current.isDate(date, inSameDayAs: selectedDate) else { return }

        selectedDate = date.toMidnight()
        UISelectionFeedbackGenerator().selectionChanged()
        refreshSelectedDay(forceReset: false)
    }

    func toggleTIRYAxisMode() {
        UserDefaults.standard.tirChartHasDynamicYAxis.toggle()
        objectWillChange.send()
    }

    // MARK: - Refresh

    private func refreshSelectedDay(forceReset: Bool) {
        refreshChart(forceReset: forceReset)
        refreshStatistics()
    }

    private func refreshChart(forceReset: Bool) {
        guard let chartStateManager = chartStateManager else { return }

        let startOfDay = selectedDate
        let endOfDay = startOfDay.addingTimeInterval(.hours(24) - 1)

        isLoadingChart = true
        chartStateManager.updateState(
            endDate: endOfDay,
            startDate: startOfDay,
            forceReset: forceReset,
            showTreatments: showTreatments
        ) { [weak self] chartState in
            self?.chartState = chartState
            self?.isLoadingChart = false
        }
    }

    private func refreshStatistics() {
        guard let statisticsManager = statisticsManager else { return }

        let startOfDay = selectedDate
        let endOfDay = startOfDay.addingTimeInterval(.hours(24) - 1)

        isLoadingStatistics = true
        statisticsManager.calculateStatistics(fromDate: startOfDay, toDate: endOfDay) { [weak self] statistics in
            self?.statistics = Self.makeStatisticsState(from: statistics)
            self?.isLoadingStatistics = false
        }
    }

    private func calculateDailyTIRData() {
        guard let statisticsManager = statisticsManager else { return }

        let startDayForWindow = tirWindowStartDate
        let endOfWindow = startDayForWindow.addingTimeInterval(Double(ConstantsStatistics.numberOfDaysForTIRChartLandscapeView) * .hours(24) - 1)

        statisticsManager.calculateDailyTIR(fromDate: startDayForWindow, toDate: endOfWindow) { [weak self] statisticsByDay in
            guard let self = self else { return }

            var values = [DailyTIRData]()

            for dayIndex in 0 ..< ConstantsStatistics.numberOfDaysForTIRChartLandscapeView {
                let date = Calendar.current.startOfDay(for: startDayForWindow.addingTimeInterval(Double(dayIndex) * .hours(24)))
                let statistics = statisticsByDay[date] ?? StatisticsManager.Statistics(
                    lowStatisticValue: 0,
                    highStatisticValue: 0,
                    inRangeStatisticValue: 0,
                    averageStatisticValue: 0,
                    a1CStatisticValue: 0,
                    cVStatisticValue: 0,
                    lowLimitForTIR: UserDefaults.standard.timeInRangeType.lowerLimit,
                    highLimitForTIR: UserDefaults.standard.timeInRangeType.higherLimit,
                    numberOfDaysUsed: 0
                )

                values.append(
                    DailyTIRData(
                        date: date,
                        lowPercentage: statistics.lowStatisticValue,
                        inRangePercentage: statistics.inRangeStatisticValue,
                        highPercentage: statistics.highStatisticValue
                    )
                )
            }

            self.dailyTIRData = values
        }
    }

    // MARK: - Formatting

    private var tirWindowEndDate: Date {
        tirWindowStartDate.addingTimeInterval(Double(ConstantsStatistics.numberOfDaysForTIRChartLandscapeView) * .hours(24) - 1)
    }

    private static func makeStatisticsState(from statistics: StatisticsManager.Statistics) -> RootHomeStatisticsState {
        let isMgDl = UserDefaults.standard.bloodGlucoseUnitIsMgDl
        let lowLimitText = "(<\(formattedLimit(statistics.lowLimitForTIR, isMgDl: isMgDl)))"
        let highLimitText = "(>\(formattedLimit(statistics.highLimitForTIR, isMgDl: isMgDl)))"
        let hasData = statistics.lowStatisticValue.value != 0 || statistics.inRangeStatisticValue.value != 0 || statistics.highStatisticValue.value != 0

        guard hasData else {
            return RootHomeStatisticsState(
                low: RootHomeMetricState(title: Texts_Common.lowStatistics, value: "-%", valueColor: ConstantsAppColors.statisticsLow),
                inRange: RootHomeMetricState(title: UserDefaults.standard.timeInRangeType.title, value: "-%", valueColor: ConstantsAppColors.statisticsInRange),
                high: RootHomeMetricState(title: Texts_Common.highStatistics, value: "-%", valueColor: ConstantsAppColors.statisticsHigh),
                average: RootHomeMetricState(title: Texts_Common.averageStatistics, value: isMgDl ? "- mg/dl" : "- mmol/l", valueColor: ConstantsAppColors.tertiaryText),
                a1c: RootHomeMetricState(title: Texts_Common.a1cStatistics, value: UserDefaults.standard.useIFCCA1C ? "- mmol" : "-%", valueColor: ConstantsAppColors.tertiaryText),
                cv: RootHomeMetricState(title: Texts_Common.cvStatistics, value: "-%", valueColor: ConstantsAppColors.tertiaryText),
                lowLimitText: lowLimitText,
                highLimitText: highLimitText,
                timePeriodText: Texts_Common.today,
                showsActivityIndicator: false
            )
        }

        let averageValue = isMgDl
            ? "\(Int(statistics.averageStatisticValue.round(toDecimalPlaces: 0))) mg/dl"
            : "\(statistics.averageStatisticValue.round(toDecimalPlaces: 1)) mmol/l"
        let a1cValue = UserDefaults.standard.useIFCCA1C
            ? "\(Int(statistics.a1CStatisticValue.round(toDecimalPlaces: 0))) mmol"
            : "\(statistics.a1CStatisticValue.round(toDecimalPlaces: 1))%"

        return RootHomeStatisticsState(
            low: RootHomeMetricState(title: Texts_Common.lowStatistics, value: "\(Int(statistics.lowStatisticValue.round(toDecimalPlaces: 0)))%", valueColor: ConstantsAppColors.statisticsLow),
            inRange: RootHomeMetricState(title: UserDefaults.standard.timeInRangeType.title, value: "\(Int(statistics.inRangeStatisticValue.round(toDecimalPlaces: 0)))%", valueColor: ConstantsAppColors.statisticsInRange),
            high: RootHomeMetricState(title: Texts_Common.highStatistics, value: "\(Int(statistics.highStatisticValue.round(toDecimalPlaces: 0)))%", valueColor: ConstantsAppColors.statisticsHigh),
            average: RootHomeMetricState(title: Texts_Common.averageStatistics, value: averageValue),
            a1c: RootHomeMetricState(title: Texts_Common.a1cStatistics, value: a1cValue),
            cv: RootHomeMetricState(title: Texts_Common.cvStatistics, value: "\(Int(statistics.cVStatisticValue.round(toDecimalPlaces: 0)))%"),
            lowLimitText: lowLimitText,
            highLimitText: highLimitText,
            timePeriodText: Texts_Common.today,
            showsActivityIndicator: false
        )
    }

    private static func formattedLimit(_ value: Double, isMgDl: Bool) -> String {
        isMgDl ? Int(value).description : value.round(toDecimalPlaces: 1).description
    }

}

// MARK: - Main View

/// Full-screen landscape Home view containing daily navigation, statistics and the glucose chart.
struct LandscapeChartView: View {

    @ObservedObject var stateModel: LandscapeChartStateModel

    private enum Layout {
        static let screenPadding: CGFloat = 10
        static let spacing: CGFloat = 10
        static let toolbarHeight: CGFloat = 40
        static let statisticsWidth: CGFloat = 190
        static let tirChartHeight: CGFloat = 110
    }

    var body: some View {
        VStack(spacing: Layout.spacing) {
            toolbar

            HStack(spacing: Layout.spacing) {
                if stateModel.showStatistics {
                    LandscapeStatisticsPanel(state: stateModel.statistics, isLoading: stateModel.isLoadingStatistics)
                        .frame(width: Layout.statisticsWidth)
                }

                VStack(spacing: Layout.spacing) {
                    if stateModel.showStatistics {
                        LandscapeTIRChartView(
                            values: stateModel.dailyTIRData,
                            selectedDate: stateModel.selectedDate,
                            yAxisMinimum: stateModel.yAxisMinimumForTIR,
                            selectDate: stateModel.selectTIRDate
                        )
                        .frame(height: Layout.tirChartHeight)
                        .onTapGesture(count: 3, perform: stateModel.toggleTIRYAxisMode)
                    }

                    LandscapeGlucoseChartView(
                        chartState: stateModel.chartState,
                        isLoading: stateModel.isLoadingChart,
                        moveBackOneDay: stateModel.moveBackOneDay,
                        moveForwardOneDay: stateModel.moveForwardOneDay,
                        selectToday: stateModel.selectToday
                    )
                    .frame(maxHeight: .infinity)
                    .layoutPriority(1)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(Layout.screenPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ConstantsAppColors.background)
    }

    private var toolbar: some View {
        HStack(spacing: 14) {
            Text(stateModel.selectedDateText)
                .font(.title3)
                .foregroundStyle(ConstantsAppColors.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .frame(maxWidth: .infinity, alignment: .leading)

            Toggle(Texts_SettingsView.sectionTitleTreatments, isOn: Binding(get: {
                stateModel.showTreatments
            }, set: {
                stateModel.setShowTreatments($0)
            }))
            .toggleStyle(.switch)
            .font(.callout)
            .foregroundStyle(ConstantsAppColors.primaryText)

            Toggle(Texts_SettingsView.sectionTitleStatistics, isOn: Binding(get: {
                stateModel.showStatistics
            }, set: {
                stateModel.setShowStatistics($0)
            }))
            .toggleStyle(.switch)
            .font(.callout)
            .foregroundStyle(ConstantsAppColors.primaryText)

            HStack(spacing: 8) {
                Button(action: stateModel.moveBackOneDay) {
                    Image(systemName: "chevron.backward")
                        .font(.headline)
                }

                Button(action: stateModel.moveForwardOneDay) {
                    Image(systemName: "chevron.forward")
                        .font(.headline)
                }
                .disabled(!stateModel.canMoveForward)
            }
            .buttonStyle(.bordered)
        }
        .frame(height: Layout.toolbarHeight)
    }

}

// MARK: - Glucose Chart

/// Renders the selected day using the shared SwiftUI glucose chart.
private struct LandscapeGlucoseChartView: View {

    let chartState: GlucoseChartState
    let isLoading: Bool
    let moveBackOneDay: () -> Void
    let moveForwardOneDay: () -> Void
    let selectToday: () -> Void

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topTrailing) {
                GlucoseChartView(
                    glucoseChartType: .widgetSystemLarge,
                    bgReadingValues: nil,
                    bgReadingDates: nil,
                    isMgDl: UserDefaults.standard.bloodGlucoseUnitIsMgDl,
                    urgentLowLimitInMgDl: UserDefaults.standard.urgentLowMarkValue,
                    lowLimitInMgDl: UserDefaults.standard.lowMarkValue,
                    highLimitInMgDl: UserDefaults.standard.highMarkValue,
                    urgentHighLimitInMgDl: UserDefaults.standard.urgentHighMarkValue,
                    liveActivityType: nil,
                    hoursToShowScalingHours: 24,
                    glucoseCircleDiameterScalingHours: 6,
                    overrideChartHeight: geometry.size.height,
                    overrideChartWidth: geometry.size.width,
                    highContrast: nil,
                    chartState: chartState
                )
                .mainChartYAxisContext()
                .transaction { transaction in
                    transaction.animation = nil
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 30)
                        .onEnded { value in
                            guard abs(value.translation.width) > abs(value.translation.height) else { return }

                            if value.translation.width < 0 {
                                moveForwardOneDay()
                            } else {
                                moveBackOneDay()
                            }
                        }
                )
                .onTapGesture(count: 2, perform: selectToday)
                .clipped()

                if isLoading {
                    ProgressView()
                        .padding(8)
                }
            }
        }
    }

}

// MARK: - Statistics

/// Selected-day statistics displayed beside the chart when enabled.
private struct LandscapeStatisticsPanel: View {

    let state: RootHomeStatisticsState
    let isLoading: Bool

    var body: some View {
        VStack(spacing: 16) {
            VStack(spacing: 7) {
                LandscapeStatisticRow(metric: state.low, limitText: state.lowLimitText)
                LandscapeStatisticRow(metric: state.inRange)
                LandscapeStatisticRow(metric: state.high, limitText: state.highLimitText)
            }

            Spacer(minLength: 0)

            ZStack {
                LandscapePieChartView(
                    low: state.low.percentValue,
                    inRange: state.inRange.percentValue,
                    high: state.high.percentValue
                )

                if isLoading {
                    ProgressView()
                        .tint(ConstantsAppColors.primaryText)
                }
            }
            .frame(maxHeight: .infinity)

            Spacer(minLength: 0)

            VStack(spacing: 7) {
                LandscapeStatisticRow(metric: state.average)
                LandscapeStatisticRow(metric: state.a1c)
                LandscapeStatisticRow(metric: state.cv)
            }
        }
        .padding(.horizontal, 15)
        .padding(.vertical, 12)
        .background(ConstantsAppColors.homePanelBackground)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .transaction { transaction in
            transaction.animation = nil
        }
    }

}

/// One title and value pair in the landscape statistics panel.
private struct LandscapeStatisticRow: View {

    let metric: RootHomeMetricState
    var limitText = ""

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            HStack(spacing: 4) {
                Text(metric.title)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(ConstantsAppColors.primaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                if !limitText.isEmpty {
                    Text(limitText)
                        .font(.system(size: 15))
                        .foregroundStyle(ConstantsAppColors.secondaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }

            Spacer(minLength: 4)

            Text(metric.value)
                .font(.system(size: 15))
                .foregroundStyle(metric.valueColor)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
    }

}

/// Selected-day low, in-range and high percentages as a pie chart.
private struct LandscapePieChartView: View {

    let low: Double
    let inRange: Double
    let high: Double

    var body: some View {
        ZStack {
            if total > 0 {
                LandscapePieSlice(startAngle: .degrees(referenceAngle), endAngle: .degrees(referenceAngle + inRangeAngle))
                    .fill(ConstantsAppColors.statisticsInRange)

                LandscapePieSlice(startAngle: .degrees(referenceAngle + inRangeAngle), endAngle: .degrees(referenceAngle + inRangeAngle + lowAngle))
                    .fill(ConstantsAppColors.statisticsLow)

                LandscapePieSlice(startAngle: .degrees(referenceAngle + inRangeAngle + lowAngle), endAngle: .degrees(referenceAngle + 360))
                    .fill(ConstantsAppColors.statisticsHigh)
            } else {
                Circle()
                    .fill(ConstantsAppColors.tertiaryText)
            }
        }
        .frame(width: 80, height: 80)
    }

    private var total: Double {
        low + inRange + high
    }

    private var inRangeAngle: Double {
        360 * inRange / total
    }

    private var lowAngle: Double {
        360 * low / total
    }

    private var referenceAngle: Double {
        90 - (inRangeAngle / 2)
    }

}

/// One percentage slice in the landscape time-in-range pie chart.
private struct LandscapePieSlice: Shape {

    let startAngle: Angle
    let endAngle: Angle

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2

        path.move(to: center)
        path.addArc(center: center, radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: false)
        path.closeSubpath()

        return path
    }

}

// MARK: - TIR Chart

/// Multi-day time-in-range bar chart used to select the day shown below.
private struct LandscapeTIRChartView: View {

    let values: [LandscapeChartStateModel.DailyTIRData]
    let selectedDate: Date
    let yAxisMinimum: Double
    let selectDate: (Date) -> Void

    private let yAxisMaximum = 100.0
    private let referencePercents = [0.0, 25.0, 50.0, 75.0, 100.0]

    var body: some View {
        GeometryReader { geometry in
            let layout = makeLayout(size: geometry.size)

            HStack(spacing: layout.axisLabelGap) {
                plotArea(layout: layout)
                    .frame(width: layout.chartWidth, height: layout.totalHeight, alignment: .topLeading)

                yAxisLabels(layout: layout)
                    .frame(width: layout.yAxisLabelWidth, height: layout.totalHeight, alignment: .topLeading)
            }
            .padding(.horizontal, layout.horizontalPadding)
            .frame(width: geometry.size.width, height: geometry.size.height)
            .background(ConstantsAppColors.homePanelBackground)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .clipped()
        }
        .transaction { transaction in
            transaction.animation = nil
        }
    }

    private func plotArea(layout: TIRLayout) -> some View {
        ZStack(alignment: .topLeading) {
            ForEach(referencePercents.filter { $0 >= yAxisMinimum }, id: \.self) { percent in
                Rectangle()
                    .fill(ConstantsAppColors.secondaryText.opacity(0.4))
                    .frame(width: layout.chartWidth, height: 1)
                    .offset(y: yPosition(percent: percent, layout: layout))
            }

            HStack(alignment: .bottom, spacing: layout.barSpacing) {
                ForEach(values) { value in
                    tirBar(value, layout: layout)
                }
            }
            .frame(width: layout.chartWidth, height: layout.totalHeight, alignment: .bottom)
        }
    }

    private func yAxisLabels(layout: TIRLayout) -> some View {
        ZStack(alignment: .topLeading) {
            ForEach(referencePercents.filter { $0 >= yAxisMinimum }, id: \.self) { percent in
                let y = yPosition(percent: percent, layout: layout)

                Text("\(Int(percent))%")
                    .font(.system(size: 10))
                    .foregroundStyle(ConstantsAppColors.secondaryText.opacity(0.85))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .frame(width: layout.yAxisLabelWidth, alignment: .trailing)
                    .offset(y: y - 6)
            }
        }
    }

    private func tirBar(_ value: LandscapeChartStateModel.DailyTIRData, layout: TIRLayout) -> some View {
        let isSelected = Calendar.current.isDate(value.date, inSameDayAs: selectedDate)
        let normalizedHeight = normalized(value.inRangePercentage)
        let barHeight = max(0, CGFloat(normalizedHeight) * layout.chartHeight)
        let dayText = dayLabel(for: value.date)

        return VStack(spacing: 0) {
            Text(value.inRangePercentage > 0 ? "\(Int(value.inRangePercentage.rounded()))%" : "-")
                .font(.system(size: isSelected ? 11 : 10, weight: isSelected ? .bold : .regular))
                .foregroundStyle(isSelected ? ConstantsAppColors.primaryText : (value.inRangePercentage > 0 ? ConstantsAppColors.secondaryText : ConstantsAppColors.tertiaryText))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .frame(height: layout.topPadding)

            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(isSelected ? ConstantsAppColors.statisticsInRange : ConstantsAppColors.statisticsInRange.opacity(0.55))
                    .frame(height: barHeight)
            }
            .frame(height: layout.chartHeight, alignment: .bottom)

            Text(dayText)
                .font(.system(size: isSelected ? 15 : 12, weight: isSelected ? .heavy : .regular))
                .foregroundStyle(isSelected ? ConstantsAppColors.primaryText : (value.inRangePercentage > 0 ? ConstantsAppColors.secondaryText : ConstantsAppColors.tertiaryText))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .frame(height: layout.bottomPadding)
        }
        .frame(width: layout.barWidth, height: layout.totalHeight)
        .clipped()
        .contentShape(Rectangle())
        .onTapGesture {
            selectDate(value.date)
        }
    }

    private func makeLayout(size: CGSize) -> TIRLayout {
        let topPadding: CGFloat = 24
        let bottomPadding: CGFloat = 24
        let horizontalPadding: CGFloat = 8
        let yAxisLabelWidth: CGFloat = 30
        let axisLabelGap: CGFloat = 4
        let chartWidth = max(1, size.width - (horizontalPadding * 2) - axisLabelGap - yAxisLabelWidth)
        let chartHeight = max(1, size.height - topPadding - bottomPadding)
        let barSpacing: CGFloat = 6
        let totalSpacing = barSpacing * CGFloat(max(values.count - 1, 0))
        let barWidth = max(1, (chartWidth - totalSpacing) / CGFloat(max(values.count, 1)))

        return TIRLayout(topPadding: topPadding, bottomPadding: bottomPadding, horizontalPadding: horizontalPadding, axisLabelGap: axisLabelGap, yAxisLabelWidth: yAxisLabelWidth, barSpacing: barSpacing, chartWidth: chartWidth, chartHeight: chartHeight, barWidth: barWidth)
    }

    private func normalized(_ percent: Double) -> Double {
        guard percent > 0 else { return 0 }

        return max(0, min(1, (percent - yAxisMinimum) / (yAxisMaximum - yAxisMinimum)))
    }

    private func yPosition(percent: Double, layout: TIRLayout) -> CGFloat {
        let normalized = max(0, min(1, (percent - yAxisMinimum) / (yAxisMaximum - yAxisMinimum)))

        return layout.topPadding + layout.chartHeight - CGFloat(normalized) * layout.chartHeight
    }

    private func dayLabel(for date: Date) -> String {
        let day = Calendar.current.component(.day, from: date)
        let month = Calendar.current.component(.month, from: date)
        guard let firstDate = values.first?.date else { return "\(day)" }

        let previousDate = Calendar.current.date(byAdding: .day, value: -1, to: date)
        let previousMonth = previousDate.map { Calendar.current.component(.month, from: $0) } ?? 0

        if Calendar.current.isDate(date, inSameDayAs: firstDate) || month != previousMonth {
            return shortMonthName(for: month)
        }

        return "\(day)"
    }

    private func shortMonthName(for monthNumber: Int) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale.current
        dateFormatter.setLocalizedDateFormatFromTemplate("MMM")

        var components = DateComponents()
        components.month = monthNumber
        components.day = 1
        components.year = 2000

        return Calendar.current.date(from: components).map { dateFormatter.string(from: $0).capitalized } ?? ""
    }

}

/// Stable dimensions shared by all bars, labels and gridlines in the TIR plot.
private struct TIRLayout {
    let topPadding: CGFloat
    let bottomPadding: CGFloat
    let horizontalPadding: CGFloat
    let axisLabelGap: CGFloat
    let yAxisLabelWidth: CGFloat
    let barSpacing: CGFloat
    let chartWidth: CGFloat
    let chartHeight: CGFloat
    let barWidth: CGFloat

    var totalHeight: CGFloat {
        topPadding + chartHeight + bottomPadding
    }
}

private extension RootHomeMetricState {
    var percentValue: Double {
        Double(value.replacingOccurrences(of: "%", with: "")) ?? 0
    }
}
