//
//  LandscapeChartView.swift
//  xdrip
//
//  Created by Paul Plant on 16/9/21.
//  Copyright © 2021 Johan Degraeve. All rights reserved.
//

import SwiftUI

private func validLandscapeDimension(_ value: CGFloat) -> CGFloat {
    value.isFinite ? max(value, 0) : 0
}

/// Supported history periods for the landscape comparison baseline.
enum LandscapeComparisonPeriod: Int, CaseIterable, Identifiable {
    case threeDays = 3
    case sevenDays = 7
    case thirtyDays = 30
    case sixtyDays = 60
    case ninetyDays = 90

    var id: Int { rawValue }

    var title: String {
        Texts_Common.landscapeComparisonDays(rawValue)
    }
}

// MARK: - State Model

/// Owns the selected day trace and recent AGP baseline for the landscape comparison view.
final class LandscapeChartStateModel: ObservableObject {

    @Published var selectedDate = Date().toMidnight()
    @Published var displayedDate = Date().toMidnight()
    @Published var chartState = GlucoseChartState.empty(startDate: Date().toMidnight(), endDate: Date().toMidnight().addingTimeInterval(.hours(24) - 1))
    @Published var baseline = StatisticsManager.LandscapeBaseline.empty
    @Published var loopalyzerSnapshot: StatisticsManager.LandscapeLoopalyzerSnapshot?
    @Published private(set) var comparisonPeriod: LandscapeComparisonPeriod
    let showsAIDCharts: Bool

    private let coreDataManager: CoreDataManager
    private let nightscoutSyncManager: NightscoutSyncManager
    private let statisticsManager: StatisticsManager
    private var activeLoadID = UUID()
    private var cachedSnapshots: [LandscapeSnapshotCacheKey: LandscapeDaySnapshot] = [:]
    private var prefetchingSnapshots = Set<LandscapeSnapshotCacheKey>()
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
        statisticsManager = StatisticsManager(coreDataManager: coreDataManager)
        showsAIDCharts = UserDefaults.standard.dataFlowPolicy.showsAIDData
        comparisonPeriod = LandscapeComparisonPeriod(rawValue: UserDefaults.standard.landscapeComparisonDays) ?? .sevenDays

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

    func selectComparisonPeriod(_ period: LandscapeComparisonPeriod) {
        guard comparisonPeriod != period else { return }

        comparisonPeriod = period
        UserDefaults.standard.landscapeComparisonDays = period.rawValue

        DispatchQueue.main.async { [weak self] in
            guard let self, self.comparisonPeriod == period else { return }

            self.startLoad(referenceDate: self.selectedDate, forceResetChart: false)
        }
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
        UISelectionFeedbackGenerator().selectionChanged()

        // Yield once so the selected date renders before any cached or Core Data work.
        DispatchQueue.main.async { [weak self] in
            guard let self,
                  Calendar.current.isDate(self.selectedDate, inSameDayAs: startOfDay) else { return }

            self.startLoad(referenceDate: startOfDay, forceResetChart: false)
        }
    }

    private func startLoad(referenceDate: Date, forceResetChart: Bool) {
        let loadID = UUID()
        let key = snapshotCacheKey(for: referenceDate, comparisonPeriod: comparisonPeriod)

        activeLoadID = loadID

        if let snapshot = cachedSnapshots[key], !forceResetChart {
            commitSnapshot(snapshot, loadID: loadID, cacheKey: key)
            return
        }

        buildSnapshot(cacheKey: key, forceResetChart: forceResetChart) { [weak self] snapshot in
            self?.cachedSnapshots[key] = snapshot
            self?.commitSnapshot(snapshot, loadID: loadID, cacheKey: key)
        }
    }

