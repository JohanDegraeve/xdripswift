//
//  RootHomeView.swift
//  xdrip
//
//  Created by Paul Plant on 11/7/26.
//  Copyright © 2026 Johan Degraeve. All rights reserved.
//

import Combine
import SwiftUI

/// Native SwiftUI home screen.
///
/// This view owns presentation-level state and chart scrolling state. RootTabView owns its
/// navigation and sheets, while RootApplicationCoordinator owns transmitter delegates,
/// notifications and application service lifecycle work.
struct RootHomeView: View {

    // MARK: - Layout

    /// Native SwiftUI layout contract for the home screen.
    ///
    /// Compact rows keep stable heights because they contain fixed-format status information.
    /// The main chart is the flexible row and expands to consume the remaining vertical space.
    fileprivate enum Layout {
        static let sectionSpacing: CGFloat = 10
        static let rowSpacing: CGFloat = 9
        static let screenHorizontalMargin: CGFloat = 8
        static let horizontalMargin: CGFloat = 8
        static let toolbarMinimumHeight: CGFloat = 44
        static let glucoseRowHeight: CGFloat = 120
        static let glucoseInfoRowHeight: CGFloat = 24
        static let pumpWidth: CGFloat = 158
        static let loopHeight: CGFloat = 35
        static let loopTopPadding: CGFloat = 2
        static let loopBottomPadding: CGFloat = 2
        static let loopStatusSymbolSize: CGFloat = 18
        static let miniChartHeight: CGFloat = 60
        static let selectorHeight: CGFloat = 30
        static let statisticsHeight: CGFloat = 90
        static let sensorProgressHeight: CGFloat = 10
        static let dataSourceHeight: CGFloat = 30
        static let bottomStatusSpacing: CGFloat = 2
        static let clockHeight: CGFloat = 140
    }

    // MARK: - Chart Range

    fileprivate enum ChartRange: Double, CaseIterable, Identifiable {
        case threeHours = 3
        case fiveHours = 5
        case eightHours = 8
        case twelveHours = 12

        var id: Double {
            rawValue
        }

        var title: String {
            "\(Int(rawValue))\(Texts_Common.hourshort)"
        }

        var timeInterval: TimeInterval {
            .hours(-rawValue)
        }

        /// Baseline used by `GlucoseChartView` to keep glucose points readable as the visible range widens.
        var glucoseCircleDiameterScalingHours: Double {
            switch self {
            case .threeHours:
                return 3.0
            case .fiveHours:
                return 4.5
            case .eightHours:
                return 6.0
            case .twelveHours:
                return 7.2
            }
        }

        static func closest(to hours: Double) -> ChartRange {
            ChartRange.allCases.min { abs($0.rawValue - hours) < abs($1.rawValue - hours) } ?? .fiveHours
        }
    }

    /// Settings that affect which cached chart series are included in the main chart state.
    ///
    /// The stored UserDefaults values are observed with `@AppStorage`, but the chart only needs a
    /// manager refresh when the effective renderable series changes, without listening to every
    /// UserDefaults write.
    private struct ChartSeriesSettings: Equatable {
        let showTreatments: Bool
        let showOriginalBGReadings: Bool
    }

    // MARK: - State

    @Environment(\.scenePhase) private var scenePhase
    @ObservedObject private var stateModel: RootHomeStateModel
    @StateObject private var glucoseChartStateManager: GlucoseChartStateManager
    @StateObject private var miniChartStateManager: GlucoseChartStateManager
    @StateObject private var scrollCoordinator: GlucoseChartScrollCoordinator

    private let nightscoutSyncManager: NightscoutSyncManager
    @State private var selectedRange: ChartRange
    @State private var isLoadingChart = false
    @State private var isBackgroundLoadingChart = false
    @State private var showOriginalBGReadingsOnly = false
    @AppStorage(UserDefaults.KeysCharts.chartWidthInHours.rawValue) private var chartWidthInHours = ConstantsGlucoseChart.defaultChartWidthInHours
    @AppStorage(UserDefaults.Key.miniChartHoursToShow.rawValue) private var miniChartHoursToShow = ConstantsGlucoseChart.miniChartHoursToShow1
    @AppStorage(UserDefaults.Key.showTreatmentsOnChart.rawValue) private var hideTreatmentsOnChart = false
    @AppStorage(UserDefaults.Key.showOriginalBGReadings.rawValue) private var hideOriginalBGReadings = false
    @AppStorage(UserDefaults.Key.enableAdjustment.rawValue) private var enableAdjustment = false
    @AppStorage(UserDefaults.Key.enableSmoothing.rawValue) private var enableSmoothing = false

    private let actions: RootHomeActions
    private let chartRefreshTimer = Timer.publish(every: ConstantsHomeView.updateHomeViewIntervalInSeconds, on: .main, in: .common).autoconnect()
    private let clockRefreshTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    private static let pannedReadingDateFormatter: DateFormatter = {
        let dateFormatter = DateFormatter()
        dateFormatter.amSymbol = ConstantsUI.timeFormatAM
        dateFormatter.pmSymbol = ConstantsUI.timeFormatPM
        dateFormatter.setLocalizedDateFormatFromTemplate(ConstantsGlucoseChart.dateFormatLatestChartPointWhenPanning)

        return dateFormatter
    }()

    // MARK: - Initialisation

