//
//  LiveActivityViewContent.swift
//  xdrip
//
//  Created by Paul Plant on 30/7/25.
//  Copyright © 2025 Johan Degraeve. All rights reserved.
//

import SwiftUI
import WidgetKit

// Standard Lock Screen Live Activity view.
struct LiveActivityViewContent: View {
    @State var context: ActivityViewContext<XDripWidgetAttributes>

    var body: some View {
        LiveActivityViewContentState(state: context.state)
    }
}

/// The production Live Activity layout, separated from `ActivityViewContext` so the main app can
/// show the exact selected presentation in Settings.
struct LiveActivityViewContentState: View {
    let state: XDripWidgetAttributes.ContentState

    var body: some View {
        switch state.liveActivityType {
        case .minimal:
            // Minimal presentation with no chart.
            ZStack {
                HStack(alignment: .center) {
                    Text("\(state.bgValueStringInUserChosenUnit()) \(state.trendArrow())")
                        .font(.largeTitle).bold()
                        .foregroundStyle(state.bgTextColor())
                        .lineLimit(1)
                        .minimumScaleFactor(0.2)

                    Spacer()

                    HStack(alignment: .center, spacing: 12) {
                        deltaAndUnitText(font: .title)
                            .lineLimit(1)
                            .minimumScaleFactor(0.2)

                        if let deviceStatusIconImage = state.deviceStatusIconImage(), let deviceStatusColor = state.deviceStatusColor() {
                            deviceStatusIconImage
                                .font(.title2).bold()
                                .foregroundStyle(deviceStatusColor)
                        }
                    }
                }

                if state.warnUserToOpenApp {
                    openAppWarning("Open app...")
                }
            }
            .activityBackgroundTint(.black)
            .padding([.leading, .trailing], 20)

        case .normal:
            // Normal presentation with compact chart.
            HStack(spacing: 12) {
                VStack(spacing: 0) {
                    Text("\(state.bgValueStringInUserChosenUnit())\(state.trendArrow())")
                        .font(.largeTitle).bold()
                        .foregroundStyle(state.bgTextColor())
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)

                    if let deviceStatusIconImage = state.deviceStatusIconImage(), let deviceStatusColor = state.deviceStatusColor() {
                        HStack(alignment: .center, spacing: 12) {
                            deltaText(font: .title2)
                                .lineLimit(1)
                                .minimumScaleFactor(0.2)

                            deviceStatusIconImage
                                .font(.body).bold()
                                .foregroundStyle(deviceStatusColor)
                        }
                    } else {
                        deltaAndUnitText(font: .title2)
                            .lineLimit(1)
                            .minimumScaleFactor(0.2)
                    }
                }
                .layoutPriority(1)

                GeometryReader { chartGeometry in
                    ZStack {
                        GlucoseChartView(glucoseChartType: .liveActivity, bgReadingValues: state.bgReadingValues, bgReadingDates: state.bgReadingDates, isMgDl: state.isMgDl, urgentLowLimitInMgDl: state.urgentLowLimitInMgDl, lowLimitInMgDl: state.lowLimitInMgDl, highLimitInMgDl: state.highLimitInMgDl, urgentHighLimitInMgDl: state.urgentHighLimitInMgDl, liveActivityType: .normal, hoursToShowScalingHours: nil, glucoseCircleDiameterScalingHours: nil, overrideChartHeight: nil, overrideChartWidth: max(chartGeometry.size.width, 0), highContrast: nil)

                        if state.warnUserToOpenApp {
                            VStack(alignment: .center) {
                                Spacer()
                                openAppWarning("Open \(ConstantsHomeView.applicationName)")
                                Spacer()
                            }
                            .padding(8)
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .padding(.horizontal, 15)
            .frame(maxWidth: .infinity)
            .activityBackgroundTint(.black)
            .padding(.top, 10)
            .padding(.bottom, 10)

        case .large:
            // Detailed presentation with full chart and metadata.
            ZStack {
                VStack(spacing: 0) {
                    HStack(alignment: .center) {
                        Text("\(state.bgValueStringInUserChosenUnit()) \(state.trendArrow())")
                            .font(.largeTitle).fontWeight(.bold)
                            .foregroundStyle(state.bgTextColor())
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)

                        Spacer()

                        HStack(alignment: .center, spacing: 10) {
                            deltaAndUnitText(font: .title)
                                .lineLimit(1)
                                .minimumScaleFactor(0.5)

                            if let deviceStatusIconImage = state.deviceStatusIconImage(), let deviceStatusColor = state.deviceStatusColor() {
                                deviceStatusIconImage
                                    .font(.title3).bold()
                                    .foregroundStyle(deviceStatusColor)
                            }
                        }
                    }
                    .padding(.top, 8)
                    .padding(.bottom, 2)
                    .padding(.leading, 15)
                    .padding(.trailing, 15)

                    GeometryReader { chartGeometry in
                        GlucoseChartView(glucoseChartType: .liveActivity, bgReadingValues: state.bgReadingValues, bgReadingDates: state.bgReadingDates, isMgDl: state.isMgDl, urgentLowLimitInMgDl: state.urgentLowLimitInMgDl, lowLimitInMgDl: state.lowLimitInMgDl, highLimitInMgDl: state.highLimitInMgDl, urgentHighLimitInMgDl: state.urgentHighLimitInMgDl, liveActivityType: .large, hoursToShowScalingHours: nil, glucoseCircleDiameterScalingHours: nil, overrideChartHeight: nil, overrideChartWidth: max(chartGeometry.size.width, 0), highContrast: nil)
                    }
                    .frame(height: ConstantsGlucoseChartSwiftUI.viewHeightLiveActivityLarge)
                    .padding(.horizontal, 15)

                    HStack(alignment: .center, spacing: 8) {
                        if let sensorNoiseIndicatorColor = state.sensorNoiseIndicatorColor() {
                            Circle()
                                .fill(sensorNoiseIndicatorColor)
                                .frame(width: 8, height: 8)
                                .overlay {
                                    Circle()
                                        .stroke(sensorNoiseIndicatorColor.opacity(0.35), lineWidth: 3)
                                }
                        }

                        // Prefer the follower patient name when one is available.
                        Text(state.followerPatientName ?? state.dataSourceDescription)
                            .font(.caption).bold()
                            .foregroundStyle(Color("colorSecondary"))
                            .lineLimit(1)
                            .truncationMode(.tail)

                        Spacer(minLength: 8)

                        Text("Last reading at \(state.bgReadingDate?.formatted(date: .omitted, time: .shortened) ?? "--:--")")
                            .font(.caption)
                            .foregroundStyle(Color("colorSecondary"))
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                    }
                    .padding(.top, 4)
                    .padding(.bottom, 8)
                    .padding(.horizontal, 20)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if state.warnUserToOpenApp {
                    VStack(alignment: .center) {
                        openAppWarning("Please open \(ConstantsHomeView.applicationName)")
                    }
                }
            }
            .activityBackgroundTint(.black)

        case .disabled:
            EmptyView()
        }
    }

    private func deltaText(font: Font) -> Text {
        Text(state.deltaChangeStringInUserChosenUnit())
            .font(font).fontWeight(.semibold)
            .foregroundColor(state.deltaChangeTextColor())
    }

    private func deltaAndUnitText(font: Font) -> Text {
        deltaText(font: font)
            + Text(" \(state.bgUnitString)")
            .font(font)
            .foregroundColor(Color("colorTertiary"))
    }

    private func openAppWarning(_ text: String) -> some View {
        Text(text)
            .font(.footnote).bold()
            .foregroundStyle(.black)
            .multilineTextAlignment(.center)
            .padding(EdgeInsets(top: 6, leading: 10, bottom: 6, trailing: 10))
            .background(.cyan).opacity(0.9)
            .cornerRadius(10)
    }
}
