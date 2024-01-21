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
    
    let glucoseChartWidgetType: GlucoseChartWidgetType = .dynamicIsland
    
    var body: some WidgetConfiguration {
        
        ActivityConfiguration(for: XDripWidgetAttributes.self) { context in
            
            LiveActivityView(state: context.state)
            
        } dynamicIsland: { context in
            
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {                    Text("\(context.state.bgValueStringInUserChosenUnit)\(context.state.trendArrow())")
                        .font(.largeTitle).bold()
                        .foregroundStyle(context.state.getBgColor())
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    context.state.deltaChangeFormatted(font: .title2)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    
                    GlucoseChartView(bgReadingValues: context.state.bgReadingValues, bgReadingDates: context.state.bgReadingDates, glucoseChartWidgetType: glucoseChartWidgetType, isMgDl: context.state.isMgDl, urgentLowLimitInMgDl: context.state.urgentLowLimitInMgDl, lowLimitInMgDl: context.state.lowLimitInMgDl, highLimitInMgDl: context.state.highLimitInMgDl, urgentHighLimitInMgDl: context.state.urgentHighLimitInMgDl, liveActivityNotificationSizeType: LiveActivityNotificationSizeType(rawValue: context.state.liveActivityNotificationSizeTypeAsInt) ?? .normal)
                    
                }
            } compactLeading: {
                Text("\(context.state.bgValueStringInUserChosenUnit)\(context.state.trendArrow())")
                    .foregroundStyle(context.state.getBgColor())
            } compactTrailing: {
                Text(context.state.getDeltaChangeStringInUserChosenUnit())
            } minimal: {
                Text(context.state.bgValueStringInUserChosenUnit)
                    .foregroundStyle(context.state.getBgColor())
            }
            .widgetURL(URL(string: "xdripswift"))
            .keylineTint(context.state.getBgColor())
        }
        
    }
    
}

@available(iOSApplicationExtension 16.2, *)
struct LiveActivityView: View {
    
    let state: XDripWidgetAttributes.ContentState
    let glucoseChartWidgetType: GlucoseChartWidgetType = .liveActivityNotification
    
    var body: some View {
        // Lock screen/banner UI goes here
        
        if state.liveActivityNotificationSizeTypeAsInt == 0 {
            // 0 = normal size chart
            
            HStack(spacing: 20) {
                VStack(spacing: 10) {
                    Text("\(state.bgValueStringInUserChosenUnit)\(state.trendArrow())")
                        .font(.largeTitle).bold()
                        .foregroundStyle(state.getBgColor())
                    
                    state.deltaChangeFormatted(font: .title2)
                }
                
                GlucoseChartView(bgReadingValues: state.bgReadingValues, bgReadingDates: state.bgReadingDates, glucoseChartWidgetType: glucoseChartWidgetType, isMgDl: state.isMgDl, urgentLowLimitInMgDl: state.urgentLowLimitInMgDl, lowLimitInMgDl: state.lowLimitInMgDl, highLimitInMgDl: state.highLimitInMgDl, urgentHighLimitInMgDl: state.urgentHighLimitInMgDl, liveActivityNotificationSizeType: LiveActivityNotificationSizeType(rawValue: state.liveActivityNotificationSizeTypeAsInt) ?? .normal)
                
            }
            .activityBackgroundTint(.black)
            .padding(10)
            
        } else if state.liveActivityNotificationSizeTypeAsInt == 1 {
            // 1 = minimal widget with no chart
            
            HStack {
                
                Text("\(state.bgValueStringInUserChosenUnit)\(state.trendArrow())")
                    .font(.largeTitle).bold()
                    .foregroundStyle(state.getBgColor())
                
                Spacer()
                
                if let bgTitle = state.getBgTitle() {
                    Text(bgTitle)
                        .foregroundStyle(state.getBgColor())
                        .font(.title2).bold()
                        .multilineTextAlignment(.center)
                }
                
                Spacer()
                
                state.deltaChangeFormatted(font: .title2)
            }
            .activityBackgroundTint(.black)
            .padding(15)
            
        } else {
            // 2 = large widget with no chart
            
            HStack(spacing: 10) {
                VStack(spacing: 10) {
                    Text("\(state.bgValueStringInUserChosenUnit)\(state.trendArrow())")
                        .font(.title).bold()
                        .foregroundStyle(state.getBgColor())
                    
                    state.deltaChangeFormatted(font: .title3)
                    
                    if let bgTitle = state.getBgTitle() {
                        Text(bgTitle)
                            .foregroundStyle(state.getBgColor())
                            .font(.subheadline).bold()
                            .multilineTextAlignment(.center)
                    }
                }
                
                GlucoseChartView(bgReadingValues: state.bgReadingValues, bgReadingDates: state.bgReadingDates, glucoseChartWidgetType: glucoseChartWidgetType, isMgDl: state.isMgDl, urgentLowLimitInMgDl: state.urgentLowLimitInMgDl, lowLimitInMgDl: state.lowLimitInMgDl, highLimitInMgDl: state.highLimitInMgDl, urgentHighLimitInMgDl: state.urgentHighLimitInMgDl, liveActivityNotificationSizeType: LiveActivityNotificationSizeType(rawValue: state.liveActivityNotificationSizeTypeAsInt) ?? .normal)
                
            }
            .activityBackgroundTint(.black)
            .padding(10)
        }
    }
}

@available(iOS 16.2, *)
struct XDripWidgetLiveActivity_Previews: PreviewProvider {
    
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
    
    static func bgValueArray() -> [Double] {
        
        var bgValueArray:[Double] = Array(repeating: 0, count: 144)
        var currentValue: Double = 100
        var increaseValues: Bool = true
        
        for index in bgValueArray.indices {
            
            if currentValue < 70 {
                increaseValues = true
            } else if currentValue > 180 {
                increaseValues = false
            }
            
            let randomValue = Double(Int.random(in: 0..<20))
            bgValueArray[index] = currentValue + (increaseValues ? randomValue : -randomValue)
            currentValue = bgValueArray[index]
        }
        
        return bgValueArray
        
    }
    
    
    static let attributes = XDripWidgetAttributes(eventStartDate: Date().addingTimeInterval(-1000))
    
    static let contentState = XDripWidgetAttributes.ContentState(bgReadingValues: bgValueArray(), bgReadingDates: bgDateArray(), isMgDl: true, slopeOrdinal:5, deltaChangeInMgDl: -2, urgentLowLimitInMgDl: 70, lowLimitInMgDl: 80, highLimitInMgDl: 140, urgentHighLimitInMgDl: 180, updatedDate: Date(), liveActivityNotificationSizeTypeAsInt: 2)
    
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