    init(stateModel: RootHomeStateModel, coreDataManager: CoreDataManager, nightscoutSyncManager: NightscoutSyncManager, actions: RootHomeActions) {
        let initialRange = ChartRange.closest(to: UserDefaults.standard.chartWidthInHours)

        self.stateModel = stateModel
        self.actions = actions
        self.nightscoutSyncManager = nightscoutSyncManager
        _glucoseChartStateManager = StateObject(wrappedValue: GlucoseChartStateManager(coreDataManager: coreDataManager, nightscoutSyncManager: nightscoutSyncManager))
        _miniChartStateManager = StateObject(wrappedValue: GlucoseChartStateManager(coreDataManager: coreDataManager, nightscoutSyncManager: nightscoutSyncManager))
        _scrollCoordinator = StateObject(wrappedValue: GlucoseChartScrollCoordinator(visibleTimeInterval: initialRange.timeInterval))
        _selectedRange = State(initialValue: initialRange)
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            ConstantsAppColors.background
                .ignoresSafeArea()

            rootContent()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .colorScheme(.dark)
        .onAppear {
            refreshChartRangeFromStoredSettings()
            requestChartState(forceReset: true)
            requestMiniChartState(forceReset: true)
        }
        .onDisappear {
            scrollCoordinator.stopDeceleration()
            glucoseChartStateManager.cleanUpMemory()
            miniChartStateManager.cleanUpMemory()
        }
        .onReceive(chartRefreshTimer) { _ in
            refreshCurrentTimeRangeIfNeeded(showsLoading: false)
            requestMiniChartState(forceReset: false)
        }
        .onReceive(clockRefreshTimer) { _ in
            if state.visibility.showsClock {
                stateModel.updateClock()
            }
        }
        .onReceive(scrollCoordinator.$endDate.throttle(for: .milliseconds(120), scheduler: RunLoop.main, latest: true)) { _ in
            requestChartStateIfNeeded()
        }
        .onReceive(nightscoutSyncManager.$deviceStatus.receive(on: RunLoop.main)) { _ in
            actions.refreshPumpAndLoopStatus()
        }
        .onChange(of: selectedRange) { newRange in
            chartWidthInHours = newRange.rawValue
            scrollCoordinator.setVisibleTimeInterval(newRange.timeInterval)
            requestChartState(forceReset: true)
        }
        .onChange(of: chartWidthInHours) { _ in
            refreshChartRangeFromStoredSettings()
        }
        .onChange(of: miniChartHoursToShow) { _ in
            requestMiniChartState(forceReset: true)
        }
        .onChange(of: chartSeriesSettings) { _ in
            requestChartState(forceReset: false)
        }
        .onChange(of: state.chartRevision) { _ in
            refreshChartsForDataChange()
        }
        .onChange(of: state.chartResetToNowRevision) { _ in
            resetChartsToNow()
        }
        .onChange(of: scenePhase) { newPhase in
            guard newPhase == .active else { return }

            resetChartsToNow()
        }
    }

    private func rootContent() -> some View {
        VStack(spacing: Layout.sectionSpacing) {
            RootHomeToolbarView(
                state: state,
                actions: actions,
                beginOriginalGlucosePeek: beginOriginalGlucosePeek,
                endOriginalGlucosePeek: endOriginalGlucosePeek
            )
                .frame(minHeight: Layout.toolbarMinimumHeight)

            VStack(spacing: Layout.rowSpacing) {
                HStack(spacing: 0) {
                    if state.visibility.showsPump {
                        RootHomePumpView(state: state.pump)
                            .frame(width: Layout.pumpWidth, height: Layout.glucoseRowHeight)
                    }

                    RootHomeGlucoseReadingView(state: glucoseDisplayState, isScreenLocked: state.isScreenLocked, actions: actions)
                        .frame(maxWidth: .infinity)
                }
                .frame(height: Layout.glucoseRowHeight)

                if state.visibility.showsLoop {
                    RootHomeLoopView(state: state.loop, actions: actions)
                        .frame(height: Layout.loopHeight)
                        .padding(.top, Layout.loopTopPadding)
                        .padding(.bottom, Layout.loopBottomPadding)
                }

                RootHomeMainChartView(
                    selectedRange: selectedRange,
                    chartState: visibleChartState,
                    isLoading: isLoadingChart,
                    scrollCoordinator: scrollCoordinator,
                    updateChartStateIfNeeded: requestChartStateIfNeeded,
                    finishChartScroll: { forceReset, showsLoading in
                        requestChartState(forceReset: forceReset, showsLoading: showsLoading)
                    }
                )
                .frame(maxHeight: .infinity)
                .layoutPriority(1)

                if state.visibility.showsMiniChart {
                    RootHomeMiniChartView(
                        miniChartHoursToShow: miniChartHoursToShowForChart,
                        chartState: miniChartState,
                        scrollCoordinator: scrollCoordinator,
                        updateChartStateIfNeeded: requestChartStateIfNeeded,
                        finishChartScroll: {
                            requestChartState(forceReset: false, showsLoading: false)
                        },
                        cycleMiniChartHoursToShow: cycleMiniChartHoursToShow
                    )
                    .frame(height: Layout.miniChartHeight)
                }

                if state.visibility.showsControls {
                    RootHomeSelectorView(
                        selectedRange: $selectedRange,
                        statisticsDays: state.controls.statisticsDays,
                        showsStatistics: state.visibility.showsStatistics,
                        onStatisticsDaysChanged: updateStatisticsDays
                    )
                    .frame(height: Layout.selectorHeight)
                }

                if state.visibility.showsStatistics {
                    RootHomeStatisticsView(
                        state: state.statistics,
                        action: actions.cycleStatisticsType
                    )
                        .frame(height: Layout.statisticsHeight)
                }

                if state.visibility.showsClock {
                    RootHomeClockView(text: state.controls.clockText)
                        .frame(height: Layout.clockHeight)
                }

                if state.visibility.showsSensor || state.visibility.showsDataSource {
                    VStack(spacing: Layout.bottomStatusSpacing) {
                        if state.visibility.showsSensor {
                            RootHomeSensorLifetimeView(state: state.sensor)
                                .frame(height: Layout.sensorProgressHeight)
                        }

                        if state.visibility.showsDataSource {
                            RootHomeDataSourceView(state: state.dataSource, sensorState: state.sensor, action: actions.hideFollowerUrl)
                                .frame(height: Layout.dataSourceHeight)
                        }
                    }
                }
            }
            .frame(maxHeight: .infinity, alignment: .top)
        }
        .padding(.horizontal, Layout.screenHorizontalMargin)
        .frame(maxHeight: .infinity, alignment: .top)
    }

