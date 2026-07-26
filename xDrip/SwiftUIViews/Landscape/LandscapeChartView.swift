//
//  LandscapeChartView.swift
//  xdrip
//
//  Created by Paul Plant on 16/9/21.
//  Copyright © 2021 Johan Degraeve. All rights reserved.
//

import SwiftUI

// MARK: - State Model

/// Owns the selected day trace and recent AGP baseline for the landscape comparison view.
final class LandscapeChartStateModel: ObservableObject {

    @Published var selectedDate = Date().toMidnight()
    @Published var displayedDate = Date().toMidnight()
    @Published var chartState = GlucoseChartState.empty(startDate: Date().toMidnight(), endDate: Date().toMidnight().addingTimeInterval(.hours(24) - 1))
    @Published var baseline = StatisticsManager.LandscapeBaseline.empty
    @Published var isLoading = false

    private let coreDataManager: CoreDataManager
    private let nightscoutSyncManager: NightscoutSyncManager
    private var activeLoadID = UUID()
    private var cachedSnapshots: [Date: LandscapeDaySnapshot] = [:]
    private var prefetchingDates = Set<Date>()
    // Each temporary manager must remain alive until its asynchronous chart request completes.
    private var snapshotChartStateManagers: [UUID: GlucoseChartStateManager] = [:]

    private let dateFormatter: DateFormatter = {
        let dateFormatter = DateFormatter()
        dateFormatter.setLocalizedDateFormatFromTemplate(ConstantsGlucoseChart.dateFormatLandscapeChart)

        return dateFormatter
    }()

    init(coreDataManager: CoreDataManager, nightscoutSyncManager: NightscoutSyncManager) {
        self.coreDataManager = coreDataManager
        self.nightscoutSyncManager = nightscoutSyncManager

        refresh()
    }

    var selectedDateText: String {
        dateFormatter.string(from: selectedDate)
    }

    var canMoveForward: Bool {
        !Calendar.current.isDateInToday(selectedDate)
    }

    func moveBackOneDay() {
        guard let date = Calendar.current.date(byAdding: .day, value: -1, to: selectedDate) else { return }

        selectDate(date)
    }

    func moveForwardOneDay() {
        guard canMoveForward,
              let date = Calendar.current.date(byAdding: .day, value: 1, to: selectedDate) else { return }

        selectDate(date)
    }

    func selectToday() {
        guard !Calendar.current.isDateInToday(selectedDate) else { return }

        selectDate(Date().toMidnight())
    }

    func refresh() {
        startLoad(referenceDate: selectedDate, forceResetChart: true)
    }

    private func refreshChart(referenceDate: Date, forceReset: Bool, completion: @escaping (GlucoseChartState) -> Void) {
        let startOfDay = referenceDate
        let nextDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)
        let endOfDay = nextDay?.addingTimeInterval(-1) ?? startOfDay.addingTimeInterval(.hours(24) - 1)
        let chartStateManager = GlucoseChartStateManager(coreDataManager: coreDataManager, nightscoutSyncManager: nightscoutSyncManager)
        let requestID = UUID()

        snapshotChartStateManagers[requestID] = chartStateManager

