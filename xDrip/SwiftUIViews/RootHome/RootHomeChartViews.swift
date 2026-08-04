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
    let selectedRange: RootHomeChartRange
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