    // MARK: - Derived State

    private var state: RootHomeState {
        stateModel.state
    }

    private var startDate: Date {
        scrollCoordinator.startDate
    }

    private var endDate: Date {
        scrollCoordinator.endDate
    }

    private var visibleChartState: GlucoseChartState {
        var state = glucoseChartStateManager.state
        state.startDate = startDate
        state.endDate = endDate

        return state
    }

    private var glucoseDisplayState: RootHomeGlucoseState {
        guard !scrollCoordinator.isShowingCurrentTimeRange, let pannedReading = latestVisibleReadingAtChartEndDate() else {
            return state.glucose
        }

        let isMgDl = UserDefaults.standard.bloodGlucoseUnitIsMgDl
        let valueInUserUnit = pannedReading.valueInMgDl.mgDlToMmol(mgDl: isMgDl).bgValueRounded(mgDl: isMgDl)

        // While the chart is scrolled back, the top reading shows the latest visible chart point,
        // uses the point timestamp instead of
        // "minutes ago", clears the delta, and marks the value as historical with strikethrough.
        return RootHomeGlucoseState(
            valueText: valueInUserUnit.bgValueToString(mgDl: isMgDl),
            valueColor: ConstantsAppColors.disabledText,
            valueHasStrikethrough: true,
            minutesText: Self.pannedReadingDateFormatter.string(from: pannedReading.date),
            minutesAgoText: "",
            minutesColor: ConstantsAppColors.urgent,
            deltaText: "",
            deltaUnitText: "",
            deltaColor: ConstantsAppColors.primaryText
        )
    }

    private var miniChartState: GlucoseChartState {
        let state = miniChartStateManager.state

        return GlucoseChartState(
            startDate: state.startDate,
            endDate: state.endDate,
            dataStartDate: state.dataStartDate,
            dataEndDate: state.dataEndDate,
            bgReadingValues: state.bgReadingValues,
            bgReadingDates: state.bgReadingDates,
            additionalBgReadingDataSets: [],
            calibrationPoints: [],
            treatmentPoints: GlucoseChartTreatmentPoints(),
            minimumChartValueInMgDl: ConstantsGlucoseChart.absoluteMinimumChartValueInMgdl,
            overlayWindowStartDate: startDate,
            overlayWindowEndDate: endDate
        )
    }

    private var showTreatments: Bool {
        !hideTreatmentsOnChart
    }

    private var showOriginalBGReadings: Bool {
        !hideOriginalBGReadings && postProcessingEnabled
    }

    private var postProcessingEnabled: Bool {
        enableAdjustment || enableSmoothing
    }

    private var chartSeriesSettings: ChartSeriesSettings {
        ChartSeriesSettings(showTreatments: showTreatments, showOriginalBGReadings: showOriginalBGReadings)
    }

    private var miniChartHoursToShowForChart: Double {
        miniChartHoursToShow == 0 ? ConstantsGlucoseChart.miniChartHoursToShow1 : miniChartHoursToShow
    }

    private func latestVisibleReadingAtChartEndDate() -> (date: Date, valueInMgDl: Double)? {
        let readings = zip(glucoseChartStateManager.state.bgReadingDates, glucoseChartStateManager.state.bgReadingValues)

        return readings
            .filter { date, value in
                value > 0 && date >= startDate && date <= endDate
            }
            .max { lhs, rhs in
                lhs.0 < rhs.0
            }
            .map { (date: $0.0, valueInMgDl: $0.1) }
    }

    // MARK: - Actions

    private func refreshChartRangeFromStoredSettings() {
        let range = ChartRange.closest(to: chartWidthInHours == 0 ? ConstantsGlucoseChart.defaultChartWidthInHours : chartWidthInHours)

        if chartWidthInHours != range.rawValue {
            chartWidthInHours = range.rawValue
        }

        if range != selectedRange {
            selectedRange = range
        }
    }

    private func refreshCurrentTimeRangeIfNeeded(showsLoading: Bool = true) {
        guard scrollCoordinator.refreshCurrentTimeRangeIfNeeded() else { return }

        requestChartState(forceReset: false, showsLoading: showsLoading)
    }

    private func requestChartStateIfNeeded() {
        guard !isBackgroundLoadingChart else { return }

        let state = glucoseChartStateManager.state
        let preloadInterval = min(max(abs(selectedRange.timeInterval) * 0.4, .hours(1)), .hours(3))
        let needsLeadingData = startDate < state.dataStartDate.addingTimeInterval(preloadInterval)
        let canLoadTrailingData = state.dataEndDate < Date().addingTimeInterval(-60)
        let needsTrailingData = canLoadTrailingData && endDate > state.dataEndDate.addingTimeInterval(-preloadInterval)

        guard needsLeadingData || needsTrailingData else { return }

        requestChartState(forceReset: false, showsLoading: false)
    }