        chartStateManager.updateState(
            endDate: endOfDay,
            startDate: startOfDay,
            forceReset: forceReset,
            showTreatments: false
        ) { [weak self] chartState in
            guard self != nil else { return }

            DispatchQueue.main.async {
                self?.snapshotChartStateManagers[requestID] = nil

                guard Calendar.current.isDate(chartState.startDate, inSameDayAs: startOfDay),
                      Calendar.current.isDate(chartState.endDate, inSameDayAs: startOfDay) else {
                    completion(GlucoseChartState.empty(startDate: startOfDay, endDate: endOfDay))
                    return
                }

                completion(chartState)
            }
        }
    }

    private func selectDate(_ date: Date) {
        let startOfDay = date.toMidnight()

        selectedDate = startOfDay
        isLoading = true
        UISelectionFeedbackGenerator().selectionChanged()

        // Yield once so the date and activity indicator render before any cached or Core Data work.
        DispatchQueue.main.async { [weak self] in
            guard let self,
                  Calendar.current.isDate(self.selectedDate, inSameDayAs: startOfDay) else { return }

            self.startLoad(referenceDate: startOfDay, forceResetChart: false)
        }
    }

    private func startLoad(referenceDate: Date, forceResetChart: Bool) {
        let loadID = UUID()
        let key = cacheKey(for: referenceDate)

        activeLoadID = loadID
        isLoading = true

        if let snapshot = cachedSnapshots[key], !forceResetChart {
            commitSnapshot(snapshot, loadID: loadID, referenceDate: key)
            return
        }

        buildSnapshot(referenceDate: key, forceResetChart: forceResetChart) { [weak self] snapshot in
            self?.cachedSnapshots[key] = snapshot
            self?.commitSnapshot(snapshot, loadID: loadID, referenceDate: key)
        }
    }

    private func buildSnapshot(referenceDate: Date, forceResetChart: Bool, completion: @escaping (LandscapeDaySnapshot) -> Void) {
        let key = cacheKey(for: referenceDate)
        var loadedChartState: GlucoseChartState?
        var loadedBaseline: StatisticsManager.LandscapeBaseline?

        // Commit the glucose trace and AGP baseline together so the chart never shows mixed dates.
        let completeIfReady: () -> Void = { [weak self] in
            guard self != nil,
                  let loadedChartState,
                  let loadedBaseline else { return }

            completion(LandscapeDaySnapshot(chartState: loadedChartState, baseline: loadedBaseline))
        }

        refreshChart(referenceDate: key, forceReset: forceResetChart) { chartState in
            loadedChartState = chartState
            completeIfReady()
        }

        refreshBaselineSnapshot(referenceDate: key) { baseline in
            loadedBaseline = baseline
            completeIfReady()
        }
    }

    private func refreshBaselineSnapshot(referenceDate: Date, completion: @escaping (StatisticsManager.LandscapeBaseline) -> Void) {
        let statisticsManager = StatisticsManager(coreDataManager: coreDataManager)

        Task {
            let baseline = await statisticsManager.landscapeBaseline(
                referenceDate: referenceDate,
                daysBack: 7
            )

            await MainActor.run {
                completion(baseline)
            }
        }
    }

    private func commitSnapshot(_ snapshot: LandscapeDaySnapshot, loadID: UUID, referenceDate: Date) {
        guard activeLoadID == loadID,
              Calendar.current.isDate(selectedDate, inSameDayAs: referenceDate) else { return }

        displayedDate = referenceDate
        chartState = snapshot.chartState
        baseline = snapshot.baseline
        isLoading = false
        prefetchAdjacentDates(around: referenceDate)
    }

    private func prefetchAdjacentDates(around referenceDate: Date) {
        let today = cacheKey(for: Date())

        // Warm the most likely navigation targets without changing the visible loading state.
        [-1, 1, -2, 2].forEach { dayOffset in
            guard let adjacentDate = Calendar.current.date(byAdding: .day, value: dayOffset, to: referenceDate) else { return }

            let date = cacheKey(for: adjacentDate)

            if date <= today {
                prefetchSnapshot(referenceDate: date)
            }
        }
    }

    private func prefetchSnapshot(referenceDate: Date) {
        guard cachedSnapshots[referenceDate] == nil,
              !prefetchingDates.contains(referenceDate) else { return }

        prefetchingDates.insert(referenceDate)

        buildSnapshot(referenceDate: referenceDate, forceResetChart: false) { [weak self] snapshot in
            self?.cachedSnapshots[referenceDate] = snapshot
            self?.prefetchingDates.remove(referenceDate)
        }
    }

    private func cacheKey(for date: Date) -> Date {
        date.toMidnight()
    }

}

private struct LandscapeDaySnapshot {
    let chartState: GlucoseChartState
    let baseline: StatisticsManager.LandscapeBaseline
}

private extension StatisticsManager.LandscapeBaseline {
    static var empty: StatisticsManager.LandscapeBaseline {
        StatisticsManager.LandscapeBaseline(
            dayCount: 0,
            usesMgDl: UserDefaults.standard.bloodGlucoseUnitIsMgDl,
            agpPoints: []
        )
    }
}

// MARK: - Main View

/// Full-screen AGP comparison with selected-day glucose and range summary.
struct LandscapeChartView: View {

