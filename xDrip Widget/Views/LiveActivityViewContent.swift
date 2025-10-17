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
        if context.state.liveActivityType == .minimal {
            // 1 = minimal widget with no chart
            HStack(alignment: .center) {
                Text("\(context.state.bgValueStringInUserChosenUnit()) \(context.state.trendArrow())")
                    .font(.largeTitle).bold()
                    .foregroundStyle(context.state.bgTextColor())
                    .lineLimit(1)
                    .minimumScaleFactor(0.2)
                
                Spacer()
                
                if context.state.warnUserToOpenApp {
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
                        Text(context.state.deltaChangeStringInUserChosenUnit())
                            .font(.title).fontWeight(.semibold)
                            .foregroundStyle(context.state.deltaChangeTextColor())
                            .lineLimit(1)
                            .minimumScaleFactor(0.2)
                        
                        Text(context.state.bgUnitString)
                            .font(.title)
                            .foregroundStyle(.colorTertiary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.2)
                    }
                    
                    if let deviceStatusIconImage = context.state.deviceStatusIconImage(), let deviceStatusColor = context.state.deviceStatusColor() {
                        deviceStatusIconImage
                            .font(.title2).bold()
                            .foregroundStyle(deviceStatusColor)
                    }
                }
            }
            .activityBackgroundTint(.black)
            .padding([.top, .bottom], 0)
            .padding([.leading, .trailing], 20)
            
        } else if context.state.liveActivityType == .normal {
            // 0 = normal size chart
            HStack(spacing: 30) {
                VStack(spacing: 0) {
                    Text("\(context.state.bgValueStringInUserChosenUnit())\(context.state.trendArrow())")
                        .font(.largeTitle).bold()
                        .foregroundStyle(context.state.bgTextColor())
                        .lineLimit(1)
                        .minimumScaleFactor(0.2)
                    
                    HStack(alignment: .center, spacing: 8) {
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text(context.state.deltaChangeStringInUserChosenUnit())
                                .font(.title2).fontWeight(.semibold)
                                .foregroundStyle(context.state.deltaChangeTextColor())
                                .lineLimit(1)
                                .minimumScaleFactor(0.2)
                            
                            if let deviceStatusIconImage = context.state.deviceStatusIconImage(), let deviceStatusColor = context.state.deviceStatusColor() {
                                deviceStatusIconImage
                                    .font(.body).bold()
                                    .foregroundStyle(deviceStatusColor)
                            } else {
                                Text(context.state.bgUnitString)
                                    .font(.title2)
                                    .foregroundStyle(.colorTertiary)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.2)
                            }
                        }
                    }
                }
                
                ZStack {
                    GlucoseChartView(glucoseChartType: .liveActivity, bgReadingValues: context.state.bgReadingValues, bgReadingDates: context.state.bgReadingDates, isMgDl: context.state.isMgDl, urgentLowLimitInMgDl: context.state.urgentLowLimitInMgDl, lowLimitInMgDl: context.state.lowLimitInMgDl, highLimitInMgDl: context.state.highLimitInMgDl, urgentHighLimitInMgDl: context.state.urgentHighLimitInMgDl, liveActivityType: .normal, hoursToShowScalingHours: nil, glucoseCircleDiameterScalingHours: nil, overrideChartHeight: nil, overrideChartWidth: nil, highContrast: nil)
                    
                    if context.state.warnUserToOpenApp {
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
                        Text("\(context.state.bgValueStringInUserChosenUnit()) \(context.state.trendArrow())")
                            .font(.largeTitle).fontWeight(.bold)
                            .foregroundStyle(context.state.bgTextColor())
                            .scaledToFill()
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                        
                        Spacer()
                        
                        HStack(alignment: .center, spacing: 10) {
                            HStack(alignment: .firstTextBaseline, spacing: 4) {
                                Text(context.state.deltaChangeStringInUserChosenUnit())
                                    .font(.title).fontWeight(.semibold)
                                    .foregroundStyle(context.state.deltaChangeTextColor())
                                    .lineLimit(1)
                                
                                Text(context.state.bgUnitString)
                                    .font(.title)
                                    .foregroundStyle(.colorTertiary)
                                    .lineLimit(1)
                            }
                            
                            if let deviceStatusIconImage = context.state.deviceStatusIconImage(), let deviceStatusColor = context.state.deviceStatusColor() {
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
                    
                    GlucoseChartView(glucoseChartType: .liveActivity, bgReadingValues: context.state.bgReadingValues, bgReadingDates: context.state.bgReadingDates, isMgDl: context.state.isMgDl, urgentLowLimitInMgDl: context.state.urgentLowLimitInMgDl, lowLimitInMgDl: context.state.lowLimitInMgDl, highLimitInMgDl: context.state.highLimitInMgDl, urgentHighLimitInMgDl: context.state.urgentHighLimitInMgDl, liveActivityType: .large, hoursToShowScalingHours: nil, glucoseCircleDiameterScalingHours: nil, overrideChartHeight: nil, overrideChartWidth: nil, highContrast: nil)
                    
                    HStack(alignment: .center) {
                        // if we're in follower mode and a patient name exists, let's use it with preference over the data source     
                        Text(context.state.followerPatientName ?? context.state.dataSourceDescription)
                            .font(.caption).bold()
                            .foregroundStyle(.colorSecondary)
                            .padding(.trailing, -4)
                        
                        Spacer()
                        
                        Text("Last reading at \(context.state.bgReadingDate?.formatted(date: .omitted, time: .shortened) ?? "--:--")")
                            .font(.caption)
                            .foregroundStyle(.colorSecondary)
                    }
                    .padding(.top, 6)
                    .padding(.bottom, 10)
                    .padding(.leading, 15)
                    .padding(.trailing, 15)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(0)
                
                if context.state.warnUserToOpenApp {
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


