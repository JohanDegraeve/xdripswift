//
//  XDripWidgetLiveActivity.swift
//  XDripWidget
//
//  Created by Paul Plant on 29/12/23.
//  Copyright © 2023 Johan Degraeve. All rights reserved.
//

import ActivityKit
import SwiftUI
import WidgetKit

struct XDripWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: XDripWidgetAttributes.self) { context in
            
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
                        
                        HStack {
                            Text(context.state.dataSourceDescription)
                                .font(.caption).bold()
                                .foregroundStyle(.colorSecondary)
                            
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
            
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) { Text("\(context.state.bgValueStringInUserChosenUnit())\(context.state.trendArrow())")
                    .font(.largeTitle).bold()
                    .foregroundStyle(context.state.bgTextColor())
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    .lineLimit(1)
                    .minimumScaleFactor(0.2)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        if let deviceStatusIconImage = context.state.deviceStatusIconImage(), let deviceStatusColor = context.state.deviceStatusColor() {
                            HStack(alignment: .center, spacing: 10) {
                                Text(context.state.deltaChangeStringInUserChosenUnit())
                                    .font(.title).fontWeight(.semibold)
                                    .foregroundStyle(context.state.deltaChangeTextColor())
                                    .minimumScaleFactor(0.2)
                                
                                deviceStatusIconImage
                                    .font(.title2).bold()
                                    .foregroundStyle(deviceStatusColor)
                            }
                        } else {
                            HStack(alignment: .firstTextBaseline, spacing: 4) {
                                Text(context.state.deltaChangeStringInUserChosenUnit())
                                    .font(.title).fontWeight(.semibold)
                                    .foregroundStyle(context.state.deltaChangeTextColor())
                                
                                Text(context.state.bgUnitString)
                                    .font(.title)
                                    .foregroundStyle(.colorSecondary)
                            }
                        }
                    }
                    .lineLimit(1)
                    .minimumScaleFactor(0.2)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    GlucoseChartView(glucoseChartType: .dynamicIsland, bgReadingValues: context.state.bgReadingValues, bgReadingDates: context.state.bgReadingDates, isMgDl: context.state.isMgDl, urgentLowLimitInMgDl: context.state.urgentLowLimitInMgDl, lowLimitInMgDl: context.state.lowLimitInMgDl, highLimitInMgDl: context.state.highLimitInMgDl, urgentHighLimitInMgDl: context.state.urgentHighLimitInMgDl, liveActivityType: nil, hoursToShowScalingHours: nil, glucoseCircleDiameterScalingHours: nil, overrideChartHeight: nil, overrideChartWidth: nil, highContrast: nil)
                }
            } compactLeading: {
                Text("\(context.state.bgValueStringInUserChosenUnit())\(context.state.trendArrow())")
                    .foregroundStyle(context.state.bgTextColor())
                    .minimumScaleFactor(0.2)
            } compactTrailing: {
                if let deviceStatusIconImage = context.state.deviceStatusIconImage(), let deviceStatusColor = context.state.deviceStatusColor() {
                    deviceStatusIconImage
                        .bold()
                        .foregroundStyle(deviceStatusColor)
                        .minimumScaleFactor(0.2)
                } else {
                    Text(context.state.deltaChangeStringInUserChosenUnit())
                        .foregroundStyle(context.state.deltaChangeTextColor())
                        .minimumScaleFactor(0.2)
                }
            } minimal: {
                Text("\(context.state.bgValueStringInUserChosenUnit())")
                    .foregroundStyle(context.state.bgTextColor())
                    .minimumScaleFactor(0.2)
            }
            .widgetURL(URL(string: "xdripswift"))
            .keylineTint(context.state.bgTextColor())
        }
    }
}

struct XDripWidgetLiveActivity_Previews: PreviewProvider {
    // generate some random dates for the preview
    static func bgDateArray() -> [Date] {
        let endDate = Date()
        let startDate = endDate.addingTimeInterval(-3600 * 12)
        var currentDate = startDate
        
        var dateArray: [Date] = []
        
        while currentDate < endDate {
            dateArray.append(currentDate)
            currentDate = currentDate.addingTimeInterval(60 * 5)
        }
        return dateArray
    }
    
    // generate some random bg values for the preview
    static func bgValueArray() -> [Double] {
        var bgValueArray: [Double] = Array(repeating: 0, count: 144)
        var currentValue: Double = 100
        var increaseValues = true
        
        for index in bgValueArray.indices {
            let randomValue = Double(Int.random(in: -10 ..< 10))
            
            if currentValue < 80 {
                increaseValues = true
                bgValueArray[index] = currentValue + abs(randomValue)
            } else if currentValue > 160 {
                increaseValues = false
                bgValueArray[index] = currentValue - abs(randomValue)
            } else {
                bgValueArray[index] = currentValue + (increaseValues ? randomValue : -randomValue)
            }
            currentValue = bgValueArray[index]
        }
        return bgValueArray
    }
    
    static let attributes = XDripWidgetAttributes()
    
    static let contentState = XDripWidgetAttributes.ContentState(bgReadingValues: bgValueArray(), bgReadingDates: bgDateArray(), isMgDl: true, slopeOrdinal: 5, deltaValueInUserUnit: -2, urgentLowLimitInMgDl: 70, lowLimitInMgDl: 80, highLimitInMgDl: 140, urgentHighLimitInMgDl: 180, liveActivityType: .large, dataSourceDescription: "Dexcom G6", deviceStatusCreatedAt: Date().addingTimeInterval(-300), deviceStatusLastLoopDate: Date().addingTimeInterval(-230))
    
    static var previews: some View {
        attributes
            .previewContext(contentState, viewKind: .content)
            .previewDisplayName("Notification")
        attributes
            .previewContext(contentState, viewKind: .dynamicIsland(.compact))
            .previewDisplayName("Compact")
        attributes
            .previewContext(contentState, viewKind: .dynamicIsland(.expanded))
            .previewDisplayName("Expanded")
        attributes
            .previewContext(contentState, viewKind: .dynamicIsland(.minimal))
            .previewDisplayName("Minimal")
    }
}