    @ObservedObject var stateModel: LandscapeChartStateModel

    private enum Layout {
        static let screenPadding: CGFloat = 6
        static let spacing: CGFloat = 7
        static let toolbarHeight: CGFloat = 46
    }

    var body: some View {
        VStack(spacing: Layout.spacing) {
            toolbar

            LandscapeAGPComparisonChart(
                chartState: stateModel.chartState,
                baseline: stateModel.baseline,
                displayedDate: stateModel.displayedDate,
                canMoveForward: stateModel.canMoveForward,
                moveBackOneDay: stateModel.moveBackOneDay,
                moveForwardOneDay: stateModel.moveForwardOneDay,
                selectToday: stateModel.selectToday
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(Layout.screenPadding)
        .padding(.top, 2)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ConstantsAppColors.background)
    }

    private var toolbar: some View {
        HStack(spacing: 12) {
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(stateModel.selectedDateText)
                        .font(.system(size: 18, weight: .heavy))
                        .foregroundStyle(ConstantsAppColors.primaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)

                    Text(comparisonContextText)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(ConstantsAppColors.secondaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .onTapGesture(count: 2) {
                    stateModel.selectToday()
                }

                if isLoading {
                    ProgressView()
                        .controlSize(.regular)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            LandscapeTIRBadge(
                chartState: stateModel.chartState,
                referenceDate: stateModel.displayedDate
            )
        }
        .frame(height: Layout.toolbarHeight)
    }

    private var isLoading: Bool {
        stateModel.isLoading
    }

    private var comparisonContextText: String {
        let dayCount = max(1, stateModel.baseline.dayCount)
        let daysText = dayCount == 1 ? "day" : "days"

        return "Comparing to the previous \(dayCount) \(daysText)"
    }

}

// MARK: - Chart

private struct LandscapeAGPComparisonChart: View {

    private enum Layout {
        static let navigationAxisSpacing: CGFloat = 14
        static let trailingAxisLabelWidth: CGFloat = 34
    }

    let chartState: GlucoseChartState
    let baseline: StatisticsManager.LandscapeBaseline
    let displayedDate: Date
    let canMoveForward: Bool
    let moveBackOneDay: () -> Void
    let moveForwardOneDay: () -> Void
    let selectToday: () -> Void

    @State private var hasTriggeredSwipe = false
    @State private var contentWidth: CGFloat = 0

    var body: some View {
        AGPChartView(
            points: baseline.agpPoints,
            usesMgDl: baseline.usesMgDl,
            presentation: .landscapeComparison,
            glucosePoints: agpGlucosePoints,
            showsNowRule: Calendar.current.isDateInToday(displayedDate),
            emptyMessage: "Glucose data will appear once recent readings are available."
        )
        .padding(.horizontal, 6)
        .padding(.top, 2)
        .padding(.bottom, 0)
        .overlay {
            chartNavigationHints
                .padding(.leading, Layout.navigationAxisSpacing)
                .padding(.trailing, Layout.navigationAxisSpacing + Layout.trailingAxisLabelWidth)
                .padding(.top, 28)
                .padding(.bottom, 28)
        }
        .background {
            GeometryReader { geometry in
                Color.clear
                    .onAppear {
                        contentWidth = geometry.size.width
                    }
                    .onChange(of: geometry.size.width) { newValue in
                        contentWidth = newValue
                    }
            }
        }
        .contentShape(Rectangle())
        .highPriorityGesture(daySwipeGesture)
        .simultaneousGesture(dayTapGesture)
        .simultaneousGesture(todayDoubleTapGesture)
    }

    private var glucosePoints: [LandscapeGlucosePoint] {
        let pairs = zip(chartState.bgReadingDates, chartState.bgReadingValues)
            .filter { date, _ in
                date >= chartState.startDate &&
                    date <= chartState.endDate &&
                    Calendar.current.isDate(date, inSameDayAs: chartState.startDate)
            }
            .map { date, value in
                LandscapeGlucosePoint(date: date, minuteOfDay: minuteOfDay(for: date), valueMgDl: value, isLatest: false)
            }
            .sorted { $0.minuteOfDay < $1.minuteOfDay }

        guard let latest = pairs.last else { return pairs }

        return pairs.map { point in
            LandscapeGlucosePoint(date: point.date, minuteOfDay: point.minuteOfDay, valueMgDl: point.valueMgDl, isLatest: point.id == latest.id)
        }
    }

    private var agpGlucosePoints: [AGPChartGlucosePoint] {
        glucosePoints.map { point in
            AGPChartGlucosePoint(
                id: point.id,
                minuteOfDay: point.minuteOfDay,
                valueMgDl: point.valueMgDl,
                isLatest: point.isLatest
            )
        }
    }

    private func minuteOfDay(for date: Date) -> Int {
        let components = Calendar.current.dateComponents([.hour, .minute], from: date)

        return (components.hour ?? 0) * 60 + (components.minute ?? 0)
    }

    private var chartNavigationHints: some View {
        HStack {
            navigationHint(systemName: "chevron.left")

            Spacer()

            if canMoveForward {
                navigationHint(systemName: "chevron.right")
            }
        }
        .allowsHitTesting(false)
    }

    private func navigationHint(systemName: String) -> some View {
        Image(systemName: systemName)
            .font(.system(size: 17, weight: .bold))
            .foregroundStyle(ConstantsAppColors.primaryText.opacity(0.72))
            .frame(width: 34, height: 34)
            .background(Color.white.opacity(0.2), in: Circle())
            .overlay {
                Circle()
                    .stroke(Color.white.opacity(0.14), lineWidth: 1)
            }
    }

    private var daySwipeGesture: some Gesture {
        DragGesture(minimumDistance: 10)
            .onChanged { value in
                guard !hasTriggeredSwipe,
                      abs(value.translation.width) > abs(value.translation.height),
                      abs(value.translation.width) > 45 else { return }

                hasTriggeredSwipe = true

                if value.translation.width < 0 {
                    moveForwardOneDay()
                } else {
                    moveBackOneDay()
                }
            }
            .onEnded { _ in
                hasTriggeredSwipe = false
            }
    }

    private var dayTapGesture: some Gesture {
        // Keep edge taps independent from the centre double tap so rapid navigation never resets.
        SpatialTapGesture(count: 1)
            .onEnded { tap in
                selectDateFromTapLocation(tap.location)
            }
    }

    private var todayDoubleTapGesture: some Gesture {
        SpatialTapGesture(count: 2)
            .onEnded { tap in
                guard isInChartCentre(tap.location) else { return }

                selectToday()
            }
    }

    private func selectDateFromTapLocation(_ location: CGPoint) {
        guard contentWidth > 0 else { return }

        // Keep the centre half of the plot passive for reading and future chart interaction.
        if location.x <= contentWidth * 0.25 {
            moveBackOneDay()
        } else if location.x >= contentWidth * 0.75 {
            moveForwardOneDay()
        }
    }

    private func isInChartCentre(_ location: CGPoint) -> Bool {
        guard contentWidth > 0 else { return false }

        return location.x > contentWidth * 0.25 && location.x < contentWidth * 0.75
    }

}

private struct LandscapeGlucosePoint: Identifiable {
    let id: String
    let date: Date
    let minuteOfDay: Int
    let valueMgDl: Double
    let isLatest: Bool

    init(date: Date, minuteOfDay: Int, valueMgDl: Double, isLatest: Bool) {
        self.date = date
        self.minuteOfDay = minuteOfDay
        self.valueMgDl = valueMgDl
        self.isLatest = isLatest
        id = "\(date.timeIntervalSince1970)-\(valueMgDl)"
    }
}

// MARK: - Toolbar TIR

private struct LandscapeTIRBadge: View {

    private enum RangeMode {
        case timeInRange
        case timeInTightRange

        var title: String {
            switch self {
            case .timeInRange:
                return "TIR"
            case .timeInTightRange:
                return "TITR"
            }
        }

        var lowLimitMgDl: Double {
            switch self {
            case .timeInRange:
                return GlucoseReportClinicalConstants.timeInRangeLowMgDl
            case .timeInTightRange:
                return GlucoseReportClinicalConstants.timeInTightRangeLowMgDl
            }
        }

        var highLimitMgDl: Double {
            switch self {
            case .timeInRange:
                return GlucoseReportClinicalConstants.timeInRangeHighMgDl
            case .timeInTightRange:
                return GlucoseReportClinicalConstants.timeInTightRangeHighMgDl
            }
        }

        mutating func toggle() {
            switch self {
            case .timeInRange:
                self = .timeInTightRange
            case .timeInTightRange:
                self = .timeInRange
            }
        }
    }

    let chartState: GlucoseChartState
    let referenceDate: Date

    @State private var rangeMode = RangeMode.timeInRange

    var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 0) {
                Text("\(rangeMode.title): ")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(ConstantsAppColors.secondaryText)
                    .lineLimit(1)

                percentageText(lowPercentage, ConstantsAppColors.statisticsLow)
                separator
                percentageText(inRangePercentage, ConstantsAppColors.statisticsInRange, weight: .bold)
                separator
                percentageText(highPercentage, ConstantsAppColors.statisticsHigh)
            }
            .fixedSize(horizontal: true, vertical: false)

            tirBar
        }
        .frame(height: 40)
        .contentShape(Rectangle())
        .onTapGesture(count: 2) {
            // This is intentionally view-local and always starts with standard TIR.
            rangeMode.toggle()
        }
        .accessibilityLabel(rangeMode.title)
        .accessibilityValue("\(Texts_Common.lowStatistics) \(percentage(lowPercentage)), \(Texts_Common.inRangeStatistics) \(percentage(inRangePercentage)), \(Texts_Common.highStatistics) \(percentage(highPercentage))")
    }

