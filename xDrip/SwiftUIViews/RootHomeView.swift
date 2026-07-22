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
    @State private var selectedRange: RootHomeChartRange
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
        let initialRange = RootHomeChartRange.closest(to: UserDefaults.standard.chartWidthInHours)

        self.stateModel = stateModel
        self.actions = actions
        self.nightscoutSyncManager = nightscoutSyncManager
        // only the main chart can show sensor noise background bands. The mini-chart keeps the
        // same clean overview behaviour and does not need the extra Core Data fetch.
        _glucoseChartStateManager = StateObject(wrappedValue: GlucoseChartStateManager(coreDataManager: coreDataManager, nightscoutSyncManager: nightscoutSyncManager, showsSensorNoiseBands: true))
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
        VStack(spacing: RootHomeLayout.sectionSpacing) {
            RootHomeToolbarView(
                state: state,
                actions: actions,
                beginOriginalGlucosePeek: beginOriginalGlucosePeek,
                endOriginalGlucosePeek: endOriginalGlucosePeek
            )
                .frame(minHeight: RootHomeLayout.toolbarMinimumHeight)

            VStack(spacing: RootHomeLayout.rowSpacing) {
                HStack(spacing: 0) {
                    if state.visibility.showsPump {
                        RootHomePumpView(state: state.pump)
                            .frame(width: RootHomeLayout.pumpWidth, height: RootHomeLayout.glucoseRowHeight)
                    }

                    RootHomeGlucoseReadingView(state: glucoseDisplayState, isScreenLocked: state.isScreenLocked, actions: actions)
                        .frame(maxWidth: .infinity)
                }
                .frame(height: RootHomeLayout.glucoseRowHeight)

                if state.visibility.showsLoop {
                    RootHomeLoopView(state: state.loop, actions: actions)
                        .frame(height: RootHomeLayout.loopHeight)
                        .padding(.top, RootHomeLayout.loopTopPadding)
                        .padding(.bottom, RootHomeLayout.loopBottomPadding)
                }

                if state.sensorNoise.showsWarning {
                    RootHomeSensorNoiseWarningView(state: state.sensorNoise, action: actions.showSensorManagement)
                        .frame(height: RootHomeLayout.sensorNoiseWarningHeight)
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
                    .frame(height: RootHomeLayout.miniChartHeight)
                }

                if state.visibility.showsControls {
                    RootHomeSelectorView(
                        selectedRange: $selectedRange,
                        statisticsDays: state.controls.statisticsDays,
                        showsStatistics: state.visibility.showsStatistics,
                        onStatisticsDaysChanged: updateStatisticsDays
                    )
                    .frame(height: RootHomeLayout.selectorHeight)
                }

                if state.visibility.showsStatistics {
                    RootHomeStatisticsView(
                        state: state.statistics,
                        action: actions.cycleStatisticsType
                    )
                        .frame(height: RootHomeLayout.statisticsHeight)
                }

                if state.visibility.showsClock {
                    RootHomeClockView(text: state.controls.clockText)
                        .frame(height: RootHomeLayout.clockHeight)
                }

                if state.visibility.showsSensor || state.visibility.showsDataSource {
                    VStack(spacing: RootHomeLayout.bottomStatusSpacing) {
                        if state.visibility.showsSensor {
                            RootHomeSensorLifetimeView(state: state.sensor)
                                .frame(height: RootHomeLayout.sensorProgressHeight)
                        }

                        if state.visibility.showsDataSource {
                            RootHomeDataSourceView(
                                state: state.dataSource,
                                sensorState: state.sensor,
                                sensorNoiseState: state.sensorNoise,
                                action: actions.hideFollowerUrl
                            )
                                .frame(height: RootHomeLayout.dataSourceHeight)
                        }
                    }
                }
            }
            .frame(maxHeight: .infinity, alignment: .top)
        }
        .padding(.horizontal, RootHomeLayout.screenHorizontalMargin)
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
        // uses the point timestamp instead of "minutes ago", clears the delta, and marks the value
        // as historical with strikethrough.
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
            backgroundBands: nil,
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
        let range = RootHomeChartRange.closest(to: chartWidthInHours == 0 ? ConstantsGlucoseChart.defaultChartWidthInHours : chartWidthInHours)

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
