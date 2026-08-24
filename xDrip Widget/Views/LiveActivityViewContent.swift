//
//  LiveActivityViewContent.swift
//  xdrip
//
//  Created by Paul Plant on 30/7/25.
//  Copyright © 2025 Johan Degraeve. All rights reserved.
//

import SwiftUI
import WidgetKit

// this is the standard live activity view
struct LiveActivityViewContent : View {
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
        if state.liveActivityType == .minimal {
            // 1 = minimal widget with no chart
            HStack(alignment: .center) {
                Text("\(state.bgValueStringInUserChosenUnit()) \(state.trendArrow())")
                    .font(.largeTitle).bold()
                    .foregroundStyle(state.bgTextColor())
                    .lineLimit(1)
                    .minimumScaleFactor(0.2)
                
                Spacer()
                
                if state.warnUserToOpenApp {
                    Text("Open app...")
                        .font(.footnote).bold()
                        .foregroundStyle(.black)
                        .multilineTextAlignment(.center)
                        .padding(EdgeInsets(top: 6, leading: 10, bottom: 6, trailing: 10))
                        .background(.cyan).opacity(0.9)
                        .cornerRadius(10)
                    
                    Spacer()
                }
                
                HStack(alignment: .center, spacing: 12) {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(state.deltaChangeStringInUserChosenUnit())
                            .font(.title).fontWeight(.semibold)
                            .foregroundStyle(state.deltaChangeTextColor())
                            .lineLimit(1)
                            .minimumScaleFactor(0.2)
                        
                        Text(state.bgUnitString)
                            .font(.title)
                            .foregroundStyle(Color("colorTertiary"))
                            .lineLimit(1)
                            .minimumScaleFactor(0.2)
                    }
                    
                    if let deviceStatusIconImage = state.deviceStatusIconImage(), let deviceStatusColor = state.deviceStatusColor() {
                        deviceStatusIconImage
                            .font(.title2).bold()
                            .foregroundStyle(deviceStatusColor)
                    }
                }
            }
            .activityBackgroundTint(.black)
            .padding([.top, .bottom], 0)
            .padding([.leading, .trailing], 20)
            
        } else if state.liveActivityType == .normal {
            // 0 = normal size chart
            HStack(spacing: 30) {
                VStack(spacing: 0) {
                    Text("\(state.bgValueStringInUserChosenUnit())\(state.trendArrow())")
                        .font(.largeTitle).bold()
                        .foregroundStyle(state.bgTextColor())
                        .lineLimit(1)
                        .minimumScaleFactor(0.2)
                    
                    HStack(alignment: .center, spacing: 8) {
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text(state.deltaChangeStringInUserChosenUnit())
                                .font(.title2).fontWeight(.semibold)
                                .foregroundStyle(state.deltaChangeTextColor())
                                .lineLimit(1)
                                .minimumScaleFactor(0.2)
                            
                            if let deviceStatusIconImage = state.deviceStatusIconImage(), let deviceStatusColor = state.deviceStatusColor() {
                                deviceStatusIconImage
                                    .font(.body).bold()
                                    .foregroundStyle(deviceStatusColor)
                            } else {
                                Text(state.bgUnitString)
                                    .font(.title2)
                                    .foregroundStyle(Color("colorTertiary"))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.2)
                            }
                        }
                    }
                }
                
                ZStack {
                    GlucoseChartView(glucoseChartType: .liveActivity, bgReadingValues: state.bgReadingValues, bgReadingDates: state.bgReadingDates, isMgDl: state.isMgDl, urgentLowLimitInMgDl: state.urgentLowLimitInMgDl, lowLimitInMgDl: state.lowLimitInMgDl, highLimitInMgDl: state.highLimitInMgDl, urgentHighLimitInMgDl: state.urgentHighLimitInMgDl, liveActivityType: .normal, hoursToShowScalingHours: nil, glucoseCircleDiameterScalingHours: nil, overrideChartHeight: nil, overrideChartWidth: nil, highContrast: nil)
                    
                    if state.warnUserToOpenApp {
                        VStack(alignment: .center) {
                            Spacer()
                            Text("Open \(ConstantsHomeView.applicationName)")
                                .font(.footnote).bold()
                                .foregroundStyle(.black)
                                .multilineTextAlignment(.center)
                                .padding(EdgeInsets(top: 6, leading: 10, bottom: 6, trailing: 10))
                                .background(.cyan).opacity(0.9)
                                .cornerRadius(10)
                            Spacer()
                        }
                        .padding(8)
                    }
                }
            }
            .activityBackgroundTint(.black)
            .padding(.top, 10)
            .padding(.bottom, 10)
            
        } else {
            // 3 = large chart is final default option
            ZStack {
                VStack(spacing: 0) {
                    HStack(alignment: .center) {
                        Text("\(state.bgValueStringInUserChosenUnit()) \(state.trendArrow())")
                            .font(.largeTitle).fontWeight(.bold)
                            .foregroundStyle(state.bgTextColor())
                            .scaledToFill()
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                        
                        Spacer()
                        
                        HStack(alignment: .center, spacing: 10) {
                            HStack(alignment: .firstTextBaseline, spacing: 4) {
                                Text(state.deltaChangeStringInUserChosenUnit())
                                    .font(.title).fontWeight(.semibold)
                                    .foregroundStyle(state.deltaChangeTextColor())
                                    .lineLimit(1)
                                
                                Text(state.bgUnitString)
                                    .font(.title)
                                    .foregroundStyle(Color("colorTertiary"))
                                    .lineLimit(1)
                            }
                            
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
                    
                    GlucoseChartView(glucoseChartType: .liveActivity, bgReadingValues: state.bgReadingValues, bgReadingDates: state.bgReadingDates, isMgDl: state.isMgDl, urgentLowLimitInMgDl: state.urgentLowLimitInMgDl, lowLimitInMgDl: state.lowLimitInMgDl, highLimitInMgDl: state.highLimitInMgDl, urgentHighLimitInMgDl: state.urgentHighLimitInMgDl, liveActivityType: .large, hoursToShowScalingHours: nil, glucoseCircleDiameterScalingHours: nil, overrideChartHeight: nil, overrideChartWidth: nil, highContrast: nil)
                    
                    HStack(alignment: .center) {
                        if let sensorNoiseIndicatorColor = state.sensorNoiseIndicatorColor() {
                            Circle()
                                .fill(sensorNoiseIndicatorColor)
                                .frame(width: 8, height: 8)
                                .overlay {
                                    Circle()
                                        .stroke(sensorNoiseIndicatorColor.opacity(0.35), lineWidth: 3)
                                }
                        }

                        // if we're in follower mode and a patient name exists, let's use it with preference over the data source     
                        Text(state.followerPatientName ?? state.dataSourceDescription)
                            .font(.caption).bold()
                            .foregroundStyle(Color("colorSecondary"))
                            .padding(.trailing, -4)
                        
                        Spacer()
                        
                        Text("Last reading at \(state.bgReadingDate?.formatted(date: .omitted, time: .shortened) ?? "--:--")")
                            .font(.caption)
                            .foregroundStyle(Color("colorSecondary"))
                    }
                    .padding(.top, 6)
                    .padding(.bottom, 10)
                    .padding(.leading, 15)
                    .padding(.trailing, 15)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(0)
                
                if state.warnUserToOpenApp {
                    VStack(alignment: .center) {
                        Text("Please open \(ConstantsHomeView.applicationName)")
                            .font(.footnote).bold()
                            .foregroundStyle(.black)
                            .multilineTextAlignment(.center)
                            .padding(EdgeInsets(top: 6, leading: 10, bottom: 6, trailing: 10))
                            .background(.cyan).opacity(0.9)
                            .cornerRadius(10)
                    }
                }
            }
            .activityBackgroundTint(.black)
        }
    }
}
