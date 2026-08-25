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
        static let sectionSpacing: CGFloat = 14
        static let rowSpacing: CGFloat = 9
        static let bottomRowSpacing: CGFloat = 3
        static let screenHorizontalMargin: CGFloat = 12
        static let glucoseStatusRowHeight: CGFloat = 120
        static let nightLockReadoutHeightWidthRatio: CGFloat = 0.50
        static let ipadPortraitNightLockMaximumReadoutWidth: CGFloat = 545
        static let ipadPortraitNightLockReadoutWidthHeightFraction: CGFloat = 0.44
        static let ipadNightLockReadoutSpacing: CGFloat = 48
        static let ipadNightLockReadoutHeightWidthRatio: CGFloat = 0.48
        static let ipadNightLockMaximumReadoutHeight: CGFloat = 300
        static let ipadGlanceCardMinimumHorizontalPadding: CGFloat = 12
        static let ipadGlanceCardHorizontalPadding: CGFloat = 30
        static let ipadGlanceCardMinimumWidthForPadding: CGFloat = 360
        static let ipadGlanceCardPreferredWidthForPadding: CGFloat = 500
        static let ipadGlanceCardSpacing: CGFloat = 42
        static let ipadGlanceCardVerticalPadding: CGFloat = 10
        static let ipadLoopRowSpacing: CGFloat = 6
        static let ipadLoopRowHeight: CGFloat = 34
        static let ipadPumpGlucoseSpacing: CGFloat = 80
        static let ipadMinimumGlucoseReadingWidth: CGFloat = 180
        static let ipadChartExpansionButtonTrailingInset: CGFloat = 52
        static let ipadStatisticsCardVerticalPadding: CGFloat = 30
        static let ipadStatisticsMetricSpacing: CGFloat = 24
        static let ipadStatisticsPieSpacing: CGFloat = 12
        static let ipadStatisticsTextScale: CGFloat = 1.2
        static let ipadPortraitAGPHeight: CGFloat = 280
    }

    /// Settings that affect which cached chart series are included in the main chart state.
    ///
    /// The stored UserDefaults values are observed with `@AppStorage`, but the chart only needs a
    /// manager refresh when the effective renderable series changes, without listening to every
    /// UserDefaults write.
    private struct ChartSeriesSettings: Equatable {
        let showTreatments: Bool
        let showOriginalBGReadings: Bool
        let automaticBasalRenderingStyleRawValue: Int
    }

    // MARK: - State

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ObservedObject private var stateModel: RootHomeStateModel
    @ObservedObject private var sensorHealthIssueManager: SensorHealthIssueManager
    @StateObject private var glucoseChartStateManager: GlucoseChartStateManager
    @StateObject private var miniChartStateManager: GlucoseChartStateManager
    @StateObject private var scrollCoordinator: GlucoseChartScrollCoordinator
    @StateObject private var historicalDataCache: RootHomeHistoricalDataCache

    private let coreDataManager: CoreDataManager
    private let nightscoutSyncManager: NightscoutSyncManager
    @State private var selectedRange: RootHomeChartRange
    @State private var isLoadingChart = false
    @State private var isBackgroundLoadingChart = false
    @State private var showOriginalBGReadingsOnly = false
    @State private var chartYAxisResetRevision = 0
    @State private var showsExpandedIPadChart = false
    @AppStorage(UserDefaults.KeysCharts.chartWidthInHours.rawValue) private var chartWidthInHours = ConstantsGlucoseChart.defaultChartWidthInHours
    @AppStorage(UserDefaults.Key.miniChartHoursToShow.rawValue) private var miniChartHoursToShow = ConstantsGlucoseChart.miniChartHoursToShow1
    @AppStorage(UserDefaults.Key.showTreatmentsOnChart.rawValue) private var hideTreatmentsOnChart = false
    @AppStorage(UserDefaults.Key.showOriginalBGReadings.rawValue) private var hideOriginalBGReadings = false
    @AppStorage(UserDefaults.Key.enableAdjustment.rawValue) private var enableAdjustment = false
    @AppStorage(UserDefaults.Key.enableSmoothing.rawValue) private var enableSmoothing = false
    @AppStorage(UserDefaults.Key.automaticBasalRenderingStyle.rawValue) private var automaticBasalRenderingStyleRawValue = AutomaticBasalRenderingStyle.deliveredDoses.rawValue

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
        self.coreDataManager = coreDataManager
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
            scrollCoordinator.resetToNow()
            chartYAxisResetRevision &+= 1
            if state.usesScreenLockNightLayout {
                applyClockModeState(isEnabled: true)
            } else if UIDevice.current.userInterfaceIdiom != .pad {
                refreshChartRangeFromStoredSettings()
            }
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
        .onReceive(NotificationCenter.default.publisher(for: .nightscoutFollowerGapFillDidMergeHistory)) { _ in
            historicalDataCache.reset()
            prepareHistoricalDataIfNeeded(at: endDate)

            // Normal live-data invalidation reloads only the recent chart-cache tail. Gap fill can
            // insert readings or treatments anywhere in its 72-hour audit window, so discard both
            // chart caches once after a successful merge to make every recovered point visible.
            requestChartState(forceReset: true, showsLoading: false)
            requestMiniChartState(forceReset: true)
        }
        // Home state already reads the current CareLink snapshot during refresh. Ignore each
        // subscription's replay so rebuilding this view cannot start a publish and rebuild loop.
        .onReceive(
            CareLinkAccountState.shared.$snapshot.map(\.pump).removeDuplicates().dropFirst().receive(on: RunLoop.main)
        ) { _ in
            guard UserDefaults.standard.dataFlowPolicy.importsTherapyFromCareLink else { return }
            actions.refreshPumpAndLoopStatus()
        }
        .onReceive(
            CareLinkAccountState.shared.$snapshot.map(\.metadata).removeDuplicates().dropFirst().receive(on: RunLoop.main)
        ) { _ in
            guard !UserDefaults.standard.isMaster,
                  UserDefaults.standard.followerDataSourceType == .careLink
            else { return }
            actions.refreshPumpAndLoopStatus()
        }
        .onReceive(
            CareLinkAccountState.shared.$snapshot.map(\.status).removeDuplicates().dropFirst().receive(on: RunLoop.main)
        ) { _ in
            guard !UserDefaults.standard.isMaster,
                  UserDefaults.standard.followerDataSourceType == .careLink
            else { return }
            actions.refreshPumpAndLoopStatus()
        }
        .onReceive(
            CareLinkAccountState.shared.$snapshot
                .map(\.lastPumpHistoryImportAt)
                .removeDuplicates()
                .dropFirst()
                .receive(on: RunLoop.main)
        ) { date in
            guard date != nil, UserDefaults.standard.dataFlowPolicy.importsTherapyFromCareLink else { return }
            historicalDataCache.reset()
            prepareHistoricalDataIfNeeded(at: endDate)
        }
        .onChange(of: selectedRange) { newRange in
            // Clock Mode temporarily uses its presentation range without replacing the user's
            // stored range.
            if !state.usesScreenLockNightLayout {
                chartWidthInHours = newRange.rawValue
            }
            scrollCoordinator.setVisibleTimeInterval(newRange.timeInterval)
            requestChartState(forceReset: true)
            prepareHistoricalDataIfNeeded(at: endDate)
        }
        .onChange(of: chartWidthInHours) { _ in
            guard !state.usesScreenLockNightLayout else { return }

            refreshChartRangeFromStoredSettings()
        }
        .onChange(of: state.usesScreenLockNightLayout) { isEnabled in
            applyClockModeState(isEnabled: isEnabled)
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
        .fullScreenCover(isPresented: $showsExpandedIPadChart) {
            expandedIPadChart
        }
    }

    @ViewBuilder
    private func rootContent() -> some View {
        if state.usesScreenLockNightLayout {
            GeometryReader { geometry in
                nightLockContent(size: geometry.size)
                    .onAppear {
                        applyClockModeRange(for: geometry.size)
                    }
                    .onChange(of: geometry.size) { newSize in
                        applyClockModeRange(for: newSize)
                    }
            }
        } else if UIDevice.current.userInterfaceIdiom == .pad {
            GeometryReader { geometry in
                Group {
                    if IPadLayoutClass.resolve(
                        isPad: true,
                        width: geometry.size.width,
                        usesAccessibilityText: dynamicTypeSize.isAccessibilitySize
                    ) == .compact {
                        phoneContent()
                    } else {
                        ipadContent(size: geometry.size)
                    }
                }
                .onAppear {
                    applyIPadChartRange(for: geometry.size)
                }
                .onChange(of: geometry.size) { newSize in
                    applyIPadChartRange(for: newSize)
                }
            }
        } else {
            phoneContent()
        }
    }

    /// Keeps the established iPhone Clock Mode hierarchy isolated while giving iPad a horizontal,
    /// equal-width pair of large readouts above the chart.
    @ViewBuilder
    private func nightLockContent(size: CGSize) -> some View {
        if UIDevice.current.userInterfaceIdiom == .pad {
            if size.width > size.height {
                ipadLandscapeNightLockContent(size: size)
            } else {
                ipadPortraitNightLockContent(size: size)
            }
        } else {
            phoneNightLockContent(size: size)
        }
    }

    /// Gives the two iPhone night-time readouts enough height for their oversized fonts to scale to
    /// the complete content width. The chart remains flexible and receives all remaining space.
    private func phoneNightLockContent(size: CGSize) -> some View {
        let contentWidth = max(size.width - (Layout.screenHorizontalMargin * 2), 0)

        return VStack(spacing: Layout.sectionSpacing) {
            homeHeader

            VStack(spacing: Layout.rowSpacing) {
                glucoseStatusRow(
                    spacing: 0,
                    height: contentWidth * Layout.nightLockReadoutHeightWidthRatio
                )

                screenLockMainChart
                    .frame(maxHeight: .infinity)
                    .layoutPriority(1)

                if state.visibility.showsClock {
                    RootHomeClockView(text: state.controls.clockText)
                        .frame(height: contentWidth * Layout.nightLockReadoutHeightWidthRatio)
                }
            }
            .frame(maxHeight: .infinity, alignment: .top)
        }
        .padding(.horizontal, Layout.screenHorizontalMargin)
        .frame(width: size.width, height: size.height, alignment: .top)
        .animation(.easeOut(duration: 0.22), value: sensorHealthIssueManager.visibleIssue?.id)
    }

    /// iPad Clock Mode keeps the same readout components as iPhone, but places glucose and time in
    /// balanced columns that remain readable from a distance. The chart receives all remaining
    /// height and therefore continues to adapt to Stage Manager and split-view resizing.
    private func ipadLandscapeNightLockContent(size: CGSize) -> some View {
        let contentWidth = max(size.width - 40, 0)
        let readoutWidth = max(
            (contentWidth - Layout.ipadNightLockReadoutSpacing) / 2,
            0
        )
        let readoutHeight = min(
            readoutWidth * Layout.ipadNightLockReadoutHeightWidthRatio,
            Layout.ipadNightLockMaximumReadoutHeight
        )

        return VStack(spacing: Layout.sectionSpacing) {
            homeHeader

            VStack(spacing: Layout.rowSpacing) {
                HStack(spacing: Layout.ipadNightLockReadoutSpacing) {
                    RootHomeGlucoseReadingView(
                        state: glucoseDisplayState,
                        isScreenLocked: true,
                        nightLockStatus: nightLockStatus
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                    if state.visibility.showsClock {
                        RootHomeClockView(text: state.controls.clockText)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                .frame(height: readoutHeight)

                screenLockMainChart
                    .frame(maxHeight: .infinity)
                    .layoutPriority(1)
            }
            .frame(maxHeight: .infinity, alignment: .top)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
        .frame(width: size.width, height: size.height, alignment: .top)
        .animation(.easeOut(duration: 0.22), value: sensorHealthIssueManager.visibleIssue?.id)
    }

    /// Portrait keeps the iPhone ordering, but caps each oversized readout to preserve a useful
    /// chart height on iPad and in resizable windows.
    private func ipadPortraitNightLockContent(size: CGSize) -> some View {
        let contentWidth = max(size.width - 40, 0)
        let readoutWidth = min(
            contentWidth,
            Layout.ipadPortraitNightLockMaximumReadoutWidth,
            size.height * Layout.ipadPortraitNightLockReadoutWidthHeightFraction
        )
        let readoutHeight = readoutWidth * Layout.nightLockReadoutHeightWidthRatio

        return VStack(spacing: Layout.sectionSpacing) {
            homeHeader

            VStack(spacing: Layout.rowSpacing) {
                RootHomeGlucoseReadingView(
                    state: glucoseDisplayState,
                    isScreenLocked: true,
                    nightLockStatus: nightLockStatus
                )
                .frame(width: readoutWidth, height: readoutHeight)

                screenLockMainChart
                    .frame(maxHeight: .infinity)
                    .layoutPriority(1)

                if state.visibility.showsClock {
                    RootHomeClockView(text: state.controls.clockText)
                        .frame(width: readoutWidth, height: readoutHeight)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
        .frame(width: size.width, height: size.height, alignment: .top)
        .animation(.easeOut(duration: 0.22), value: sensorHealthIssueManager.visibleIssue?.id)
    }

    /// The original iPhone hierarchy remains isolated here so the tablet composition cannot alter
    /// phone sizing, ordering, or gesture behaviour.
    private func phoneContent() -> some View {
        VStack(spacing: Layout.sectionSpacing) {
            homeHeader

            VStack(spacing: Layout.rowSpacing) {
                glucoseStatusRow

                if state.visibility.showsLoop {
                    RootHomeLoopView(state: loopDisplayState, actions: actions)
                }

                mainChart
                .frame(maxHeight: .infinity)
                .layoutPriority(1)

                if state.visibility.showsMiniChart {
                    miniChart
                }

                lowerStatusContent()
            }
            .frame(maxHeight: .infinity, alignment: .top)
        }
        .padding(.horizontal, Layout.screenHorizontalMargin)
        .frame(maxHeight: .infinity, alignment: .top)
        .animation(.easeOut(duration: 0.22), value: sensorHealthIssueManager.visibleIssue?.id)
    }

    /// The iPad Home screen is a vertical clinical dashboard in every orientation. Rotation only
    /// changes section proportions; it never trades chart width for an independent status rail.
    @ViewBuilder
    private func ipadContent(size: CGSize) -> some View {
        if size.width > size.height {
            ipadLandscapeContent(size: size)
        } else {
            ipadPortraitContent(size: size)
        }
    }

    /// Landscape prioritizes the live glucose timeline. The mini-chart keeps its own intrinsic
    /// height and the main chart receives all remaining vertical space.
    private func ipadLandscapeContent(size: CGSize) -> some View {
        VStack(spacing: 12) {
            homeHeader

            ipadGlanceBand(availableWidth: max(size.width - 40, 0))

            VStack(spacing: Layout.bottomRowSpacing) {
                ipadPreChartStatusContent
            }

            expandableMainChart(showsExpansionButton: true)
                .frame(maxHeight: .infinity)
                .layoutPriority(1)

            if state.visibility.showsMiniChart {
                miniChart
            }

            ipadDataSourceContent
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
        .frame(width: size.width, height: size.height, alignment: .top)
        .animation(.easeOut(duration: 0.22), value: sensorHealthIssueManager.visibleIssue?.id)
    }

    private func ipadPortraitContent(size: CGSize) -> some View {
        VStack(spacing: 16) {
            homeHeader

            ipadGlanceBand(availableWidth: max(size.width - 40, 0))

            VStack(spacing: Layout.bottomRowSpacing) {
                ipadPreChartStatusContent
            }

            expandableMainChart(showsExpansionButton: false)
                .frame(maxHeight: .infinity)
                .layoutPriority(1)

            if state.visibility.showsMiniChart {
                miniChart
            }

            ipadDataSourceContent

            ipadAGP
                .frame(height: Layout.ipadPortraitAGPHeight)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 24)
        .frame(width: size.width, height: size.height, alignment: .top)
        .animation(.easeOut(duration: 0.22), value: sensorHealthIssueManager.visibleIssue?.id)
    }

    private var ipadAGP: some View {
        IPadHomeAGPView(
            coreDataManager: coreDataManager,
            nightscoutSyncManager: nightscoutSyncManager,
            refreshRevision: state.chartRevision
        )
    }

    @ViewBuilder private func ipadGlanceBand(availableWidth: CGFloat) -> some View {
        if availableWidth < 720 || dynamicTypeSize.isAccessibilitySize {
            VStack(spacing: 12) {
                ipadCurrentStatusCard()

                if state.visibility.showsStatistics {
                    ipadStatisticsCard()
                }
            }
        } else {
            let cardWidth = state.visibility.showsStatistics
                ? max((availableWidth - Layout.ipadGlanceCardSpacing) / 2, 0)
                : availableWidth
            let currentStatusHorizontalPadding = ipadGlanceCardHorizontalPadding(for: cardWidth)

            HStack(alignment: .top, spacing: Layout.ipadGlanceCardSpacing) {
                ipadCurrentStatusCard(
                    height: ipadGlanceCardHeight,
                    horizontalPadding: currentStatusHorizontalPadding,
                    pumpGlucoseSpacing: ipadPumpGlucoseSpacing(
                        for: cardWidth,
                        horizontalPadding: currentStatusHorizontalPadding
                    )
                )
                    .frame(width: cardWidth)

                if state.visibility.showsStatistics {
                    ipadStatisticsCard(height: ipadGlanceCardHeight)
                        .frame(width: cardWidth)
                }
            }
        }
    }

    private var ipadGlanceCardHeight: CGFloat {
        let currentStatusHeight = Layout.glucoseStatusRowHeight
            + (Layout.ipadGlanceCardVerticalPadding * 2)
            + (state.visibility.showsLoop ? Layout.ipadLoopRowSpacing + Layout.ipadLoopRowHeight : 0)

        guard state.visibility.showsStatistics else { return currentStatusHeight }

        let statisticsHeight = RootHomeStatisticsView.preferredHeight(
            for: Layout.ipadStatisticsTextScale,
            metricSpacing: Layout.ipadStatisticsMetricSpacing
        )
            + (Layout.ipadStatisticsCardVerticalPadding * 2)

        return max(currentStatusHeight, statisticsHeight)
    }

    private func ipadGlanceCardHorizontalPadding(for cardWidth: CGFloat) -> CGFloat {
        let widthRange = Layout.ipadGlanceCardPreferredWidthForPadding
            - Layout.ipadGlanceCardMinimumWidthForPadding
        let widthProgress = (cardWidth - Layout.ipadGlanceCardMinimumWidthForPadding) / widthRange
        let clampedProgress = min(max(widthProgress, 0), 1)

        return Layout.ipadGlanceCardMinimumHorizontalPadding
            + ((Layout.ipadGlanceCardHorizontalPadding - Layout.ipadGlanceCardMinimumHorizontalPadding) * clampedProgress)
    }

    private func ipadPumpGlucoseSpacing(
        for cardWidth: CGFloat,
        horizontalPadding: CGFloat
    ) -> CGFloat {
        guard state.visibility.showsPump else { return 0 }

        let availableSpacing = cardWidth
            - (horizontalPadding * 2)
            - RootHomePumpView.preferredWidth
            - Layout.ipadMinimumGlucoseReadingWidth

        return min(Layout.ipadPumpGlucoseSpacing, max(availableSpacing, 0))
    }

    private func ipadCurrentStatusCard(
        height: CGFloat? = nil,
        horizontalPadding: CGFloat = Layout.ipadGlanceCardHorizontalPadding,
        pumpGlucoseSpacing: CGFloat = Layout.ipadPumpGlucoseSpacing
    ) -> some View {
        VStack(spacing: Layout.ipadLoopRowSpacing) {
            glucoseStatusRow(spacing: pumpGlucoseSpacing)

            if state.visibility.showsLoop {
                RootHomeLoopView(state: loopDisplayState, actions: actions)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, horizontalPadding)
        .padding(.vertical, Layout.ipadGlanceCardVerticalPadding)
        .frame(maxWidth: .infinity)
        .frame(height: height, alignment: .top)
        .background(ConstantsAppColors.homePanelBackground)
        .clipShape(RoundedRectangle(cornerRadius: ConstantsHomeView.standardCornerRadius, style: .continuous))
    }

    private func ipadStatisticsCard(height: CGFloat? = nil) -> some View {
        RootHomeStatisticsView(
            state: state.statistics,
            statisticsDays: state.controls.statisticsDays,
            statisticsDaysChanged: actions.statisticsDaysChanged,
            action: actions.cycleStatisticsType,
            textScale: Layout.ipadStatisticsTextScale,
            metricSpacing: Layout.ipadStatisticsMetricSpacing,
            pieSpacing: Layout.ipadStatisticsPieSpacing
        )
            .padding(.horizontal, 10)
            .padding(.vertical, Layout.ipadStatisticsCardVerticalPadding)
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .background(ConstantsAppColors.homePanelBackground)
            .clipShape(RoundedRectangle(cornerRadius: ConstantsHomeView.standardCornerRadius, style: .continuous))
    }

    @ViewBuilder private var homeHeader: some View {
        RootHomeToolbarView(
            state: state,
            actions: actions,
            beginOriginalGlucosePeek: beginOriginalGlucosePeek,
            endOriginalGlucosePeek: endOriginalGlucosePeek
        )

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
    }

    private var glucoseStatusRow: some View {
        glucoseStatusRow(spacing: 0)
    }

    private func glucoseStatusRow(
        spacing: CGFloat,
        height: CGFloat = Layout.glucoseStatusRowHeight
    ) -> some View {
        HStack(spacing: spacing) {
            if state.visibility.showsPump {
                RootHomePumpView(state: pumpDisplayState)
                    .frame(maxHeight: .infinity)
            }

            RootHomeGlucoseReadingView(
                state: glucoseDisplayState,
                isScreenLocked: state.usesScreenLockNightLayout,
                nightLockStatus: nightLockStatus
            )
            .frame(maxWidth: .infinity)
        }
        .frame(height: height)
    }

    private var mainChart: some View {
        configuredMainChart(
            chartState: visibleChartState,
            showsTreatments: true
        )
    }

    /// Every full Clock Mode presentation uses the same treatment-free chart. The normal Home chart
    /// remains preference-driven and returns immediately when the screen is unlocked.
    private var screenLockMainChart: some View {
        configuredMainChart(
            chartState: visibleChartState,
            showsTreatments: false
        )
    }

    private func configuredMainChart(
        chartState: GlucoseChartState,
        showsTreatments: Bool
    ) -> some View {
        RootHomeMainChartView(
            selectedRange: $selectedRange,
            showsTreatments: showsTreatments,
            chartState: chartState,
            isLoading: isLoadingChart,
            scrollCoordinator: scrollCoordinator,
            yAxisResetRevision: chartYAxisResetRevision,
            updateChartStateIfNeeded: requestChartStateIfNeeded,
            finishChartScroll: { forceReset, showsLoading in
                if forceReset {
                    chartYAxisResetRevision &+= 1
                }
                requestChartState(forceReset: forceReset, showsLoading: showsLoading)
            }
        )
        // Clock Mode is a current-status display. Prevent dragging, pinching and double-tapping
        // the main chart until the user unlocks it.
        .allowsHitTesting(!state.usesScreenLockNightLayout)
    }

    private func expandableMainChart(showsExpansionButton: Bool) -> some View {
        mainChart
            .overlay(alignment: .topTrailing) {
                if showsExpansionButton {
                    Button {
                        showsExpandedIPadChart = true
                    } label: {
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                            .font(.system(size: 14, weight: .semibold))
                            .frame(width: 36, height: 36)
                            .background(.ultraThinMaterial, in: Circle())
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(ConstantsAppColors.navigationTint)
                    .padding(.top, 8)
                    .padding(.trailing, Layout.ipadChartExpansionButtonTrailingInset)
                    .accessibilityLabel(Texts_HomeView.expandChart)
                }
            }
    }

    private var miniChart: some View {
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

    private var statisticsContent: some View {
        RootHomeStatisticsView(
            state: state.statistics,
            statisticsDays: state.controls.statisticsDays,
            statisticsDaysChanged: actions.statisticsDaysChanged,
            action: actions.cycleStatisticsType
        )
    }

    @ViewBuilder private var ipadPreChartStatusContent: some View {
        if state.visibility.showsClock {
            RootHomeClockView(text: state.controls.clockText)
        }
    }

    @ViewBuilder private var ipadDataSourceContent: some View {
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

    private var expandedIPadChart: some View {
        NavigationStack {
            IPadExpandedLandscapeChartView(
                coreDataManager: coreDataManager,
                nightscoutSyncManager: nightscoutSyncManager
            )
                .navigationTitle(Texts_Common.statisticsAmbulatoryGlucoseProfile)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button(Texts_Common.dismiss) {
                            showsExpandedIPadChart = false
                        }
                        .tint(ConstantsAppColors.toolbarAction)
                    }
                }
        }
        .colorScheme(.dark)
    }

    @ViewBuilder private func lowerStatusContent() -> some View {
        VStack(spacing: Layout.bottomRowSpacing) {
            if state.visibility.showsStatistics {
                RootHomeStatisticsView(
                    state: state.statistics,
                    statisticsDays: state.controls.statisticsDays,
                    statisticsDaysChanged: actions.statisticsDaysChanged,
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

    /// Uses the same point on the historical timeline for glucose, pump and loop presentation.
    ///
    /// The chart window includes space after its newest visible glucose point. Selecting pump and
    /// loop data from that padded edge can incorrectly expire an otherwise valid status record.
    /// Anchoring every historical strip to the latest visible reading keeps the display independent
    /// of the service that originally supplied the normalized Core Data entries.
    private var historicalReferenceDate: Date {
        latestVisibleReadingAtChartEndDate()?.date ?? endDate
    }

    private var pumpDisplayState: RootHomePumpState {
        guard !scrollCoordinator.isShowingCurrentTimeRange else {
            return state.pump
        }

        // Establish an explicit SwiftUI dependency on asynchronous cache completion.
        _ = historicalDataCache.revision
        let referenceDate = historicalReferenceDate
        let historicalData = historicalDataCache.selection(at: referenceDate)

        return historicalPumpState(
            stateModel.pumpState(
                deviceStatus: historicalData.deviceStatus,
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

        // Pump and loop must refresh together when the shared historical cache finishes loading.
        _ = historicalDataCache.revision
        let referenceDate = historicalReferenceDate
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
                deviceStatus: snapshot,
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
        stateModel.historicalLoopState(
            loopState,
            aidAnalyticsSource: UserDefaults.standard.dataFlowPolicy.aidAnalyticsSource
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
        ChartSeriesSettings(
            showTreatments: showTreatments,
            showOriginalBGReadings: showOriginalBGReadings,
            automaticBasalRenderingStyleRawValue: automaticBasalRenderingStyleRawValue
        )
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

    /// Applies every main-chart transition for Clock Mode in one place.
    ///
    /// When enabled:
    /// 1. Select the established temporary three-hour range without changing UserDefaults. The
    ///    active iPad landscape geometry overrides this with five hours.
    /// 2. Return the chart to `now()` and cancel any active scrolling or deceleration.
    /// 3. Chart gestures are disabled declaratively by `mainChart` while the same mode is active.
    ///
    /// When disabled, the user's stored range and normal chart interaction are restored.
    private func applyClockModeState(isEnabled: Bool) {
        if isEnabled {
            if selectedRange != .threeHours {
                selectedRange = .threeHours
            }

            resetMainChartToNow()
        } else {
            refreshChartRangeFromStoredSettings()
        }
    }

    /// Rotation and Stage Manager resizing can change Clock Mode presentation without toggling the
    /// lock itself, so the temporary range follows the live iPad geometry.
    private func applyClockModeRange(for size: CGSize) {
        guard size.width > 0, size.height > 0 else { return }

        let range: RootHomeChartRange = UIDevice.current.userInterfaceIdiom == .pad && size.width > size.height
            ? .fiveHours
            : .threeHours

        if selectedRange != range {
            selectedRange = range
        }
    }

    private func refreshChartRangeFromStoredSettings() {
        let range = RootHomeChartRange.closest(to: chartWidthInHours == 0 ? ConstantsGlucoseChart.defaultChartWidthInHours : chartWidthInHours)

        if chartWidthInHours != range.rawValue {
            chartWidthInHours = range.rawValue
        }

        if range != selectedRange {
            selectedRange = range
        }
    }

    private var nightLockStatus: RootHomeLoopState? {
        guard state.usesScreenLockNightLayout,
              state.loop.statusSystemImage != nil || state.loop.showsActivityIndicator
        else { return nil }

        return state.loop
    }

    private func applyIPadChartRange(for size: CGSize) {
        guard size.width > 0, size.height > 0 else { return }

        let orientationRange: RootHomeChartRange = size.width > size.height ? .twentyFourHours : .twelveHours
        guard selectedRange != orientationRange else { return }

        selectedRange = orientationRange
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
        resetMainChartToNow()
        requestMiniChartState(forceReset: false, refreshCachedData: true)
    }

    private func resetMainChartToNow() {
        scrollCoordinator.resetToNow()
        chartYAxisResetRevision &+= 1
        requestChartState(forceReset: false, showsLoading: false, refreshCachedData: true)
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

/// Owns the landscape analytics state for one expanded iPad chart presentation.
private struct IPadExpandedLandscapeChartView: View {
    @StateObject private var stateModel: LandscapeChartStateModel

    init(coreDataManager: CoreDataManager, nightscoutSyncManager: NightscoutSyncManager) {
        _stateModel = StateObject(wrappedValue: LandscapeChartStateModel(
            coreDataManager: coreDataManager,
            nightscoutSyncManager: nightscoutSyncManager
        ))
    }

    var body: some View {
        LandscapeChartView(stateModel: stateModel, presentation: .expandedIPad)
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
        let deviceStatus: NightscoutDeviceStatus?
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
        let oldestAllowedDate = date.addingTimeInterval(-ConstantsHomeView.loopShowNoDataAfterMinutes)
        var statusIndex = deviceStatuses.lastIndexAtOrBefore(date, date: \.createdAt)

        // The buffered range is loaded asynchronously. Resolve its first requested point directly
        // so the strips do not remain blank until another chart movement causes a redraw.
        let dateIsOutsideCache = cacheStartDate.map { date < $0 } ?? true
            || cacheEndDate.map { date > $0 } ?? true
        if statusIndex == nil, dateIsOutsideCache || isLoading {
            merge(deviceStatusAccessor.fetch(fromDate: oldestAllowedDate, toDate: date))
            statusIndex = deviceStatuses.lastIndexAtOrBefore(date, date: \.createdAt)
        }

        let status: NightscoutDeviceStatus?
        if let statusIndex, deviceStatuses[statusIndex].createdAt >= oldestAllowedDate {
            let firstRelevantIndex = deviceStatuses.firstIndexAtOrAfter(oldestAllowedDate, date: \.createdAt)
                ?? statusIndex
            let newestFirst = deviceStatuses[firstRelevantIndex ... statusIndex]
                .reversed()
                .map { $0.deviceStatus() }
            status = NightscoutDeviceStatus.composingDisplayValues(fromNewestFirst: newestFirst)
        } else {
            status = nil
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
    /// Binary-searches an ascending value-snapshot array for its first value at or after a date.
    func firstIndexAtOrAfter(_ targetDate: Date, date: (Element) -> Date) -> Index? {
        var lowerBound = startIndex
        var upperBound = endIndex

        while lowerBound < upperBound {
            let distance = self.distance(from: lowerBound, to: upperBound)
            let middle = index(lowerBound, offsetBy: distance / 2)

            if date(self[middle]) < targetDate {
                lowerBound = index(after: middle)
            } else {
                upperBound = middle
            }
        }

        return lowerBound == endIndex ? nil : lowerBound
    }

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