    private func buildSnapshot(cacheKey: LandscapeSnapshotCacheKey, forceResetChart: Bool, completion: @escaping (LandscapeDaySnapshot) -> Void) {
        var loadedChartState: GlucoseChartState?
        var loadedAnalytics: StatisticsManager.LandscapeAnalytics?

        // Commit every visible series together so date navigation never shows mixed days.
        let completeIfReady: () -> Void = { [weak self] in
            guard self != nil,
                  let loadedChartState,
                  let loadedAnalytics else { return }

            completion(LandscapeDaySnapshot(
                chartState: loadedChartState,
                baseline: loadedAnalytics.baseline,
                loopalyzerSnapshot: loadedAnalytics.loopalyzer
            ))
        }

        refreshChart(referenceDate: cacheKey.date, forceReset: forceResetChart) { chartState in
            loadedChartState = chartState
            completeIfReady()
        }

        refreshAnalytics(referenceDate: cacheKey.date, daysBack: cacheKey.comparisonDays) { analytics in
            loadedAnalytics = analytics
            completeIfReady()
        }
    }

    private func refreshAnalytics(referenceDate: Date, daysBack: Int, completion: @escaping (StatisticsManager.LandscapeAnalytics) -> Void) {
        Task {
            let analytics = await statisticsManager.landscapeAnalytics(
                referenceDate: referenceDate,
                daysBack: daysBack,
                includesAID: showsAIDCharts
            )

            await MainActor.run {
                completion(analytics)
            }
        }
    }

    private func commitSnapshot(_ snapshot: LandscapeDaySnapshot, loadID: UUID, cacheKey: LandscapeSnapshotCacheKey) {
        guard activeLoadID == loadID,
              comparisonPeriod.rawValue == cacheKey.comparisonDays,
              Calendar.current.isDate(selectedDate, inSameDayAs: cacheKey.date) else { return }

        displayedDate = cacheKey.date
        chartState = snapshot.chartState
        baseline = snapshot.baseline
        loopalyzerSnapshot = snapshot.loopalyzerSnapshot
        prefetchAdjacentDates(around: cacheKey.date, comparisonPeriod: comparisonPeriod)
    }

    private func prefetchAdjacentDates(around referenceDate: Date, comparisonPeriod: LandscapeComparisonPeriod) {
        let today = Date().toMidnight()

        // Warm the most likely navigation targets without changing the visible loading state.
        [-1, 1, -2, 2].forEach { dayOffset in
            guard let adjacentDate = Calendar.current.date(byAdding: .day, value: dayOffset, to: referenceDate) else { return }

            let key = snapshotCacheKey(for: adjacentDate, comparisonPeriod: comparisonPeriod)

            if key.date <= today {
                prefetchSnapshot(cacheKey: key)
            }
        }
    }

    private func prefetchSnapshot(cacheKey: LandscapeSnapshotCacheKey) {
        guard cachedSnapshots[cacheKey] == nil,
              !prefetchingSnapshots.contains(cacheKey) else { return }

        prefetchingSnapshots.insert(cacheKey)

        buildSnapshot(cacheKey: cacheKey, forceResetChart: false) { [weak self] snapshot in
            self?.cachedSnapshots[cacheKey] = snapshot
            self?.prefetchingSnapshots.remove(cacheKey)
        }
    }

    private func snapshotCacheKey(for date: Date, comparisonPeriod: LandscapeComparisonPeriod) -> LandscapeSnapshotCacheKey {
        LandscapeSnapshotCacheKey(date: date.toMidnight(), comparisonDays: comparisonPeriod.rawValue)
    }

}

private struct LandscapeSnapshotCacheKey: Hashable {
    let date: Date
    let comparisonDays: Int
}

private struct LandscapeDaySnapshot {
    let chartState: GlucoseChartState
    let baseline: StatisticsManager.LandscapeBaseline
    let loopalyzerSnapshot: StatisticsManager.LandscapeLoopalyzerSnapshot?
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

    enum Presentation: Equatable {
        case standard
        case expandedIPad
    }

    @ObservedObject var stateModel: LandscapeChartStateModel
    let presentation: Presentation