    private func requestChartState(forceReset: Bool, showsLoading: Bool = true, refreshCachedData: Bool = false) {
        if showsLoading {
            isLoadingChart = true
            isBackgroundLoadingChart = false
        } else {
            guard !isBackgroundLoadingChart || refreshCachedData else { return }

            isBackgroundLoadingChart = true
        }

        glucoseChartStateManager.updateState(endDate: endDate, startDate: startDate, forceReset: forceReset, refreshCachedData: refreshCachedData, showTreatments: showTreatments, showOriginalReadingsOnly: showOriginalBGReadingsOnly) { _ in
            isLoadingChart = false
            isBackgroundLoadingChart = false
        }
    }

    private func requestMiniChartState(forceReset: Bool, refreshCachedData: Bool = false) {
        let endDate = Date()
        let startDate = endDate.addingTimeInterval(.hours(-miniChartHoursToShowForChart))

        miniChartStateManager.updateState(endDate: endDate, startDate: startDate, forceReset: forceReset, refreshCachedData: refreshCachedData, showTreatments: false)
    }

    private func refreshChartsForDataChange() {
        refreshMainChartForDataChange()
        requestMiniChartState(forceReset: false, refreshCachedData: true)
    }

    private func resetChartsToNow() {
        scrollCoordinator.resetToNow()
        requestChartState(forceReset: false, showsLoading: false, refreshCachedData: true)
        requestMiniChartState(forceReset: false, refreshCachedData: true)
    }

    private func refreshMainChartForDataChange() {
        guard scrollCoordinator.isShowingCurrentTimeRange else { return }

        // Move the live window to the current time before loading the new tail. A chart deliberately
        // scrolled back by the user remains fixed.
        _ = scrollCoordinator.refreshCurrentTimeRangeIfNeeded()

        requestChartState(forceReset: false, showsLoading: false, refreshCachedData: true)
    }

    private func cycleMiniChartHoursToShow() {
        switch miniChartHoursToShowForChart {
        case ConstantsGlucoseChart.miniChartHoursToShow1:
            miniChartHoursToShow = ConstantsGlucoseChart.miniChartHoursToShow2
        case ConstantsGlucoseChart.miniChartHoursToShow2:
            miniChartHoursToShow = ConstantsGlucoseChart.miniChartHoursToShow3
        case ConstantsGlucoseChart.miniChartHoursToShow3:
            miniChartHoursToShow = ConstantsGlucoseChart.miniChartHoursToShow4
        default:
            miniChartHoursToShow = ConstantsGlucoseChart.miniChartHoursToShow1
        }
    }

    private func updateStatisticsDays(_ days: Int) {
        UserDefaults.standard.daysToUseStatistics = days
        actions.statisticsDaysChanged(days)
    }

    private func beginOriginalGlucosePeek() {
        guard postProcessingEnabled, !showOriginalBGReadingsOnly else { return }

        showOriginalBGReadingsOnly = true
        requestChartState(forceReset: false, showsLoading: false)
    }

    private func endOriginalGlucosePeek() {
        guard showOriginalBGReadingsOnly else { return }

        showOriginalBGReadingsOnly = false
        requestChartState(forceReset: false, showsLoading: false)
    }
}

// MARK: - Toolbar

// MARK: - Toolbar

/// Home toolbar with commands supplied by the tab and application coordinator.
private struct RootHomeToolbarView: View {
    let state: RootHomeState
    let actions: RootHomeActions
    let beginOriginalGlucosePeek: () -> Void
    let endOriginalGlucosePeek: () -> Void

    @State private var originalGlucosePeekIsActive = false
    @State private var shouldIgnoreNextPostProcessingTap = false

    var body: some View {
        HStack(spacing: 0) {
            toolbarButton(systemImage: state.controls.snoozeSystemImage, label: Texts_HomeView.snoozeButton, action: actions.showSnooze)
            toolbarButton(systemImage: "drop", label: "BgReadings", action: actions.showBgReadings)
            toolbarButton(systemImage: "sensor.tag.radiowaves.forward", label: Texts_HomeView.sensor, action: actions.showSensorManagement)
                .disabled(!state.controls.sensorButtonEnabled)
                .opacity(state.controls.sensorButtonEnabled ? 1 : 0.35)
            postProcessingToolbarButton()
            toolbarButton(systemImage: "rectangle.3.group", label: "Show/Hide", action: actions.showHideItems)
            toolbarButton(systemImage: state.isScreenLocked ? "lock.fill" : "lock", label: Texts_HomeView.lockButton, action: actions.toggleScreenLock)
                .foregroundStyle(state.isScreenLocked ? ConstantsAppColors.toolbarLockedIcon : ConstantsAppColors.toolbarIcon)
        }
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity)
        .frame(height: RootHomeView.Layout.toolbarMinimumHeight)
    }

    private func postProcessingToolbarButton() -> some View {
        Image(systemName: state.controls.postProcessingSystemImage)
            .font(.system(size: 23, weight: .regular))
            .frame(width: 38, height: 38)
            .contentShape(Rectangle())
            .onTapGesture {
                guard !shouldIgnoreNextPostProcessingTap else {
                    shouldIgnoreNextPostProcessingTap = false
                    return
                }

                actions.showBgAdjustments()
            }
            .simultaneousGesture(originalGlucosePeekGesture())
            .foregroundStyle(ConstantsAppColors.toolbarIcon)
            .frame(maxWidth: .infinity)
            .accessibilityLabel(Texts_HomeView.postProcessingTitle)
    }

    private func originalGlucosePeekGesture() -> some Gesture {
        LongPressGesture(minimumDuration: 0.35)
            .sequenced(before: DragGesture(minimumDistance: 0))
            .onChanged { value in
                guard case .second(true, _) = value else { return }
                guard state.controls.postProcessingEnabled, !originalGlucosePeekIsActive else { return }

                originalGlucosePeekIsActive = true
                shouldIgnoreNextPostProcessingTap = true
                actions.originalGlucosePeekActivated()
                beginOriginalGlucosePeek()
            }
            .onEnded { _ in
                guard originalGlucosePeekIsActive else { return }

                originalGlucosePeekIsActive = false
                endOriginalGlucosePeek()

                // Do not let release of a completed peek also open the adjustments screen. Clear the
                // guard shortly afterwards if no tap event consumed it.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                    shouldIgnoreNextPostProcessingTap = false
                }
            }
    }

    private func toolbarButton(systemImage: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 23, weight: .regular))
                .frame(width: 38, height: 38)
        }
        .buttonStyle(.plain)
        .foregroundStyle(ConstantsAppColors.toolbarIcon)
        .frame(maxWidth: .infinity)
        .accessibilityLabel(label)
    }
}

