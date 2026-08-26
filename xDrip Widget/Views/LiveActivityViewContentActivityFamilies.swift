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
                            if let iob = aidStatus.iob {
                                metricText(
                                    label: "IOB: ",
                                    value: "\(iob.formatted(.number.precision(.fractionLength(1))))U"
                                )
                            }

                            if let cob = aidStatus.cob {
                                metricText(
                                    label: "COB: ",
                                    value: "\(cob.formatted(.number.precision(.fractionLength(0))))g"
                                )
                            }

                            deviceStatusIcon
                        }
                        .font(.footnote.bold())
                        .lineLimit(1)
                        .minimumScaleFactor(0.65)
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

            HStack(alignment: .center, spacing: 8) {
                Text("\(state.bgValueStringInUserChosenUnit()) \(state.trendArrow())")
                    .font(.system(size: fontSize, weight: .bold))
                    .foregroundStyle(state.bgTextColor())
                    .lineLimit(1)
                    .minimumScaleFactor(0.25)
                    .layoutPriority(1)

                Spacer(minLength: 0)

                Text(state.deltaChangeStringInUserChosenUnit())
                    .font(.system(size: fontSize, weight: .bold))
                    .foregroundStyle(state.deltaChangeTextColor())
                    .lineLimit(1)
                    .minimumScaleFactor(0.25)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .padding(.horizontal, 8)
    }

    @ViewBuilder
    private var deviceStatusIcon: some View {
        if let deviceStatusIconImage = state.deviceStatusIconImage(), let deviceStatusColor = state.deviceStatusColor() {
            deviceStatusIconImage
                .font(.headline.bold())
                .foregroundStyle(deviceStatusColor)
        }
    }

    private func metricText(label: String, value: String) -> Text {
        Text(label)
            .foregroundColor(Color("colorSecondary"))
            + Text(value)
            .foregroundColor(Color("colorPrimary"))
    }
}