    private var tirBar: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                Rectangle()
                    .fill(ConstantsAppColors.statisticsLow)
                    .frame(width: segmentWidth(for: lowPercentage, totalWidth: geometry.size.width))

                Rectangle()
                    .fill(ConstantsAppColors.statisticsInRange)
                    .frame(width: segmentWidth(for: inRangePercentage, totalWidth: geometry.size.width))

                Rectangle()
                    .fill(ConstantsAppColors.statisticsHigh)
                    .frame(width: segmentWidth(for: highPercentage, totalWidth: geometry.size.width))
            }
            .background(Color.white.opacity(0.14))
            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
        }
        .frame(width: 210, height: 18)
    }

    private var analysisPoints: [LandscapeGlucosePoint] {
        let points = zip(chartState.bgReadingDates, chartState.bgReadingValues)
            .map { date, value in
                let components = Calendar.current.dateComponents([.hour, .minute], from: date)
                let minute = (components.hour ?? 0) * 60 + (components.minute ?? 0)
                return LandscapeGlucosePoint(date: date, minuteOfDay: minute, valueMgDl: value, isLatest: false)
            }
            .sorted { $0.date < $1.date }

        guard Calendar.current.isDateInToday(referenceDate) else { return points }

        let now = Date()

        return points.filter { $0.date <= now }
    }

    private var lowPercentage: Double {
        percentage { $0 < rangeMode.lowLimitMgDl }
    }

    private var inRangePercentage: Double {
        percentage { $0 >= rangeMode.lowLimitMgDl && $0 <= rangeMode.highLimitMgDl }
    }

    private var highPercentage: Double {
        percentage { $0 > rangeMode.highLimitMgDl }
    }

    private var separator: some View {
        Text("·")
            .font(.system(size: 18, weight: .regular))
            .foregroundStyle(ConstantsAppColors.tertiaryText)
            .padding(.horizontal, 6)
    }

    private func percentage(_ matches: (Double) -> Bool) -> Double {
        guard !analysisPoints.isEmpty else { return 0 }

        let count = analysisPoints.filter { matches($0.valueMgDl) }.count

        return Double(count) / Double(analysisPoints.count) * 100
    }

    private func segmentWidth(for percentage: Double, totalWidth: CGFloat) -> CGFloat {
        totalWidth * CGFloat(max(0, min(100, percentage)) / 100)
    }

    private func percentage(_ value: Double) -> String {
        "\(Int(value.round(toDecimalPlaces: 0)))%"
    }

    private func percentageText(_ value: Double, _ color: Color, weight: Font.Weight = .regular) -> some View {
        Text(percentage(value))
            .font(.system(size: 18, weight: weight))
            .foregroundStyle(color)
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.9)
    }
}