// MARK: - Pump and Loop

// MARK: - Current Status

/// Compact pump status displayed beside the current glucose reading.
private struct RootHomePumpView: View {
    let state: RootHomePumpState

    var body: some View {
        VStack(spacing: 0) {
            RootHomeHorizontalMetricView(metric: state.basal)
            RootHomeHorizontalMetricView(metric: state.reservoir)
            RootHomeHorizontalMetricView(metric: state.battery)
            RootHomeHorizontalMetricView(metric: state.cage)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(ConstantsAppColors.homePanelBackground)
        .clipShape(RoundedRectangle(cornerRadius: ConstantsHomeView.standardCornerRadius, style: .continuous))
    }
}

/// Loop status row displayed below the pump and glucose values.
private struct RootHomeLoopView: View {
    let state: RootHomeLoopState
    let actions: RootHomeActions

    var body: some View {
        Button(action: actions.showAIDStatus) {
            HStack(spacing: 0) {
                RootHomeInlineMetricView(metric: state.iob)
                Spacer(minLength: 16)
                RootHomeInlineMetricView(metric: state.cob)
                Spacer(minLength: 16)

                HStack(spacing: 6) {
                    if state.showsUploaderBattery {
                        Image(systemName: state.uploaderBatterySystemImage)
                            .font(.system(size: 14))
                            .foregroundStyle(state.uploaderBatteryColor)
                    }

                    if state.showsActivityIndicator {
                        ProgressView()
                            .scaleEffect(0.75)
                            .tint(ConstantsAppColors.primaryText)
                    }

                    if let statusSystemImage = state.statusSystemImage {
                        Image(systemName: statusSystemImage)
                            .font(.system(size: RootHomeView.Layout.loopStatusSymbolSize, weight: .black))
                            .symbolRenderingMode(.monochrome)
                            .foregroundStyle(state.statusColor)
                    }

                    Text(state.statusTitle)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(state.statusColor)
                        .lineLimit(1)
                        .minimumScaleFactor(0.65)

                    if state.showsStatusTimeAgo {
                        Text(state.statusTimeAgo)
                            .font(.system(size: 16))
                            .foregroundStyle(ConstantsAppColors.primaryText)
                            .monospacedDigit()
                            .lineLimit(1)
                            .minimumScaleFactor(0.65)
                    }
                }
            }
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(ConstantsAppColors.homePanelBackground)
            .clipShape(RoundedRectangle(cornerRadius: ConstantsHomeView.standardCornerRadius, style: .continuous))
        }
        .buttonStyle(.plain)
        .transaction { transaction in
            // Calculation updates replace label text immediately. Threshold colors animate separately.
            transaction.animation = nil
        }
    }
}

/// One compact title and value pair used inside the pump panel.
private struct RootHomeInlineMetricView: View {
    let metric: RootHomeMetricState

    var body: some View {
        HStack(spacing: 6) {
            Text(metric.title)
                .font(.system(size: 16))
                .foregroundStyle(ConstantsAppColors.secondaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(metric.value)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(metric.valueColor)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.65)
        }
    }
}

/// One horizontal title and value pair used by the loop row.
private struct RootHomeHorizontalMetricView: View {
    let metric: RootHomeMetricState

    var body: some View {
        HStack(spacing: 4) {
            Text(metric.title)
                .font(.system(size: 15))
                .foregroundStyle(ConstantsAppColors.secondaryText)
                .lineLimit(1)

            Spacer(minLength: 4)

            Text(metric.value)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(metric.valueColor)
                .monospacedDigit()
                .lineLimit(1)
        }
        .frame(maxHeight: .infinity)
    }
}

// MARK: - Glucose

/// Current glucose value, age and delta presentation.
private struct RootHomeGlucoseReadingView: View {
    let state: RootHomeGlucoseState
    let isScreenLocked: Bool
    let actions: RootHomeActions

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                HStack(spacing: 4) {
                    Text(state.minutesText)
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(state.minutesColor)
                        .monospacedDigit()

                    Text(state.minutesAgoText)
                        .font(.system(size: 20))
                        .foregroundStyle(ConstantsAppColors.secondaryText)
                }

                Spacer(minLength: 8)

