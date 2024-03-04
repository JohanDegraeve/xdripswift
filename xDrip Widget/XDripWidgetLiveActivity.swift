//
//  XDripWidgetLiveActivity.swift
//  XDripWidget
//
//  Created by Paul Plant on 29/12/23.
//  Copyright © 2023 Johan Degraeve. All rights reserved.
//

import ActivityKit
import WidgetKit
import SwiftUI

@available(iOSApplicationExtension 16.2, *)
struct XDripWidgetLiveActivity: Widget {
    
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: XDripWidgetAttributes.self) { context in
            
            if context.state.liveActivitySize == .minimal {
                
                // 1 = minimal widget with no chart
                HStack(alignment: .center) {
                    Text("\(context.state.bgValueStringInUserChosenUnit)\(context.state.trendArrow())")
                        .font(.system(size: 35)).fontWeight(.semibold)
                        .foregroundStyle(context.state.bgTextColor())
                        .minimumScaleFactor(0.1)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    if context.state.warnUserToOpenApp {
                        Text("Ending soon...")
                            .font(.footnote).bold()
                            .foregroundStyle(.black)
                            .multilineTextAlignment(.center)
                            .padding(EdgeInsets(top: 6, leading: 10, bottom: 6, trailing: 10))
                            .background(.cyan).opacity(0.9)
                            .cornerRadius(10)
                        
                        Spacer()
                    }
                    
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(context.state.deltaChangeStringInUserChosenUnit())
                            .font(.title).bold()
                            .foregroundStyle(Color(white: 0.9))
                            .minimumScaleFactor(0.2)
                            .lineLimit(1)
                        
                        Text(context.state.bgUnitString)
                            .font(.title)
                            .foregroundStyle(Color(white: 0.5))
                            .minimumScaleFactor(0.2)
                            .lineLimit(1)
                    }
                }
                .activityBackgroundTint(.black)
                .padding([.top, .bottom], 0)
                .padding([.leading, .trailing], 20)
                
            } else if context.state.liveActivitySize == .normal {
                
                // 0 = normal size chart
                HStack(spacing: 20) {
                    VStack {
                        Text("\(context.state.bgValueStringInUserChosenUnit)\(context.state.trendArrow())")
                            .font(.system(size: 50)).fontWeight(.semibold)
                            .foregroundStyle(context.state.bgTextColor())
                            .minimumScaleFactor(0.1)
                            .lineLimit(1)
                        
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text(context.state.deltaChangeStringInUserChosenUnit())
                                .font(.system(size: 25)).bold()
                                .foregroundStyle(Color(white: 0.9))
                                .minimumScaleFactor(0.2)
                                .lineLimit(1)
                            
                            Text(context.state.bgUnitString)
                                .font(.system(size: 25))
                                .foregroundStyle(Color(white: 0.5))
                                .minimumScaleFactor(0.2)
                                .lineLimit(1)
                        }
                    }
                    .padding(2)
                    
                    ZStack {
                        GlucoseChartView(glucoseChartType: .liveActivity, bgReadingValues: context.state.bgReadingValues, bgReadingDates: context.state.bgReadingDates, isMgDl: context.state.isMgDl, urgentLowLimitInMgDl: context.state.urgentLowLimitInMgDl, lowLimitInMgDl: context.state.lowLimitInMgDl, highLimitInMgDl: context.state.highLimitInMgDl, urgentHighLimitInMgDl: context.state.urgentHighLimitInMgDl, liveActivitySize: .normal, hoursToShowScalingHours: nil, glucoseCircleDiameterScalingHours: nil)
                        
                        if context.state.warnUserToOpenApp {
                            VStack(alignment: .center) {
                                Spacer()
                                Text("Activity ending soon")
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
                .padding(4)
                
            } else {
                
                // 3 = large chart is final default option
                ZStack {
                    VStack {
                            if context.state.showClockAtNight {
                                HStack(alignment: .firstTextBaseline) {
                                    Text(Date().formatted(date: .omitted, time: .shortened))
                                        .font(.system(size: 50)).bold()
                                        .foregroundStyle(Color(white: 0.7))
                                        .minimumScaleFactor(0.2)
                                    
                                    Spacer()
                                    
                                    
                                    Text("\(context.state.bgValueStringInUserChosenUnit)\(context.state.trendArrow()) ")
                                        .font(.system(size: 50)).bold()
                                        .foregroundStyle(context.state.bgTextColor())
                                }
                                .padding(.top, 4)
                                .padding(.bottom, -14)
                                .padding(.leading, 6)
                                .padding(.trailing, 6)
                            } else {
                                HStack(alignment: .center) {
                                    Text("\(context.state.bgValueStringInUserChosenUnit)\(context.state.trendArrow()) ")
                                        .font(.largeTitle).bold()
                                        .foregroundStyle(context.state.bgTextColor())
                                    
                                    Spacer()
                                    
                                    HStack(alignment: .center, spacing: 4) {
                                        Text(context.state.deltaChangeStringInUserChosenUnit())
                                            .font(.title2).bold()
                                            .foregroundStyle(Color(white: 0.9))
                                            .minimumScaleFactor(0.2)
                                            .lineLimit(1)
                                        
                                        Text(context.state.bgUnitString)
                                            .font(.title2)
                                            .foregroundStyle(Color(white: 0.5))
                                            .minimumScaleFactor(0.2)
                                            .lineLimit(1)
                                    }
                                }
                                .padding(.top, 4)
                                .padding(.bottom, -8)
                                .padding(.leading, 10)
                                .padding(.trailing, 10)
                            }
                        
                        GlucoseChartView(glucoseChartType: .liveActivity, bgReadingValues: context.state.bgReadingValues, bgReadingDates: context.state.bgReadingDates, isMgDl: context.state.isMgDl, urgentLowLimitInMgDl: context.state.urgentLowLimitInMgDl, lowLimitInMgDl: context.state.lowLimitInMgDl, highLimitInMgDl: context.state.highLimitInMgDl, urgentHighLimitInMgDl: context.state.urgentHighLimitInMgDl, liveActivitySize: .large, hoursToShowScalingHours: nil, glucoseCircleDiameterScalingHours: nil)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(0)
                    
                    if context.state.warnUserToOpenApp {
                        VStack(alignment: .center) {
                            Text("Live activity ending soon")
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
                DynamicIslandExpandedRegion(.leading) {                    Text("\(context.state.bgValueStringInUserChosenUnit)\(context.state.trendArrow())")
                        .font(.largeTitle).bold()
                        .foregroundStyle(context.state.bgTextColor())
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                        .minimumScaleFactor(0.1)
                        .lineLimit(1)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(context.state.deltaChangeStringInUserChosenUnit())
                            .font(.title).bold()
                            .foregroundStyle(Color(white: 0.9))
                            .minimumScaleFactor(0.2)
                            .lineLimit(1)
                        
                        Text(context.state.bgUnitString)
                            .font(.title)
                            .foregroundStyle(Color(white: 0.5))
                            .minimumScaleFactor(0.2)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    GlucoseChartView(glucoseChartType: .dynamicIsland, bgReadingValues: context.state.bgReadingValues, bgReadingDates: context.state.bgReadingDates, isMgDl: context.state.isMgDl, urgentLowLimitInMgDl: context.state.urgentLowLimitInMgDl, lowLimitInMgDl: context.state.lowLimitInMgDl, highLimitInMgDl: context.state.highLimitInMgDl, urgentHighLimitInMgDl: context.state.urgentHighLimitInMgDl, liveActivitySize: nil, hoursToShowScalingHours: nil, glucoseCircleDiameterScalingHours: nil)
                }
            } compactLeading: {
                Text("\(context.state.bgValueStringInUserChosenUnit)\(context.state.trendArrow())")
                    .foregroundStyle(context.state.bgTextColor())
                    .minimumScaleFactor(0.1)
            } compactTrailing: {
                Text(context.state.deltaChangeStringInUserChosenUnit())
                    .minimumScaleFactor(0.1)
            } minimal: {
                Text("\(context.state.bgValueStringInUserChosenUnit)")
                    .foregroundStyle(context.state.bgTextColor())
                    .minimumScaleFactor(0.1)
            }
            .widgetURL(URL(string: "xdripswift"))
            .keylineTint(context.state.bgTextColor())
        }
    }
}

@available(iOS 16.2, *)
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
        var bgValueArray:[Double] = Array(repeating: 0, count: 144)
        var currentValue: Double = 100
        var increaseValues: Bool = true
        
        for index in bgValueArray.indices {
            let randomValue = Double(Int.random(in: -10..<10))
            
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
    
    static let contentState = XDripWidgetAttributes.ContentState(bgReadingValues: bgValueArray(), bgReadingDates: bgDateArray(), isMgDl: true, slopeOrdinal: 5, deltaChangeInMgDl: -2, urgentLowLimitInMgDl: 70, lowLimitInMgDl: 80, highLimitInMgDl: 140, urgentHighLimitInMgDl: 180, showClockAtNight: false, liveActivitySize: .minimal)
    
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

