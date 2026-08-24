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

/// The compact production layout used by supplemental activity families such as CarPlay.
@available(iOS 18.0, *)
struct LiveActivityViewContentActivityFamiliesState: View {
    let state: XDripWidgetAttributes.ContentState
    
    var body: some View {
        ZStack {
            AccessoryWidgetBackground()
                .cornerRadius(8)
            
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.black.opacity(0.4))
            
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
                    
                    Spacer()

                    HStack(alignment: .center, spacing: 6) {
                        Text("\(state.bgReadingDate?.formatted(date: .omitted, time: .shortened) ?? "--:--")")
                            .font(.subheadline)
                            .foregroundStyle(Color("colorTertiary"))
                            .minimumScaleFactor(0.2)

                        if let deviceStatusIconImage = state.deviceStatusIconImage(), let deviceStatusColor = state.deviceStatusColor() {
                            deviceStatusIconImage
                                .font(.headline).bold()
                                .foregroundStyle(deviceStatusColor)
                        }
                    }
                    .padding(.trailing, 10)
                }
                .padding(.top, 4)

                // use the height left below the header so the chart adapts to each activity family
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
        .activityBackgroundTint(.clear)
    }
}