                HStack(spacing: 4) {
                    Text(state.deltaText)
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(state.deltaColor)
                        .monospacedDigit()

                    Text(state.deltaUnitText)
                        .font(.system(size: 20))
                        .foregroundStyle(ConstantsAppColors.secondaryText)
                }
            }
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .allowsTightening(true)
            .frame(height: RootHomeView.Layout.glucoseInfoRowHeight)
            .padding(.horizontal, RootHomeView.Layout.horizontalMargin)

            Text(state.valueText)
                .font(.system(size: isScreenLocked ? 120 : 78, weight: .medium))
                .foregroundStyle(state.valueColor)
                .strikethrough(state.valueHasStrikethrough, color: state.valueColor)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.2)
                .allowsTightening(true)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .onTapGesture(perform: actions.toggleExpandedAIDInfo)
                .onLongPressGesture(minimumDuration: 0.5, perform: actions.keepScreenAwake)
        }
    }
}

// MARK: - Charts

/// Main interactive chart with loading state and the reading shown at the panned end date.
private struct RootHomeMainChartView: View {
    let selectedRange: RootHomeView.ChartRange
    let chartState: GlucoseChartState
    let isLoading: Bool
    let scrollCoordinator: GlucoseChartScrollCoordinator
    let updateChartStateIfNeeded: () -> Void
    let finishChartScroll: (_ forceReset: Bool, _ showsLoading: Bool) -> Void

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
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
                    hoursToShowScalingHours: selectedRange.rawValue,
                    glucoseCircleDiameterScalingHours: selectedRange.glucoseCircleDiameterScalingHours,
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
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            scrollCoordinator.updateVisibleRange(value: value, chartWidth: geometry.size.width)
                            updateChartStateIfNeeded()
                        }
                        .onEnded { value in
                            scrollCoordinator.finishUpdatingVisibleRange(value: value, chartWidth: geometry.size.width)
                            finishChartScroll(false, false)
                        }
                )
                .simultaneousGesture(TapGesture(count: 2).onEnded {
                    scrollCoordinator.resetToNow()
                    finishChartScroll(true, true)
                })
                .clipped()

                if isLoading {
                    ProgressView()
                        .padding(8)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                        .allowsHitTesting(false)
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .topLeading)
        }
    }
}

/// Historical overview chart and the active main-chart window.
private struct RootHomeMiniChartView: View {
    let miniChartHoursToShow: Double
    let chartState: GlucoseChartState
    let scrollCoordinator: GlucoseChartScrollCoordinator
    let updateChartStateIfNeeded: () -> Void
    let finishChartScroll: () -> Void
    let cycleMiniChartHoursToShow: () -> Void

    /// `nil` until a new drag is classified. The result is then held for the whole gesture because
    /// the active window moves away from its original touch point during a valid drag.
    @State private var activeWindowDragIsEnabled: Bool?

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                GlucoseChartView(
                    glucoseChartType: .miniChart,
                    bgReadingValues: nil,
                    bgReadingDates: nil,
                    isMgDl: UserDefaults.standard.bloodGlucoseUnitIsMgDl,
                    urgentLowLimitInMgDl: UserDefaults.standard.urgentLowMarkValue,
                    lowLimitInMgDl: UserDefaults.standard.lowMarkValue,
                    highLimitInMgDl: UserDefaults.standard.highMarkValue,
                    urgentHighLimitInMgDl: UserDefaults.standard.urgentHighMarkValue,
                    liveActivityType: nil,
                    hoursToShowScalingHours: miniChartHoursToShow,
                    glucoseCircleDiameterScalingHours: miniChartHoursToShow,
                    overrideChartHeight: geometry.size.height,
                    overrideChartWidth: geometry.size.width,
                    highContrast: nil,
                    chartState: chartState
                )
                .transaction { transaction in
                    transaction.animation = nil
                }
                .contentShape(Rectangle())
                // Treat the fixed mini-chart as a scrubber: moving its active window updates the shared
                // coordinator and therefore the main chart, while the overview data stays stationary.
                .gesture(
                    DragGesture(minimumDistance: 5)
                        .onChanged { value in
                            if activeWindowDragIsEnabled == nil {
                                activeWindowDragIsEnabled = activeWindowContains(xPosition: value.startLocation.x, chartWidth: geometry.size.width)
                            }

                            guard activeWindowDragIsEnabled == true else { return }

                            scrollCoordinator.updateVisibleRangeFromOverview(
                                value: value,
                                overviewStartDate: chartState.startDate,
                                overviewEndDate: chartState.endDate,
                                chartWidth: geometry.size.width
                            )
                            updateChartStateIfNeeded()
                        }
                        .onEnded { value in
                            let shouldFinishDrag = activeWindowDragIsEnabled ?? activeWindowContains(xPosition: value.startLocation.x, chartWidth: geometry.size.width)
                            activeWindowDragIsEnabled = nil

                            guard shouldFinishDrag else { return }

                            scrollCoordinator.finishUpdatingVisibleRangeFromOverview(
                                value: value,
                                overviewStartDate: chartState.startDate,
                                overviewEndDate: chartState.endDate,
                                chartWidth: geometry.size.width
                            )
                            finishChartScroll()
                        }
                )
                .simultaneousGesture(TapGesture(count: 2).onEnded(cycleMiniChartHoursToShow))
                .clipped()
            }
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .leading)
        }
    }

    /// Converts the active window's dates into the fixed mini-chart's horizontal coordinate space.
    private func activeWindowContains(xPosition: CGFloat, chartWidth: CGFloat) -> Bool {
        guard chartWidth > 0,
              let activeWindowStartDate = chartState.overlayWindowStartDate,
              let activeWindowEndDate = chartState.overlayWindowEndDate,
              activeWindowStartDate < activeWindowEndDate else {
            return false
        }

        let overviewStartDate = chartState.startDate
        let overviewEndDate = chartState.endDate
        let overviewTimeInterval = overviewEndDate.timeIntervalSince(overviewStartDate)
        let visibleActiveStartDate = max(activeWindowStartDate, overviewStartDate)
        let visibleActiveEndDate = min(activeWindowEndDate, overviewEndDate)

        guard overviewTimeInterval > 0, visibleActiveStartDate < visibleActiveEndDate else { return false }

        let activeStartX = CGFloat(visibleActiveStartDate.timeIntervalSince(overviewStartDate) / overviewTimeInterval) * chartWidth
        let activeEndX = CGFloat(visibleActiveEndDate.timeIntervalSince(overviewStartDate) / overviewTimeInterval) * chartWidth

        return xPosition >= activeStartX && xPosition <= activeEndX
    }
}

