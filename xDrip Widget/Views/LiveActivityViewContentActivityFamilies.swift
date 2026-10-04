//
//  LiveActivityViewContentActivityFamilies.swift
//  xdrip
//
//  Created by Paul Plant on 29/7/25.
//  Copyright © 2025 Johan Degraeve. All rights reserved.
//

import SwiftUI
import WidgetKit

// this is the newer live activity view which is used for >=iOS18 and uses the activity family to
// correctly show the view in Smart Stack and CarPlay if possible (>=iOS26)
@available(iOS 18.0, *)
struct LiveActivityViewContentActivityFamilies: View {
    @State var context: ActivityViewContext<XDripWidgetAttributes>

    var body: some View {
        LiveActivityViewContentActivityFamiliesState(
            state: context.state
        )
    }
}

/// The compact layout used by the small supplemental family in CarPlay and Apple Watch.
@available(iOS 18.0, *)
struct LiveActivityViewContentActivityFamiliesState: View {
    let state: XDripWidgetAttributes.ContentState

    private var carPlayLiveActivityType: CarPlayLiveActivityType {
        state.carPlayLiveActivityType ?? .chart
    }

    var body: some View {
        ZStack {
            AccessoryWidgetBackground()
                .cornerRadius(8)

            RoundedRectangle(cornerRadius: 8)
                .fill(Color.black.opacity(0.4))

            if state.showsSensorWarmupStatus, let endDate = state.sensorWarmupEndDate {
                GeometryReader { geometry in
                    LiveActivitySensorWarmupView(endDate: endDate, waitingForReading: state.isWaitingForSensorReading, compactWidth: geometry.size.width)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            } else {
                switch carPlayLiveActivityType {
                case .chart:
                    chartContent
                case .basic:
                    basicContent
                }
            }
        }
        .activityBackgroundTint(.clear)
    }

    private var chartContent: some View {
        VStack(spacing: 3) {
            HStack(alignment: .center) {
                HStack(alignment: .center, spacing: 3) {
                    Text("\(state.bgValueStringInUserChosenUnit())\(state.trendArrow()) ")
                        .font(.headline)
                        .foregroundStyle(state.bgTextColor())

                    Text(state.deltaChangeStringInUserChosenUnit())
                        .font(.subheadline)
                        .foregroundStyle(state.deltaChangeTextColor())
                        .lineLimit(1)
                }
                .padding(.leading, 10)

                Spacer(minLength: 6)

                Group {
                    if state.aidStatus != nil || state.showsTherapyMetrics {
                        HStack(alignment: .center, spacing: 8) {
                            if state.showsTherapyMetrics {
                                aidMetrics()
                            }

                            deviceStatusIcon
                        }
                        .lineLimit(1)
                    } else {
                        HStack(alignment: .center, spacing: 6) {
                            Text("\(state.bgReadingDate?.formatted(date: .omitted, time: .shortened) ?? "--:--")")
                                .font(.subheadline)
                                .foregroundStyle(Color("colorTertiary"))
                                .minimumScaleFactor(0.2)

                            deviceStatusIcon
                        }
                    }
                }
                .padding(.trailing, 10)
            }
            .padding(.top, 4)

            // Use the space below the header so the chart adapts to the available height.
            GeometryReader { chartGeometry in
                GlucoseChartView(
                    glucoseChartType: .watchAccessoryRectangular,
                    bgReadingValues: state.bgReadingValues,
                    bgReadingDates: state.bgReadingDates,
                    isMgDl: state.isMgDl,
                    urgentLowLimitInMgDl: state.urgentLowLimitInMgDl,
                    lowLimitInMgDl: state.lowLimitInMgDl,
                    highLimitInMgDl: state.highLimitInMgDl,
                    urgentHighLimitInMgDl: state.urgentHighLimitInMgDl,
                    liveActivityType: nil,
                    hoursToShowScalingHours: 4,
                    glucoseCircleDiameterScalingHours: 5,
                    overrideChartHeight: chartGeometry.size.height,
                    overrideChartWidth: max(chartGeometry.size.width - 20, 0),
                    highContrast: nil
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            }
        }
    }

    private var basicContent: some View {
        GeometryReader { geometry in
            let fontSize = max(geometry.size.height * 0.76, 1)

            basicReadingText
                .font(.system(size: fontSize, weight: .bold))
                .lineLimit(1)
                .minimumScaleFactor(0.1)
                .allowsTightening(true)
                .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .padding(.horizontal, 12)
    }

    private var basicReadingText: Text {
        Text("\(state.bgValueStringInUserChosenUnit()) \(state.trendArrow())")
            .foregroundColor(state.bgTextColor())
            + Text("\u{2003}\(state.deltaChangeStringInUserChosenUnit())")
            .foregroundColor(state.deltaChangeTextColor())
    }

    @ViewBuilder
    // CarPlay and Smart Stack share this view. Keep the symbol at 15 pt while the shared renderer
    // supplies black weight for circle-based symbols and retains bold for the other AID symbols.
    private var deviceStatusIcon: some View {
        if let deviceStatusIconImage = state.deviceStatusIconImage(), let deviceStatusColor = state.deviceStatusColor() {
            deviceStatusIconImage
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(deviceStatusColor)
        }
    }

    private func aidMetrics() -> some View {
        // Keep both metrics at the same size while adapting to the limited CarPlay width.
        ViewThatFits(in: .horizontal) {
            aidMetricsRow(font: .system(size: 15))
            aidMetricsRow(font: .system(size: 14))
            aidMetricsRow(font: .footnote)
            aidMetricsRow(font: .system(size: 12))
            aidMetricsRow(font: .system(size: 11))
            aidMetricsRow(font: .system(size: 10))
            aidMetricsRow(font: .system(size: 9))
        }
    }

    private func aidMetricsRow(font: Font) -> some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            let metrics = state.resolvedTherapyMetrics
            HStack(alignment: .center, spacing: 12) {
                if metrics.iob.isVisible(at: context.date) {
                    let iobValue = metrics.iob.value(at: context.date)?.formatted(.number.precision(.fractionLength(1))) ?? "-"
                    aidMetric(value: iobValue, unit: "U", font: font)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(metrics.iob.accessibilityName(isIOB: true))
                        .accessibilityValue("\(iobValue) U")
                }
                if metrics.cob.isVisible(at: context.date) {
                    aidMetric(value: metrics.cob.number(isIOB: false, at: context.date), unit: "g", font: font)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(metrics.cob.accessibilityName(isIOB: false))
                        .accessibilityValue(metrics.cob.formatted(isIOB: false, at: context.date))
                }
            }
            .fixedSize(horizontal: true, vertical: false)
            .lineLimit(1)
        }
    }

    private func aidMetric(value: String, unit: String, font: Font) -> some View {
        HStack(alignment: .center, spacing: 1) {
            Text(value)
                .fontWeight(.regular)

            Text(unit)
        }
        .font(font)
        .foregroundColor(Color("colorSecondary"))
    }
}