    private enum Layout {
        static let screenPadding: CGFloat = 6
        static let contentSpacing: CGFloat = 8
        static let expandedContentSpacing: CGFloat = 22
        static let expandedPanelHorizontalInset: CGFloat = 16
        static let chartColumnSpacing: CGFloat = 18
        static let agpColumnFraction = 0.65
        static let toolbarHeight: CGFloat = 48
        static let expandedToolbarHeight: CGFloat = 64
        static let expandedSummaryHeight: CGFloat = 72
        static let expandedMinimumChartHeight: CGFloat = 360
        static let expandedMaximumChartHeight: CGFloat = 640
        static let expandedChartHeightFraction: CGFloat = 0.72
    }

    init(stateModel: LandscapeChartStateModel, presentation: Presentation = .standard) {
        self.stateModel = stateModel
        self.presentation = presentation
    }

    var body: some View {
        Group {
            switch presentation {
            case .standard:
                VStack(spacing: Layout.contentSpacing) {
                    toolbar

                    chartContent
                }
            case .expandedIPad:
                GeometryReader { geometry in
                    VStack(spacing: Layout.expandedContentSpacing) {
                        toolbar
                            .padding(.horizontal, Layout.expandedPanelHorizontalInset)
                        expandedSummary
                            .padding(.horizontal, Layout.expandedPanelHorizontalInset)

                        chartContent
                            .frame(height: expandedChartHeight(for: geometry.size.height))

                        Spacer(minLength: 0)
                    }
                }
            }
        }
        .padding(Layout.screenPadding)
        .padding(.top, 2)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ConstantsAppColors.background)
    }

    @ViewBuilder private var chartContent: some View {
        if stateModel.showsAIDCharts {
            GeometryReader { geometry in
                let availableWidth = validLandscapeDimension(
                    geometry.size.width - Layout.chartColumnSpacing
                )

                HStack(spacing: Layout.chartColumnSpacing) {
                    landscapeAGPColumn
                        .frame(width: availableWidth * Layout.agpColumnFraction)

                    LandscapeLoopalyzerCharts(snapshot: stateModel.loopalyzerSnapshot)
                        .frame(width: availableWidth * (1 - Layout.agpColumnFraction))
                }
            }
        } else {
            landscapeAGPColumn
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var landscapeAGPColumn: some View {
        VStack(alignment: .leading, spacing: 0) {
            if presentation == .standard {
                comparisonPeriodMenu
                    .padding(.leading, 8)
            }

            landscapeAGPChart
        }
    }

    private var landscapeAGPChart: some View {
        LandscapeAGPComparisonChart(
            chartState: stateModel.chartState,
            baseline: stateModel.baseline,
            displayedDate: stateModel.displayedDate,
            canMoveForward: stateModel.canMoveForward,
            moveBackOneDay: stateModel.moveBackOneDay,
            moveForwardOneDay: stateModel.moveForwardOneDay,
            selectToday: stateModel.selectToday
        )
    }

    private var toolbar: some View {
        HStack(spacing: 12) {
            Text(stateModel.selectedDateText)
                .font(.system(size: 22, weight: .heavy))
                .foregroundStyle(ConstantsAppColors.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .onTapGesture(count: 2) {
                    stateModel.selectToday()
                }
                .frame(maxWidth: .infinity, alignment: .leading)

            LandscapeTIRBadge(
                chartState: stateModel.chartState,
                referenceDate: stateModel.displayedDate,
                isExpandedIPad: presentation == .expandedIPad
            )
        }
        .padding(.horizontal, 14)
        .frame(height: presentation == .expandedIPad ? Layout.expandedToolbarHeight : Layout.toolbarHeight)
        .background(ConstantsAppColors.homePanelBackground)
        .clipShape(RoundedRectangle(cornerRadius: ConstantsHomeView.standardCornerRadius + 8, style: .continuous))
    }

    private var expandedSummary: some View {
        HStack(spacing: 0) {
            VStack(spacing: 5) {
                Text(Texts_Common.statisticsPeriod)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(ConstantsAppColors.secondaryText)

                comparisonPeriodMenu
            }
            .frame(maxWidth: .infinity)

            summaryDivider
            summaryMetric(title: Texts_Common.statisticsAverageGlucose, value: averageGlucoseText)
            summaryDivider
            summaryMetric(title: Texts_Common.cvStatistics, value: cvText)
        }
        .padding(.horizontal, 18)
        .frame(height: Layout.expandedSummaryHeight)
        .background(ConstantsAppColors.homePanelBackground)
        .clipShape(RoundedRectangle(cornerRadius: ConstantsHomeView.standardCornerRadius + 8, style: .continuous))
    }

    private func summaryMetric(title: String, value: String) -> some View {
        VStack(spacing: 5) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(ConstantsAppColors.secondaryText)
                .lineLimit(1)

            Text(value)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(ConstantsAppColors.primaryText)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
    }

    private var summaryDivider: some View {
        Divider()
            .frame(height: 38)
            .overlay(ConstantsAppColors.tertiaryText.opacity(0.35))
    }

    private var dailyValuesMgDl: [Double] {
        zip(stateModel.chartState.bgReadingDates, stateModel.chartState.bgReadingValues)
            .filter { date, value in
                value > 0 && Calendar.current.isDate(date, inSameDayAs: stateModel.displayedDate)
            }
            .map { $0.1 }
    }

    private var averageMgDl: Double? {
        guard !dailyValuesMgDl.isEmpty else { return nil }

        return dailyValuesMgDl.reduce(0, +) / Double(dailyValuesMgDl.count)
    }

    private var averageGlucoseText: String {
        guard let averageMgDl else { return "-" }

        let usesMgDl = stateModel.baseline.usesMgDl
        let unit = usesMgDl ? Texts_Common.mgdl : Texts_Common.mmol

        return "\(averageMgDl.mgDlToMmolAndToString(mgDl: usesMgDl)) \(unit)"
    }

    private var cvText: String {
        guard let averageMgDl, averageMgDl > 0 else { return "-" }

        let variance = dailyValuesMgDl.reduce(0) { partialResult, value in
            partialResult + pow(value - averageMgDl, 2)
        } / Double(dailyValuesMgDl.count)
        let cv = sqrt(variance) / averageMgDl * 100

        return GlucoseReportFormatting.percentage(cv)
    }

    private func expandedChartHeight(for availableHeight: CGFloat) -> CGFloat {
        let validAvailableHeight = validLandscapeDimension(availableHeight)
        let heightAfterHeader = max(
            0,
            validAvailableHeight
                - Layout.expandedToolbarHeight
                - Layout.expandedSummaryHeight
                - (Layout.expandedContentSpacing * 2)
        )
        let preferredHeight = min(
            Layout.expandedMaximumChartHeight,
            max(Layout.expandedMinimumChartHeight, validAvailableHeight * Layout.expandedChartHeightFraction)
        )

        return min(preferredHeight, heightAfterHeader)
    }

    private var comparisonPeriodMenu: some View {
        HStack(spacing: presentation == .expandedIPad ? 6 : 0) {
            Text(Texts_Common.landscapeComparingWithLast)
                .foregroundStyle(comparisonPeriodColor)
                .font(comparisonPeriodFont)

            Menu {
                ForEach(LandscapeComparisonPeriod.allCases) { period in
                    Button {
                        stateModel.selectComparisonPeriod(period)
                    } label: {
                        if stateModel.comparisonPeriod == period {
                            Label(period.title, systemImage: "checkmark")
                        } else {
                            Text(period.title)
                        }
                    }
                }
            } label: {
                HStack(spacing: 2) {
                    Text(stateModel.comparisonPeriod.title)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption.weight(.semibold))
                }
                .font(comparisonPeriodFont)
                .foregroundStyle(comparisonPeriodColor)
            }
            .buttonStyle(.plain)

        }
        .lineLimit(1)
        .minimumScaleFactor(0.8)
    }

    private var comparisonPeriodColor: Color {
        presentation == .expandedIPad
            ? ConstantsAppColors.primaryText
            : ConstantsAppColors.secondaryText
    }

    private var comparisonPeriodFont: Font {
        presentation == .expandedIPad
            ? .system(size: 18, weight: .semibold)
            : .body
    }

}

/// Full-width AGP insight card used at the end of the iPad Home dashboard. It shares the same
/// state model and chart renderer as the dedicated landscape view, without its Loopalyzer column.
struct IPadHomeAGPView: View {
    @StateObject private var stateModel: LandscapeChartStateModel
    let refreshRevision: Int

    init(
        coreDataManager: CoreDataManager,
        nightscoutSyncManager: NightscoutSyncManager,
        refreshRevision: Int
    ) {
        _stateModel = StateObject(wrappedValue: LandscapeChartStateModel(
            coreDataManager: coreDataManager,
            nightscoutSyncManager: nightscoutSyncManager
        ))
        self.refreshRevision = refreshRevision
    }

    var body: some View {
        LandscapeAGPComparisonChart(
            chartState: stateModel.chartState,
            baseline: stateModel.baseline,
            displayedDate: stateModel.displayedDate,
            canMoveForward: stateModel.canMoveForward,
            moveBackOneDay: stateModel.moveBackOneDay,
            moveForwardOneDay: stateModel.moveForwardOneDay,
            selectToday: stateModel.selectToday
        )
        .padding(8)
        .background(ConstantsAppColors.homePanelBackground)
        .clipShape(RoundedRectangle(cornerRadius: ConstantsHomeView.standardCornerRadius + 8, style: .continuous))
        .onChange(of: refreshRevision) { _ in
            stateModel.refresh()
        }
    }
}

private struct LandscapeLoopalyzerCharts: View {
    let snapshot: StatisticsManager.LandscapeLoopalyzerSnapshot?

    private enum Layout {
        static let chartSpacing: CGFloat = 14
        static let chartChromeHeight: CGFloat = 112
    }

    var body: some View {
        GeometryReader { geometry in
            if let snapshot {
                LandscapeLoopalyzerChart(
                    points: snapshot.points,
                    insulinTreatmentMarkers: snapshot.insulinTreatmentMarkers,
                    carbTreatmentMarkers: snapshot.carbTreatmentMarkers,
                    plotHeight: max(
                        44,
                        (validLandscapeDimension(geometry.size.height) - Layout.chartChromeHeight) / 3
                    ),
                    chartSpacing: Layout.chartSpacing
                )
            }
        }
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
            emptyMessage: Texts_Common.statisticsWaitingForGlucoseData
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

    private enum RangeMode: CaseIterable {
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

    }

    let chartState: GlucoseChartState
    let referenceDate: Date
    var isExpandedIPad = false

    @State private var rangeMode = RangeMode.timeInRange

    var body: some View {
        HStack(spacing: isExpandedIPad ? 22 : 12) {
            HStack(spacing: isExpandedIPad ? 12 : 0) {
                percentageText(lowPercentage, ConstantsAppColors.statisticsLow)
                separator
                percentageText(inRangePercentage, ConstantsAppColors.statisticsInRange, weight: .bold)
                separator
                percentageText(highPercentage, ConstantsAppColors.statisticsHigh)
            }
            .fixedSize(horizontal: true, vertical: false)

            HStack(spacing: isExpandedIPad ? 12 : 0) {
                tirBar

                Menu {
                    ForEach(RangeMode.allCases, id: \.self) { mode in
                        Button {
                            rangeMode = mode
                        } label: {
                            if rangeMode == mode {
                                Label(mode.title, systemImage: "checkmark")
                            } else {
                                Text(mode.title)
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 2) {
                        Text(rangeMode.title)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.caption.weight(.semibold))
                    }
                    .foregroundStyle(ConstantsAppColors.primaryText)
                }
                .buttonStyle(.plain)
            }
            .fixedSize(horizontal: true, vertical: false)
        }
        .frame(height: isExpandedIPad ? 48 : 40)
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
        .frame(width: isExpandedIPad ? 220 : 160, height: isExpandedIPad ? 22 : 18)
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
        validLandscapeDimension(totalWidth) * CGFloat(max(0, min(100, percentage)) / 100)
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