// MARK: - Controls

/// Quiet, direct controls for the statistics calculation period and main-chart width.
private struct RootHomeSelectorView: View {
    @Binding var selectedRange: RootHomeView.ChartRange
    let statisticsDays: Int
    let showsStatistics: Bool
    let onStatisticsDaysChanged: (Int) -> Void

    private let statisticsOptions = [0, 1, 7, 30, 90]

    var body: some View {
        HStack(spacing: 4) {
            if showsStatistics {
                HStack(spacing: 2) {
                    ForEach(statisticsOptions, id: \.self) { days in
                        RootHomeSelectorButton(
                            title: statisticsTitle(for: days),
                            accessibilityLabel: Texts_SettingsView.labelDaysToUseStatisticsTitle,
                            accessibilityValue: statisticsAccessibilityValue(for: days),
                            indicatorDirection: .down,
                            isSelected: statisticsDays == days,
                            action: { onStatisticsDaysChanged(days) }
                        )
                    }
                }
                .fixedSize(horizontal: true, vertical: false)
                .frame(maxWidth: .infinity, alignment: .leading)

                Color.clear
                    .frame(width: 9, height: 14)
                    .accessibilityHidden(true)
            }

            HStack(spacing: 2) {
                ForEach(RootHomeView.ChartRange.allCases) { range in
                    RootHomeSelectorButton(
                        title: range.title,
                        accessibilityLabel: Texts_HomeView.showHideGlucoseChartTitle,
                        accessibilityValue: "\(Int(range.rawValue)) \(Texts_Common.hours)",
                        indicatorDirection: .up,
                        isSelected: selectedRange == range,
                        action: { selectedRange = range }
                    )
                }
            }
            .fixedSize(horizontal: true, vertical: false)
            .frame(maxWidth: .infinity, alignment: showsStatistics ? .trailing : .center)
        }
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func statisticsTitle(for days: Int) -> String {
        RootHomeStatisticsPeriodText.title(for: days)
    }

    private func statisticsAccessibilityValue(for days: Int) -> String {
        switch days {
        case 0:
            return Texts_Common.today
        case 1:
            return "1 \(Texts_Common.day)"
        default:
            return "\(days) \(Texts_Common.days)"
        }
    }
}

/// One label-only selector item. Its indicator points toward the content controlled by the group.
private struct RootHomeSelectorButton: View {
    let title: String
    let accessibilityLabel: String
    let accessibilityValue: String
    let indicatorDirection: RootHomeSelectorIndicator.Direction
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? ConstantsAppColors.primaryText : ConstantsAppColors.tertiaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .allowsTightening(true)
                .frame(minWidth: 32, maxHeight: .infinity)
                .overlay(alignment: indicatorDirection == .up ? .top : .bottom) {
                    RootHomeSelectorIndicator(direction: indicatorDirection)
                        .fill(ConstantsGlucoseChartSwiftUI.overlayWindowEdgeColor)
                        .frame(width: 16, height: 6)
                        .opacity(isSelected ? 1 : 0)
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(accessibilityValue)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// A shallow directional marker linking a selector group to the content above or below it.
private struct RootHomeSelectorIndicator: Shape {
    enum Direction {
        case up
        case down
    }

    let direction: Direction

    func path(in rect: CGRect) -> Path {
        var path = Path()

        switch direction {
        case .up:
            path.move(to: CGPoint(x: rect.midX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        case .down:
            path.move(to: CGPoint(x: rect.minX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        }

        path.closeSubpath()
        return path
    }
}

// MARK: - Statistics

/// Statistics values and time-in-range pie chart for the selected period.
private struct RootHomeStatisticsView: View {
    let state: RootHomeStatisticsState
    let action: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            RootHomeStatisticsColumn(top: state.low, bottom: state.average, limitText: state.lowLimitText)
            RootHomeStatisticsColumn(top: state.inRange, bottom: state.a1c, limitText: "")
            RootHomeStatisticsColumn(top: state.high, bottom: state.cv, limitText: state.highLimitText)

            VStack(spacing: 6) {
                ZStack {
                    RootHomePieChartView(
                        low: state.low.percentValue,
                        inRange: state.inRange.percentValue,
                        high: state.high.percentValue
                    )

                    if state.showsActivityIndicator {
                        ProgressView()
                            .tint(ConstantsAppColors.primaryText)
                    }
                }
                .frame(height: 52)

                Text(state.timePeriodText)
                    .font(.caption2)
                    .foregroundStyle(ConstantsAppColors.tertiaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 9)
        .contentShape(Rectangle())
        .onTapGesture(count: 2, perform: action)
        .transaction { transaction in
            // Calculation updates replace label text immediately. Threshold colors animate separately.
            transaction.animation = nil
        }
    }

}

/// Vertical group of statistics with matching column alignment.
private struct RootHomeStatisticsColumn: View {
    let top: RootHomeMetricState
    let bottom: RootHomeMetricState
    let limitText: String

    var body: some View {
        VStack(spacing: 10) {
            RootHomeStatisticsMetricView(metric: top, limitText: limitText)
            RootHomeStatisticsMetricView(metric: bottom)
        }
        .frame(maxWidth: .infinity)
    }
}

/// One statistics title, optional limit and calculated value.
private struct RootHomeStatisticsMetricView: View {
    let metric: RootHomeMetricState
    var limitText = ""

    var body: some View {
        VStack(spacing: 2) {
            HStack(spacing: 2) {
                Text(metric.title)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(ConstantsAppColors.primaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)

                if !limitText.isEmpty {
                    Text(limitText)
                        .font(.system(size: 12))
                        .foregroundStyle(ConstantsAppColors.secondaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.65)
                }
            }
            .frame(maxWidth: .infinity, alignment: .center)

            Text(metric.value)
                .font(.system(size: 12))
                .foregroundStyle(metric.valueColor)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.65)
                .frame(maxWidth: .infinity, alignment: .center)
        }
    }
}

/// Time-in-range pie chart drawn from low, in-range and high percentages.
private struct RootHomePieChartView: View {
    let low: Double
    let inRange: Double
    let high: Double

    var body: some View {
        ZStack {
            if total > 0 {
                RootHomePieSlice(startAngle: .degrees(referenceAngle), endAngle: .degrees(referenceAngle + inRangeAngle))
                    .fill(ConstantsAppColors.statisticsInRange)

                RootHomePieSlice(startAngle: .degrees(referenceAngle + inRangeAngle), endAngle: .degrees(referenceAngle + inRangeAngle + lowAngle))
                    .fill(ConstantsAppColors.statisticsLow)

                RootHomePieSlice(startAngle: .degrees(referenceAngle + inRangeAngle + lowAngle), endAngle: .degrees(referenceAngle + 360))
                    .fill(ConstantsAppColors.statisticsHigh)
            }
        }
        .frame(width: 52, height: 52)
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

/// One percentage slice in the Home time-in-range pie chart.
private struct RootHomePieSlice: Shape {
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

private extension RootHomeMetricState {
    var percentValue: Double {
        Double(value.replacingOccurrences(of: "%", with: "")) ?? 0
    }
}

// MARK: - Sensor and Data Source

// MARK: - Footer Status

/// Sensor age and directional lifetime progress indicator.
private struct RootHomeSensorLifetimeView: View {
    let state: RootHomeSensorState

    var body: some View {
        GeometryReader { geometry in
            let progress = min(max(state.progress, 0), 1)
            let arrowPosition = min(max(progress * geometry.size.width, 7), geometry.size.width - 7)

            ProgressView(value: progress)
                .progressViewStyle(.linear)
                .tint(state.progressColor)
                .frame(height: 5)
                .overlay {
                    Image(systemName: state.countsDown ? "arrowtriangle.left.fill" : "arrowtriangle.right.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .scaleEffect(x: 0.75, y: 0.95)
                        .foregroundStyle(state.progressColor)
                        .opacity(0.85)
                        .position(x: arrowPosition, y: 2.5)
                }
                .frame(maxHeight: .infinity, alignment: .center)
        }
        .padding(.horizontal, 10)
    }
}

/// Active data source, connection state and follower keep-alive status.
private struct RootHomeDataSourceView: View {
    let state: RootHomeDataSourceState
    let sensorState: RootHomeSensorState
    let action: () -> Void

    var body: some View {
        HStack(spacing: 5) {
            HStack(spacing: 5) {
//                if state.showsKeepAliveIcon {
//                    Image(systemName: state.keepAliveSystemImage)
//                        .font(.system(size: 15))
//                        .foregroundStyle(state.keepAliveColor)
//                }

                if state.showsConnectionIcon {
                    Circle()
                        .fill(state.connectionColor)
                        .frame(width: 8, height: 8)
                }

                Text(state.title)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(ConstantsAppColors.dataSourceText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .layoutPriority(1)

            Spacer(minLength: 8)

            HStack(spacing: 0) {
                Text(dataSourceDetailText)
                    .font(.system(size: 13))
                    .foregroundStyle(dataSourceDetailColor)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                if let maxAgeText {
                    Text(maxAgeText)
                        .font(.system(size: 13))
                        .foregroundStyle(ConstantsAppColors.dataSourceText)
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .onTapGesture(count: 2, perform: action)
    }

    private var dataSourceDetailText: String {
        sensorState.currentAge.isEmpty ? state.detail : sensorState.currentAge
    }

    private var maxAgeText: String? {
        sensorState.currentAge.isEmpty || sensorState.maxAge.isEmpty || sensorState.countsDown ? nil : sensorState.maxAge
    }

    private var dataSourceDetailColor: Color {
        sensorState.currentAge.isEmpty ? state.detailColor : sensorState.currentAgeColor
    }
}

// MARK: - Clock

/// Large clock used by the locked night layout.
private struct RootHomeClockView: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 120))
            .foregroundStyle(ConstantsAppColors.clockText)
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.2)
            .frame(maxWidth: .infinity)
    }
}
