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

            switch carPlayLiveActivityType {
            case .chart:
                chartContent
            case .basic:
                basicContent
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
                    if let aidStatus = state.aidStatus {
                        HStack(alignment: .center, spacing: 8) {
                            if aidStatus.iob != nil || aidStatus.cob != nil {
                                aidMetrics(iob: aidStatus.iob, cob: aidStatus.cob)
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
    private var deviceStatusIcon: some View {
        if let deviceStatusIconImage = state.deviceStatusIconImage(), let deviceStatusColor = state.deviceStatusColor() {
            deviceStatusIconImage
                .font(.headline.bold())
                .foregroundStyle(deviceStatusColor)
        }
    }

    private func aidMetrics(iob: Double?, cob: Double?) -> some View {
        // Keep both metrics at the same size while adapting to the limited CarPlay width.
        ViewThatFits(in: .horizontal) {
            aidMetricsRow(iob: iob, cob: cob, font: .footnote)
            aidMetricsRow(iob: iob, cob: cob, font: .system(size: 12))
            aidMetricsRow(iob: iob, cob: cob, font: .system(size: 11))
            aidMetricsRow(iob: iob, cob: cob, font: .system(size: 10))
            aidMetricsRow(iob: iob, cob: cob, font: .system(size: 9))
        }
    }

    private func aidMetricsRow(iob: Double?, cob: Double?, font: Font) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            if let iob {
                aidMetric(
                    value: iob.formatted(.number.precision(.fractionLength(1))),
                    unit: "U",
                    font: font
                )
            }

            if let cob {
                aidMetric(
                    value: cob.formatted(.number.precision(.fractionLength(0))),
                    unit: "g",
                    font: font
                )
            }
        }
        .fixedSize(horizontal: true, vertical: false)
    }

    private func aidMetric(value: String, unit: String, font: Font) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 2) {
            Text(value)
                .fontWeight(.bold)

            Text(unit)
        }
        .font(font)
        .foregroundColor(Color("colorSecondary"))
    }
}
