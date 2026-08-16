//
//  RootHomeChartViews.swift
//  xdrip
//
//  Created by Paul Plant on 22/7/26.
//  Copyright © 2026 Johan Degraeve. All rights reserved.
//

import SwiftUI

/// Main interactive chart with loading state and the reading shown at the panned end date.
struct RootHomeMainChartView: View {
    @Binding var selectedRange: RootHomeChartRange
    let showsTreatments: Bool
    let chartState: GlucoseChartState
    let isLoading: Bool
    let scrollCoordinator: GlucoseChartScrollCoordinator
    let yAxisResetRevision: Int
    let updateChartStateIfNeeded: () -> Void
    let finishChartScroll: (_ forceReset: Bool, _ showsLoading: Bool) -> Void

    @State private var showsRangeOverlay = false
    @State private var hideRangeOverlayWorkItem: DispatchWorkItem?
    @State private var hasUpdatedRangeDuringPinch = false

    private enum Layout {
        static let rangeOverlayTopInset: CGFloat = 8
        static let rangeOverlayHorizontalPadding: CGFloat = 10
        static let rangeOverlayVerticalPadding: CGFloat = 5
        static let rangeOverlayFontSize: CGFloat = 16
        static let rangeOverlayMinimumWidth: CGFloat = 70
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .top) {
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
                    showsTreatments: showsTreatments,
                    overrideChartHeight: geometry.size.height,
                    overrideChartWidth: geometry.size.width,
                    highContrast: nil,
                    chartState: chartState
                )
                .mainChartYAxisContext(
                    resetRevision: yAxisResetRevision
                )
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
                .simultaneousGesture(
                    MagnificationGesture()
                        .onChanged(updateRange)
                        .onEnded { _ in
                            hasUpdatedRangeDuringPinch = false
                        }
                )
                .clipped()

                if showsRangeOverlay {
                    HStack(spacing: 4) {
                        Text("\(Int(selectedRange.rawValue))")
                            .fontWeight(.semibold)
                            .monospacedDigit()
                        Text(Texts_Common.hours)
                    }
                    .font(.system(size: Layout.rangeOverlayFontSize))
                    .foregroundStyle(ConstantsAppColors.secondaryText)
                    .frame(minWidth: Layout.rangeOverlayMinimumWidth)
                    .padding(.horizontal, Layout.rangeOverlayHorizontalPadding)
                    .padding(.vertical, Layout.rangeOverlayVerticalPadding)
                    .background(
                        ConstantsAppColors.homePanelBackground,
                        in: RoundedRectangle(cornerRadius: ConstantsHomeView.standardCornerRadius, style: .continuous)
                    )
                    .padding(.top, Layout.rangeOverlayTopInset)
                    .allowsHitTesting(false)
                    .accessibilityElement(children: .combine)
                }

                if isLoading {
                    ProgressView()
                        .padding(8)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                        .allowsHitTesting(false)
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .topLeading)
        }
        .onDisappear {
            hideRangeOverlayWorkItem?.cancel()
            hideRangeOverlayWorkItem = nil
        }
    }

    private func updateRange(magnification: CGFloat) {
        guard !hasUpdatedRangeDuringPinch else { return }

        let threshold = ConstantsHomeView.mainChartZoomMagnificationThreshold
        let newRange: RootHomeChartRange?

        // One pinch changes one range step as soon as it crosses the deliberate threshold.
        if magnification >= 1 + threshold {
            newRange = selectedRange.nextShorterRange
        } else if magnification <= 1 - threshold {
            newRange = selectedRange.nextLongerRange
        } else {
            newRange = nil
        }

        guard let newRange else { return }

        hasUpdatedRangeDuringPinch = true
        selectedRange = newRange
        showRangeOverlay()
    }

    private func showRangeOverlay() {
        hideRangeOverlayWorkItem?.cancel()

        var transaction = Transaction()
        transaction.animation = nil
        withTransaction(transaction) {
            showsRangeOverlay = true
        }

        // Restart the delayed fade whenever another successful pinch selects a range.
        let workItem = DispatchWorkItem {
            withAnimation(.easeOut(duration: ConstantsHomeView.mainChartZoomOverlayFadeDuration)) {
                showsRangeOverlay = false
            }
        }
        hideRangeOverlayWorkItem = workItem
        DispatchQueue.main.asyncAfter(
            deadline: .now() + ConstantsHomeView.mainChartZoomOverlayVisibleDuration,
            execute: workItem
        )
    }
}

