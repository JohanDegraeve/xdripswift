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

    private enum Layout {
        static let sectionSpacing: CGFloat = 10
        static let rowSpacing: CGFloat = 9
        static let bottomRowSpacing: CGFloat = 3
        static let screenHorizontalMargin: CGFloat = 12
        static let glucoseStatusRowHeight: CGFloat = 120
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
    @ObservedObject private var sensorHealthIssueManager: SensorHealthIssueManager
    @StateObject private var glucoseChartStateManager: GlucoseChartStateManager
    @StateObject private var miniChartStateManager: GlucoseChartStateManager
    @StateObject private var scrollCoordinator: GlucoseChartScrollCoordinator
    @StateObject private var historicalDataCache: RootHomeHistoricalDataCache

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

    init(
        stateModel: RootHomeStateModel,
        sensorHealthIssueManager: SensorHealthIssueManager,
        coreDataManager: CoreDataManager,
        nightscoutSyncManager: NightscoutSyncManager,
        actions: RootHomeActions
    ) {
        let initialRange = RootHomeChartRange.closest(to: UserDefaults.standard.chartWidthInHours)

        self.stateModel = stateModel
        self.sensorHealthIssueManager = sensorHealthIssueManager
        self.actions = actions
        self.nightscoutSyncManager = nightscoutSyncManager
        // only the main chart can show sensor noise background bands. The mini-chart keeps the
        // same clean overview behaviour and does not need the extra Core Data fetch.
        _glucoseChartStateManager = StateObject(wrappedValue: GlucoseChartStateManager(coreDataManager: coreDataManager, nightscoutSyncManager: nightscoutSyncManager, showsSensorNoiseBands: true))
        _miniChartStateManager = StateObject(wrappedValue: GlucoseChartStateManager(coreDataManager: coreDataManager, nightscoutSyncManager: nightscoutSyncManager))
        _scrollCoordinator = StateObject(wrappedValue: GlucoseChartScrollCoordinator(visibleTimeInterval: initialRange.timeInterval))
        _historicalDataCache = StateObject(wrappedValue: RootHomeHistoricalDataCache(coreDataManager: coreDataManager))
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
            historicalDataCache.cleanUpMemory()
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
        .onReceive(scrollCoordinator.$endDate.throttle(for: .milliseconds(120), scheduler: RunLoop.main, latest: true)) { endDate in
            requestChartStateIfNeeded()
            prepareHistoricalDataIfNeeded(at: endDate)
        }
        .onReceive(nightscoutSyncManager.$deviceStatus.receive(on: RunLoop.main)) { _ in
            if scrollCoordinator.isShowingCurrentTimeRange {
                historicalDataCache.reset()
            }
            actions.refreshPumpAndLoopStatus()
        }
        .onChange(of: selectedRange) { newRange in
            chartWidthInHours = newRange.rawValue
            scrollCoordinator.setVisibleTimeInterval(newRange.timeInterval)
            requestChartState(forceReset: true)
            prepareHistoricalDataIfNeeded(at: endDate)
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

            // Home owns the visible explanation for every active sensor-health episode. Keeping the
            // banner inside this layout makes it dismissible and removes all reserved space when it
            // is absent. The user chooses when to open the relevant detail view from here.
            if let issue = sensorHealthIssueManager.visibleIssue {
                SensorHealthBannerView(
                    issue: issue,
                    action: {
                        switch issue.destination {
                        case .sensorManagement:
                            actions.showSensorManagement()
                        case .bluetoothPeripheral:
                            actions.showBluetooth()
                        }
                    },
                    dismiss: sensorHealthIssueManager.dismissVisibleIssue
                )
                .transition(.move(edge: .top).combined(with: .opacity))
            }

            VStack(spacing: Layout.rowSpacing) {
                HStack(spacing: 0) {
                    if state.visibility.showsPump {
                        RootHomePumpView(state: pumpDisplayState)
                            .frame(maxHeight: .infinity)
                    }

                    RootHomeGlucoseReadingView(state: glucoseDisplayState, isScreenLocked: state.isScreenLocked, actions: actions)
                        .frame(maxWidth: .infinity)
                }
                .frame(height: Layout.glucoseStatusRowHeight)

                if state.visibility.showsLoop {
                    RootHomeLoopView(state: loopDisplayState, actions: actions)
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
                }

                lowerStatusContent()
            }
            .frame(maxHeight: .infinity, alignment: .top)
        }
        .padding(.horizontal, Layout.screenHorizontalMargin)
        .frame(maxHeight: .infinity, alignment: .top)
        .animation(.easeOut(duration: 0.22), value: sensorHealthIssueManager.visibleIssue?.id)
    }

    @ViewBuilder private func lowerStatusContent() -> some View {
        VStack(spacing: Layout.bottomRowSpacing) {
            if state.visibility.showsControls {
                RootHomeSelectorView(
                    selectedRange: $selectedRange,
                    statisticsDays: state.controls.statisticsDays,
                    showsStatistics: state.visibility.showsStatistics,
                    onStatisticsDaysChanged: updateStatisticsDays
                )
            }

            if state.visibility.showsStatistics {
                RootHomeStatisticsView(
                    state: state.statistics,
                    action: actions.cycleStatisticsType
                )
            }

            if state.visibility.showsClock {
                RootHomeClockView(text: state.controls.clockText)
            }

            if state.visibility.showsSensor || state.visibility.showsDataSource {
                VStack(spacing: 0) {
                    if state.visibility.showsSensor {
                        RootHomeSensorLifetimeView(state: state.sensor)
                    }

                    if state.visibility.showsDataSource {
                        RootHomeDataSourceView(
                            state: state.dataSource,
                            sensorState: state.sensor,
                            sensorNoiseState: state.sensorNoise,
                            action: actions.hideFollowerUrl
                        )
                    }
                }
            }
        }
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

    private var pumpDisplayState: RootHomePumpState {
        guard !scrollCoordinator.isShowingCurrentTimeRange else {
            return state.pump
        }

        let referenceDate = endDate
        let historicalData = historicalDataCache.selection(at: referenceDate)

        return historicalPumpState(
            stateModel.pumpState(
                deviceStatus: historicalData.deviceStatus?.deviceStatus(),
                latestSiteChangeDate: historicalData.siteChangeDate,
                referenceDate: referenceDate,
                usesRelativeCageTime: false,
                defaultTextColor: ConstantsAppColors.secondaryText
            )
        )
    }

    private var loopDisplayState: RootHomeLoopState {
        guard !scrollCoordinator.isShowingCurrentTimeRange else {
            return state.loop
        }

        let referenceDate = endDate
        guard let snapshot = historicalDataCache.selection(at: referenceDate).deviceStatus else {
            let loopStatusState = LoopStatusState(deviceStatusCreatedAt: nil, lastLoopDate: nil, referenceDate: referenceDate)
            return historicalLoopState(RootHomeLoopState(
                iob: RootHomeMetricState(title: "IOB", value: "- U", valueColor: ConstantsAppColors.secondaryText),
                cob: RootHomeMetricState(title: "COB", value: "- g", valueColor: ConstantsAppColors.secondaryText),
                statusTitle: loopStatusState.title,
                statusSystemImage: loopStatusState.systemImage,
                statusColor: ConstantsAppColors.secondaryText
            ))
        }

        return historicalLoopState(
            stateModel.loopState(
                deviceStatus: snapshot.deviceStatus(),
                referenceDate: referenceDate,
                usesRelativeStatusTime: false,
                defaultTextColor: ConstantsAppColors.secondaryText
            )
        )
    }

    private func historicalPumpState(_ pumpState: RootHomePumpState) -> RootHomePumpState {
        var pumpState = pumpState
        pumpState.isHistorical = true

        return pumpState
    }

    private func historicalLoopState(_ loopState: RootHomeLoopState) -> RootHomeLoopState {
        var loopState = loopState
        loopState.isHistorical = true

        return loopState
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

    private func prepareHistoricalDataIfNeeded(at referenceDate: Date) {
        guard !scrollCoordinator.isShowingCurrentTimeRange else { return }

        historicalDataCache.prepare(
            around: referenceDate,
            visibleTimeInterval: selectedRange.timeInterval
        )
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

// MARK: - Historical Pump and Loop Cache

/// Keeps the historical values used by the pump and loop strips away from SwiftUI's render path.
///
/// Dragging publishes a new chart end date for almost every point moved. Core Data work in a derived
/// view property would therefore run repeatedly while SwiftUI evaluates the same body. This cache
/// loads a buffered range on a serial background queue, then resolves each timestamp from immutable
/// value snapshots already held in memory.
private final class RootHomeHistoricalDataCache: ObservableObject {

    struct Selection {
        let deviceStatus: NightscoutDeviceStatusSnapshot?
        let siteChangeDate: Date?
    }

    private struct Load {
        let startDate: Date
        let endDate: Date
        let siteChangeStartDate: Date?
        let loadsSiteChanges: Bool
        let resetsCache: Bool
        let generation: Int
    }

    @Published private(set) var revision = 0

    private let deviceStatusAccessor: NightscoutDeviceStatusAccessor
    private let treatmentEntryAccessor: TreatmentEntryAccessor
    private let operationQueue = OperationQueue()

    private var deviceStatuses = [NightscoutDeviceStatusSnapshot]()
    private var siteChangeDates = [Date]()
    private var cacheStartDate: Date?
    private var cacheEndDate: Date?
    private var requestedDate: Date?
    private var requestedVisibleTimeInterval: TimeInterval = 0
    private var isLoading = false
    private var generation = 0

    private static let minimumBufferTimeInterval: TimeInterval = .hours(1)
    private static let maximumBufferTimeInterval: TimeInterval = .hours(6)

    init(coreDataManager: CoreDataManager) {
        deviceStatusAccessor = NightscoutDeviceStatusAccessor(coreDataManager: coreDataManager)
        treatmentEntryAccessor = TreatmentEntryAccessor(coreDataManager: coreDataManager)
        operationQueue.maxConcurrentOperationCount = 1
        operationQueue.name = "RootHomeHistoricalDataCache"
    }

    /// Extends the cache only when the requested timestamp approaches an unloaded edge.
    ///
    /// Site changes are initially loaded through the requested range because CAGE may depend on an
    /// entry many days earlier. Later forward extensions fetch only newly possible site changes.
    func prepare(around date: Date, visibleTimeInterval: TimeInterval) {
        requestedDate = date
        requestedVisibleTimeInterval = abs(visibleTimeInterval)

        guard !isLoading else { return }

        let buffer = min(
            max(requestedVisibleTimeInterval * 0.5, Self.minimumBufferTimeInterval),
            Self.maximumBufferTimeInterval
        )
        let desiredStartDate = date.addingTimeInterval(-buffer)
        let desiredEndDate = min(date.addingTimeInterval(buffer), Date())

        let load: Load?

        if let cacheStartDate, let cacheEndDate {
            if desiredEndDate < cacheStartDate || desiredStartDate > cacheEndDate {
                load = Load(startDate: desiredStartDate, endDate: desiredEndDate, siteChangeStartDate: nil, loadsSiteChanges: true, resetsCache: true, generation: generation)
            } else if desiredStartDate < cacheStartDate {
                // The initial site-change fetch already includes every older retained entry.
                load = Load(startDate: desiredStartDate, endDate: cacheStartDate, siteChangeStartDate: nil, loadsSiteChanges: false, resetsCache: false, generation: generation)
            } else if desiredEndDate > cacheEndDate {
                load = Load(startDate: cacheEndDate, endDate: desiredEndDate, siteChangeStartDate: cacheEndDate, loadsSiteChanges: true, resetsCache: false, generation: generation)
            } else {
                load = nil
            }
        } else {
            load = Load(startDate: desiredStartDate, endDate: desiredEndDate, siteChangeStartDate: nil, loadsSiteChanges: true, resetsCache: true, generation: generation)
        }

        guard let load, load.startDate < load.endDate else { return }

        isLoading = true
        let statusStartDate = load.startDate.addingTimeInterval(-ConstantsHomeView.loopShowNoDataAfterMinutes)

        operationQueue.addOperation { [weak self] in
            guard let self else { return }

            let statuses = self.deviceStatusAccessor.fetch(fromDate: statusStartDate, toDate: load.endDate)
            let siteChanges = load.loadsSiteChanges
                ? self.treatmentEntryAccessor.siteChangeDates(
                    fromDate: load.siteChangeStartDate,
                    toDate: load.endDate
                )
                : []

            DispatchQueue.main.async {
                guard self.generation == load.generation else { return }

                if load.resetsCache {
                    self.deviceStatuses = statuses
                    self.siteChangeDates = siteChanges
                    self.cacheStartDate = load.startDate
                    self.cacheEndDate = load.endDate
                } else {
                    self.merge(statuses)
                    self.siteChangeDates = Array(Set(self.siteChangeDates).union(siteChanges)).sorted()
                    self.cacheStartDate = min(self.cacheStartDate ?? load.startDate, load.startDate)
                    self.cacheEndDate = max(self.cacheEndDate ?? load.endDate, load.endDate)
                }

                self.isLoading = false
                self.revision &+= 1

                if let requestedDate = self.requestedDate {
                    self.prepare(
                        around: requestedDate,
                        visibleTimeInterval: self.requestedVisibleTimeInterval
                    )
                }
            }
        }
    }

    /// Resolves both strips from the same cached status snapshot for one selected timestamp.
    func selection(at date: Date) -> Selection {
        let statusIndex = deviceStatuses.lastIndexAtOrBefore(date, date: \.createdAt)
        let status = statusIndex.map { deviceStatuses[$0] }.flatMap {
            $0.createdAt >= date.addingTimeInterval(-ConstantsHomeView.loopShowNoDataAfterMinutes) ? $0 : nil
        }
        let siteChangeIndex = siteChangeDates.lastIndexBefore(date)

        return Selection(
            deviceStatus: status,
            siteChangeDate: siteChangeIndex.map { siteChangeDates[$0] }
        )
    }

    func reset() {
        generation &+= 1
        operationQueue.cancelAllOperations()
        deviceStatuses.removeAll()
        siteChangeDates.removeAll()
        cacheStartDate = nil
        cacheEndDate = nil
        requestedDate = nil
        requestedVisibleTimeInterval = 0
        isLoading = false
        revision &+= 1
    }

    func cleanUpMemory() {
        reset()
    }

    private func merge(_ snapshots: [NightscoutDeviceStatusSnapshot]) {
        var snapshotsByID = [String: NightscoutDeviceStatusSnapshot]()

        for snapshot in deviceStatuses + snapshots {
            snapshotsByID[snapshot.id] = snapshot
        }

        deviceStatuses = snapshotsByID.values.sorted { $0.createdAt < $1.createdAt }
    }
}

private extension Array {
    /// Binary-searches an ascending value-snapshot array without rebuilding filtered copies per frame.
    func lastIndexAtOrBefore(_ targetDate: Date, date: (Element) -> Date) -> Index? {
        var lowerBound = startIndex
        var upperBound = endIndex

        while lowerBound < upperBound {
            let distance = self.distance(from: lowerBound, to: upperBound)
            let middle = index(lowerBound, offsetBy: distance / 2)

            if date(self[middle]) <= targetDate {
                lowerBound = index(after: middle)
            } else {
                upperBound = middle
            }
        }

        return lowerBound == startIndex ? nil : index(before: lowerBound)
    }
}

private extension Array where Element == Date {
    func lastIndexBefore(_ targetDate: Date) -> Index? {
        var lowerBound = startIndex
        var upperBound = endIndex

        while lowerBound < upperBound {
            let distance = self.distance(from: lowerBound, to: upperBound)
            let middle = index(lowerBound, offsetBy: distance / 2)

            if self[middle] < targetDate {
                lowerBound = index(after: middle)
            } else {
                upperBound = middle
            }
        }

        return lowerBound == startIndex ? nil : index(before: lowerBound)
    }
}