/// Historical overview chart and the active main-chart window.
struct RootHomeMiniChartView: View {
    let miniChartHoursToShow: Double
    let chartState: GlucoseChartState
    let scrollCoordinator: GlucoseChartScrollCoordinator
    let updateChartStateIfNeeded: () -> Void
    let finishChartScroll: () -> Void
    let cycleMiniChartHoursToShow: () -> Void

    /// `nil` until a new drag is classified. The result is then held for the whole gesture because
    /// the active window moves away from its original touch point during a valid drag.
    @State private var activeWindowDragIsEnabled: Bool?

    private enum Layout {
        static let chartHeight: CGFloat = 60
    }

    var body: some View {
        GeometryReader { geometry in
            let overviewStartDate = chartState.startDate
            let edgeInsetTimeInterval = overviewEdgeInsetTimeInterval(chartWidth: geometry.size.width)
            let renderedOverviewEndDate = chartState.endDate.addingTimeInterval(edgeInsetTimeInterval)

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
                                activeWindowDragIsEnabled = activeWindowContains(
                                    xPosition: value.startLocation.x,
                                    chartWidth: geometry.size.width,
                                    overviewStartDate: overviewStartDate,
                                    overviewEndDate: renderedOverviewEndDate
                                )
                            }

                            guard activeWindowDragIsEnabled == true else { return }

                            scrollCoordinator.updateVisibleRangeFromOverview(
                                value: value,
                                overviewStartDate: overviewStartDate,
                                overviewEndDate: renderedOverviewEndDate,
                                leadingEdgeInsetTimeInterval: edgeInsetTimeInterval,
                                chartWidth: geometry.size.width
                            )
                            updateChartStateIfNeeded()
                        }
                        .onEnded { value in
                            let shouldFinishDrag = activeWindowDragIsEnabled ?? activeWindowContains(
                                xPosition: value.startLocation.x,
                                chartWidth: geometry.size.width,
                                overviewStartDate: overviewStartDate,
                                overviewEndDate: renderedOverviewEndDate
                            )
                            activeWindowDragIsEnabled = nil

                            guard shouldFinishDrag else { return }

                            scrollCoordinator.finishUpdatingVisibleRangeFromOverview(
                                value: value,
                                overviewStartDate: overviewStartDate,
                                overviewEndDate: renderedOverviewEndDate,
                                leadingEdgeInsetTimeInterval: edgeInsetTimeInterval,
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
        .frame(height: Layout.chartHeight)
    }

    /// Converts the active window's dates into the same extended coordinate space used to render
    /// the mini-chart, so only touches that begin within the visible window can move it.
    private func activeWindowContains(
        xPosition: CGFloat,
        chartWidth: CGFloat,
        overviewStartDate: Date,
        overviewEndDate: Date
    ) -> Bool {
        guard chartWidth > 0,
              let activeWindowStartDate = chartState.overlayWindowStartDate,
              let activeWindowEndDate = chartState.overlayWindowEndDate,
              activeWindowStartDate < activeWindowEndDate else {
            return false
        }

        let overviewTimeInterval = overviewEndDate.timeIntervalSince(overviewStartDate)
        let visibleActiveStartDate = max(activeWindowStartDate, overviewStartDate)
        let visibleActiveEndDate = min(activeWindowEndDate, overviewEndDate)

        guard overviewTimeInterval > 0, visibleActiveStartDate < visibleActiveEndDate else { return false }

        let activeStartX = CGFloat(visibleActiveStartDate.timeIntervalSince(overviewStartDate) / overviewTimeInterval) * chartWidth
        let activeEndX = CGFloat(visibleActiveEndDate.timeIntervalSince(overviewStartDate) / overviewTimeInterval) * chartWidth

        return xPosition >= activeStartX && xPosition <= activeEndX
    }

    /// Uses one time-equivalent inset for both rounded corners without changing chart data. The
    /// trailing span protects the `now` edge. The overview-only clamp protects the leading edge.
    private func overviewEdgeInsetTimeInterval(chartWidth: CGFloat) -> TimeInterval {
        let visibleTimeInterval = chartState.endDate.timeIntervalSince(chartState.startDate)
        return ConstantsGlucoseChartSwiftUI.miniChartEdgeInsetTimeInterval(
            visibleTimeInterval: visibleTimeInterval,
            chartWidth: chartWidth
        )
    }
}
